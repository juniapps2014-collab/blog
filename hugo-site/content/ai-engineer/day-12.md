---
title: "Day 12 — Conditional Edge & Checkpoint — 분기와 상태 저장"
date: 2026-07-04
weight: 12
---

> **Phase 4: 에이전트 프레임워크** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- `add_conditional_edges`로 라우터 함수 기반의 분기 그래프를 설계할 수 있다
- Checkpointer(MemorySaver, SqliteSaver)로 그래프 상태를 영속화하는 원리를 이해한다
- `thread_id`를 이용해 중단된 그래프를 이어서 실행할 수 있다

---

## 1. 왜 조건부 엣지가 필요한가?

Day 11에서 다룬 기본 그래프는 노드가 순차적으로 실행되는 선형(linear) 구조였습니다. 하지만 실제 에이전트는 "이 답변이 충분한가? 아니면 재시도해야 하는가", "도구 호출이 필요한가, 아니면 바로 종료할 수 있는가" 같은 판단을 매 스텝마다 내려야 합니다.

이런 분기를 코드로 표현하려면 그래프 구조 자체가 실행 중 결정된 경로를 따라가야 합니다. LangGraph는 이를 **조건부 엣지(Conditional Edge)** 로 지원합니다 — 특정 노드 실행 후, 라우터 함수가 현재 State를 보고 다음에 갈 노드 이름을 문자열로 반환하면, 그래프는 해당 이름에 매핑된 노드로 이동합니다.

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict

class AgentState(TypedDict):
    query: str
    answer: str
    retry_count: int

def generate_answer(state: AgentState) -> AgentState:
    # LLM 호출로 답변 생성 (예시로 단순화)
    state["answer"] = call_llm(state["query"])
    return state

def should_retry(state: AgentState) -> str:
    """라우터 함수: 다음 노드 이름을 문자열로 반환"""
    if "모르겠습니다" in state["answer"] and state["retry_count"] < 3:
        return "retry"
    return "end"

graph = StateGraph(AgentState)
graph.add_node("generate", generate_answer)
graph.add_node("retry_node", lambda s: {**s, "retry_count": s["retry_count"] + 1})

graph.set_entry_point("generate")
graph.add_conditional_edges(
    "generate",       # 분기 시작 노드
    should_retry,     # 라우터 함수
    {
        "retry": "retry_node",   # 반환값 -> 다음 노드 매핑
        "end": END,
    },
)
graph.add_edge("retry_node", "generate")

app = graph.compile()
```

라우터 함수의 반환값은 문자열이어야 하며, 세 번째 인자로 넘긴 딕셔너리의 키와 일치해야 합니다. 이 매핑 덕분에 라우터 함수 자체는 노드 이름을 몰라도 되고, 그래프 구조와 로직이 느슨하게 결합됩니다.

> 💡 **실무 팁**: 라우터 함수는 부수효과(side effect)가 없어야 합니다. State를 변경하지 말고 오직 "다음 어디로 갈지"만 판단하세요. 상태 변경은 일반 노드에서 하는 것이 디버깅과 재현성 측면에서 훨씬 안전합니다.

---

## 2. 다중 분기 — 재시도 / 도구 호출 / 종료

실무 에이전트는 보통 2개 이상의 분기를 가집니다. 예를 들어 ReAct 스타일 에이전트는 아래 세 갈래로 나뉩니다.

| 라우터 반환값 | 의미 | 다음 노드 |
|---|---|---|
| `"tool_call"` | LLM이 도구 호출을 요청함 | `tools` 노드 |
| `"retry"` | 답변 품질이 낮아 재생성 필요 | `generate` 노드 (루프) |
| `"end"` | 최종 답변 완성 | `END` |

```python
def route(state: AgentState) -> str:
    last_message = state["messages"][-1]
    if last_message.tool_calls:
        return "tool_call"
    if state.get("needs_retry"):
        return "retry"
    return "end"

