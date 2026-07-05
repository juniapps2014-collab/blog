---
title: "Day 07 — vLLM: 고성능 추론 서버 구축"
date: 2026-07-04
weight: 7
---

> **Phase 2: 로컬 LLM** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Hugging Face `generate()`의 한계와 vLLM이 이를 해결하는 원리(PagedAttention, Continuous Batching)를 설명할 수 있다
- `vllm serve`로 OpenAI 호환 API 서버를 실행하고 핵심 실행 플래그를 이해한다
- 처리량(throughput)과 지연시간(latency) 사이의 트레이드오프를 판단할 수 있다

---

## 1. 왜 naive `generate()`로는 부족한가

Ollama(Day 06)는 "개인이 로컬에서 편하게" 모델을 돌리는 도구였다면, vLLM은 "여러 사용자의 요청을 동시에, 최대한 빠르게" 처리해야 하는 **서빙(serving)** 상황을 위한 도구입니다.

Hugging Face `transformers`의 기본 `model.generate()`를 그대로 프로덕션에 쓰면 두 가지 문제가 생깁니다.

- **메모리 낭비** — 각 요청마다 KV 캐시를 위해 "최대 시퀀스 길이" 크기의 연속된 메모리 블록을 미리 할당합니다. 실제로는 짧게 끝나는 요청이 많아도 메모리는 미리 다 잡아먹혀 GPU를 효율적으로 못 씁니다.
- **배치 처리 비효율** — 요청을 하나씩 처리하거나, 정적 배치(static batching)로 묶으면 배치 내 가장 긴 요청이 끝날 때까지 짧은 요청들도 GPU를 붙잡고 대기해야 합니다.

vLLM은 이 두 문제를 각각 **PagedAttention**과 **Continuous Batching**으로 해결합니다.

### PagedAttention

운영체제의 가상 메모리 페이징 기법을 KV 캐시에 적용한 아이디어입니다. KV 캐시를 고정 크기 블록(page) 단위로 나눠 필요한 만큼만 할당하고, 논리적으로는 연속된 것처럼 보이지만 물리적으로는 흩어진 블록을 매핑 테이블로 관리합니다.

- 메모리 단편화(fragmentation)를 거의 제거 → 같은 GPU 메모리로 더 많은 동시 요청 처리 가능
- 여러 요청이 같은 프롬프트 접두사(prefix)를 공유할 때 블록을 재사용 가능 (예: 같은 시스템 프롬프트를 쓰는 요청들)

### Continuous Batching (Iteration-level Scheduling)

정적 배치는 배치를 한 번 구성하면 그 배치가 끝날 때까지 새 요청을 못 넣습니다. vLLM은 매 디코딩 스텝(iteration)마다 배치를 재구성해서, 먼저 끝난 요청 자리에 대기 중인 새 요청을 즉시 채워 넣습니다.

| 방식 | 배치 구성 시점 | GPU 유휴 시간 |
|---|---|---|
| Static Batching | 요청 시작 시 고정 | 짧은 요청이 긴 요청을 기다림 → 낭비 큼 |
| Continuous Batching | 매 디코딩 스텝마다 재구성 | 요청 완료 즉시 새 요청 투입 → 낭비 최소 |

> 💡 **실무 팁**: 벤치마크에서 vLLM이 naive HF `generate()` 대비 최대 24배 처리량을 낸다는 수치가 나오는 이유가 바로 이 두 기술의 조합입니다. 단일 요청 지연시간보다 "동시에 몇 명을 처리할 수 있는가"가 핵심 지표인 서비스라면 vLLM은 사실상 표준 선택지입니다.

---

## 2. 설치와 기본 서버 실행

```bash
# CUDA 환경 기준 설치 (GPU 필요)
pip install vllm

# OpenAI 호환 API 서버 실행
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0 \
  --port 8000
```

서버가 뜨면 `/v1/chat/completions`, `/v1/completions`, `/v1/models` 등 OpenAI API와 동일한 엔드포인트가 노출됩니다. 즉 기존에 OpenAI SDK로 작성한 코드의 `base_url`만 바꾸면 그대로 재사용할 수 있습니다.

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "vLLM이 뭐야?"}]
  }'
