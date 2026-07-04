---
title: "Day 29 — LoRA / QLoRA / PEFT: 효율적 파인튜닝"
date: 2026-08-01
weight: 29
---

> **Phase 12: 파인튜닝** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 전체 파인튜닝(Full Fine-Tuning)이 왜 비용/메모리 측면에서 비현실적인지 설명할 수 있다
- LoRA의 저랭크 어댑터 원리와 QLoRA가 여기에 4비트 양자화를 더하는 이유를 이해한다
- PEFT 라이브러리로 LoRA 파인튜닝을 실행하고 어댑터를 베이스 모델에 병합할 수 있다

---

## 1. 전체 파인튜닝(Full Fine-Tuning)이 비싼 이유

전체 파인튜닝은 사전학습된 모델의 **모든 파라미터**를 학습 대상으로 삼아 역전파(backpropagation)로 업데이트하는 방식입니다. 7B(70억) 파라미터 모델 기준으로 메모리 요구량을 계산해보면:

| 항목 | 계산 (FP16 기준) | 7B 모델 예상 용량 |
|---|---|---|
| 모델 가중치 | 파라미터 수 × 2바이트 | 14GB |
| 그래디언트 | 파라미터 수 × 2바이트 | 14GB |
| 옵티마이저 상태 (Adam: m, v) | 파라미터 수 × 2 × 4바이트 | 56GB |
| **합계** | | **약 84GB** |

여기에 활성화값(activation) 저장까지 더하면 실제로는 100GB를 훌쩍 넘습니다. 즉 7B급 모델 하나를 전체 파인튜닝하려면 A100 80GB 여러 장을 묶어야 하는 수준입니다. 13B, 70B로 올라가면 이 비용은 기하급수적으로 커집니다.

또한 전체 파인튜닝은 태스크마다 모델 전체 사본을 새로 저장해야 하므로, 태스크 10개를 지원하려면 7B 모델 10벌(140GB × 10)을 보관해야 하는 운영 부담도 생깁니다.

> 💡 **실무 팁**: "우리 회사 데이터로 모델을 파인튜닝하고 싶다"는 요구가 들어오면, 실제로 전체 파인튜닝이 필요한 경우는 드뭅니다. 대부분의 커스터마이징 요구(말투, 도메인 용어, 출력 포맷)는 PEFT 기법이나 프롬프트 엔지니어링만으로 충분히 해결됩니다.

---

## 2. LoRA — 저랭크 어댑터로 파라미터 효율화

**LoRA(Low-Rank Adaptation)**의 핵심 아이디어는 "가중치 행렬 전체를 업데이트하는 대신, 그 변화량(ΔW)을 훨씬 작은 두 개의 저랭크 행렬의 곱으로 근사한다"는 것입니다.

원래 어텐션 층의 가중치 행렬 W가 있을 때 (예: d × d 크기), 전체 파인튜닝은 W 자체를 직접 업데이트합니다. LoRA는 대신:

```text
W_new = W (동결, freeze) + ΔW
ΔW = B × A

W: d × d (예: 4096 × 4096 = 약 1,678만 파라미터)
A: r × d  (예: r=8 → 8 × 4096 = 32,768 파라미터)
B: d × r  (예: 4096 × 8 = 32,768 파라미터)
```

여기서 **r(rank)**는 8, 16, 32처럼 원래 차원 d보다 훨씬 작은 값입니다. 원본 W는 학습 중 완전히 동결(freeze)되고, 새로 추가된 A, B 두 행렬만 학습됩니다. 위 예시에서는 전체 1,678만 개 대신 약 6.5만 개(원본 대비 0.4%)의 파라미터만 학습하면 됩니다.

**왜 이게 작동하는가**: 연구에 따르면 사전학습된 모델을 특정 태스크에 적응시킬 때 필요한 가중치 변화량은 "본질적 랭크(intrinsic rank)"가 낮다는 가설이 있습니다. 즉 모델의 표현력 전체를 다시 학습할 필요 없이, 저차원 부분공간 안에서의 조정만으로 충분히 태스크에 적응시킬 수 있다는 것입니다.

