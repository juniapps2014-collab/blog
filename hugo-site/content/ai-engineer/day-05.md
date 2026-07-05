---
title: "Day 05 — Token / Embedding / Context Window / KV Cache"
date: 2026-07-04
weight: 5
---

> **Phase 1: 기초** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- BPE 토큰화 방식과 임베딩이 텍스트를 숫자로 바꾸는 과정을 설명할 수 있다
- 컨텍스트 윈도우가 실무에서 어떤 제약으로 작동하는지 이해한다
- KV 캐시의 목적과 메모리 비용 공식을 계산할 수 있다

---

## 1. 토큰화(Tokenization) — 텍스트를 숫자로

LLM은 텍스트를 직접 이해하지 못합니다. 먼저 텍스트를 **토큰(token)**이라는 단위로 쪼개고, 각 토큰을 정수 ID로 변환해야 모델에 입력할 수 있습니다.

가장 널리 쓰이는 방식은 **BPE(Byte Pair Encoding)**입니다. 단어 단위로 쪼개면 사전에 없는 단어(OOV)를 처리할 수 없고, 글자 단위로 쪼개면 시퀀스가 너무 길어집니다. BPE는 그 중간 지점을 찾습니다.

**BPE 학습 과정 (개념):**

1. 모든 텍스트를 개별 문자(또는 바이트) 단위로 시작
2. 코퍼스에서 가장 자주 등장하는 인접 쌍(pair)을 찾아 하나의 새 토큰으로 병합
3. 원하는 어휘 크기(vocab size)에 도달할 때까지 2번을 반복

예를 들어 "lower", "lowest", "newer"가 자주 등장하면 `low`, `er`, `est` 같은 서브워드 단위가 자연스럽게 어휘에 포함됩니다. 그 결과 "unbelievable" 같은 긴 단어는 `un`, `believ`, `able` 처럼 의미 있는 조각으로 쪼개지고, 처음 보는 단어라도 서브워드 조합으로 표현 가능합니다.

```python
# tiktoken으로 GPT 계열 토크나이저 사용 예시
import tiktoken

enc = tiktoken.get_encoding("cl100k_base")
tokens = enc.encode("AI 엔지니어가 되는 길")
print(tokens)          # [정수 토큰 ID 리스트]
print(len(tokens))     # 토큰 개수
print(enc.decode(tokens))  # 원문 복원
```

| 언어 | 특징 |
|---|---|
| 영어 | 단어 대부분이 1~2 토큰으로 효율적으로 인코딩됨 |
| 한국어 | 음절/형태소 단위로 쪼개져 같은 의미라도 영어보다 토큰 수가 많이 소요되는 경향 |

> 💡 **실무 팁**: 같은 문장이라도 언어에 따라 토큰 수가 크게 다릅니다. 한국어는 영어 대비 토큰 소모가 많은 경우가 흔해서, 비용(토큰당 과금)과 컨텍스트 윈도우 관리 시 이를 감안해야 합니다.

---

## 2. 임베딩(Embedding) — 토큰을 벡터로

토큰 ID는 그 자체로는 의미를 담지 못하는 임의의 숫자입니다(토큰 42와 43이 의미적으로 가깝다는 보장이 없음). **임베딩 레이어**는 각 토큰 ID를 고차원 실수 벡터로 변환하며, 이 벡터 공간에서는 의미가 비슷한 토큰들이 서로 가까이 위치하도록 학습됩니다.

```
토큰 ID → Embedding Lookup Table → 고차원 벡터 (예: 4096차원)
```

임베딩 테이블의 크기는 `vocab_size × hidden_dim`입니다. 예를 들어 vocab이 128,000개이고 hidden_dim이 4096이면 임베딩 테이블만 약 5억 개(128,000 × 4096) 파라미터를 차지합니다.

**활용 관점에서 두 가지를 구분해야 합니다:**

- **모델 내부 임베딩**: Transformer 입력단에서 토큰을 벡터로 변환하는 레이어 (모델 아키텍처의 일부)
- **임베딩 모델(Embedding Model)**: 문장/문서 전체를 하나의 의미 벡터로 압축해 유사도 검색(RAG, 시맨틱 서치)에 사용하는 별도 모델 (예: `text-embedding-3-small`, `bge-m3`)

