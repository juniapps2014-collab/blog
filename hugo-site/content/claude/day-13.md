---
title: "Day 13 — Anthropic API 기초"
date: 2026-07-03
weight: 13
---


> **Phase 3: API 활용** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- API 키 발급부터 첫 Messages API 호출까지 전체 흐름을 이해한다
- 요청 헤더(x-api-key, anthropic-version)의 역할과 필수 파라미터를 설명할 수 있다
- 응답 객체의 구조(content, usage, stop_reason)를 읽고 활용할 수 있다

---

## 1. API 접근 준비

Anthropic API를 쓰려면 두 가지가 필요합니다: **API 키**와 **엔드포인트**입니다.

1. https://console.anthropic.com 에서 계정 생성 후 Settings → API Keys에서 키 발급 (`sk-ant-`로 시작)
2. 결제 수단 등록 및 크레딧 충전 (사용량 기반 과금)
3. SDK 설치 또는 REST 호출 준비

```bash
# Python SDK
pip install anthropic

# Node.js SDK
npm install @anthropic-ai/sdk
```

API 키는 절대 클라이언트 코드(프론트엔드)에 노출하면 안 됩니다. 반드시 서버 환경변수로 관리하세요.

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

---

## 2. 요청 구조 — Messages API

Anthropic API의 핵심 엔드포인트는 `POST /v1/messages` 하나입니다. GPT의 `chat/completions`와 유사한 역할을 합니다.

**필수 헤더:**

| 헤더 | 값 | 설명 |
|------|-----|------|
| `x-api-key` | 발급받은 키 | 인증 (Authorization: Bearer 아님에 주의) |
| `anthropic-version` | `2023-06-01` | API 버전 고정 (하위 호환성 보장) |
| `content-type` | `application/json` | 요청 본문 형식 |

**curl 예시:**

```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Anthropic API를 한 문장으로 설명해줘"}
    ]
  }'
```

`anthropic-version`을 고정하는 이유: Anthropic이 API를 변경해도 이 헤더 값을 유지하면 기존 요청 형식이 계속 동작합니다. 새 기능을 쓰려면 버전을 올리고 마이그레이션 가이드를 확인하면 됩니다.

---

## 3. Python SDK로 첫 호출

```python
import anthropic

client = anthropic.Anthropic()  # ANTHROPIC_API_KEY 환경변수 자동 사용

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="당신은 친절한 한국어 기술 문서 작성 도우미입니다.",
    messages=[
        {"role": "user", "content": "REST API와 RPC의 차이를 3줄로 설명해줘"}
    ]
)

# 응답 텍스트 추출
print(response.content[0].text)

# 메타데이터 확인
print(response.stop_reason)   # "end_turn", "max_tokens", "tool_use" 등
print(response.usage)         # {"input_tokens": ..., "output_tokens": ...}
```

**응답 객체 구조 이해가 중요한 이유:**

- `content`는 배열입니다. 텍스트 하나만 오더라도 `content[0].text`로 접근해야 합니다. Tool use나 멀티 블록 응답에서는 배열에 여러 항목이 들어옵니다.
- `stop_reason`으로 응답이 왜 끝났는지 판단합니다. `max_tokens`이면 응답이 잘렸다는 뜻이므로 `max_tokens` 값을 늘리거나 이어받기 로직이 필요합니다.
- `usage`는 과금과 직결됩니다. 토큰 수를 로깅해두면 이후 비용 최적화(Day 18)에 필요한 데이터가 됩니다.

**필수 파라미터 정리:**

| 파라미터 | 필수 여부 | 설명 |
|---------|----------|------|
| `model` | 필수 | 사용할 모델 ID |
| `max_tokens` | 필수 | 생성할 최대 토큰 수 (응답 길이 상한) |
| `messages` | 필수 | 대화 배열 (role: user/assistant) |
| `system` | 선택 | 시스템 프롬프트 (별도 필드, messages에 넣지 않음) |
| `temperature` | 선택 | 0~1, 무작위성 조절 (기본 1) |

주의할 점: `messages` 배열은 반드시 `user` role로 시작해야 하고, `system`은 messages 안이 아니라 별도 최상위 필드로 전달합니다. OpenAI API에 익숙하다면 이 부분이 가장 헷갈리는 차이점입니다.

---

## 📝 핵심 요약

1. Anthropic API는 단일 엔드포인트(`/v1/messages`)에 `x-api-key`, `anthropic-version` 헤더로 인증한다
2. `model`, `max_tokens`, `messages`는 필수 파라미터이며 `system`은 별도 필드로 분리되어 있다
3. 응답의 `content`는 배열이므로 `content[0].text`로 접근하고, `stop_reason`으로 종료 사유를 확인한다
4. `usage` 필드는 토큰 사용량을 담고 있어 과금 추적과 최적화의 기초 데이터가 된다
5. API 키는 서버 사이드에서만 관리하고 절대 클라이언트에 노출하지 않는다

---

## 🔗 참고 자료

- [Anthropic API 시작하기](https://docs.anthropic.com/en/api/getting-started)
- [Messages API 레퍼런스](https://docs.anthropic.com/en/api/messages)
- [API 인증 가이드](https://docs.anthropic.com/en/api/overview)

---

*⬅️ 이전: [Day 12](../day-12/)  |  다음: [Day 14](../day-14/) ➡️*
