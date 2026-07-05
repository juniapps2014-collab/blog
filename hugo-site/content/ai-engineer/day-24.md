---
title: "Day 24 — WebSocket & Streaming Response, 인증(Authentication)"
date: 2026-07-04
weight: 24
---

> **Phase 9: 백엔드 API** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- SSE와 WebSocket의 차이와 각각이 적합한 상황을 구분할 수 있다
- FastAPI에서 토큰 단위 스트리밍 응답과 WebSocket 채팅 엔드포인트를 구현할 수 있다
- API Key와 JWT 기반 인증 미들웨어의 기본 구조를 이해한다

---

## 1. 왜 스트리밍이 필요한가

LLM은 토큰을 순차적으로 생성합니다. 전체 응답이 완성될 때까지 기다렸다가 한 번에 반환하면, 답변이 길수록 사용자는 수 초에서 수십 초를 아무 반응 없이 기다려야 합니다. ChatGPT류 UI에서 글자가 하나씩 나타나는 이유가 바로 이 토큰 스트리밍입니다.

스트리밍을 구현하는 방법은 크게 두 가지입니다.

| 방식 | 방향 | 프로토콜 | 적합한 경우 |
|---|---|---|---|
| SSE (Server-Sent Events) | 서버 → 클라이언트 단방향 | HTTP 위에서 동작 | 단순 챗봇 답변 스트리밍, 별도 인프라 불필요 |
| WebSocket | 양방향 풀-듀플렉스 | 별도 프로토콜(ws://) | 실시간 대화, 중간에 사용자가 끼어들기(interrupt)해야 하는 경우 |

> 💡 **실무 팁**: "지금 만드는 게 챗봇 답변 스트리밍뿐인가, 아니면 사용자가 생성 중에도 메시지를 보낼 수 있어야 하는가"를 먼저 판단하세요. 단방향이면 SSE로 충분하고 구현·디버깅이 훨씬 단순합니다. WebSocket은 로드밸런서/프록시 설정(sticky session, timeout)이 추가로 필요해 운영 복잡도가 올라갑니다.

---

## 2. FastAPI로 SSE 스트리밍 구현

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from openai import AsyncOpenAI
import json

app = FastAPI()
client = AsyncOpenAI()


async def token_generator(message: str):
    stream = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": message}],
        stream=True,
    )
    async for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            # SSE 포맷: "data: <payload>\n\n"
            yield f"data: {json.dumps({'token': delta})}\n\n"
    yield "data: [DONE]\n\n"


@app.get("/chat/stream")
async def chat_stream(message: str):
    return StreamingResponse(
        token_generator(message),
        media_type="text/event-stream",
    )
```

클라이언트(브라우저)는 `EventSource` API로 간단히 소비할 수 있습니다.

```javascript
const source = new EventSource("/chat/stream?message=hello");
source.onmessage = (event) => {
  if (event.data === "[DONE]") { source.close(); return; }
  const { token } = JSON.parse(event.data);
  appendToUI(token);
};
```

---

## 3. WebSocket 채팅 세션

여러 턴에 걸친 대화, 혹은 클라이언트가 생성 도중 취소·개입해야 하는 경우 WebSocket이 더 자연스럽습니다.

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()


@app.websocket("/ws/chat/{session_id}")
async def chat_ws(websocket: WebSocket, session_id: str):
    await websocket.accept()
    history: list[dict] = []
    try:
        while True:
            user_message = await websocket.receive_text()
            history.append({"role": "user", "content": user_message})

            stream = await client.chat.completions.create(
                model="gpt-4o-mini",
                messages=history,
                stream=True,
            )
            full_reply = ""
            async for chunk in stream:
                delta = chunk.choices[0].delta.content
                if delta:
                    full_reply += delta
                    await websocket.send_json({"type": "token", "content": delta})

            history.append({"role": "assistant", "content": full_reply})
            await websocket.send_json({"type": "done"})
    except WebSocketDisconnect:
        # 연결 종료 시 세션 정리 (예: history를 Redis/DB에 저장)
        pass
```

