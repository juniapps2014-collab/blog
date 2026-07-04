---
title: "Day 15 — Streaming 응답 처리"
date: 2026-07-05
weight: 15
---


> **Phase 3: API 활용** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Streaming Messages API의 이벤트 흐름(`message_start` → `content_block_*` → `message_delta` → `message_stop`)을 설명할 수 있다
- Python SDK로 텍스트, 도구 입력, extended thinking 델타를 각각 구분해 처리하는 코드를 작성할 수 있다
- 스트리밍 중 발생하는 에러를 감지하고, 모델 세대별로 다른 복구 전략을 적용할 수 있다

---

## 1. 스트리밍이 필요한 이유와 기본 구조

일반적인 `messages.create()` 호출은 Claude가 전체 응답을 다 생성할 때까지 기다렸다가 한 번에 반환합니다. 응답이 길어질수록 사용자는 아무 반응 없는 화면을 오래 바라봐야 하고, `max_tokens`가 크면 HTTP 커넥션이 타임아웃될 위험도 커집니다. 요청에 `"stream": true`를 추가하면 Claude가 토큰을 생성하는 즉시 Server-Sent Events(SSE)로 잘게 쪼개 전송합니다. 챗봇 UI에서 흔히 보는 "타이핑되는" 효과가 바로 이 방식입니다.

스트림은 항상 정해진 순서로 이벤트를 보냅니다.

| 순서 | 이벤트 | 의미 |
|-----|--------|------|
| 1 | `message_start` | 빈 `content`를 가진 Message 객체로 시작 |
| 2 | `content_block_start` | 새 콘텐츠 블록(텍스트/도구/thinking) 시작, `index` 부여 |
| 3 | `content_block_delta` | 해당 블록에 조금씩 내용 추가 (반복) |
| 4 | `content_block_stop` | 해당 블록 완료 |
| 5 | `message_delta` | `stop_reason` 등 최상위 필드 갱신, 누적 `usage` 포함 |
| 6 | `message_stop` | 스트림 종료 |

2~4번은 응답에 텍스트, 도구 호출, thinking 블록이 여러 개 있으면 그만큼 반복됩니다. 중간중간 `ping` 이벤트가 끼어들 수 있는데, 이는 연결 유지용이므로 무시해도 됩니다. 새 버전의 API에서 예고 없이 새로운 이벤트 타입이 추가될 수 있으므로, 클라이언트 코드는 모르는 이벤트를 만나도 죽지 않고 건너뛰도록 작성해야 합니다.

```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 256,
    "stream": true,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

이 요청은 `event: message_start`, `event: content_block_delta` (여러 번), `event: content_block_stop`, `event: message_delta`, `event: message_stop` 순서로 원문 SSE 텍스트를 그대로 반환합니다. 직접 파싱하려면 이 형식을 이해하고 있어야 하지만, 실무에서는 SDK를 쓰는 편이 훨씬 안전합니다.

---

## 2. SDK로 델타 타입별 처리하기

Python SDK의 `client.messages.stream()`은 컨텍스트 매니저를 제공하며, 가장 간단한 형태는 텍스트만 순서대로 출력하는 것입니다.

```python
import anthropic

client = anthropic.Anthropic()

with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "스트리밍 API의 장점을 설명해줘"}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

텍스트 외에 도구 호출(`tool_use`)이나 extended thinking을 함께 다뤄야 한다면 `stream.text_stream` 대신 원시 이벤트를 순회하면서 `delta.type`으로 분기합니다.

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=2048,
    thinking={"type": "adaptive", "display": "summarized"},
    messages=[{"role": "user", "content": "1071과 462의 최대공약수는?"}],
) as stream:
    for event in stream:
        if event.type == "content_block_delta":
            if event.delta.type == "thinking_delta":
                print(f"[생각] {event.delta.thinking}", end="", flush=True)
            elif event.delta.type == "text_delta":
                print(event.delta.text, end="", flush=True)
            elif event.delta.type == "input_json_delta":
                print(f"[도구 입력] {event.delta.partial_json}", end="", flush=True)
