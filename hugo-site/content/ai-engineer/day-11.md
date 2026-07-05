---
title: "Day 11 — LangGraph 개념: State, Node, Edge"
date: 2026-07-04
weight: 11
---

> **Phase 4: 에이전트 프레임워크** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 함수 체이닝 방식 대비 그래프 기반 에이전트 프레임워크가 필요한 이유를 설명할 수 있다
- State, Node, Edge의 역할과 관계를 이해한다
- 2~3개 노드로 구성된 최소 동작 LangGraph 예제를 직접 작성하고 실행할 수 있다

---

## 1. 왜 단순 함수 체이닝으로는 부족한가

LLM 애플리케이션을 처음 만들 때는 보통 이렇게 짭니다.

```python
def run(query):
    plan = plan_step(query)
    result = execute_step(plan)
    answer = summarize_step(result)
    return answer
```

이 방식은 흐름이 단순한 A → B → C일 때는 괜찮지만, 실제 에이전트는 다음과 같은 요구사항이 자주 생깁니다.

- **조건에 따라 다른 경로로 분기** (예: 검색이 필요하면 검색 노드로, 아니면 바로 답변 노드로)
- **같은 단계를 반복** (예: 도구 호출 결과가 부족하면 다시 계획을 세워 재시도)
- **여러 단계에 걸쳐 공유되는 상태**를 명확하게 추적 (대화 이력, 중간 결과, 재시도 횟수 등)
- **중간 상태 저장/재개** (긴 작업을 중간에 멈췄다가 나중에 이어서 실행 — Day 12에서 다룰 Checkpoint)

이런 요구사항을 순수 함수 체이닝(`if/else`와 재귀 호출의 조합)으로 구현하면 코드가 금세 스파게티가 됩니다. **LangGraph**는 에이전트의 흐름을 "상태를 공유하는 그래프(노드+엣지)"로 명시적으로 표현하게 해줘서, 분기·반복·상태 추적을 프레임워크 차원에서 다룰 수 있게 합니다.

> 💡 **실무 팁**: LangGraph는 LangChain 생태계의 일부지만, LangChain의 체인(Chain) 추상화보다 더 낮은 레벨에서 "그래프"라는 명시적 구조를 제공합니다. 복잡한 분기나 루프가 필요 없는 단순한 파이프라인이라면 굳이 LangGraph를 쓸 필요는 없습니다.

---

## 2. State — 노드 간에 공유되는 데이터

State는 그래프의 모든 노드가 읽고 쓸 수 있는 공유 데이터 구조입니다. 보통 Python의 `TypedDict` 또는 Pydantic 모델로 스키마를 정의합니다.

```python
from typing import TypedDict, Annotated
import operator

class AgentState(TypedDict):
    query: str                              # 사용자 질문 (한 번 설정 후 변경 안 함)
    messages: Annotated[list, operator.add]  # 노드가 실행될 때마다 리스트에 이어 붙임
    step_count: int                          # 현재까지 실행된 스텝 수
```

여기서 `Annotated[list, operator.add]`가 중요합니다. LangGraph는 각 노드가 반환한 State 조각을 **어떻게 기존 State와 합칠지(reducer)**를 지정할 수 있습니다. 지정하지 않으면 기본적으로 값을 덮어쓰지만, `operator.add`를 지정하면 리스트를 이어 붙입니다. 대화 이력(`messages`)처럼 "누적"이 필요한 필드에 자주 씁니다.

---

## 3. Node — State를 받아 State 조각을 반환하는 함수

Node는 "현재 State를 입력받아, 갱신할 State 조각을 반환하는" 평범한 Python 함수입니다. LLM 호출, 도구 실행, 단순 로직 판단 등 무엇이든 노드가 될 수 있습니다.

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o-mini")

def planner_node(state: AgentState) -> dict:
    response = llm.invoke(f"다음 질문에 답하기 위한 계획을 세워줘: {state['query']}")
    return {
        "messages": [f"[planner] {response.content}"],
        "step_count": state["step_count"] + 1,
    }

def answer_node(state: AgentState) -> dict:
    response = llm.invoke(f"질문: {state['query']}\n이전 기록: {state['messages']}\n최종 답변을 작성해줘.")
    return {
        "messages": [f"[answer] {response.content}"],
        "step_count": state["step_count"] + 1,
    }