**LoRA의 실무적 이점:**

- 학습 파라미터가 원본의 0.1~1% 수준 → 그래디언트/옵티마이저 상태 메모리 급감
- 원본 가중치는 그대로 두므로 **여러 태스크용 어댑터를 각각 몇 MB~수십 MB로 저장** 가능 (베이스 모델은 하나만 유지)
- 추론 시 어댑터를 켜고 끄듯 교체 가능 (멀티테넌트 서빙에 유리)

> 💡 **실무 팁**: rank(r)는 보통 8~64 사이에서 실험적으로 정합니다. r을 너무 낮게 잡으면 표현력이 부족해 학습이 잘 안 되고, 너무 높게 잡으면 전체 파인튜닝과 메모리 이점 차이가 줄어듭니다. 일반적인 지시문 튜닝(instruction tuning)에는 r=16 정도가 흔한 시작점입니다.

---

## 3. QLoRA — 4비트 양자화 + LoRA

LoRA는 학습 파라미터 수를 줄여주지만, **베이스 모델 자체는 여전히 FP16으로 GPU 메모리에 올라가 있어야** 합니다. 7B 모델도 FP16으로는 14GB가 필요해서, 소비자용 GPU(RTX 3090/4090, VRAM 24GB)로는 배치 크기나 시퀀스 길이를 넉넉히 잡기 어렵습니다.

**QLoRA**는 여기에 한 가지를 더합니다: **베이스 모델 가중치를 4비트로 양자화해서 메모리에 올리고, 그 위에 LoRA 어댑터(FP16/BF16)만 학습**하는 방식입니다.

| 구성 요소 | 정밀도 | 역할 |
|---|---|---|
| 베이스 모델 가중치 | 4비트 (NF4) | 동결, 순전파 시에만 사용 |
| LoRA 어댑터 (A, B) | BF16 | 학습 대상 |
| 옵티마이저 상태 | BF16 (어댑터分만) | 학습 대상 (매우 작음) |

QLoRA는 단순히 4비트로 반올림하는 것이 아니라, 다음 세 가지 기법을 결합합니다.

1. **NF4 (4-bit NormalFloat)** — 사전학습된 가중치가 대체로 정규분포를 따른다는 점에 착안한, 정규분포에 최적화된 4비트 데이터 타입
2. **이중 양자화(Double Quantization)** — 양자화에 쓰이는 스케일 상수 자체도 다시 양자화해서 메모리를 추가로 절약
3. **페이지드 옵티마이저(Paged Optimizer)** — GPU 메모리가 부족한 순간 옵티마이저 상태를 CPU 메모리로 페이징해 OOM(Out of Memory)을 방지

이 조합 덕분에 **7B 모델을 단일 24GB GPU에서, 33B 모델을 단일 48GB GPU에서** 파인튜닝하는 것이 가능해졌습니다. LoRA만으로는 어려웠던 "개인/소규모 팀이 로컬 GPU 한 장으로 파인튜닝"이 QLoRA로 현실이 된 것입니다.

> 💡 **실무 팁**: 양자화는 순전파(forward) 계산 정밀도를 낮추는 것이라 추론/학습 속도에 약간의 오버헤드가 있습니다. VRAM이 충분하다면(예: A100 80GB 한 장으로 7B 모델) 굳이 QLoRA를 쓸 필요 없이 일반 LoRA(BF16)로 학습하는 것이 더 빠르고 안정적입니다. QLoRA는 "메모리가 부족할 때"를 위한 기법입니다.

---

## 4. PEFT 라이브러리로 실습하기

Hugging Face의 **PEFT(Parameter-Efficient Fine-Tuning)** 라이브러리는 LoRA/QLoRA를 몇 줄로 적용할 수 있게 해줍니다.

```bash
pip install transformers peft bitsandbytes accelerate datasets
```

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
import torch