graph.add_conditional_edges(
    "agent",
    route,
    {
        "tool_call": "tools",
        "retry": "agent",
        "end": END,
    },
)
graph.add_edge("tools", "agent")  # 도구 실행 후 다시 agent로
```

이 구조가 바로 LangGraph의 `create_react_agent` 프리빌트가 내부적으로 구성하는 그래프의 단순화된 형태입니다. 조건부 엣지와 루프백 엣지(`tools -> agent`)를 조합하면 "생각 → 행동 → 관찰"을 반복하는 에이전트 루프가 완성됩니다.

---

## 3. Checkpointer — 그래프 상태의 영속화

지금까지의 그래프는 `app.invoke()`가 끝나면 State가 메모리에서 사라집니다. 하지만 실제 서비스에서는 다음이 필요합니다.

- 사용자가 대화를 며칠 뒤 이어가야 함 (멀티턴 세션)
- 서버가 재시작돼도 진행 중이던 워크플로우를 복구해야 함
- 사람의 승인을 기다리며 그래프를 일시 정지해야 함 (Day 13에서 다룰 HITL의 기반)

이를 위해 LangGraph는 **Checkpointer**를 제공합니다. 컴파일 시점에 checkpointer를 지정하면, 매 노드 실행 후 State 스냅샷이 저장소에 기록됩니다.

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.sqlite import SqliteSaver

# 1) 인메모리 — 프로세스 종료 시 소멸, 테스트/프로토타입용
memory_checkpointer = MemorySaver()

# 2) SQLite — 파일 기반 영속 저장, 로컬/단일 서버 운영에 적합
sqlite_checkpointer = SqliteSaver.from_conn_string("checkpoints.db")

app = graph.compile(checkpointer=sqlite_checkpointer)
```

| Checkpointer | 저장 위치 | 적합한 용도 |
|---|---|---|
| `MemorySaver` | 프로세스 메모리 | 단위 테스트, 로컬 실험 |
| `SqliteSaver` | 로컬 SQLite 파일 | 단일 인스턴스 운영, 소규모 서비스 |
| `PostgresSaver` | Postgres DB | 다중 인스턴스, 프로덕션 운영 |

> 💡 **실무 팁**: 프로덕션에서 여러 서버 인스턴스가 같은 그래프를 실행한다면 반드시 `PostgresSaver`처럼 공유 DB 기반 checkpointer를 써야 합니다. `SqliteSaver`는 파일 잠금 특성상 다중 프로세스 동시 접근에 취약합니다.

---

## 4. thread_id — 세션 단위로 상태 구분하기

Checkpointer는 State를 통째로 저장하는 게 아니라 **thread_id**라는 키로 세션을 구분합니다. 같은 그래프라도 `thread_id`가 다르면 완전히 독립된 대화/작업으로 취급됩니다.

```python
config = {"configurable": {"thread_id": "user-42-session-1"}}

# 첫 실행
result = app.invoke({"query": "LangGraph가 뭐야?", "retry_count": 0}, config)

# 같은 thread_id로 다시 호출하면 이전 State를 이어받아 실행
result2 = app.invoke({"query": "방금 답변을 더 짧게 요약해줘"}, config)

# 현재 저장된 State 스냅샷 확인
snapshot = app.get_state(config)
print(snapshot.values)     # 저장된 State 값
print(snapshot.next)       # 다음에 실행될 노드
```

`get_state_history(config)`를 호출하면 해당 thread의 모든 체크포인트 히스토리를 시간순으로 조회할 수 있어, "특정 시점으로 되돌리기(time travel)" 같은 디버깅도 가능합니다.

```python
for state in app.get_state_history(config):
    print(state.config["configurable"]["checkpoint_id"], state.next)
```

> 💡 **실무 팁**: `thread_id`는 보통 사용자 ID + 대화 ID 조합으로 설계합니다. 하나의 사용자가 여러 독립적인 작업을 동시에 진행한다면 작업 단위로 thread_id를 새로 발급하세요.

---

## 📝 핵심 요약

1. `add_conditional_edges`는 라우터 함수의 반환값(문자열)을 노드 이름 매핑에 연결해 그래프에 분기를 만든다
2. 라우터 함수는 State를 읽기만 하고, 실제 상태 변경은 일반 노드에서 수행하는 것이 원칙
3. Checkpointer(MemorySaver/SqliteSaver/PostgresSaver)는 매 노드 실행 후 State 스냅샷을 저장해 영속성을 제공한다
4. `thread_id`는 세션을 구분하는 키이며, 같은 thread_id로 재호출하면 이전 상태를 이어받는다
5. `get_state`/`get_state_history`로 현재 상태와 체크포인트 이력을 조회해 디버깅과 복구에 활용할 수 있다

---

## 🔗 참고 자료

- [LangGraph Persistence 공식 문서](https://langchain-ai.github.io/langgraph/concepts/persistence/)
- [LangGraph Conditional Edges 가이드](https://langchain-ai.github.io/langgraph/how-tos/branching/)
- [LangGraph Checkpointer API Reference](https://langchain-ai.github.io/langgraph/reference/checkpoints/)

---

*⬅️ 이전: [Day 11 — LangGraph 개념 — State, Node, Edge](../day-11/)  |  다음: [Day 13 — Interrupt & Human-in-the-loop — 사람이 개입하는 워크플로우](../day-13/) ➡️*