WebSocket 연결은 세션(대화)이 유지되는 동안 계속 열려 있으므로, `history`를 커넥션 스코프에 두면 별도 세션 스토어 조회 없이 문맥을 유지할 수 있습니다. 다만 서버 재시작이나 스케일 아웃 시 커넥션이 끊기면 메모리 상의 `history`도 사라지므로, 프로덕션에서는 각 턴마다 Redis 등 외부 저장소에 백업하는 것이 안전합니다.

> 💡 **실무 팁**: WebSocket은 로드밸런서(nginx, ALB) 뒤에 여러 인스턴스를 둘 때 "어느 인스턴스가 이 연결을 들고 있는가" 문제가 생깁니다. 수평 확장이 필요하다면 Redis Pub/Sub 등으로 인스턴스 간 메시지를 중계하는 구조를 함께 고려하세요.

---

## 4. 인증 — API Key와 JWT

**API Key 방식** — 서비스 간(B2B) 호출이나 단순한 클라이언트 인증에 적합합니다.

```python
from fastapi import Depends, HTTPException, Header

API_KEYS = {"sk-live-abc123": "tenant_a", "sk-live-def456": "tenant_b"}


async def verify_api_key(x_api_key: str = Header(...)) -> str:
    tenant = API_KEYS.get(x_api_key)
    if tenant is None:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return tenant


@app.post("/chat")
async def chat(req: ChatRequest, tenant: str = Depends(verify_api_key)):
    ...
```

**JWT 방식** — 사용자별 세션, 만료 시간, 클레임(claim)이 필요한 경우에 적합합니다.

```python
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

SECRET_KEY = "your-secret-key"
security = HTTPBearer()


async def verify_jwt(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    return payload  # {"sub": "user_id", "exp": ...}


@app.get("/me")
async def me(user: dict = Depends(verify_jwt)):
    return {"user_id": user["sub"]}
```

WebSocket에서는 헤더를 자유롭게 못 붙이는 클라이언트 환경(브라우저 `WebSocket` API)이 많아, 보통 연결 시 쿼리 파라미터나 첫 메시지로 토큰을 전달해 검증합니다.

```python
@app.websocket("/ws/chat/{session_id}")
async def chat_ws(websocket: WebSocket, session_id: str, token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    except jwt.InvalidTokenError:
        await websocket.close(code=1008)  # Policy Violation
        return
    await websocket.accept()
    ...
```

> 💡 **실무 팁**: JWT를 쿼리 파라미터로 전달하면 서버 로그나 프록시 로그에 토큰이 그대로 남을 위험이 있습니다. 가능하면 연결 직후 첫 메시지로 토큰을 보내 검증하는 방식을 우선 고려하세요.

---

## 📝 핵심 요약

1. SSE는 단방향 스트리밍에 충분히 단순하고 가볍고, WebSocket은 양방향·개입 가능한 대화에 적합하다
2. FastAPI의 `StreamingResponse`로 OpenAI의 `stream=True` 응답을 SSE 포맷으로 그대로 전달할 수 있다
3. WebSocket 엔드포인트는 커넥션 스코프에서 대화 history를 유지하되, 스케일 아웃 시엔 외부 저장소 백업이 필요하다
4. API Key는 서비스 간 인증에, JWT는 사용자별 세션·만료·클레임이 필요한 인증에 적합하다
5. WebSocket 인증은 헤더 대신 쿼리 파라미터나 첫 메시지로 토큰을 전달하는 경우가 많으며 로깅 노출에 유의해야 한다

---

## 🔗 참고 자료

- [FastAPI — StreamingResponse](https://fastapi.tiangolo.com/advanced/custom-response/#streamingresponse)
- [FastAPI — WebSockets](https://fastapi.tiangolo.com/advanced/websockets/)
- [MDN — Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)

---

*⬅️ 이전: [Day 23 — FastAPI 기초 — REST API 설계](../day-23/)  |  다음: [Day 25 — Planner / Researcher / Coder / Reviewer 역할 분리](../day-25/) ➡️*