model_name = "meta-llama/Llama-3.1-8B"

# 1. QLoRA: 4비트 양자화 설정
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    model_name,
    quantization_config=bnb_config,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained(model_name)

# 2. 4비트 학습을 위한 준비 (그래디언트 체크포인팅 등 포함)
model = prepare_model_for_kbit_training(model)

# 3. LoRA 설정 — 어텐션의 q_proj, v_proj에 어댑터 주입
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# 예: trainable params: 20,971,520 || all params: 8,051,232,768 || trainable%: 0.26%
```

학습 루프는 `transformers.Trainer`를 그대로 사용할 수 있습니다 — PEFT가 모델을 감싸는 것이지, 학습 파이프라인 자체를 바꾸는 것이 아닙니다.

```python
from transformers import TrainingArguments, Trainer

training_args = TrainingArguments(
    output_dir="./lora-out",
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    num_train_epochs=3,
    learning_rate=2e-4,
    bf16=True,
    logging_steps=10,
)

trainer = Trainer(model=model, args=training_args, train_dataset=train_dataset)
trainer.train()

# 어댑터만 저장 (수십 MB 수준)
model.save_pretrained("./lora-adapter")
```

### 어댑터를 베이스 모델에 병합하기

서빙 단계에서는 매 요청마다 어댑터를 별도로 곱하는 오버헤드를 없애기 위해, 어댑터를 베이스 모델에 **병합(merge)**해서 하나의 가중치로 만드는 것이 일반적입니다.

```python
from peft import PeftModel

base_model = AutoModelForCausalLM.from_pretrained(model_name, torch_dtype=torch.bfloat16)
merged_model = PeftModel.from_pretrained(base_model, "./lora-adapter")
merged_model = merged_model.merge_and_unload()  # ΔW = B×A를 W에 더해서 하나로 합침

merged_model.save_pretrained("./merged-model")
tokenizer.save_pretrained("./merged-model")
# 이제 이 디렉토리를 Day 07의 vLLM으로 바로 서빙 가능
```

병합 후에는 일반 모델과 동일하게 취급되므로, 이전에 배운 vLLM 서빙 파이프라인에 그대로 태울 수 있습니다.

> 💡 **실무 팁**: 여러 태스크별 어댑터를 스위칭하며 서빙해야 한다면(예: 고객사별 커스텀 어댑터) 병합하지 않고 vLLM의 멀티-LoRA 서빙 기능을 활용해 베이스 모델 하나에 어댑터 여러 개를 동적으로 로드하는 구성이 더 효율적입니다.

---

## 📝 핵심 요약

1. 전체 파인튜닝은 가중치+그래디언트+옵티마이저 상태를 모두 저장해야 해서 7B 모델도 80GB+ 메모리가 필요
2. LoRA는 원본 가중치를 동결하고 저랭크 행렬 A, B(ΔW = BA)만 학습해 파라미터를 0.1~1% 수준으로 줄임
3. QLoRA는 베이스 모델을 4비트(NF4)로 양자화해 소비자용 GPU 한 장으로도 대형 모델 파인튜닝을 가능하게 함
4. PEFT 라이브러리는 `LoraConfig` + `get_peft_model()`로 몇 줄 만에 LoRA를 적용, `Trainer`는 그대로 재사용
5. 서빙 전에는 `merge_and_unload()`로 어댑터를 베이스 모델에 병합해 추론 오버헤드를 제거하는 것이 일반적

---

## 🔗 참고 자료

- [LoRA: Low-Rank Adaptation of Large Language Models (논문)](https://arxiv.org/abs/2106.09685)
- [QLoRA: Efficient Finetuning of Quantized LLMs (논문)](https://arxiv.org/abs/2305.14314)
- [Hugging Face PEFT 공식 문서](https://huggingface.co/docs/peft/index)

---

*⬅️ 이전: [Day 28 — Metrics & Evaluation](../day-28/)  |  다음: [Day 30 — SFT / DPO / RLHF](../day-30/) ➡️*
