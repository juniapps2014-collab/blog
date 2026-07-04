---
title: "Day 04 — Transformer 아키텍처: 현대 LLM의 근간"
date: 2026-07-07
weight: 4
---

> **Phase 1: 기초** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Self-Attention의 Q/K/V 개념과 계산 흐름을 설명할 수 있다
- Multi-Head Attention과 Positional Encoding의 필요성을 이해한다
- 인코더-디코더 구조와 디코더 전용(decoder-only) 구조의 차이, 그리고 왜 대부분의 LLM이 후자를 택했는지 설명할 수 있다

---

## 1. Transformer 이전의 한계 — RNN의 순차성 문제

2017년 "Attention Is All You Need" 논문 이전, 자연어 처리의 주류는 RNN/LSTM이었습니다. RNN은 토큰을 순서대로 하나씩 처리하기 때문에 두 가지 근본적 한계가 있었습니다.

- **병렬화 불가**: 토큰 i를 처리하려면 토큰 i-1의 결과가 필요 → GPU의 병렬 연산 능력을 활용하지 못함
- **장거리 의존성 손실**: 문장이 길어질수록 앞쪽 정보가 뒤로 전달되며 희석됨 (vanishing gradient)

Transformer는 순차 처리를 버리고, 모든 토큰이 서로를 직접 참조하는 **Self-Attention** 메커니즘으로 이 문제를 해결했습니다. 모든 토큰 쌍의 관계를 한 번에 행렬 연산으로 계산하므로 GPU 병렬화에 이상적입니다.

---

## 2. Self-Attention — Query, Key, Value

Self-Attention의 핵심 아이디어는 "각 토큰이 문장 내 다른 모든 토큰을 얼마나 참고해야 하는지"를 학습하는 것입니다. 이를 위해 각 토큰의 임베딩으로부터 세 가지 벡터를 만듭니다.

- **Query (Q)**: "나는 무엇을 찾고 있는가" — 현재 토큰의 질의
- **Key (K)**: "나는 무엇을 제공할 수 있는가" — 각 토큰이 가진 정보의 색인
- **Value (V)**: "실제로 전달할 내용" — Key가 매칭되었을 때 가져올 실제 값

세 벡터 모두 입력 임베딩에 각각 다른 학습 가능한 가중치 행렬(Wq, Wk, Wv)을 곱해서 얻습니다.

Attention 계산 공식은 다음과 같습니다.

```
Attention(Q, K, V) = softmax( (Q · K^T) / sqrt(d_k) ) · V
```

단계별로 풀어보면:

1. **Q · K^T**: 모든 토큰 쌍 사이의 유사도(내적)를 계산 → "이 토큰이 저 토큰을 얼마나 참고해야 하는가"에 대한 원시 점수(raw score) 행렬
2. **/ sqrt(d_k)**: Key 벡터 차원(d_k)의 제곱근으로 나눠 스케일 조정 → 차원이 커질수록 내적 값이 과도하게 커져 softmax가 극단적으로 치우치는 것을 방지
3. **softmax**: 각 행(토큰)에 대해 점수를 0~1 사이 확률 분포로 정규화 → "각 토큰에 얼마만큼의 비중(가중치)을 둘 것인가"
4. **· V**: 이 확률 가중치로 Value 벡터들을 가중합 → 최종 출력은 "다른 토큰들의 정보를 얼마나 섞어 반영한 새로운 표현"

> 💡 **실무 팁**: Attention을 직관적으로 이해하려면 "검색(search)"에 비유하는 것이 좋습니다. Query는 검색어, Key는 문서 색인, Value는 문서 내용입니다. 검색어와 색인의 유사도(softmax 확률)만큼 각 문서 내용을 섞어서 답을 만드는 것이 Attention입니다.

디코더에서는 미래 토큰을 미리 보지 못하도록 **causal mask**를 적용해, 각 토큰이 자기 자신과 이전 토큰만 참조하도록 제한합니다 (Q·K^T 행렬의 상삼각 부분을 -∞로 마스킹 후 softmax).

---

## 3. Multi-Head Attention

하나의 Attention만 사용하면 "문법적 관계", "의미적 유사성", "지시대명사가 가리키는 대상" 같은 서로 다른 종류의 관계를 동시에 포착하기 어렵습니다. Multi-Head Attention은 Q/K/V를 여러 개의 더 작은 부분공간(head)으로 나눠 **병렬로 여러 종류의 관계를 동시에 학습**합니다.

```
head_i = Attention(Q·Wq_i, K·Wk_i, V·Wv_i)
MultiHead(Q, K, V) = Concat(head_1, ..., head_h) · Wo
```

예를 들어 임베딩 차원이 4096이고 head 수가 32개라면, 각 head는 128차원 부분공간에서 독립적으로 attention을 계산한 뒤, 이를 모두 이어붙이고(concat) 다시 하나의 행렬(Wo)로 투영해 원래 차원으로 되돌립니다.

| head 수 | 특징 |
|---|---|
| 적음 (예: 1~4) | 표현력이 제한적, 다양한 관계 포착 어려움 |
| 많음 (예: 32~96, 최신 대형 모델) | 다양한 언어적 패턴을 병렬로 포착 가능, 연산량 증가 |

---

## 4. Positional Encoding — 순서 정보 주입

