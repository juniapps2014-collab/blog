---
title: "Day 13 — Interrupt & Human-in-the-loop — 사람이 개입하는 워크플로우"
date: 2026-07-16
weight: 13
---

> **Phase 4: 에이전트 프레임워크** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- `interrupt_before`/`interrupt_after`로 그래프 실행을 특정 노드 앞뒤에서 일시 정지시킬 수 있다
- 사람의 승인/수정을 받은 뒤 State를 갱신하고 그래프를 재개하는 흐름을 구현할 수 있다
- 이메일 발송, 결제 등 민감한 액션 전에 HITL(Human-in-the-loop) 게이트를 설계할 수 있다

---

## 1. 왜 사람이 개입해야 하는가?

LLM 에이전트가 자율적으로 도구를 호출하는 것은 강력하지만, 되돌릴 수 없는(irreversible) 작업 — 이메일 발송, 결제, 프로덕션 배포, 데이터 삭제 — 을 맡기기엔 위험합니다. 모델이 착각(hallucination)했거나 사용자 의도를 잘못 해석했을 경우, 실행 전에 사람이 검토할 기회가 반드시 있어야 합니다.

LangGraph는 Day 12에서 배운 **Checkpoint** 메커니즘을 그대로 활용해 HITL을 구현합니다. 그래프가 특정 노드 실행 직전/직후에 멈추고, State가 checkpoint에 저장된 채로 대기하다가, 사람이 승인하면 그 지점부터 재개됩니다.

```
[사용자 요청] → [LLM: 이메일 초안 작성] → 🛑 (사람 승인 대기) → [이메일 발송 노드] → [완료]
                                              ↑
                                     여기서 interrupt_before 적용
```

> 💡 **실무 팁**: HITL은 "느린 에이전트"가 아니라 "신뢰할 수 있는 에이전트"를 만드는 장치입니다. 특히 금융, 의료, 프로덕션 인프라 도메인에서는 HITL 게이트가 규제 준수(compliance)의 필수 요소인 경우가 많습니다.

---

## 2. interrupt_before / interrupt_after

`compile()` 시점에 `interrupt_before` 또는 `interrupt_after`에 노드 이름 리스트를 넘기면, 해당 노드 실행 전/후 그래프가 자동으로 멈춥니다.

```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.sqlite import SqliteSaver
from typing import TypedDict

class MailState(TypedDict):
    request: str
    draft: str
    approved: bool

def draft_email(state: MailState) -> MailState:
    state["draft"] = call_llm(f"다음 요청으로 이메일 초안 작성: {state['request']}")
    return state

def send_email(state: MailState) -> MailState:
    # 실제 발송 API 호출 (민감한 액션)
    email_api.send(state["draft"])
    return state

graph = StateGraph(MailState)
graph.add_node("draft", draft_email)
graph.add_node("send", send_email)
graph.set_entry_point("draft")
graph.add_edge("draft", "send")
graph.add_edge("send", END)

checkpointer = SqliteSaver.from_conn_string("hitl.db")

app = graph.compile(
    checkpointer=checkpointer,
    interrupt_before=["send"],   # send 노드 실행 직전에 정지
)
```

`interrupt_before`는 "이 노드를 아직 실행하지 않은 상태"에서 멈추므로, 실행 전 State(여기서는 `draft`)를 사람이 검토하기에 적합합니다. 반대로 `interrupt_after`는 노드 실행 결과를 확인한 후 다음 단계로 넘어갈지 판단할 때 씁니다 — 예를 들어 도구 호출 결과가 의심스러울 때 다음 단계 진행을 막는 용도입니다.

---

## 3. 실행 흐름 — 정지, 검토, 재개

```python
config = {"configurable": {"thread_id": "email-task-7"}}

# 1) 첫 실행 — draft까지 실행되고 send 직전에 자동 정지
result = app.invoke({"request": "고객에게 환불 안내 메일", "approved": False}, config)

# 2) 현재 상태 확인 — 다음 실행될 노드가 "send"로 남아있음
snapshot = app.get_state(config)
print(snapshot.next)          # ('send',)
print(snapshot.values["draft"])  # 사람이 검토할 초안

# 3) 사람이 초안을 검토/수정한 뒤 State를 갱신
app.update_state(config, {"draft": "수정된 최종 이메일 본문...", "approved": True})

# 4) 승인 후 재개 — None을 입력으로 넘기면 정지된 지점부터 이어서 실행
app.invoke(None, config)
```

