---
title: "Day 06 — Ollama: 가장 간단한 로컬 LLM 실행"
date: 2026-07-04
weight: 6
---

> **Phase 2: 로컬 LLM** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Ollama로 로컬에서 LLM을 설치, 실행, 커스터마이징할 수 있다
- Ollama의 REST API를 사용해 애플리케이션에서 로컬 모델을 호출할 수 있다
- Ollama와 vLLM 중 상황에 맞는 도구를 선택하는 기준을 이해한다

---

## 1. Ollama란

Ollama는 로컬 환경(개인 PC, 서버)에서 오픈소스 LLM을 손쉽게 다운로드하고 실행할 수 있게 해주는 도구입니다. 내부적으로 `llama.cpp`를 엔진으로 사용하며, 모델 다운로드·양자화 버전 관리·REST API 서버·CLI를 하나로 통합해 "가장 진입장벽이 낮은 로컬 LLM 실행 도구"로 자리잡았습니다.

Docker와 비슷한 사용 경험을 목표로 설계되었습니다 — `docker pull`처럼 `ollama pull`, `docker run`처럼 `ollama run`을 사용합니다.

```bash
# macOS / Linux 설치
curl -fsSL https://ollama.com/install.sh | sh

# 설치 확인
ollama --version
```

---

## 2. 기본 명령어 — pull, run, serve

```bash
# 모델 다운로드 (기본 태그는 보통 4-bit 양자화 버전)
ollama pull llama3.1:8b

# 모델 다운로드 + 대화형 실행 (없으면 자동으로 pull)
ollama run llama3.1:8b

# 백그라운드에서 API 서버로 실행 (기본 포트 11434)
ollama serve

# 로컬에 다운로드된 모델 목록 확인
ollama list

# 현재 메모리에 로드되어 실행 중인 모델 확인
ollama ps

# 모델 삭제
ollama rm llama3.1:8b
```

`ollama run` 안에서는 대화형으로 프롬프트를 주고받을 수 있고, `/bye`로 종료합니다. 대부분의 배포판(macOS 앱, systemd 서비스)은 설치 시 `ollama serve`가 자동으로 백그라운드 데몬으로 등록되어 별도 실행 없이도 API가 열려 있습니다.

> 💡 **실무 팁**: `ollama pull llama3.1:8b`처럼 태그를 명시하지 않으면 기본적으로 `:latest`가 아니라 모델별로 지정된 기본 양자화 버전(대개 Q4_0 계열)이 받아집니다. 태그 뒤에 `-q8_0`, `-fp16` 등을 붙여 정밀도를 직접 지정할 수 있습니다 (예: `ollama pull llama3.1:8b-instruct-q8_0`).

---

## 3. Modelfile — 모델 커스터마이징

Ollama는 Dockerfile과 유사한 개념인 **Modelfile**로 시스템 프롬프트, 파라미터, 베이스 모델을 정의해 나만의 커스텀 모델을 만들 수 있습니다.

```dockerfile
# Modelfile
FROM llama3.1:8b

# 생성 파라미터 조정
PARAMETER temperature 0.3
PARAMETER num_ctx 8192
PARAMETER top_p 0.9

# 시스템 프롬프트 고정
SYSTEM """
당신은 한국어로만 답하는 친절한 AI 엔지니어링 튜터입니다.
코드 예제는 항상 주석과 함께 제공하세요.
"""
```

```bash
# Modelfile로부터 커스텀 모델 생성
ollama create my-tutor -f ./Modelfile

# 생성한 모델 실행
ollama run my-tutor
```

주요 `PARAMETER` 옵션:

| 파라미터 | 설명 |
|---|---|
| `temperature` | 생성의 무작위성 (낮을수록 결정적) |
| `num_ctx` | 컨텍스트 윈도우 크기 (기본값보다 늘리면 VRAM 사용량 증가) |
| `top_p`, `top_k` | 샘플링 다양성 제어 |
| `repeat_penalty` | 반복 생성 억제 강도 |
| `num_gpu` | GPU에 오프로드할 레이어 수 (VRAM 부족 시 일부만 GPU, 나머지는 CPU) |

---

## 4. REST API — 애플리케이션에서 호출하기

Ollama는 설치 즉시 `http://localhost:11434`에서 REST API를 제공하므로, 별도 서버 코드 없이 바로 애플리케이션에 통합할 수 있습니다.

```bash
# 기본 생성 API (스트리밍 기본 활성화)
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Transformer의 attention을 한 문장으로 설명해줘",
  "stream": false
}'

# 대화형(chat) API — 메시지 히스토리 형식 지원
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [
    {"role": "system", "content": "당신은 친절한 AI 튜터입니다."},
    {"role": "user", "content": "KV 캐시가 왜 필요한가요?"}
  ],
  "stream": false
}'
```

Python에서는 공식 클라이언트 라이브러리로 더 간단히 호출할 수 있습니다.