Self-Attention 자체는 토큰의 **순서**를 구분하지 못합니다. Q·K^T 연산은 집합(set) 연산이라 "나는 학교에 간다"와 "학교는 나에 간다"의 토큰 집합이 같다면 순서 정보 없이는 동일하게 취급됩니다.

이를 해결하기 위해 각 토큰의 임베딩에 **위치 정보를 더하거나 결합**합니다.

- **Sinusoidal Positional Encoding** (원조 Transformer): sin/cos 함수로 위치마다 고유한 패턴 생성, 학습 파라미터 없음
- **Learned Positional Embedding** (GPT-2 등): 위치마다 학습 가능한 임베딩 벡터를 직접 학습
- **RoPE (Rotary Positional Embedding)** (LLaMA, Mistral, Qwen 등 최신 LLM 대부분): Q, K 벡터에 위치에 따른 회전 변환을 적용해 상대적 위치 정보를 attention 계산 내부에 자연스럽게 녹여냄. 긴 컨텍스트로 확장(extrapolation)하기 유리해 사실상 현재 업계 표준

> 💡 **실무 팁**: 모델 카드에서 "RoPE scaling", "context length extension" 같은 표현을 보게 되면 이는 RoPE의 회전 주기를 조정해 학습 시보다 더 긴 컨텍스트를 처리하도록 확장하는 기법(예: NTK-aware scaling, YaRN)을 가리킵니다.

---

## 5. 인코더-디코더 vs 디코더 전용(Decoder-Only)

원조 Transformer는 번역 작업을 위해 **인코더-디코더** 구조로 설계되었습니다.

- **인코더(Encoder)**: 입력 문장 전체를 양방향(bidirectional)으로 self-attention 처리 → 문맥이 풍부한 표현 생성 (예: BERT)
- **디코더(Decoder)**: 인코더의 출력을 참고(cross-attention)하며, 자기 자신은 causal mask로 이전 토큰만 참조해 한 토큰씩 순차 생성 (예: 원조 Transformer의 번역 디코더)
- **디코더 전용(Decoder-Only)**: 인코더 없이, causal self-attention만으로 "다음 토큰 예측"을 반복 (GPT, LLaMA, Qwen, Claude 계열 등 현재 대부분의 LLM)

**왜 현대 LLM은 디코더 전용을 택했는가:**

1. **범용성**: "다음 토큰 예측"이라는 단일 목표로 번역, 요약, 코드 생성, 대화 등 사실상 모든 텍스트 생성 작업을 하나의 아키텍처로 통일 가능
2. **스케일링 효율**: 구조가 단순해 파라미터 수를 키우기 쉽고, 대규모 비지도 사전학습(다음 토큰 예측)에 적합
3. **자기회귀 생성과의 자연스러운 결합**: 실제 서비스에서 LLM은 텍스트를 한 토큰씩 생성하므로, 학습 목표(다음 토큰 예측)와 추론 방식이 완벽히 일치

디코더 전용 블록 하나의 구조를 텍스트로 표현하면 다음과 같습니다.

```
입력 임베딩 + Positional Encoding(RoPE)
        │
        ▼
┌───────────────────────┐
│  Layer Norm            │
│        ▼               │
│  Causal Self-Attention │ ──┐
│        ▼               │   │ (Residual 연결)
└───────────────────────┘   │
        │ + ──────────────────┘
        ▼
┌───────────────────────┐
│  Layer Norm            │
│        ▼               │
│  Feed-Forward Network  │ ──┐
│  (2개 Linear + 활성함수) │   │ (Residual 연결)
└───────────────────────┘   │
        │ + ──────────────────┘
        ▼
   다음 블록으로 (N번 반복)
        ▼
  최종 Linear + Softmax → 다음 토큰 확률 분포
```

이 블록을 수십~수백 개 쌓은 것이 GPT, LLaMA 같은 현대 LLM의 실체입니다. 예를 들어 LLaMA 3 70B는 이런 디코더 블록을 80개 쌓은 구조입니다.

> 💡 **실무 팁**: Residual 연결(입력을 출력에 더해주는 skip connection)과 Layer Norm은 수십~수백 개 블록을 쌓아도 gradient가 안정적으로 전파되게 하는 핵심 장치입니다. 이게 없으면 깊은 네트워크는 학습이 거의 불가능합니다.

---

## 📝 핵심 요약

1. Self-Attention은 Q·K^T로 토큰 간 유사도를 계산하고, softmax로 정규화한 뒤 V를 가중합하는 연산이다
2. Multi-Head Attention은 여러 부분공간에서 병렬로 다른 종류의 관계를 학습해 표현력을 높인다
3. Attention 자체는 순서를 모르기 때문에 Positional Encoding(RoPE가 현재 표준)으로 위치 정보를 주입한다
4. 현대 LLM 대부분은 인코더 없이 causal self-attention만 사용하는 디코더 전용 구조다
5. 디코더 블록(Attention + FFN + Residual + LayerNorm)을 수십~수백 개 쌓은 것이 LLM의 실체다

---

## 🔗 참고 자료

- [Attention Is All You Need (원 논문, arXiv)](https://arxiv.org/abs/1706.03762)
- [RoFormer: Rotary Position Embedding 논문](https://arxiv.org/abs/2104.09864)
- [Hugging Face Transformers 아키텍처 문서](https://huggingface.co/docs/transformers/index)

---

*⬅️ 이전: [Day 03 — GPU & CUDA](../day-03/)  |  다음: [Day 05 — Token / Embedding / Context Window / KV Cache](../day-05/) ➡️*
