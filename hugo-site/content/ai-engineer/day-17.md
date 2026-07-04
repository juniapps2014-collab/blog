---
title: "Day 17 — Structured Output & Pydantic 검증"
date: 2026-07-20
weight: 17
---

> **Phase 6: 툴 콜링 & 구조화 출력** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- LLM이 자연어 대신 검증 가능한 구조화된 데이터를 반환하도록 강제하는 방법을 이해한다
- Pydantic 모델로 LLM 출력의 스키마를 정의하고 파싱/검증하는 흐름을 구현할 수 있다
- 검증 실패 시 재시도(retry) 루프를 설계할 수 있다

---

## 1. 왜 "구조화 출력"이 필요한가

LLM의 기본 출력은 자유 형식 텍스트입니다. 하지만 실제 프로덕션 시스템에서는 LLM의 응답을 프론트엔드에 렌더링하거나, DB에 저장하거나, 다른 API에 전달해야 하는 경우가 대부분입니다. 이때 "대략 JSON처럼 생긴 텍스트"는 쓸모가 없습니다 — 파싱이 실패하거나, 필드가 누락되거나, 타입이 틀리면 시스템 전체가 죽습니다.

**구조화 출력(Structured Output)**이란 LLM이 미리 정의한 스키마(JSON Schema)에 정확히 맞는 데이터만 반환하도록 강제하는 기법입니다. Day 16에서 다룬 Function Calling도 사실 구조화 출력의 한 형태입니다 — 모델이 "함수를 호출한다"는 명목으로 스키마에 맞는 인자를 생성하기 때문입니다.

**구조화 출력이 필요한 대표 상황:**

- 사용자 입력에서 이름/날짜/금액 등을 추출해 DB row로 저장
- LLM 응답을 기반으로 UI 컴포넌트(카드, 표)를 렌더링
- 멀티 에이전트 파이프라인에서 한 에이전트의 출력을 다음 에이전트의 입력으로 그대로 전달

---

## 2. 구조화 출력을 강제하는 3가지 패턴

| 패턴 | 설명 | 신뢰도 |
|---|---|---|
| 프롬프트 지시만 | "JSON으로만 답하라"고 지시 | 낮음 — 모델이 설명을 덧붙이거나 형식을 어길 수 있음 |
| Tool/Function Forcing | 함수 하나만 정의하고 `tool_choice`로 강제 호출 | 높음 — 인자가 스키마를 따르도록 모델이 학습되어 있음 |
| 네이티브 `response_format` | OpenAI의 `response_format={"type": "json_schema", ...}` (Structured Outputs) | 매우 높음 — 디코딩 단계에서 스키마 제약을 직접 적용 |

OpenAI의 최신 Structured Outputs 기능은 constrained decoding(제약 디코딩)을 사용해 모델이 스키마를 위반하는 토큰 자체를 생성할 수 없도록 만듭니다. 반면 프롬프트 지시만으로는 모델이 여전히 스키마를 "위반할 자유"가 있습니다.

```python
from openai import OpenAI
from pydantic import BaseModel

client = OpenAI()

class Invoice(BaseModel):
    vendor: str
    total_amount: float
    due_date: str
    line_items: list[str]

response = client.chat.completions.parse(
    model="gpt-4o-2024-08-06",
    messages=[
        {"role": "system", "content": "청구서 텍스트에서 정보를 추출하세요."},
        {"role": "user", "content": "Acme Corp, 총액 $1,250.00, 결제기한 2026-08-01. 항목: 컨설팅, 라이선스"},
    ],
    response_format=Invoice,
)

invoice: Invoice = response.choices[0].message.parsed
print(invoice.vendor, invoice.total_amount)
```

`.parse()`를 사용하면 SDK가 내부적으로 Pydantic 모델을 JSON Schema로 변환해 요청에 실어 보내고, 응답을 받은 뒤 다시 Pydantic 객체로 역직렬화까지 해줍니다.

> 💡 **실무 팁**: 모든 LLM 제공업체가 네이티브 `response_format`을 지원하는 것은 아닙니다(Anthropic, 로컬 오픈소스 모델 등). 이런 경우 Tool Forcing 패턴이나 아래에서 다룰 재시도 루프로 대체해야 합니다.

---

## 3. Pydantic 모델 설계

Pydantic은 Python 타입 힌트를 런타임 검증 로직으로 바꿔주는 라이브러리입니다. LLM 출력 검증에 특히 적합한 이유는 "타입이 맞는가"뿐 아니라 "값의 범위/형식이 유효한가"까지 선언적으로 표현할 수 있기 때문입니다.

```python
from pydantic import BaseModel, Field, field_validator
from typing import Literal
from datetime import date

class TicketClassification(BaseModel):
    category: Literal["billing", "technical", "account", "other"]
    priority: int = Field(ge=1, le=5, description="1(낮음)~5(긴급)")
    summary: str = Field(max_length=200)
    escalate: bool
    estimated_resolution_date: date | None = None

    @field_validator("summary")
    @classmethod
    def summary_must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("summary는 비어 있을 수 없습니다")
        return v.strip()
```

**핵심 설계 원칙:**

