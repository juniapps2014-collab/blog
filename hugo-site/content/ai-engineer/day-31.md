---
title: "Day 31 — 통합 프로젝트: Runpod → vLLM → Local LLM → LangGraph → MCP → RAG → FastAPI → Web UI"
date: 2026-08-03
weight: 31
---

> **Final Project** | 예상 소요 시간: 1~2주 (파트타임 기준)

---

## 🎯 프로젝트 목표

지난 30일 동안 조각조각 배운 GPU 인프라, 로컬 LLM 서빙, 에이전트 프레임워크, 도구 연동, 검색 증강, API 서버, 관찰성, 파인튜닝을 하나의 파이프라인으로 엮습니다. 이 프로젝트를 마치면 다음이 모두 갖춰진 상태가 됩니다.

- Runpod GPU 위에서 vLLM으로 서빙되는 자체 호스팅 LLM
- 그 LLM 위에서 동작하는, 도구를 스스로 선택해 호출하는 LangGraph 에이전트
- MCP(Model Context Protocol)를 통해 외부 도구/데이터 소스에 표준화된 방식으로 접근
- 사내 문서를 검색해 답변 근거로 삼는 RAG 파이프라인
- 이 모든 것을 감싸는 FastAPI 백엔드와, 사용자가 실제로 대화할 수 있는 웹 UI
- Langfuse로 전체 요청 흐름을 추적하고, 최소한의 평가 데이터셋으로 품질을 체크하는 관측 체계

즉 "로컬 모델을 하나 띄워봤다" 수준을 넘어, **실제 서비스 형태를 갖춘 엔드투엔드 에이전트 시스템**을 스스로 설계하고 조립할 수 있는 능력을 최종 확인하는 것이 이 프로젝트의 목표입니다.

---

## 1. 아키텍처 개요

```text
┌─────────────────────────────────────────────────────────────────────┐
│  사용자 (브라우저)                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Web UI (Next.js / Streamlit / Gradio 등)                      │  │
│  │  - 채팅 인터페이스, 스트리밍 응답 렌더링                            │  │
│  └───────────────────────────────────────────────────────────────┘  │
└───────────────────────────────┬───────────────────────────────────┘
                                 │ HTTPS (SSE/WebSocket 스트리밍)
┌───────────────────────────────▼───────────────────────────────────┐
│  FastAPI 백엔드 (자체 서버 또는 Runpod 위 별도 컨테이너)                  │
│  - POST /chat  → LangGraph 에이전트 invoke                          │
│  - Langfuse CallbackHandler로 전 구간 트레이싱                        │
└───────────────────────────────┬───────────────────────────────────┘
                                 │
┌───────────────────────────────▼───────────────────────────────────┐
│  LangGraph 에이전트 (StateGraph)                                     │
│                                                                     │
│   [입력] → router 노드 → ┬─ RAG 필요? → retrieve 노드 ─┐             │
│                          ├─ 도구 필요? → tool_call 노드 ┤            │
│                          └─ 바로 답변? ──────────────┐ │             │
│                                                       ▼ ▼             │
│                                              generate 노드 (LLM 호출) │
└──────┬───────────────────────────┬───────────────────────┬────────┘
       │                           │                       │
       ▼                           ▼                       ▼
┌─────────────┐        ┌────────────────────┐   ┌────────────────────┐
│ MCP 클라이언트 │        │  RAG 파이프라인       │   │  vLLM 추론 서버       │
│ → MCP 서버   │        │  - 임베딩 모델        │   │  (Runpod GPU Pod)   │
│  (도구 실행)  │        │  - 벡터DB (검색)      │   │  - Local LLM        │
│              │        │  - 문서 청크 저장소    │   │  - OpenAI 호환 API   │
└─────────────┘        └────────────────────┘   └────────────────────┘
```

핵심 설계 원칙은 **"vLLM 추론 서버는 OpenAI 호환 API로 격리하고, 그 위의 모든 로직(라우팅, RAG, 도구 호출)은 LangGraph가 오케스트레이션한다"**는 것입니다. 이렇게 분리하면 나중에 로컬 모델을 상용 API(OpenAI, Anthropic)로 바꾸거나 그 반대로 바꿀 때 에이전트 로직을 거의 건드리지 않아도 됩니다.

