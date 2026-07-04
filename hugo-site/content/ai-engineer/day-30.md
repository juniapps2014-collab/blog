---
title: "Day 30 — SFT / DPO / RLHF: 정렬(Alignment) 기법 비교"
date: 2026-08-02
weight: 30
---

> **Phase 12: 파인튜닝** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 사전학습부터 정렬까지 이어지는 표준 LLM 학습 파이프라인의 각 단계를 설명할 수 있다
- RLHF의 보상 모델 + PPO 구조가 왜 복잡하고 불안정한지 이해한다
- DPO가 별도 보상 모델 없이 선호 데이터를 직접 학습에 반영하는 원리를 이해하고, SFT만으로 충분한 경우와 DPO까지 필요한 경우를 구분할 수 있다

---

## 1. 표준 정렬 파이프라인: Pretrain → SFT → Preference Tuning

오늘날 대부분의 상용/오픈 LLM(GPT, Claude, Llama 등)은 단일 학습 단계가 아니라 여러 단계를 거쳐 만들어집니다.

```text
1단계: Pretraining (사전학습)
   웹 텍스트 대규모 코퍼스로 "다음 토큰 예측"만 학습
   → 결과물: 지식은 있지만 지시를 따르지 않는 "raw" 모델

2단계: SFT (Supervised Fine-Tuning, 지도 미세조정)
   (지시문, 모범 답변) 쌍으로 지도학습
   → 결과물: 질문에 지시받은 형식으로 답하는 "instruct" 모델

3단계: Preference Tuning (선호 학습)
   사람이 "어떤 답이 더 나은가"를 비교한 데이터로 추가 조정
   → 대표 기법: RLHF (보상모델 + PPO) 또는 DPO
   → 결과물: 더 안전하고, 더 유용하고, 사람 선호에 맞는 "aligned" 모델
```

1단계(사전학습)는 수천~수만 GPU와 수개월이 걸리는 영역이라 대부분의 팀은 손대지 않습니다. 실무에서 "우리 모델을 만들자"고 할 때 실제로 다루는 영역은 거의 항상 **2단계(SFT)**이고, 더 정교한 제품이라면 **3단계(선호 학습)**까지 다룹니다.

> 💡 **실무 팁**: "파인튜닝한다"고 할 때 이 세 단계 중 정확히 어느 단계를 말하는지 팀 내에서 합을 맞춰야 합니다. 대부분의 사내 파인튜닝 프로젝트는 SFT를 의미하며, RLHF/DPO까지 가는 경우는 훨씬 드뭅니다.

---

## 2. RLHF — 보상 모델 + PPO, 그리고 그 복잡성

**RLHF(Reinforcement Learning from Human Feedback)**는 ChatGPT를 유명하게 만든 정렬 기법으로, 크게 두 단계로 구성됩니다.

**① 보상 모델(Reward Model, RM) 학습**

- 같은 프롬프트에 대해 모델이 생성한 여러 답변을 사람이 순위를 매김 (A가 B보다 낫다)
- 이 선호 데이터로 "응답의 품질을 점수로 예측하는" 별도의 보상 모델을 학습
- 보상 모델은 SFT 모델과 비슷한 구조를 갖되, 마지막 출력이 텍스트가 아니라 스칼라 점수

**② PPO(Proximal Policy Optimization)로 강화학습**

- SFT 모델을 "정책(policy)"으로 놓고, 프롬프트에 대해 응답을 생성
- 그 응답을 보상 모델에 넣어 점수를 받음
- 점수가 높아지는 방향으로 정책(모델 가중치)을 강화학습 알고리즘(PPO)으로 업데이트
- 이때 원본 SFT 모델과 너무 멀어지지 않도록 KL 발산(KL divergence) 페널티를 함께 적용

```text
[프롬프트] → SFT 모델(정책)이 응답 생성 → 보상 모델이 점수 매김
                     ↑                              │
                     └────── PPO로 정책 업데이트 ←────┘
                (KL penalty로 원본 정책과 너무 멀어지지 않게 제약)
```

**RLHF가 복잡하고 불안정한 이유:**