```

`tool_use` 블록의 델타는 완성된 JSON이 아니라 **부분 문자열**(`partial_json`)로 옵니다. 최종 `input`은 언제나 객체이지만, 스트리밍 중에는 문자열 조각을 계속 이어붙여야 하며 완전한 파싱은 `content_block_stop` 이후에 해야 안전합니다. thinking 블록은 마지막에 `signature_delta`라는 별도 이벤트가 한 번 오는데, 이는 thinking 내용의 무결성을 검증하기 위한 서명이므로 별도 저장이 필요할 수 있습니다.

이벤트 하나하나를 다룰 필요 없이 완성된 `Message` 객체만 있으면 될 때는 `get_final_message()`를 씁니다. 특히 `max_tokens`를 크게(예: 128000) 잡는 요청은 SDK가 내부적으로 스트리밍을 강제하는데, 그러지 않으면 HTTP 타임아웃이 발생하기 때문입니다.

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=64000,
    messages=[{"role": "user", "content": "긴 기술 문서를 작성해줘"}],
) as stream:
    message = stream.get_final_message()

print(message.content[0].text)
```

---

## 3. 에러 처리와 재연결

스트림 도중에도 에러 이벤트가 올 수 있습니다. 트래픽이 몰리는 시점에는 비스트리밍 요청이라면 HTTP 529로 떨어질 상황이 `overloaded_error`라는 이벤트로 전달됩니다.

```
event: error
data: {"type": "error", "error": {"type": "overloaded_error", "message": "Overloaded"}}
```

네트워크 문제나 타임아웃으로 스트림이 중간에 끊긴 경우, 전체를 재요청하지 않고 이미 받은 부분부터 이어가는 복구 전략을 쓸 수 있습니다. 다만 모델 세대에 따라 이어가는 방식이 다릅니다. Claude 4.5 이하 모델은 지금까지 받은 부분 응답을 새 요청의 assistant 메시지 앞부분으로 넣어 이어쓰게 합니다. Claude 4.6 이상 모델은 이 방식 대신, 받은 부분 응답과 "이어서 계속하라"는 지시를 user 메시지에 담아 보내야 합니다.

```python
partial_text = "지금까지 받은 응답..."

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": f"이전 응답이 다음 지점에서 끊겼습니다: [{partial_text}]. 이어서 계속 작성해줘.",
        }
    ],
)
```

주의할 점은 `tool_use`와 thinking 블록은 부분적으로 복구할 수 없다는 것입니다. 재연결은 가장 최근의 텍스트 블록 지점에서만 안전하게 이어갈 수 있으므로, 도구 호출이나 thinking이 중간에 끊겼다면 해당 블록부터 다시 요청하는 편이 낫습니다. 실무에서는 이런 복구 로직을 직접 구현하기보다 SDK가 제공하는 메시지 누적(accumulation) 기능과 에러 핸들링을 최대한 활용하는 것이 안전합니다.

---

## 📝 핵심 요약

1. `stream: true`를 설정하면 SSE로 응답을 조각내 실시간으로 받을 수 있고, `max_tokens`가 큰 요청의 타임아웃도 방지한다
2. 이벤트 흐름은 `message_start` → (`content_block_start`/`content_block_delta`/`content_block_stop` 반복) → `message_delta` → `message_stop` 순서로 고정되어 있다
3. 델타 타입은 `text_delta`, `input_json_delta`(부분 JSON 문자열), `thinking_delta`/`signature_delta`로 나뉘며 각각 다르게 누적·파싱해야 한다
4. 완성된 Message 객체만 필요하면 이벤트를 직접 다루지 않고 `get_final_message()`를 쓰는 것이 간단하다
5. 스트림 중단 시 복구 방식은 모델 세대에 따라 다르며(4.5 이하: assistant 메시지에 이어쓰기, 4.6 이상: user 메시지로 이어서 요청), tool_use/thinking 블록은 부분 복구가 불가능하다

---

## 🔗 참고 자료

- [Streaming Messages](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Messages API 레퍼런스](https://platform.claude.com/docs/en/api/messages)
- [Fine-grained tool streaming](https://platform.claude.com/docs/en/agents-and-tools/tool-use/fine-grained-tool-streaming)
- [Stop reasons and fallback](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)

---

*⬅️ 이전: [Day 14 — Messages API 파라미터 심화](../day-14/)  |  다음: [Day 16 — Tool Use (Function Calling)](../day-16/) ➡️*