> 💡 **실무 팁**: 아키텍처 다이어그램을 실제로 그려보고 각 화살표에 "어떤 프로토콜/포맷으로 통신하는가"(HTTP+JSON, OpenAI 호환 스키마, MCP 프로토콜 등)를 적어보세요. 이 작업만으로도 설계 단계에서 놓친 인터페이스 불일치를 상당수 미리 잡아낼 수 있습니다.

---

## 2. 구현 단계별 체크리스트

아래는 실제 구현 순서로 진행하기 좋은 체크리스트입니다. 괄호 안은 각 개념을 처음 다룬 Day를 가리킵니다 — 막히면 해당 Day 노트로 돌아가서 복습하세요.

1. **Runpod에 GPU Pod 생성** (Day 09) — 예산에 맞는 GPU(A100/A6000 등) 선택, SSH 접속 확인
2. **컨테이너 환경 구성** (Day 02) — Docker 이미지에 CUDA, Python, vLLM 의존성 고정
3. **vLLM으로 모델 서빙** (Day 07) — 선택한 오픈소스 모델(Llama, Qwen 등)을 OpenAI 호환 엔드포인트로 기동, `/v1/chat/completions` 응답 확인
4. **(선택) Day 29 파인튜닝 적용** — 도메인 특화가 필요하면 QLoRA로 어댑터를 학습해 병합한 모델을 3번 단계에서 서빙
5. **LangGraph 기본 그래프 구성** (Day 11) — router → generate로 이어지는 최소 그래프부터 시작해 vLLM 엔드포인트를 `ChatOpenAI(base_url=...)`로 연결
6. **Conditional Edge로 분기 로직 추가** (Day 12) — "도구가 필요한 질문인가 / RAG가 필요한 질문인가 / 바로 답할 질문인가"를 라우팅
7. **MCP 서버 연동** (Day 17) — 사내 API(예: 주문 조회, 티켓 생성)를 MCP 서버로 노출하고, LangGraph에서 MCP 클라이언트로 도구 목록을 불러와 바인딩
8. **RAG 파이프라인 구축** (Day 20) — 문서를 청크 단위로 임베딩해 벡터DB에 적재, retrieve 노드에서 유사도 검색 후 컨텍스트로 주입
9. **FastAPI로 백엔드 감싸기** (Day 23) — `/chat` 엔드포인트에서 LangGraph 그래프를 invoke/stream, 세션별 상태 관리
10. **Web UI 연결** (Day 25) — 스트리밍 응답을 실시간으로 렌더링하는 채팅 화면 구성
11. **Langfuse 트레이싱 삽입** (Day 27) — FastAPI 진입점부터 LangGraph 전체 실행까지 CallbackHandler로 계측
12. **최소 평가셋으로 회귀 테스트** (Day 28) — 배포 전 핵심 시나리오 20~30개로 품질 점검
13. **End-to-End 통합 테스트** — 실제 브라우저에서 질문을 던져 RAG 근거 인용, 도구 호출 결과, 스트리밍이 모두 정상 동작하는지 확인

> 💡 **실무 팁**: 13단계를 한 번에 다 연결하려 하지 말고, 5→6번(에이전트 로직)까지 먼저 로컬에서 목(mock) 데이터로 검증한 뒤 7~8번(MCP, RAG)을 하나씩 붙이는 식으로 진행하세요. 문제가 생겼을 때 "어느 레이어에서 깨졌는지"를 좁히기가 훨씬 쉬워집니다.

---

## 3. 최소 구현 예시

아래는 각 구성 요소가 어떻게 맞물리는지 보여주는 축약된 스켈레톤입니다. 실제 프로젝트에서는 에러 처리, 인증, 세션 관리 등을 추가해야 하지만, 전체 흐름을 이해하는 데는 이 정도로 충분합니다.

