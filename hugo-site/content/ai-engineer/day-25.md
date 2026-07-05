---
title: "Day 25 — Planner / Researcher / Coder / Reviewer 역할 분리"
date: 2026-07-04
weight: 25
---

> **Phase 10: Multi-Agent** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 하나의 거대 프롬프트(mega-prompt) 대신 역할을 분리한 멀티 에이전트가 신뢰성을 높이는 이유를 설명할 수 있다
- Planner/Researcher/Coder/Reviewer의 대표적인 역할 분담 패턴을 이해한다
- 역할 간 작업 인계(handoff)가 공유 상태 또는 메시지 전달로 이루어지는 방식을 구분할 수 있다

---

## 1. 왜 역할을 쪼개는가

하나의 프롬프트에 "계획을 세우고, 조사하고, 코드를 짜고, 검토까지 해줘"라고 요청하면 모델은 각 단계를 대충 뭉뚱그려 처리하는 경향이 있습니다. 컨텍스트가 길어질수록 앞서 세운 계획을 잊거나, 코드를 작성하면서 동시에 스스로를 비판적으로 검토하는 이중 역할을 잘 수행하지 못합니다.

멀티 에이전트 역할 분리는 이 문제를 소프트웨어 엔지니어링의 오래된 원칙으로 해결합니다: **단일 책임 원칙(Single Responsibility Principle)**. 각 에이전트가 하나의 관점에만 집중하도록 프롬프트와 컨텍스트를 좁히면:

- **집중도 향상** — 각 에이전트의 시스템 프롬프트가 짧고 명확해져 지시를 놓칠 확률이 줄어듦
- **검증 가능성** — 단계별 산출물(계획서, 조사 결과, 코드, 리뷰 코멘트)이 명시적으로 남아 중간 검증과 디버깅이 쉬워짐
- **모델 특화** — 예를 들어 Reviewer에는 더 보수적인 temperature나 더 강력한 모델을, Researcher에는 웹 검색 도구를 붙이는 식으로 역할별 최적화 가능
- **실패 격리** — 한 단계(예: 조사)가 실패해도 전체를 재시작하지 않고 해당 단계만 재시도 가능

> 💡 **실무 팁**: 역할 분리가 항상 이득은 아닙니다. 단계 간 통신(직렬화, 파싱) 비용과 지연시간이 늘어나므로, 작업이 간단하고 실패 허용도가 낮지 않다면 단일 에이전트가 더 빠르고 저렴할 수 있습니다. "이 작업이 실제로 서로 다른 사고 방식을 요구하는가"를 기준으로 분리 여부를 판단하세요.

---

## 2. 대표적인 4역할 패턴

| 역할 | 책임 | 입력 | 출력 |
|---|---|---|---|
| **Planner** | 목표를 실행 가능한 하위 작업으로 분해 | 사용자 요청 | 단계별 작업 목록(TODO) |
| **Researcher** | 필요한 정보·컨텍스트 수집 (웹 검색, 문서 조회, 코드베이스 탐색) | Planner의 작업 목록 중 조사 항목 | 조사 결과 요약, 근거 자료 |
| **Coder** | 실제 코드 작성/수정 | 조사 결과 + 요구사항 | 코드 diff, 커밋 |
| **Reviewer** | 코드 정확성·품질·부작용 검토 | Coder의 산출물 | 승인 또는 수정 요청(피드백) |

이 패턴은 실제 소프트웨어 팀의 역할 분담(기획 → 조사 → 구현 → 코드리뷰)을 그대로 에이전트에 대응시킨 것입니다. Claude Code의 서브에이전트 구조, LangGraph의 멀티 노드 그래프, AutoGen의 멀티 에이전트 대화가 모두 변형된 형태로 이 패턴을 구현합니다.

---

## 3. 역할 간 작업 인계 — 공유 상태 vs 메시지 전달

역할을 나눴다면, 각 역할이 결과물을 어떻게 다음 역할에 넘길지 설계해야 합니다. 크게 두 가지 방식이 있습니다.

**(1) 공유 상태(Shared State) 방식** — LangGraph 스타일. 모든 에이전트가 하나의 상태 객체를 읽고 쓰며, 그래프의 엣지가 다음 실행할 노드를 결정합니다.

```python
from typing import TypedDict, Literal
from langgraph.graph import StateGraph, END


class AgentState(TypedDict):
    task: str
    plan: list[str]
    research_notes: str
    code: str
    review_feedback: str
    approved: bool


def planner_node(state: AgentState) -> AgentState:
    plan = llm_plan(state["task"])
    return {**state, "plan": plan}


def researcher_node(state: AgentState) -> AgentState:
    notes = llm_research(state["plan"])
    return {**state, "research_notes": notes}


def coder_node(state: AgentState) -> AgentState:
    code = llm_code(state["research_notes"], state["plan"])
    return {**state, "code": code}


def reviewer_node(state: AgentState) -> AgentState:
    feedback, approved = llm_review(state["code"])
    return {**state, "review_feedback": feedback, "approved": approved}


def route_after_review(state: AgentState) -> Literal["coder", "__end__"]:
    return "coder" if not state["approved"] else END


graph = StateGraph(AgentState)
graph.add_node("planner", planner_node)
graph.add_node("researcher", researcher_node)
graph.add_node("coder", coder_node)
graph.add_node("reviewer", reviewer_node)

graph.set_entry_point("planner")
graph.add_edge("planner", "researcher")
graph.add_edge("researcher", "coder")
graph.add_edge("coder", "reviewer")
graph.add_conditional_edges("reviewer", route_after_review)

app = graph.compile()
```

