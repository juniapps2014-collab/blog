---
title: "Day 08 — 양자화 & 추론 최적화: GGUF/GPTQ/AWQ, Tensor Parallel, Flash Attention, Speculative Decoding"
date: 2026-07-04
weight: 8
---

> **Phase 2: 로컬 LLM** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- GGUF, GPTQ, AWQ의 차이와 각각을 언제 선택해야 하는지 설명할 수 있다
- Tensor Parallelism과 Flash Attention이 추론 속도를 개선하는 원리를 이해한다
- Speculative Decoding의 draft-verify 구조와 속도 향상 메커니즘을 설명할 수 있다

---

## 1. 양자화(Quantization)란 무엇이고 왜 필요한가

LLM의 가중치는 보통 16비트(FP16/BF16) 부동소수점으로 저장됩니다. 70억 개 파라미터 모델이면 대략 14GB, 700억이면 140GB — 개인 GPU는커녕 서버 GPU 여러 장도 부족할 수 있습니다.

양자화는 가중치를 더 적은 비트(8bit, 4bit, 심지어 2~3bit)로 표현해서 **메모리 사용량을 줄이고 로딩/연산 속도를 높이는** 기법입니다. 정확도는 어느 정도 손실되지만, 잘 설계된 양자화 기법은 사람이 체감하기 어려운 수준의 손실만 발생시킵니다.

---

## 2. GGUF vs GPTQ vs AWQ

세 가지 모두 "양자화된 모델을 저장/실행하는 포맷 또는 방식"이지만 목적과 실행 환경이 다릅니다.

| 구분 | GGUF | GPTQ | AWQ |
|---|---|---|---|
| 주 사용처 | llama.cpp, Ollama (CPU/저사양 GPU) | GPU 서버 추론 (vLLM, AutoGPTQ) | GPU 서버 추론 (vLLM, AutoAWQ) |
| 양자화 방식 | 다양한 비트폭(2~8bit) 정적 양자화, CPU 친화적 레이아웃 | 레이어별 2차 오차(Hessian) 기반 후처리 양자화(PTQ) | 활성화 값 분포를 분석해 "중요한 가중치"를 보존하는 방식 |
| 강점 | CPU/Apple Silicon/저VRAM 환경에서도 실행 가능, Ollama와 궁합 | GPU에서 GPTQ 전용 커널로 빠른 추론 | GPTQ보다 정확도 손실이 적은 경향, 특히 4bit에서 강점 |
| 대표 비트폭 | 4bit(Q4_K_M 등)가 가장 흔함 | 4bit | 4bit |
| 캘리브레이션 필요 | 상대적으로 단순 | 필요 (소량의 캘리브레이션 데이터셋으로 오차 최소화) | 필요 (활성화 통계 수집) |

**선택 기준 요약:**

- 로컬 PC, Mac, CPU 위주 환경 → **GGUF** (Day 06의 Ollama가 내부적으로 GGUF를 사용)
- GPU 서버에서 vLLM으로 최대 처리량을 뽑고 싶다 → **AWQ** (정확도 손실이 GPTQ보다 적은 경우가 많아 최근 선호도가 높음)
- 이미 GPTQ로 양자화된 공개 체크포인트가 많은 모델을 그대로 쓰고 싶다 → **GPTQ**

```bash
# vLLM에서 AWQ 모델 서빙
vllm serve TheBloke/Llama-3.1-8B-Instruct-AWQ --quantization awq

# vLLM에서 GPTQ 모델 서빙
vllm serve TheBloke/Llama-3.1-8B-Instruct-GPTQ --quantization gptq
```

> 💡 **실무 팁**: 비트폭을 낮출수록(8bit → 4bit → 2bit) 메모리는 줄지만 정확도 손실 폭이 급격히 커지는 지점이 있습니다. 실무에서는 4bit가 "메모리 절약 대비 품질 손실"의 균형점으로 가장 널리 쓰입니다.

---

## 3. Tensor Parallelism — 모델을 여러 GPU에 쪼개기

모델 하나가 GPU 한 장의 메모리에 다 안 들어갈 때 쓰는 기법입니다. Data Parallelism(같은 모델 복사본을 여러 GPU에 두고 다른 데이터를 처리)과 달리, Tensor Parallelism은 **하나의 레이어 연산 자체를 여러 GPU가 나눠서 계산**합니다.

예를 들어 어떤 Linear 레이어의 가중치 행렬을 열(column) 방향으로 GPU 2장에 반씩 나누면, 각 GPU는 절반의 출력을 계산하고 이를 통신(all-reduce)으로 합칩니다.

- 장점: 단일 GPU 메모리 한계를 넘는 대형 모델도 서빙 가능
- 단점: GPU 간 통신 오버헤드 발생 → 같은 노드 내 NVLink처럼 대역폭이 높은 연결이 중요

```bash
# GPU 4장에 텐서 병렬로 분산
vllm serve meta-llama/Llama-3.1-70B-Instruct --tensor-parallel-size 4
```

> GPU 수는 보통 attention head 개수의 약수로 맞춰야 합니다(예: head가 32개면 2, 4, 8 분할이 자연스러움).

