---
title: "Day 16 — Tool Use (Function Calling)"
date: 2026-07-06
weight: 16
---


> **Phase 3: API 활용** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Client tool과 Server tool의 실행 위치 차이를 설명하고, 상황에 맞게 선택할 수 있다
- `input_schema`와 `tool_choice`를 사용해 Claude의 도구 호출 방식을 설계할 수 있다
- `tool_use` → 실행 → `tool_result`로 이어지는 전체 루프를 Python 코드로 구현할 수 있다

---

## 1. Tool Use란 무엇인가 — Client Tool vs Server Tool

Tool Use(Function Calling)는 Claude가 스스로 답할 수 없는 질문에 부딪혀 외부 함수나 API를 "호출"하도록 만드는 기능입니다. 정확히 말하면 Claude가 직접 코드를 실행하는 것이 아니라, "이 도구를 이런 입력으로 불러달라"는 구조화된 요청(JSON)을 반환할 뿐입니다. 실제 실행은 도구의 종류에 따라 둘 중 한 곳에서 일어납니다.

| 구분 | 실행 위치 | 예시 | 흐름 |
|-----|----------|------|------|
| Client tool | 내 애플리케이션 서버 | 사용자가 직접 정의한 함수, `bash`, `text_editor` | Claude가 `tool_use` 반환 → 내가 실행 → `tool_result`를 다시 전송 |
| Server tool | Anthropic 인프라 | `web_search`, `web_fetch`, `code_execution` | Claude가 호출부터 실행까지 처리 → 결과가 같은 응답에 포함 |

즉 "직접 만든 함수"는 항상 client tool이고, Anthropic이 스키마와 실행 환경을 모두 제공하는 몇 가지 도구만 server tool입니다. 이 강의에서는 실무에서 가장 많이 쓰는 client tool, 즉 사용자 정의 함수 연동에 집중합니다.

전체 흐름은 다음과 같은 반복 루프(agentic loop)입니다.

1. 사용자가 질문을 보낸다
2. Claude가 `tools`에 정의된 함수 중 필요한 것을 판단해 `stop_reason: "tool_use"`와 함께 `tool_use` 블록을 반환한다
3. 내 애플리케이션이 해당 함수를 실제로 실행한다
4. 실행 결과를 `tool_result` 블록으로 담아 다시 Claude에게 보낸다
5. Claude가 결과를 바탕으로 최종 답변을 생성한다

이 루프는 한 번에 끝나지 않을 수도 있습니다. 복잡한 작업이라면 Claude가 도구를 여러 번 연쇄적으로 호출하기도 합니다.

---

## 2. Tool 정의하기 — input_schema와 tool_choice

도구는 요청의 `tools` 파라미터에 배열로 전달하며, 각 도구는 세 가지 핵심 필드로 구성됩니다.

- **name**: `^[a-zA-Z0-9_-]{1,64}$` 정규식을 만족하는 이름
- **description**: 도구가 무엇을 하는지, 언제 써야 하는지, 각 파라미터가 무엇을 의미하는지 최소 3~4문장으로 상세히 설명 — 이 항목의 품질이 도구 선택 정확도에 가장 큰 영향을 줍니다
- **input_schema**: 입력 파라미터를 정의하는 JSON Schema 객체

```python
tools = [
    {
        "name": "get_weather",
        "description": (
            "지정한 도시의 현재 날씨 정보를 반환한다. "
            "실시간 기온, 습도, 날씨 상태를 알려줄 때 사용하고, "
            "미래 예보나 과거 날씨는 지원하지 않는다."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "도시와 국가, 예: 'Seoul, South Korea'",
                },
                "unit": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "온도 단위 (기본값: celsius)",
                },
            },
            "required": ["location"],
        },
    }
]
```

Claude가 도구를 호출할지 여부는 `tool_choice`로 제어합니다.

| 값 | 동작 |
|-----|------|
| `auto` (기본값) | Claude가 상황에 맞게 스스로 판단 |
| `any` | 반드시 도구 중 하나를 호출하되, 어떤 도구인지는 자유 |
| `{"type": "tool", "name": "..."}` | 지정한 도구를 강제로 호출 |
| `none` | 도구를 전혀 사용하지 않음 |