```

노드는 State 전체가 아니라 **바뀐 부분만** 반환하면 됩니다. LangGraph가 앞서 정의한 reducer 규칙에 따라 나머지 State와 자동으로 병합합니다.

---

## 4. Edge — 노드 사이의 연결

Edge는 "이 노드가 끝나면 다음에 어떤 노드로 갈지"를 정의합니다. 이번 Day에서는 가장 단순한 **고정 엣지(fixed edge)**만 다루고, 조건에 따라 경로가 갈리는 **Conditional Edge**는 Day 12에서 다룹니다.

```python
from langgraph.graph import StateGraph, START, END

graph_builder = StateGraph(AgentState)

# 노드 등록
graph_builder.add_node("planner", planner_node)
graph_builder.add_node("answer", answer_node)

# 고정 엣지 연결: START → planner → answer → END
graph_builder.add_edge(START, "planner")
graph_builder.add_edge("planner", "answer")
graph_builder.add_edge("answer", END)

graph = graph_builder.compile()
```

`START`와 `END`는 LangGraph가 제공하는 특수 노드로, 그래프의 진입점과 종료점을 나타냅니다.

---

## 5. 최소 동작 예제 실행

앞서 정의한 조각을 모아 실제로 실행하는 전체 코드입니다.

```python
from typing import TypedDict, Annotated
import operator
from langgraph.graph import StateGraph, START, END
from langchain_openai import ChatOpenAI

class AgentState(TypedDict):
    query: str
    messages: Annotated[list, operator.add]
    step_count: int

llm = ChatOpenAI(model="gpt-4o-mini")

def planner_node(state: AgentState) -> dict:
    response = llm.invoke(f"다음 질문에 답하기 위한 계획을 세워줘: {state['query']}")
    return {"messages": [f"[planner] {response.content}"], "step_count": state["step_count"] + 1}

def answer_node(state: AgentState) -> dict:
    response = llm.invoke(f"질문: {state['query']}\n이전 기록: {state['messages']}\n최종 답변을 작성해줘.")
    return {"messages": [f"[answer] {response.content}"], "step_count": state["step_count"] + 1}

graph_builder = StateGraph(AgentState)
graph_builder.add_node("planner", planner_node)
graph_builder.add_node("answer", answer_node)
graph_builder.add_edge(START, "planner")
graph_builder.add_edge("planner", "answer")
graph_builder.add_edge("answer", END)

graph = graph_builder.compile()

result = graph.invoke({
    "query": "vLLM과 Ollama의 차이는 뭐야?",
    "messages": [],
    "step_count": 0,
})

print(result["messages"])
print("총 실행 스텝:", result["step_count"])
```

실행하면 `planner` 노드가 먼저 계획을 세우고, 그 결과를 담은 State가 `answer` 노드로 전달되어 최종 답변을 생성합니다. `messages`는 두 노드의 출력이 누적된 리스트로, `step_count`는 2로 끝납니다.

> 💡 **실무 팁**: 그래프가 커지면 `graph.get_graph().draw_mermaid_png()`로 현재 그래프 구조를 시각화할 수 있습니다. 노드가 5개를 넘어가는 순간부터는 시각화 없이는 흐름을 파악하기 어려워집니다.

---

## 📝 핵심 요약

1. 분기·반복·상태 추적이 필요한 에이전트는 단순 함수 체이닝보다 그래프 기반 구조가 유지보수하기 쉽다
2. State는 TypedDict/Pydantic으로 정의하는 공유 데이터 구조이며, reducer(예: `operator.add`)로 병합 방식을 지정한다
3. Node는 State를 받아 바뀐 부분만 반환하는 평범한 함수이며, LLM 호출이든 로직 판단이든 무엇이든 될 수 있다
4. Edge는 노드 간 연결이며, `START`/`END`로 그래프의 시작과 끝을 표시한다
5. `StateGraph` → `add_node` → `add_edge` → `compile()` → `invoke()`가 LangGraph의 기본 골격이다

---

## 🔗 참고 자료

- [LangGraph 공식 문서](https://langchain-ai.github.io/langgraph/)
- [LangGraph Concepts — Low Level](https://langchain-ai.github.io/langgraph/concepts/low_level/)
- [LangGraph Quickstart Tutorial](https://langchain-ai.github.io/langgraph/tutorials/introduction/)

---

*⬅️ 이전: [Day 10 — SSH / tmux / nvidia-smi](../day-10/)  |  다음: [Day 12 — Conditional Edge & Checkpoint](../day-12/) ➡️*