---

## 4. Flash Attention — 근사가 아니라 IO 최적화

Flash Attention은 "정확도를 낮춰 속도를 얻는" 근사 기법이 아닙니다. **수학적으로 동일한 결과**를 내면서, GPU 메모리 계층 구조(HBM vs SRAM)를 고려해 연산 순서를 재배치한 IO-aware 알고리즘입니다.

기존 attention 구현은 $QK^T$ 행렬(시퀀스 길이의 제곱 크기)을 전부 느린 HBM(고대역폭 메모리)에 썼다가 다시 읽어오는 과정을 반복합니다. Flash Attention은 시퀀스를 블록 단위로 쪼개 빠른 SRAM(GPU 코어 근처의 캐시) 안에서 attention 연산을 끝내고, 최종 결과만 HBM에 씁니다.

- HBM ↔ SRAM 간 데이터 이동(메모리 IO)이 병목이었던 부분을 줄여 **동일한 결과를 더 빠르게, 더 적은 메모리로** 계산
- 시퀀스 길이가 길어질수록 효과가 커짐 (attention의 메모리 사용량이 시퀀스 길이의 제곱에 비례하기 때문)
- vLLM, Hugging Face `transformers` 모두 기본적으로 지원하며 별도 설정 없이 자동 적용되는 경우가 많음

> 💡 **실무 팁**: "Flash Attention = 근사치라 품질이 떨어진다"는 오해가 흔한데, 사실은 정확히 같은 수학 연산을 다른 순서/메모리 배치로 계산하는 것뿐입니다. 품질 저하 걱정 없이 켜도 됩니다.

---

## 5. Speculative Decoding — 작은 모델로 미리 찍고, 큰 모델이 검증

LLM 디코딩은 본질적으로 **순차적**입니다. 토큰을 한 개씩 생성해야 하고, 각 스텝마다 전체 모델의 forward pass가 필요합니다. Speculative Decoding은 이 순차성의 병목을 우회하는 기법입니다.

**동작 방식:**

1. 작고 빠른 **draft 모델**이 여러 토큰(예: 4~5개)을 한 번에 빠르게 예측합니다
2. 원본의 크고 정확한 **target 모델**이 이 draft 토큰들을 "한 번의 forward pass"로 병렬 검증합니다
3. target 모델의 확률 분포와 비교해 일치하는 앞부분 토큰은 그대로 채택하고, 불일치가 발생한 지점부터는 target 모델이 직접 다시 생성합니다

핵심은 **검증(verify)은 병렬로 할 수 있다**는 점입니다. target 모델 입장에서 "5개 토큰을 순차 생성"하는 것과 "5개 토큰 후보를 한 번에 검증"하는 것은 비슷한 연산량이지만, 후자는 forward pass 1회로 끝납니다. 즉 draft 모델의 예측이 자주 맞을수록 target 모델의 forward pass 횟수가 줄어 전체 속도가 빨라집니다.

- 최종 출력 품질은 target 모델이 검증하므로 **target 모델 단독 생성과 수학적으로 동일한 분포**를 보장 (품질 손실 없음)
- draft 모델과 target 모델의 어휘(vocabulary)가 같아야 하며, 보통 같은 모델 패밀리의 더 작은 버전을 draft로 씁니다 (예: Llama-3.1-70B의 draft로 Llama-3.1-8B)

```bash
# vLLM에서 speculative decoding 활성화 예시
vllm serve meta-llama/Llama-3.1-70B-Instruct \
  --speculative-model meta-llama/Llama-3.1-8B-Instruct \
  --num-speculative-tokens 5
```

> 💡 **실무 팁**: Speculative Decoding은 "생성되는 텍스트가 예측 가능할 때"(코드, 반복적인 패턴) 특히 잘 먹힙니다. 창의적이고 다양성이 높은 텍스트에서는 draft-target 불일치가 잦아 속도 향상 폭이 줄어듭니다.

---

## 📝 핵심 요약

1. GGUF는 CPU/로컬 저사양 환경, GPTQ/AWQ는 GPU 서버 추론에 적합하며 AWQ가 최근 정확도 면에서 선호되는 추세
2. Tensor Parallelism은 모델 하나를 여러 GPU에 쪼개 계산하는 방식으로, 단일 GPU 메모리 한계를 넘어설 때 필수
3. Flash Attention은 근사가 아니라 GPU 메모리 계층을 고려한 IO 최적화로, 동일한 결과를 더 빠르게 계산
4. Speculative Decoding은 작은 draft 모델의 예측을 큰 target 모델이 병렬 검증해 품질 손실 없이 속도를 높이는 기법

---

## 🔗 참고 자료

- [vLLM Quantization 가이드](https://docs.vllm.ai/en/latest/features/quantization/index.html)
- [FlashAttention 공식 GitHub](https://github.com/Dao-AILab/flash-attention)
- [AutoAWQ 문서](https://github.com/casper-hansen/AutoAWQ)

---

*⬅️ 이전: [Day 07 — vLLM: 고성능 추론 서버 구축](../day-07/)  |  다음: [Day 09 — Runpod 기초](../day-09/) ➡️*