```python
# 문장 임베딩으로 유사도 계산 예시 (개념 코드)
from sentence_transformers import SentenceTransformer
import numpy as np

model = SentenceTransformer("BAAI/bge-m3")
vecs = model.encode(["오늘 날씨가 좋다", "날씨가 맑고 화창하다", "주식 시장이 하락했다"])

# 코사인 유사도로 의미적 유사성 비교
sim = np.dot(vecs[0], vecs[1]) / (np.linalg.norm(vecs[0]) * np.linalg.norm(vecs[1]))
print(sim)  # 의미가 비슷한 문장일수록 1에 가까움
```

---

## 3. 컨텍스트 윈도우(Context Window) — 실무 제약

컨텍스트 윈도우는 모델이 한 번에 "볼 수 있는" 토큰의 최대 개수입니다. 입력 프롬프트 + 이전 대화 히스토리 + 생성될 출력 토큰이 모두 이 한도 안에 들어가야 합니다.

| 모델 (예시) | 컨텍스트 윈도우 |
|---|---|
| GPT-3.5 초기 | 4K |
| GPT-4 Turbo | 128K |
| Claude 3.5/4 계열 | 200K |
| Gemini 1.5/2.x Pro | 최대 1M~2M |

**실무에서 부딪히는 제약:**

- **긴 문서 처리**: 컨텍스트 윈도우를 초과하는 문서는 통째로 넣을 수 없음 → 청킹(chunking) + RAG로 필요한 부분만 검색해 주입
- **긴 대화 히스토리**: 대화가 길어지면 이전 메시지를 요약하거나 오래된 메시지를 잘라내는 전략(sliding window, summarization) 필요
- **비용과 지연시간**: 컨텍스트가 길수록 처리해야 할 토큰이 많아져 비용과 응답 지연이 함께 증가 (Day 05의 KV 캐시와 직결)
- **"Lost in the middle" 현상**: 컨텍스트 윈도우가 커도 중간에 위치한 정보를 모델이 상대적으로 덜 활용하는 경향이 실험적으로 보고됨 → 중요한 정보는 프롬프트의 앞/뒤에 배치하는 것이 유리

> 💡 **실무 팁**: "컨텍스트 윈도우가 크다"는 것이 "긴 문서를 다 넣어도 잘 이해한다"는 것을 보장하지 않습니다. 실무에서는 여전히 RAG로 관련성 높은 정보만 선별해 주입하는 것이 비용/품질 면에서 유리한 경우가 많습니다.

---

## 4. KV 캐시(KV Cache) — 자기회귀 생성의 핵심 최적화

디코더 전용 모델은 토큰을 한 번에 하나씩 생성하는 **자기회귀(autoregressive)** 방식으로 동작합니다. 이때 이전에 생성한 모든 토큰의 Key, Value 벡터를 매번 새로 계산한다면 극도로 비효율적입니다.

**왜 재계산이 낭비인가:** N번째 토큰을 생성할 때 필요한 것은 1~N번째 토큰 모두의 K, V 벡터입니다. 하지만 1~(N-1)번째 토큰의 K, V는 이전 스텝에서 이미 계산한 값과 동일합니다(causal mask 덕분에 과거 토큰의 K/V는 미래 토큰에 영향받지 않음). 이 값을 **캐시에 저장해두고 재사용**하면, 매 스텝마다 새로 생성된 토큰 1개에 대해서만 K, V를 계산하면 됩니다.

```
캐시 없음: 매 스텝마다 1~N개 토큰 전체의 K, V를 재계산 → O(N²) 연산
KV 캐시 사용: 매 스텝마다 새 토큰 1개의 K, V만 계산 후 캐시에 추가 → O(N) 연산
```

이 덕분에 토큰 생성 속도가 크게 빨라지지만, 대가로 **VRAM을 소비**합니다. KV 캐시 메모리 크기는 다음 공식으로 계산합니다.

```
KV 캐시 크기 = 2 × batch_size × seq_len × num_layers × num_kv_heads × head_dim × bytes_per_param
```