- `Literal`로 카테고리형 값의 후보를 제한하면, 모델이 스키마를 준수하는 한 오탈자나 예상 밖 값이 원천 차단됩니다.
- `Field(ge=..., le=...)`처럼 제약 조건을 추가하면 "숫자이긴 한데 범위를 벗어난" 값도 검증 단계에서 걸러집니다.
- `Optional`/`None` 기본값은 LLM이 정보를 찾지 못했을 때 강제로 값을 지어내는(hallucinate) 대신 명시적으로 "없음"을 표현하게 해줍니다.
- 필드에 `description`을 달면 이것이 JSON Schema의 `description`으로 그대로 전달되어 모델의 이해를 돕는 프롬프트 역할도 겸합니다.

---

## 4. 검증 실패 시 재시도 루프

Structured Outputs를 지원하지 않는 모델(구형 API, 오픈소스 로컬 모델)을 쓰거나, 복잡한 커스텀 검증 로직(`field_validator`, `model_validator`)이 있는 경우 모델이 스키마를 완벽히 지키지 못할 수 있습니다. 이때는 **검증 실패 → 에러 메시지를 모델에게 피드백 → 재생성**하는 루프가 표준 패턴입니다.

```python
from pydantic import ValidationError
import json

def extract_with_retry(client, prompt: str, schema_model, max_retries: int = 3):
    messages = [{"role": "user", "content": prompt}]

    for attempt in range(max_retries):
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            response_format={"type": "json_object"},
        )
        raw = response.choices[0].message.content

        try:
            data = json.loads(raw)
            return schema_model.model_validate(data)
        except (json.JSONDecodeError, ValidationError) as e:
            if attempt == max_retries - 1:
                raise RuntimeError(f"{max_retries}회 시도 후 검증 실패") from e

            # 모델에게 실패 원인을 알려주고 재생성 요청
            messages.append({"role": "assistant", "content": raw})
            messages.append({
                "role": "user",
                "content": f"출력이 스키마를 위반했습니다. 에러: {e}\n"
                            f"다시 유효한 JSON으로만 응답하세요.",
            })

    raise RuntimeError("도달 불가")
```

이 패턴에서 중요한 것은 **에러 메시지를 그대로 모델에게 돌려주는 것**입니다. Pydantic의 `ValidationError`는 어떤 필드가 왜 실패했는지 사람이 읽을 수 있는 형태로 알려주므로, 이를 컨텍스트에 추가하면 모델이 다음 시도에서 스스로 교정할 확률이 크게 높아집니다.

> 💡 **실무 팁**: 재시도 루프는 비용과 지연시간을 증가시킵니다. `max_retries`를 낮게(2~3회) 설정하고, 그래도 실패하면 사람에게 에스컬레이션하거나 기본값으로 폴백하는 안전장치를 반드시 두세요.

---

## 5. LangChain/Instructor 같은 라이브러리 활용

매번 재시도 루프를 직접 짜는 대신, 이 패턴을 캡슐화한 라이브러리를 쓰는 것이 실무에서는 일반적입니다.

```python
import instructor
from openai import OpenAI

client = instructor.from_openai(OpenAI())

class Invoice(BaseModel):
    vendor: str
    total_amount: float

invoice = client.chat.completions.create(
    model="gpt-4o-mini",
    response_model=Invoice,
    max_retries=3,   # 검증 실패 시 자동 재시도
    messages=[{"role": "user", "content": "..."}],
)
```

`instructor` 라이브러리는 Pydantic 모델을 `response_model`로 넘기기만 하면 스키마 변환, 파싱, 검증 실패 시 재시도까지 전부 자동으로 처리합니다. LangChain의 `with_structured_output()` 메서드도 동일한 목적을 가지지만 내부 구현(네이티브 지원 vs 프롬프트 기반)은 모델 제공업체에 따라 달라집니다.

---

## 📝 핵심 요약

1. 구조화 출력은 "프롬프트로 부탁하기"가 아니라 스키마 강제(tool forcing, constrained decoding)로 신뢰도를 높이는 것이 핵심이다
2. Pydantic 모델은 타입 검증뿐 아니라 `Literal`, `Field(ge/le)`, `field_validator`로 비즈니스 규칙까지 선언적으로 표현할 수 있다
3. 네이티브 `response_format`을 지원하지 않는 환경에서는 검증 실패 메시지를 모델에게 피드백하는 재시도 루프가 표준 대응책이다
4. `instructor` 같은 라이브러리는 스키마 변환-파싱-재시도 과정을 캡슐화해 보일러플레이트를 줄여준다

---

## 🔗 참고 자료

- [OpenAI Structured Outputs 공식 가이드](https://platform.openai.com/docs/guides/structured-outputs)
- [Pydantic 공식 문서 — Validators](https://docs.pydantic.dev/latest/concepts/validators/)
- [Instructor 라이브러리 문서](https://python.useinstructor.com/)

---

*⬅️ 이전: [Day 16 — Function Calling & JSON Schema](../day-16/)  |  다음: [Day 18 — RAG 개념과 Chunking 전략](../day-18/) ➡️*