```python
import ollama

response = ollama.chat(
    model="llama3.1:8b",
    messages=[{"role": "user", "content": "vLLM과 Ollama의 차이를 요약해줘"}],
)
print(response["message"]["content"])
```

또한 Ollama는 OpenAI SDK와 호환되는 엔드포인트(`/v1/chat/completions`)도 제공해, 기존에 OpenAI API용으로 작성된 코드를 baseURL만 바꿔서 그대로 재사용할 수 있습니다.

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
resp = client.chat.completions.create(
    model="llama3.1:8b",
    messages=[{"role": "user", "content": "안녕하세요"}],
)
print(resp.choices[0].message.content)
```

---

## 5. 양자화 레벨 — Ollama가 제공하는 선택지

Ollama의 모델 라이브러리는 대부분 GGUF 포맷의 다양한 양자화 버전을 태그로 제공합니다.

| 태그 접미사 | 양자화 방식 | 특징 |
|---|---|---|
| `fp16` | 16비트 부동소수점 | 원본에 가장 가까운 품질, 가장 큰 용량 |
| `q8_0` | 8비트 정수 | 품질 손실 거의 없음, fp16 대비 절반 용량 |
| `q6_K` | 6비트 (k-quant) | 품질과 용량의 균형 |
| `q4_K_M` | 4비트 (k-quant, medium) | 가장 널리 쓰이는 기본값, 용량 대비 품질 우수 |
| `q4_0` | 4비트 (레거시) | 구형 방식, 대부분 k-quant로 대체됨 |
| `q2_K` | 2비트 | 용량은 최소지만 품질 저하가 뚜렷함 |

```bash
# 특정 양자화 버전을 명시해서 다운로드
ollama pull llama3.1:8b-instruct-q4_K_M
ollama pull llama3.1:8b-instruct-q8_0
```

> 💡 **실무 팁**: VRAM이 넉넉하지 않은 개인 GPU(8~16GB)에서는 `q4_K_M`이 품질/용량 균형의 사실상 기본 선택지입니다. 정확도가 중요한 작업(코드 생성, 수치 추론)에서는 `q8_0` 이상을 고려하되, VRAM 여유를 반드시 계산해야 합니다 (Day 03의 VRAM 어림 공식 참고).

---

## 6. Ollama vs vLLM — 언제 무엇을 쓸까

Ollama와 vLLM은 둘 다 로컬/자체 인프라에서 LLM을 서빙하지만, 설계 목표가 다릅니다.

| 기준 | Ollama | vLLM |
|---|---|---|
| 목표 | 간편한 로컬 실행, 개인/개발 환경 | 고성능 프로덕션 서빙, 높은 처리량 |
| 동시 요청 처리 | 제한적 (기본적으로 순차/소규모 동시성) | PagedAttention 기반 대규모 동시 배치 처리 |
| 설치 난이도 | 매우 쉬움 (원커맨드 설치) | 상대적으로 복잡 (CUDA 환경, 설정 필요) |
| 양자화 지원 | GGUF 기반 다양한 양자화 즉시 지원 | AWQ, GPTQ, FP8 등 프로덕션급 양자화 지원 |
| 적합한 상황 | 개인 실험, 프로토타입, 로컬 개발, 저사양 GPU | 다수 사용자 동시 접속, API 서버, 처리량이 중요한 프로덕션 |

> 💡 **실무 팁**: "로컬에서 빠르게 아이디어를 검증하고 싶다"면 Ollama, "실제 트래픽을 받는 API 서버를 GPU 클러스터에 배포해야 한다"면 vLLM으로 넘어가는 것이 자연스러운 흐름입니다. 다음 시간(Day 07)에 vLLM을 자세히 다룹니다.

---

## 📝 핵심 요약

1. Ollama는 llama.cpp를 엔진으로 한 원커맨드 로컬 LLM 실행 도구로, Docker와 유사한 CLI 경험을 제공한다
2. Modelfile로 시스템 프롬프트, temperature, context 크기 등을 정의해 커스텀 모델을 만들 수 있다
3. `localhost:11434`의 REST API와 OpenAI 호환 엔드포인트로 기존 코드에 쉽게 통합 가능하다
4. GGUF 양자화 태그(q4_K_M, q8_0 등)로 품질/VRAM 트레이드오프를 직접 선택할 수 있다
5. Ollama는 개인/개발 환경, vLLM은 고처리량 프로덕션 서빙에 적합하다

---

## 🔗 참고 자료

- [Ollama 공식 문서](https://ollama.com/docs)
- [Ollama GitHub 저장소](https://github.com/ollama/ollama)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)

---

*⬅️ 이전: [Day 05 — Token / Embedding / Context Window / KV Cache](../day-05/)  |  다음: [Day 07 — vLLM 고성능 추론 서버 구축](../day-07/) ➡️*