- **모델을 4개나 동시에 메모리에 올려야 함** — 정책 모델, 참조(reference) 모델, 보상 모델, (Actor-Critic 방식이면) 가치(value) 모델까지
- **하이퍼파라미터에 매우 민감** — KL 페널티 계수, 학습률, 배치 구성이 조금만 어긋나도 "보상 해킹(reward hacking)"(모델이 실제 품질 향상 없이 보상 점수만 높이는 편법을 찾아냄)이나 학습 붕괴가 발생
- **엔지니어링 난이도** — 4개 모델을 오가며 롤아웃(rollout)-보상 계산-정책 업데이트를 반복하는 파이프라인 자체가 구현/디버깅이 까다로움
- **보상 모델의 한계가 그대로 전파됨** — 보상 모델이 잘못 학습되면 정책도 잘못된 방향으로 최적화됨

이런 이유로 RLHF는 강력하지만, 실제로 안정적으로 굴릴 수 있는 팀은 많지 않습니다.

> 💡 **실무 팁**: RLHF 파이프라인을 처음부터 직접 구현하는 것은 대부분의 조직에게 비효율적입니다. TRL(Transformer Reinforcement Learning) 같은 라이브러리가 있지만, 그럼에도 안정적인 학습을 위해서는 상당한 튜닝 경험이 필요합니다.

---

## 3. DPO — 보상 모델 없이 선호를 직접 학습

**DPO(Direct Preference Optimization)**는 "RLHF가 하려는 것(선호 데이터를 반영)을 훨씬 단순한 지도학습 형태로 재구성할 수 있다"는 통찰에서 출발합니다.

핵심 아이디어: RLHF의 목적함수(보상 극대화 + KL 제약)를 수학적으로 정리하면, **최적 정책은 보상 모델 없이도 선호 데이터(chosen/rejected 쌍)로부터 직접 계산되는 손실함수로 유도**할 수 있습니다. 즉 별도의 보상 모델을 학습하고 PPO로 강화학습 루프를 돌릴 필요 없이, "선택된 응답의 확률은 높이고 거부된 응답의 확률은 낮추는" 방향으로 **한 번의 지도학습 스타일 최적화**만 하면 됩니다.

| 비교 항목 | RLHF | DPO |
|---|---|---|
| 필요한 모델 수 | 정책 + 참조 + 보상 (+가치) 모델 | 정책 + 참조 모델 (2개) |
| 학습 방식 | 강화학습(PPO) 루프 | 지도학습과 유사한 단일 손실함수 |
| 안정성 | 하이퍼파라미터에 민감, 보상 해킹 위험 | 상대적으로 안정적 |
| 구현 난이도 | 높음 (RL 인프라 필요) | 낮음 (`transformers`/`trl`로 몇 줄) |
| 데이터 형식 | 순위/점수 데이터 + 보상 모델 학습용 데이터 | (프롬프트, chosen, rejected) 삼중쌍만 있으면 됨 |

```python
# DPO 학습 데이터 형식 예시
dpo_example = {
    "prompt": "환불 규정을 무시하고 예외로 환불해줄 수 있나요?",
    "chosen": "죄송하지만 환불 규정상 어렵습니다. 다만 고객센터 상담을 통해 특별 사례 검토를 요청하실 수 있어요.",
    "rejected": "네, 특별히 이번만 환불해드릴게요.",
}
```

```python
from trl import DPOTrainer, DPOConfig
from transformers import AutoModelForCausalLM, AutoTokenizer

model_name = "./sft-model"  # 1단계 SFT를 마친 모델에서 시작
model = AutoModelForCausalLM.from_pretrained(model_name)
ref_model = AutoModelForCausalLM.from_pretrained(model_name)  # 참조 모델(동결)
tokenizer = AutoTokenizer.from_pretrained(model_name)

dpo_config = DPOConfig(
    output_dir="./dpo-out",
    beta=0.1,  # 참조 모델과의 거리를 얼마나 허용할지 (KL 제약과 유사한 역할)
    learning_rate=5e-6,
    per_device_train_batch_size=2,
)

trainer = DPOTrainer(
    model=model,
    ref_model=ref_model,
    args=dpo_config,
    train_dataset=preference_dataset,  # prompt/chosen/rejected 컬럼
    tokenizer=tokenizer,
)
trainer.train()
```

