---
title: "Day 23 — FastAPI 기초 — REST API 설계"
date: 2026-07-26
weight: 23
---

> **Phase 9: 백엔드 API** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- FastAPI가 LLM 백엔드의 사실상 표준으로 자리잡은 이유를 설명할 수 있다
- Pydantic 모델을 이용해 LLM 호출용 REST 엔드포인트를 직접 작성할 수 있다
- Path/Query/Body 파라미터와 의존성 주입(Dependency Injection)의 기본 패턴을 이해한다

---

## 1. 왜 LLM 백엔드는 FastAPI로 수렴하는가

지금까지 만든 에이전트, RAG 파이프라인, 벡터 검색 로직은 결국 어떤 형태로든 프론트엔드나 다른 서비스에 "API"로 노출되어야 합니다. Python 생태계에는 Flask, Django도 있지만, LLM 백엔드에서는 FastAPI가 사실상 표준입니다.

**핵심 이유:**

- **네이티브 async/await** — LLM API 호출은 대부분 I/O 대기(초 단위 응답 지연)이므로, 비동기 처리로 동시에 여러 요청을 효율적으로 처리 가능
- **자동 OpenAPI 문서화** — 코드에 타입 힌트만 달아도 `/docs`에서 Swagger UI가 자동 생성됨. 프론트엔드/QA 팀과의 협업 비용이 크게 줄어듦
- **Pydantic 통합** — 요청/응답 스키마를 파이썬 클래스로 정의하면 자동으로 검증(validation)과 직렬화가 이루어짐. LangChain, LangGraph의 구조화된 출력과도 자연스럽게 맞물림
- **성능** — Starlette + Uvicorn 기반이라 Flask 대비 동시성 처리량이 훨씬 높음

> 💡 **실무 팁**: LangChain/LangGraph로 만든 에이전트를 서비스화할 때, FastAPI는 "얇은 어댑터" 역할만 하도록 설계하세요. 비즈니스 로직(에이전트 그래프, 프롬프트 조립)은 별도 모듈에 두고 라우터는 요청 파싱과 호출만 담당하는 것이 테스트와 유지보수에 유리합니다.

---

## 2. 최소 앱 — LLM 호출 엔드포인트

```python
# main.py
from fastapi import FastAPI
from pydantic import BaseModel, Field
from openai import AsyncOpenAI

app = FastAPI(title="LLM Agent API", version="0.1.0")
client = AsyncOpenAI()


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    session_id: str
    temperature: float = 0.7


class ChatResponse(BaseModel):
    reply: str
    model: str


@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    completion = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": req.message}],
        temperature=req.temperature,
    )
    return ChatResponse(
        reply=completion.choices[0].message.content,
        model=completion.model,
    )
```

```bash
# 개발 서버 실행 (파일 변경 시 자동 재시작)
uvicorn main:app --reload --port 8000

# 자동 생성된 문서 확인
open http://localhost:8000/docs
```

`ChatRequest`에 타입과 `Field` 제약을 선언하는 것만으로 다음이 자동으로 처리됩니다:

- 잘못된 JSON 요청 시 422 응답과 상세 에러 메시지 자동 생성
- `/docs`(Swagger UI), `/redoc`에 스키마 자동 반영
- IDE 자동완성 및 타입 체크

---

## 3. Path / Query / Body 파라미터

FastAPI는 함수 시그니처만으로 파라미터 위치를 추론합니다.

```python
from fastapi import FastAPI, Query, Path
from typing import Optional

app = FastAPI()


@app.get("/sessions/{session_id}/messages")
async def get_messages(
    session_id: str = Path(..., description="대화 세션 ID"),
    limit: int = Query(20, ge=1, le=100, description="반환할 메시지 수"),
    role: Optional[str] = Query(None, description="user/assistant 필터"),
):
    # session_id는 URL 경로에서, limit/role은 쿼리스트링에서 추출됨
    # GET /sessions/abc123/messages?limit=10&role=user
    return {"session_id": session_id, "limit": limit, "role": role}
```

**구분 규칙 요약:**

| 파라미터 종류 | 선언 방법 | 예시 |
|---|---|---|
| Path | 함수 인자명이 경로의 `{}`와 일치 | `/items/{item_id}` |
| Query | 기본값이 있고 Pydantic 모델이 아닌 단순 타입 | `?limit=20` |
| Body | Pydantic `BaseModel`을 타입으로 갖는 인자 | JSON 요청 본문 |

---

## 4. 의존성 주입(Dependency Injection) 기초

인증 확인, DB 세션 생성, 설정값 로딩처럼 여러 엔드포인트에서 반복되는 로직은 `Depends`로 분리합니다.

```python
from fastapi import Depends, HTTPException, Header

async def get_current_user(x_api_key: str = Header(...)) -> dict:
    if x_api_key != "expected-secret-key":
        raise HTTPException(status_code=401, detail="Invalid API key")
    return {"user_id": "u_123"}


async def get_llm_client() -> AsyncOpenAI:
    # 요청마다 새로 만들지 않고 재사용 가능한 클라이언트를 주입
    return client


@app.post("/chat")
async def chat(
    req: ChatRequest,
    user: dict = Depends(get_current_user),
    llm: AsyncOpenAI = Depends(get_llm_client),
):
    completion = await llm.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": req.message}],
    )
    return {"reply": completion.choices[0].message.content, "user_id": user["user_id"]}
```

의존성 함수는 자동으로 계층화(nested)될 수 있고, `Depends`는 테스트 시 `app.dependency_overrides`로 손쉽게 목(mock)으로 교체할 수 있어 유닛 테스트 작성이 쉬워집니다.

> 💡 **실무 팁**: 요청마다 새 OpenAI 클라이언트를 생성하지 마세요. `lifespan` 이벤트(구 `startup`)에서 한 번 생성해 `app.state`에 저장하고 의존성 함수로 꺼내 쓰는 패턴이 커넥션 풀 재사용 측면에서 훨씬 효율적입니다.

---

## 📝 핵심 요약

1. FastAPI는 async 네이티브, 자동 OpenAPI 문서화, Pydantic 통합 덕분에 LLM 백엔드의 사실상 표준이 되었다
2. Pydantic `BaseModel`로 요청/응답 스키마를 정의하면 검증과 문서화가 자동으로 이루어진다
3. 함수 시그니처의 타입과 기본값만으로 Path/Query/Body 파라미터가 자동 구분된다
4. `Depends`로 인증, 클라이언트 주입 등 공통 로직을 분리하면 테스트와 재사용이 쉬워진다
5. LLM 클라이언트는 요청마다 생성하지 말고 앱 lifespan에서 한 번만 만들어 재사용해야 한다

---

## 🔗 참고 자료

- [FastAPI 공식 문서](https://fastapi.tiangolo.com/)
- [Pydantic 공식 문서](https://docs.pydantic.dev/)
- [Uvicorn 공식 문서](https://www.uvicorn.org/)

---

*⬅️ 이전: [Day 22 — Milvus / pgvector 비교와 선택 기준](../day-22/)  |  다음: [Day 24 — WebSocket & Streaming Response, 인증(Authentication)](../day-24/) ➡️*
