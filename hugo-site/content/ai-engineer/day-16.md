---
title: "Day 16 — Function Calling & JSON Schema"
date: 2026-07-04
weight: 16
---

> **Phase 6: 툴 콜링 & 구조화 출력** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Function Calling(Tool Use)이 모델-호스트-실행 환경 사이에서 동작하는 전체 흐름을 설명할 수 있다
- 타입, required, description을 정확히 채운 JSON Schema 도구 정의를 작성할 수 있다
- 잘못된 도구 호출을 유발하는 흔한 스키마 설계 실수를 식별하고 고칠 수 있다

---

## 1. Function Calling의 동작 원리

LLM은 실제로 함수를 "실행"하지 않습니다. 모델이 하는 일은 오직 하나입니다 — 주어진 도구 목록(스키마)을 보고, "지금 상황에서는 이 도구를 이런 인자로 호출하는 게 적절하다"는 **구조화된 텍스트(JSON)** 를 생성하는 것뿐입니다. 실제 실행은 항상 모델 바깥의 호스트 애플리케이션이 담당합니다.

전체 흐름은 다음 4단계로 이루어집니다.

1. **스키마 전달**: 호스트가 사용 가능한 도구 목록(이름, 설명, JSON Schema 파라미터)을 요청과 함께 모델에 전달
2. **모델의 호출 결정**: 모델이 사용자 요청을 이해하고, 필요하다고 판단되면 도구 이름 + 인자(JSON)를 응답으로 생성 (텍스트 응답 대신, 혹은 함께)
3. **호스트의 실행**: 호스트 애플리케이션이 그 JSON을 파싱해 실제 함수/API를 호출하고 결과를 받음
4. **결과 재주입**: 실행 결과를 다시 대화 컨텍스트(tool 역할 메시지)에 넣어 모델에 전달 → 모델이 최종 자연어 응답 생성

```
[사용자] "서울 날씨 알려줘"
   │
   ▼
[모델] 도구 목록을 보고 판단 → { "name": "get_weather", "arguments": {"city": "Seoul"} }
   │  (아직 실행되지 않음 — 순수 텍스트/JSON 생성 결과)
   ▼
[호스트] JSON 파싱 → 실제 get_weather("Seoul") 함수 실행
   │
   ▼
[호스트] 실행 결과("맑음, 27도")를 tool 메시지로 대화에 추가
   │
   ▼
[모델] 최종 응답 생성 → "서울은 현재 맑고 27도입니다."
```

> 💡 **실무 팁**: 모델이 도구 호출 JSON을 생성했다고 해서 그 인자가 안전하다고 가정하면 안 됩니다. SQL 인젝션, 경로 탈출(path traversal) 등을 막기 위해 호스트 쪽에서 실행 전 반드시 인자를 검증·이스케이프해야 합니다. 이는 Day 14의 MCP Tool 실행에도 동일하게 적용되는 원칙입니다.

---

## 2. JSON Schema로 도구 정의하기

모델은 자연어 설명이 아니라 **JSON Schema**로 도구의 인터페이스를 이해합니다. 아래는 OpenAI/Anthropic 계열 API에서 공통적으로 쓰이는 형태의 도구 정의 예시입니다.

```json
{
  "name": "get_weather",
  "description": "지정한 도시의 현재 날씨 정보를 조회합니다. 도시 이름은 영문으로 입력해야 합니다.",
  "input_schema": {
    "type": "object",
    "properties": {
      "city": {
        "type": "string",
        "description": "날씨를 조회할 도시의 영문 이름 (예: 'Seoul', 'Tokyo')"
      },
      "unit": {
        "type": "string",
        "enum": ["celsius", "fahrenheit"],
        "description": "온도 단위. 사용자가 별도로 언급하지 않으면 'celsius'를 사용"
      }
    },
    "required": ["city"]
  }
}
```

이 스키마에서 모델이 실제로 참고하는 요소는 다음과 같습니다.

| 필드 | 역할 | 정확도에 미치는 영향 |
|---|---|---|
| `name` | 도구 식별자 | 모호하면(`process`, `handle`) 잘못된 도구 선택 유발 |
| `description` (도구 전체) | 언제 이 도구를 써야 하는지 판단 근거 | 가장 큰 영향 — 모델의 도구 선택 정확도를 좌우 |
| `properties.*.description` | 각 인자의 의미/형식 | 잘못된 형식의 인자 생성을 방지 |
| `type` | 값의 자료형 | 타입 불일치 시 파싱 실패나 엉뚱한 값 생성 |
| `enum` | 허용 가능한 값의 집합 | 모델이 임의 문자열을 만들지 않고 정해진 값만 선택하도록 강제 |
| `required` | 필수 인자 목록 | 누락되면 안 되는 값을 모델이 반드시 채우도록 유도 |