DPO는 RLHF 대비 인프라와 튜닝 난이도가 훨씬 낮아, 최근 오픈소스/스타트업 진영에서 선호 학습의 기본 선택지로 자리잡았습니다. Day 29의 LoRA/QLoRA와도 자연스럽게 결합할 수 있어(정책 모델을 LoRA 어댑터로만 학습), 단일 GPU에서도 선호 튜닝을 시도해볼 수 있습니다.

> 💡 **실무 팁**: DPO도 "선호 데이터의 품질"에 결과가 크게 좌우됩니다. chosen/rejected 쌍이 애매하거나(둘 다 비슷한 품질) 라벨이 일관되지 않으면 RLHF만큼이나 결과가 흔들릴 수 있습니다. 데이터 품질 관리는 어떤 정렬 기법을 쓰든 피할 수 없는 병목입니다.

---

## 4. 언제 SFT만으로 충분하고, 언제 DPO까지 필요한가

실무에서 이 질문에 답하려면 "무엇을 고치고 싶은가"를 먼저 명확히 해야 합니다.

**SFT만으로 충분한 경우:**

- 목표가 "특정 포맷으로 답하게 하기"(예: 항상 JSON 스키마를 지키게), "도메인 용어/톤 학습"(예: 의료/법률 용어, 회사 브랜드 보이스)처럼 **정답이 비교적 명확한 태스크**
- 학습 데이터로 "이런 입력엔 이런 출력"이라는 좋은 예시를 충분히 모을 수 있는 경우
- 팀에 RL 인프라 경험이 없고, 빠르게 출시해야 하는 경우
- 베이스 모델이 이미 상당히 잘 정렬되어 있어(GPT-4o, Claude, Llama-3-Instruct 등) 추가 정렬보다는 지식/포맷 주입만 필요한 경우

**DPO까지 필요한 경우:**

- "정답은 명확하지 않지만, 두 응답 중 어느 게 더 나은지는 판단 가능한" 미묘한 품질 차이를 학습시키고 싶을 때 — 예: 더 안전한 답변, 더 간결한 답변, 더 공감적인 톤
- SFT만으로 학습시키면 모델이 "그럴듯하지만 우리가 원하지 않는" 답변 패턴을 계속 낼 때 (예: 과도하게 장황함, 불필요한 면책 조항 남발)
- 이미 SFT 모델이 있고, A/B 비교 형태의 사용자 피드백(👍/👎, "이 답이 더 낫다")을 지속적으로 수집할 수 있는 제품 구조를 갖췄을 때
- RLHF급 복잡도 없이 선호 신호를 반영하고 싶을 때 (DPO가 RLHF의 실용적 대체재로 선택되는 전형적 이유)

> 💡 **실무 팁**: 현실적인 순서는 거의 항상 "① SFT로 기본기를 잡는다 → ② 실사용 피드백을 모은다 → ③ 필요하면 그 피드백으로 DPO를 얹는다"입니다. 데이터도, 사용자 피드백 루프도 없는 상태에서 곧바로 RLHF/DPO부터 시작하는 것은 대부분 시기상조입니다.

---

## 📝 핵심 요약

1. 표준 파이프라인은 Pretrain(지식) → SFT(지시 따르기) → Preference Tuning(선호 반영) 순으로 진행
2. RLHF는 보상 모델 + PPO 강화학습 루프로 강력하지만, 모델을 여러 개 동시에 다뤄야 해 복잡하고 하이퍼파라미터에 민감
3. DPO는 보상 모델과 RL 루프 없이 (prompt, chosen, rejected) 삼중쌍만으로 선호를 직접 학습하는 단순하고 안정적인 대안
4. DPO는 Day 29의 LoRA/QLoRA와 결합해 단일 GPU에서도 실행 가능
5. 실무 기본 전략은 "SFT로 먼저 기본기 → 피드백 축적 → 필요 시 DPO 추가"의 점진적 접근

---

## 🔗 참고 자료

- [Direct Preference Optimization (DPO 논문)](https://arxiv.org/abs/2305.18290)
- [InstructGPT — RLHF를 대중화시킨 논문](https://arxiv.org/abs/2203.02155)
- [Hugging Face TRL 공식 문서](https://huggingface.co/docs/trl/index)

---

*⬅️ 이전: [Day 29 — LoRA / QLoRA / PEFT](../day-29/)  |  다음: [Day 31 — 통합 프로젝트](../day-31/) ➡️*