```python
# graph.py — LangGraph 에이전트 정의
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from typing import TypedDict, Annotated
import operator

# vLLM이 OpenAI 호환 API로 떠 있으므로 base_url만 바꿔서 연결
llm = ChatOpenAI(
    base_url="http://runpod-vllm-endpoint:8000/v1",
    api_key="dummy",  # vLLM 자체 인증 미사용 시
    model="local-llama-3.1-8b",
)

class AgentState(TypedDict):
    messages: Annotated[list, operator.add]
    route: str

def router_node(state: AgentState):
    last_msg = state["messages"][-1].content
    # 간단한 라우팅 로직 (실무에서는 LLM 분류 또는 임베딩 유사도 활용)
    if "주문" in last_msg or "환불" in last_msg:
        return {"route": "tool"}
    if "정책" in last_msg or "문서" in last_msg:
        return {"route": "rag"}
    return {"route": "direct"}

def rag_node(state: AgentState):
    from rag import retrieve_context
    query = state["messages"][-1].content
    context = retrieve_context(query, top_k=3)
    prompt = f"다음 문서를 참고해 답하세요:\n{context}\n\n질문: {query}"
    response = llm.invoke(prompt)
    return {"messages": [response]}

def tool_node(state: AgentState):
    from mcp_client import call_mcp_tool
    query = state["messages"][-1].content
    tool_result = call_mcp_tool("get_order_status", {"query": query})
    response = llm.invoke(f"도구 실행 결과: {tool_result}\n\n이를 바탕으로 사용자에게 답하세요.")
    return {"messages": [response]}

def direct_node(state: AgentState):
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

graph = StateGraph(AgentState)
graph.add_node("router", router_node)
graph.add_node("rag", rag_node)
graph.add_node("tool", tool_node)
graph.add_node("direct", direct_node)
graph.set_entry_point("router")
graph.add_conditional_edges(
    "router",
    lambda state: state["route"],
    {"rag": "rag", "tool": "tool", "direct": "direct"},
)
graph.add_edge("rag", END)
graph.add_edge("tool", END)
graph.add_edge("direct", END)

agent = graph.compile()
```

```python
# rag.py — 최소 RAG 검색 함수
from qdrant_client import QdrantClient
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
vector_db = QdrantClient(url="http://localhost:6333")

def retrieve_context(query: str, top_k: int = 3) -> str:
    query_vector = embeddings.embed_query(query)
    hits = vector_db.search(
        collection_name="company_docs",
        query_vector=query_vector,
        limit=top_k,
    )
    return "\n---\n".join(hit.payload["text"] for hit in hits)
```

```python
# mcp_client.py — MCP 도구 호출 래퍼 (개념 스켈레톤)
from mcp import ClientSession

async def call_mcp_tool(tool_name: str, arguments: dict) -> str:
    async with ClientSession(server_url="http://localhost:9000/mcp") as session:
        result = await session.call_tool(tool_name, arguments)
        return result.content[0].text
```

```python
# main.py — FastAPI 진입점
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from langfuse.callback import CallbackHandler
from graph import agent

app = FastAPI()
langfuse_handler = CallbackHandler()

class ChatRequest(BaseModel):
    message: str
    session_id: str

@app.post("/chat")
async def chat(req: ChatRequest):
    config = {
        "callbacks": [langfuse_handler],
        "metadata": {"langfuse_session_id": req.session_id},
    }
    result = agent.invoke(
        {"messages": [("user", req.message)]},
        config=config,
    )
    return {"answer": result["messages"][-1].content}
```

Web UI는 이 `/chat` 엔드포인트를 호출하는 얇은 클라이언트(Streamlit, Gradio, 또는 별도 Next.js 앱)로 붙이면 전체 파이프라인이 완성됩니다.

---

## 4. 흔한 실패 지점과 디버깅 팁

**① VRAM OOM (Out of Memory)**

- **증상**: vLLM 서버가 모델 로딩 중 또는 배치가 몰릴 때 `CUDA out of memory`로 죽음
- **원인**: `gpu_memory_utilization` 설정이 너무 높거나, 동시 요청/시퀀스 길이가 GPU 용량을 초과
- **디버깅**: `nvidia-smi`로 실시간 메모리 사용량 확인 → vLLM의 `--gpu-memory-utilization`을 낮추거나(예: 0.85), `--max-model-len`을 줄이거나, Day 29의 양자화(QLoRA/AWQ 등)로 모델 자체 크기를 줄임

**② 컨텍스트 윈도우 초과 (Context Window Overflow)**