`any`나 특정 `tool`을 강제하면 Claude는 자연어 설명 없이 곧바로 `tool_use` 블록만 반환합니다. 도구 호출과 함께 자연스러운 설명도 원한다면 `tool_choice`는 `auto`로 두고, 시스템 프롬프트나 사용자 메시지에 "get_weather 도구를 사용해서 답해줘"처럼 명시적으로 지시하는 편이 낫습니다. 또한 `strict: true`를 도구 정의에 추가하면 Claude가 반환하는 입력이 스키마를 정확히 준수하도록 강제할 수 있어, 파싱 에러를 크게 줄일 수 있습니다.

---

## 3. 실습: 전체 Tool Use 루프 구현하기

실제로 함수를 실행하고 결과를 돌려주는 전체 루프를 구현해 보겠습니다. 핵심은 `tool_use` 블록의 `id`를 그대로 `tool_result`의 `tool_use_id`에 담아 매칭시키는 것입니다.

```python
import anthropic

client = anthropic.Anthropic()

def get_weather(location: str, unit: str = "celsius") -> str:
    # 실제로는 외부 날씨 API를 호출하는 부분
    return f"{location}의 현재 기온은 22{unit[0].upper()}이고 맑음입니다."

messages = [{"role": "user", "content": "서울 날씨 어때?"}]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    messages=messages,
)

if response.stop_reason == "tool_use":
    messages.append({"role": "assistant", "content": response.content})

    tool_results = []
    for block in response.content:
        if block.type == "tool_use":
            result = get_weather(**block.input)
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": result,
            })

    messages.append({"role": "user", "content": tool_results})

    final = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        tools=tools,
        messages=messages,
    )
    print(final.content[0].text)
```

함수 실행 중 에러가 발생하면 `tool_result`에 `"is_error": true`를 추가해 Claude에게 실패를 알릴 수 있습니다. 이렇게 하면 Claude가 무작정 같은 결과를 다시 요청하지 않고, 다른 파라미터로 재시도하거나 사용자에게 상황을 설명하는 등 적절히 대응합니다.

```python
tool_results.append({
    "type": "tool_result",
    "tool_use_id": block.id,
    "content": "오류: 알 수 없는 도시명입니다.",
    "is_error": True,
})
```

Claude가 한 응답 안에서 여러 도구를 동시에 호출하는 경우(parallel tool use)도 흔합니다. 이때는 `response.content`를 순회하며 `tool_use` 타입인 블록을 모두 처리한 뒤, 각각의 `tool_result`를 하나의 user 메시지에 함께 담아 보내야 합니다. 하나라도 빠뜨리면 다음 요청에서 400 에러가 발생하므로, 반환된 `tool_use` 블록 수와 보내는 `tool_result` 수가 항상 일치해야 합니다.

---

## 📝 핵심 요약

1. Client tool은 내 애플리케이션이 실행하고 결과를 `tool_result`로 돌려줘야 하며, server tool(`web_search` 등)은 Anthropic 인프라에서 실행되어 같은 응답에 결과가 포함된다
2. 도구 정의의 핵심은 `description`이며, 무엇을 하는지·언제 쓰는지·파라미터 의미를 최소 3~4문장으로 상세히 적을수록 선택 정확도가 올라간다
3. `tool_choice`는 `auto`/`any`/특정 `tool`/`none` 네 가지이며, 강제 호출 시 Claude는 자연어 설명 없이 곧바로 도구를 호출한다
4. `tool_use` 블록의 `id`는 반드시 `tool_result`의 `tool_use_id`로 그대로 매칭해서 돌려줘야 하고, 병렬 호출 시에는 모든 호출에 대한 결과를 빠짐없이 보내야 한다
5. 실행 실패는 `is_error: true`로 알려주면 Claude가 재시도나 사용자 안내 등 스스로 적절히 대응한다

---

## 🔗 참고 자료

- [Tool use with Claude — Overview](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)
- [Define tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools)
- [Handle tool calls](https://platform.claude.com/docs/en/agents-and-tools/tool-use/handle-tool-calls)
- [Parallel tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/parallel-tool-use)
- [Strict tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use)

---

*⬅️ 이전: [Day 15 — Streaming 응답 처리](../day-15/)  |  다음: [Day 17 — Vision API](../day-17/) ➡️*