```

---

## 3. 핵심 실행 플래그

`vllm serve` 실행 시 자주 조정하게 되는 플래그들입니다.

| 플래그 | 역할 | 비고 |
|---|---|---|
| `--tensor-parallel-size` | 모델을 N개 GPU에 텐서 병렬로 분산 | GPU 1장에 모델이 안 들어갈 때 필수 (Day 08에서 심화) |
| `--gpu-memory-utilization` | KV 캐시용으로 사용할 GPU 메모리 비율 (기본 0.9) | 다른 프로세스와 GPU를 공유하면 낮춰야 함 |
| `--max-model-len` | 처리할 최대 컨텍스트 길이 | 모델 기본값보다 줄이면 KV 캐시 공간이 늘어나 동시 처리량 증가 |
| `--max-num-seqs` | 배치당 최대 동시 시퀀스 수 | 처리량 상한 조절 |
| `--quantization` | 양자화 방식 지정 (awq, gptq 등) | Day 08 참고 |
| `--dtype` | 연산 정밀도 (bfloat16, float16 등) | GPU 아키텍처에 맞게 선택 |

```bash
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --tensor-parallel-size 2 \
  --gpu-memory-utilization 0.85 \
  --max-model-len 8192 \
  --max-num-seqs 64
```

> 💡 **실무 팁**: `--gpu-memory-utilization`을 너무 높게(0.95 이상) 잡으면 다른 프로세스가 OOM(Out of Memory)으로 죽는 경우가 흔합니다. Runpod 같은 공유 환경에서는 0.8~0.85 정도로 여유를 두는 것이 안전합니다.

---

## 4. 처리량 vs 지연시간 트레이드오프

vLLM 튜닝은 결국 "처리량(throughput)"과 "개별 요청 지연시간(latency)" 사이의 저울질입니다.

- **처리량 우선** (배치 API, 대량 문서 요약 등) — `--max-num-seqs`를 높이고 `--gpu-memory-utilization`도 높여 동시 요청을 최대한 많이 밀어 넣습니다. 개별 요청은 배치 경쟁 때문에 조금 느려질 수 있습니다.
- **지연시간 우선** (실시간 챗봇) — 동시 요청 수를 제한해 각 요청이 GPU 연산 스텝을 더 자주 할당받게 합니다. `--max-num-seqs`를 낮추거나 우선순위 스케줄링을 고려합니다.

또한 vLLM은 **첫 토큰까지의 시간(TTFT, Time To First Token)**과 **토큰당 생성 시간(TPOT, Time Per Output Token)**을 구분해서 봐야 합니다. 프롬프트가 긴 요청이 배치에 섞이면 prefill 연산이 커져 다른 요청들의 TTFT가 늘어나는 현상(head-of-line blocking과 유사)이 발생할 수 있습니다.

---

## 5. OpenAI SDK로 호출하기

vLLM 서버는 OpenAI API 스펙을 그대로 따르므로, 기존 OpenAI 클라이언트 코드를 거의 수정 없이 재사용합니다.

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",  # vLLM은 기본적으로 키 검증을 안 함
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "PagedAttention을 한 문장으로 설명해줘"}],
    stream=True,
)

for chunk in response:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

> 💡 **실무 팁**: `--api-key` 플래그로 vLLM 서버에도 인증을 걸 수 있습니다. 외부에 포트를 노출하는 Runpod 환경(Day 09)에서는 반드시 설정해야 합니다.

---

## 📝 핵심 요약

1. vLLM은 PagedAttention(메모리 단편화 제거)과 Continuous Batching(동적 배치 재구성)으로 naive `generate()` 대비 압도적인 처리량을 냅니다
2. `vllm serve`는 OpenAI 호환 엔드포인트를 제공해 기존 OpenAI SDK 코드를 거의 그대로 재사용할 수 있습니다
3. `--tensor-parallel-size`, `--gpu-memory-utilization`, `--max-model-len`은 실무에서 가장 자주 조정하는 핵심 플래그입니다
4. 처리량과 지연시간은 트레이드오프 관계이며, TTFT와 TPOT를 구분해 목적에 맞게 튜닝해야 합니다

---

## 🔗 참고 자료

- [vLLM 공식 문서](https://docs.vllm.ai/)
- [vLLM: Easy, Fast, and Cheap LLM Serving (PagedAttention 논문/블로그)](https://blog.vllm.ai/2023/06/20/vllm.html)
- [vLLM OpenAI-Compatible Server 가이드](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html)

---

*⬅️ 이전: [Day 06 — Ollama — 가장 간단한 로컬 LLM 실행](../day-06/)  |  다음: [Day 08 — 양자화 & 추론 최적화](../day-08/) ➡️*