- **증상**: RAG 검색 결과 + 대화 히스토리 + 시스템 프롬프트를 다 합쳤더니 모델의 최대 토큰 수를 넘어서 에러 또는 잘린 응답 발생
- **원인**: retrieve 노드가 너무 많은 청크를 가져오거나(top_k 과다), 멀티턴 히스토리를 무한정 누적
- **디버깅**: 각 구성 요소의 토큰 수를 로깅(tiktoken 등으로 계산)해서 어디서 예산을 초과하는지 확인 → top_k를 줄이거나, 오래된 대화 턴을 요약해서 압축하거나, 더 긴 컨텍스트를 지원하는 모델로 교체

**③ 도구 호출 스키마 불일치 (Tool Call Schema Mismatch)**

- **증상**: 에이전트가 MCP 도구를 호출했는데 인자 타입이 안 맞아 실패하거나, 모델이 존재하지 않는 파라미터를 만들어냄(환각된 인자)
- **원인**: 도구 스키마(JSON Schema) 설명이 모호하거나, 예시가 부족해 모델이 인자 형식을 잘못 추론
- **디버깅**: Langfuse 트레이스에서 실제로 모델에 전달된 tool 스키마와 모델이 생성한 호출 인자를 나란히 비교 → 스키마에 `description`과 예시 값을 보강, 필수 필드는 `required`로 명시

**④ RAG 검색 결과가 질문과 무관함**

- **증상**: 답변에 참고 문서와 상관없는 내용이 섞이거나, 명백히 관련 있는 문서가 있는데도 검색에 안 걸림
- **원인**: 청크 크기가 부적절(너무 크면 노이즈 포함, 너무 작으면 문맥 손실), 임베딩 모델과 질의 표현 방식의 불일치, 유사도 임계값 미설정
- **디버깅**: 검색 단계만 따로 떼어내 top_k 결과와 유사도 점수를 직접 출력해보고, 낮은 점수의 청크가 섞여 들어가고 있다면 임계값 필터링을 추가하거나 청크 분할 전략(청크 크기, 오버랩)을 재조정

> 💡 **실무 팁**: 네 가지 실패 모두 공통적으로 "Langfuse 트레이스를 먼저 열어서 실제로 각 단계에 무엇이 들어가고 나왔는지 확인"하는 것이 첫 번째 디버깅 스텝이어야 합니다. 추측으로 코드를 고치기 전에 트레이스로 사실을 확인하는 습관이 디버깅 시간을 가장 크게 줄여줍니다.

---

## 📝 마치며

31일 동안 Python/Linux 기초에서 시작해 로컬 LLM 서빙, GPU 클라우드 운영, 에이전트 프레임워크, 표준화된 도구 연동(MCP), 검색 증강 생성(RAG), 멀티에이전트 설계, 관측성, 그리고 파인튜닝까지 훑어왔습니다. 이 통합 프로젝트는 그 조각들이 실제로 하나의 시스템 안에서 어떻게 맞물리는지를 손으로 확인하는 자리였습니다.

여기서 멈추지 않는다면, 다음으로 파고들 만한 방향은 다음과 같습니다.

- **프로덕션 신뢰성** — 재시도/폴백 전략, 레이트리밋, 멀티 리전 배포, A/B 테스트 인프라
- **비용 최적화** — 모델 캐스케이딩(작은 모델로 먼저 시도 후 필요할 때만 큰 모델 호출), 프롬프트 캐싱, 배치 추론
- **더 정교한 평가** — Day 28에서 다룬 LLM-as-judge를 넘어, 실제 프로덕션 트래픽 기반의 온라인 평가(shadow deployment) 체계
- **최신 에이전트 아키텍처 추적** — 멀티에이전트 오케스트레이션, 장기 메모리, 에이전트 간 통신 프로토콜은 지금도 빠르게 발전 중인 영역

기술 자체는 계속 바뀌겠지만, 이번 커리큘럼에서 반복해서 강조한 원칙 — **비결정적인 시스템은 트레이싱 없이 디버깅할 수 없고, 평가 없이 개선할 수 없다** — 은 도구가 바뀌어도 유효합니다. 이 원칙을 축으로 삼아 계속 실험하고 배포하고 관찰하시길 바랍니다. 수고하셨습니다.

---

*⬅️ 이전: [Day 30 — SFT / DPO / RLHF](../day-30/)  |  다음: —*