> 💡 **실무 팁**: description은 "무엇을 하는 도구인가"뿐 아니라 "언제 쓰고 언제 쓰면 안 되는가"까지 적어주는 것이 효과적입니다. 예: "이 도구는 실시간 날씨만 조회합니다. 과거 날씨 통계는 `get_weather_history`를 사용하세요."처럼 도구 간 경계를 명시하면 혼동을 줄일 수 있습니다.

---

## 3. 흔한 스키마 설계 실수

실무에서 도구 호출 정확도가 낮을 때, 원인의 상당수는 모델이 아니라 스키마 설계에 있습니다.

**1) description을 생략하거나 너무 짧게 쓰는 경우**

```json
// 나쁜 예
{"name": "search", "description": "검색", "input_schema": {...}}

// 좋은 예
{
  "name": "search_knowledge_base",
  "description": "사내 기술 문서 지식베이스에서 키워드로 문서를 검색합니다. 코드/API 문서 관련 질문일 때 사용하세요. 일반 웹 검색이 필요하면 이 도구를 쓰지 마세요.",
  ...
}
```

**2) 타입을 문자열로 뭉뚱그리는 경우**

날짜, 숫자, 불리언까지 전부 `"type": "string"`으로 정의하면 모델이 `"true"`, `"5"`, `"2026/07/19"`처럼 일관성 없는 포맷으로 값을 채워 파싱 오류를 유발합니다. 가능한 한 `integer`, `boolean`, 표준 포맷(`"format": "date"`)을 명시하세요.

**3) required를 빠뜨리거나 과도하게 지정하는 경우**

필수 값을 `required`에 넣지 않으면 모델이 임의로 생략해 런타임에서 `None`/`undefined` 에러가 납니다. 반대로 선택적인 값까지 전부 `required`로 강제하면, 사용자가 언급하지 않은 정보를 모델이 억지로 지어내(hallucinate) 채우는 부작용이 생깁니다.

**4) 열거형(enum)을 쓸 수 있는데 자유 문자열로 두는 경우**

```json
// 나쁜 예 — 모델이 "activated", "ACTIVE", "on" 등 제각각의 값을 생성할 수 있음
{"status": {"type": "string", "description": "상태값"}}

// 좋은 예
{"status": {"type": "string", "enum": ["active", "inactive", "pending"]}}
```

**5) 중첩 구조를 과도하게 깊게 설계하는 경우**

객체 안에 객체, 그 안에 배열처럼 3~4단계 이상 중첩된 스키마는 모델이 정확히 채우기 어렵습니다. 가능하면 평탄한(flat) 구조로 설계하고, 꼭 필요한 경우에만 중첩을 사용하세요.

> 💡 **실무 팁**: 새 도구를 배포하기 전, 실제 사용자 발화 5~10개로 도구 호출을 시뮬레이션해보고 인자가 의도대로 채워지는지 확인하는 것이 스키마 리뷰의 기본입니다. 이는 Day 17에서 다룰 Pydantic 기반 구조화 출력 검증과도 자연스럽게 이어집니다.

---

## 📝 핵심 요약

1. Function Calling에서 모델은 함수를 실행하지 않고, 호출할 도구와 인자를 구조화된 JSON으로 "생성"만 한다 — 실제 실행은 항상 호스트 애플리케이션의 책임이다
2. 흐름은 스키마 전달 → 모델의 호출 결정 → 호스트 실행 → 결과 재주입 → 최종 응답 생성의 4단계로 구성된다
3. JSON Schema의 `description`이 모델의 도구 선택/인자 생성 정확도에 가장 큰 영향을 미친다
4. `type`, `enum`, `required`를 정확히 설계하면 모델이 잘못된 형식이나 임의의 값을 만들어내는 것을 크게 줄일 수 있다
5. 도구 호출 실패의 상당수는 모델 성능이 아니라 모호한 이름, 부실한 설명, 과도한 중첩 구조 등 스키마 설계 문제에서 비롯된다

---

## 🔗 참고 자료

- [Anthropic Tool Use 공식 문서](https://docs.claude.com/en/docs/agents-and-tools/tool-use/overview)
- [OpenAI Function Calling 가이드](https://platform.openai.com/docs/guides/function-calling)
- [JSON Schema 공식 스펙](https://json-schema.org/understanding-json-schema/)

---

*⬅️ 이전: [Day 15 — stdio vs Streamable HTTP — 전송 방식 이해와 실습](../day-15/)  |  다음: [Day 17 — Structured Output & Pydantic 검증](../day-17/) ➡️*