Reviewer가 반려하면 `route_after_review`가 다시 `coder` 노드로 되돌리는 루프가 생기는 점에 주목하세요. 이것이 "역할 분리 + 명시적 상태"가 주는 실질적 이득입니다 — 재작업이 필요할 때 처음부터 다시 하지 않고 실패한 단계만 반복합니다.

**(2) 메시지 전달(Message Passing) 방식** — AutoGen/CrewAI 스타일. 에이전트들이 대화하듯 메시지를 주고받으며, 각 에이전트는 자신에게 온 메시지 히스토리만 보고 판단합니다. 상태가 명시적 객체가 아니라 대화 로그 자체입니다.

| 구분 | 공유 상태 방식 | 메시지 전달 방식 |
|---|---|---|
| 제어 흐름 | 그래프 엣지로 명시적 정의 | 에이전트 간 자율적 대화로 결정 |
| 디버깅 | 상태 스냅샷을 단계별로 확인 가능 | 대화 로그를 추적해야 함 |
| 유연성 | 정해진 흐름에 최적화 (구조적) | 즉흥적 협업에 유리 (유동적) |
| 대표 프레임워크 | LangGraph | AutoGen, CrewAI |

> 💡 **실무 팁**: 흐름이 예측 가능하고 반복 실행되는 파이프라인(예: 코드 리뷰 루프)은 공유 상태 방식이 디버깅과 재현성 면에서 유리합니다. 반대로 에이전트들이 서로 질문하고 협상해야 하는 열린 문제는 메시지 전달 방식이 더 자연스럽습니다.

---

## 4. 예시로 끝까지 따라가기 — "결제 재시도 로직 추가"

사용자 요청: *"결제 실패 시 3번까지 지수 백오프로 재시도하는 로직을 추가해줘."*

1. **Planner** — 작업을 분해합니다.
   - (1) 기존 결제 모듈 구조 파악
   - (2) 재시도 로직 설계 (지수 백오프 파라미터 결정)
   - (3) 코드 작성
   - (4) 기존 테스트에 영향 없는지 검토

2. **Researcher** — 코드베이스에서 결제 모듈(`payment_service.py`)을 탐색하고, 현재 에러 핸들링 방식과 기존에 쓰이는 재시도 라이브러리(`tenacity` 등) 유무를 조사해 요약합니다.

3. **Coder** — Researcher의 조사 결과를 바탕으로 `tenacity` 데코레이터를 이용한 재시도 로직을 작성합니다.

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def charge_payment(order_id: str, amount: float):
    ...
```

4. **Reviewer** — 다음을 점검합니다: 재시도가 멱등성(idempotency)을 깨뜨리지 않는지, 결제 API가 이미 자체 재시도를 갖고 있어 중복 결제 위험은 없는지, 예외 타입이 재시도할 만한 것(네트워크 오류)과 재시도하면 안 되는 것(카드 거절)을 구분하는지. 문제를 발견하면 구체적 피드백과 함께 Coder에게 반려합니다.

이 흐름에서 각 역할은 "자기 관점"에만 집중하기 때문에, 하나의 프롬프트에 다 밀어 넣었을 때 흔히 놓치는 멱등성·예외 분기 같은 디테일을 Reviewer 단계가 별도로 짚어낼 확률이 높아집니다.

---

## 📝 핵심 요약

1. 역할 분리는 단일 책임 원칙을 멀티 에이전트에 적용한 것으로, 집중도·검증 가능성·실패 격리를 높인다
2. Planner(분해) → Researcher(조사) → Coder(구현) → Reviewer(검토)는 실제 개발팀 워크플로를 그대로 반영한 패턴이다
3. 작업 인계는 LangGraph식 공유 상태(명시적, 재현 가능) 또는 AutoGen/CrewAI식 메시지 전달(유연, 자율적) 중 하나로 설계한다
4. Reviewer가 반려하면 실패한 단계로만 되돌아가는 루프 구조가 전체 재시작보다 효율적이다
5. 역할 분리는 통신 오버헤드를 동반하므로, 작업이 단순하다면 오히려 단일 에이전트가 더 나을 수 있다

---

## 🔗 참고 자료

- [LangGraph 공식 문서 — Multi-Agent Systems](https://langchain-ai.github.io/langgraph/concepts/multi_agent/)
- [Microsoft AutoGen 공식 문서](https://microsoft.github.io/autogen/)
- [CrewAI 공식 문서](https://docs.crewai.com/)

---

*⬅️ 이전: [Day 24 — WebSocket & Streaming Response, 인증(Authentication)](../day-24/)  |  다음: [Day 26 — Supervisor 패턴 & Memory 설계](../day-26/) ➡️*