- `2`: Key와 Value 두 종류를 저장하기 때문
- `batch_size`: 동시에 처리하는 요청(시퀀스) 수
- `seq_len`: 현재까지의 컨텍스트 길이 (토큰 수)
- `num_layers`: Transformer 블록(레이어) 개수
- `num_kv_heads`: KV 헤드 수 (GQA/MQA 적용 시 attention head 수보다 작을 수 있음)
- `head_dim`: 헤드 하나의 차원
- `bytes_per_param`: FP16=2, FP8=1 등

**예시 계산** (LLaMA 3 8B 근사치: 32 layers, 8 KV heads, head_dim 128, FP16):

```
2 × 1(batch) × 8192(seq_len) × 32(layers) × 8(kv_heads) × 128(head_dim) × 2(bytes)
≈ 1.07 GB (요청 1개, 컨텍스트 8K 토큰 기준)
```

**왜 컨텍스트/배치가 늘면 VRAM이 폭발하는가:** 공식에서 보듯 KV 캐시는 `seq_len`과 `batch_size`에 각각 **선형으로 비례**합니다. 배치를 32개 동시 처리하고 컨텍스트를 32K로 늘리면, 위 예시 대비 캐시 크기가 32 × 4 = 128배로 커집니다. 모델 가중치는 고정 크기지만 KV 캐시는 트래픽과 컨텍스트 길이에 따라 계속 커지기 때문에, 실제 서빙 환경에서 VRAM 부족(OOM)의 가장 흔한 원인이 됩니다.

| 완화 기법 | 설명 |
|---|---|
| **GQA (Grouped Query Attention)** | 여러 Query head가 KV head를 공유해 KV 캐시 크기 자체를 줄임 (LLaMA 2/3, Mistral 등 채택) |
| **MQA (Multi-Query Attention)** | 모든 Query head가 단 하나의 KV head를 공유 (더 극단적인 절감) |
| **PagedAttention** | KV 캐시를 OS의 가상 메모리 페이징처럼 블록 단위로 관리해 메모리 단편화를 줄임 (vLLM의 핵심 기술) |
| **KV 캐시 양자화** | KV 캐시 자체를 INT8/FP8로 저장해 메모리 절반 이하로 절감 |

> 💡 **실무 팁**: 서빙 프레임워크(vLLM 등)를 고를 때 "동시 처리 가능한 요청 수"는 GPU 연산 능력보다 KV 캐시가 소비하는 VRAM에 의해 결정되는 경우가 많습니다. 처리량을 늘리려면 모델을 더 작게 양자화하거나, GQA를 채택한 모델을 쓰거나, PagedAttention 기반 서버를 사용하는 것이 효과적입니다.

---

## 📝 핵심 요약

1. BPE는 단어와 글자 단위의 중간인 서브워드 단위로 텍스트를 토큰화해 OOV 문제와 시퀀스 길이 문제를 동시에 완화한다
2. 임베딩은 토큰 ID를 의미가 반영된 고차원 벡터로 변환하며, 모델 내부 임베딩과 검색용 임베딩 모델은 별개 개념이다
3. 컨텍스트 윈도우는 입력+출력 토큰의 합산 한도이며, 크다고 항상 정보 활용이 균일한 것은 아니다
4. KV 캐시는 이전 토큰의 K/V 재계산을 없애 생성 속도를 O(N²)에서 O(N)으로 줄이는 핵심 최적화다
5. KV 캐시 크기는 batch_size와 seq_len에 선형 비례해 커지므로, 긴 컨텍스트·큰 배치는 VRAM 부족의 주 원인이 된다

---

## 🔗 참고 자료

- [tiktoken 공식 저장소](https://github.com/openai/tiktoken)
- [vLLM: PagedAttention 논문/문서](https://docs.vllm.ai/en/latest/design/kernel/paged_attention.html)
- [Hugging Face: Sentence Transformers 문서](https://www.sbert.net/)

---

*⬅️ 이전: [Day 04 — Transformer 아키텍처](../day-04/)  |  다음: [Day 06 — Ollama](../day-06/) ➡️*