핵심은 `app.invoke(None, config)`입니다. 새로운 입력을 주지 않고 `None`을 넘기면, LangGraph는 checkpoint에 저장된 State를 그대로 사용해 정지 지점(`send` 노드)부터 실행을 재개합니다. 만약 사람이 거절(reject)한다면, 재개하지 않고 State에 `approved: False`를 기록한 채 별도 노드(예: 취소 처리)로 라우팅하도록 조건부 엣지를 추가할 수도 있습니다.

> 💡 **실무 팁**: `update_state`로 State를 고칠 때는 TypedDict의 일부 필드만 넘겨도 됩니다. LangGraph는 기존 State와 병합(merge)합니다. 단, 리스트 타입 필드는 리듀서(reducer) 설정에 따라 append/overwrite 동작이 달라지므로 State 스키마 설계 시 주의하세요.

---

## 4. 승인/거절 분기까지 포함한 완전한 설계

실무에서는 단순히 "멈췄다 재개"가 아니라 승인/거절 두 갈래를 모두 처리해야 합니다. Day 12의 조건부 엣지와 결합하면 다음과 같은 구조가 됩니다.

```python
def route_after_review(state: MailState) -> str:
    if state["approved"]:
        return "send"
    return "cancel"

graph.add_node("cancel", lambda s: {**s, "draft": "사용자가 취소함"})
graph.add_conditional_edges(
    "draft",
    route_after_review,
    {"send": "send", "cancel": "cancel"},
)
```

이 패턴을 결제 승인, 인프라 변경 승인(Terraform apply 전 리뷰), 데이터 삭제 승인 등에 그대로 적용할 수 있습니다. 핵심은 항상 "되돌릴 수 없는 노드" 앞에 `interrupt_before`를 걸고, 재개 여부를 사람이 명시적으로 결정하게 만드는 것입니다.

| 시나리오 | interrupt 위치 | 재개 조건 |
|---|---|---|
| 이메일 발송 | `send_email` 노드 직전 | 사람이 초안 승인 |
| 결제 처리 | `charge_payment` 노드 직전 | 금액/수취인 확인 후 승인 |
| 프로덕션 배포 | `deploy` 노드 직전 | 코드 리뷰어 승인 |
| 대량 데이터 삭제 | `delete_records` 노드 직전 | 관리자 2차 확인 |

---

## 📝 핵심 요약

1. HITL은 되돌릴 수 없는 액션 앞에 사람의 승인 게이트를 두는 안전장치이며, LangGraph의 checkpoint 메커니즘 위에서 동작한다
2. `interrupt_before`는 노드 실행 전, `interrupt_after`는 노드 실행 후 그래프를 자동 정지시킨다
3. 정지된 그래프는 `app.get_state(config)`로 확인하고, `app.update_state(config, ...)`로 사람이 State를 수정할 수 있다
4. `app.invoke(None, config)`로 정지 지점부터 그래프를 재개한다 — 새 입력이 아니라 저장된 checkpoint를 사용
5. 승인/거절 두 경로 모두 조건부 엣지로 명시적으로 설계해야 실무에서 안전하게 쓸 수 있다

---

## 🔗 참고 자료

- [LangGraph Human-in-the-loop 공식 가이드](https://langchain-ai.github.io/langgraph/concepts/human_in_the_loop/)
- [LangGraph Breakpoints (interrupt_before/after) How-to](https://langchain-ai.github.io/langgraph/how-tos/human_in_the_loop/breakpoints/)
- [LangGraph update_state API Reference](https://langchain-ai.github.io/langgraph/reference/graphs/)

---

*⬅️ 이전: [Day 12 — Conditional Edge & Checkpoint — 분기와 상태 저장](../day-12/)  |  다음: [Day 14 — MCP 개념 — Server/Client, Tool, Resource, Prompt](../day-14/) ➡️*
