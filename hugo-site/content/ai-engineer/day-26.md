---
title: "Day 26 — Supervisor 패턴 & Memory 설계"
date: 2026-07-29
weight: 26
---

> **Phase 10: Multi-Agent** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Supervisor(오케스트레이터) 에이전트가 워커 에이전트를 라우팅하고 종료를 판단하는 방식을 설명할 수 있다
- 단기 메모리(대화 버퍼)와 장기 메모리(벡터 저장소 회상)의 차이와 사용 시점을 구분할 수 있다
- 메모리를 언제 영속화하고 언제 휘발시켜야 하는지 판단 기준을 세울 수 있다

---

## 1. Supervisor 패턴 — 중앙에서 라우팅하는 오케스트레이터

Day 25에서 다룬 Planner/Researcher/Coder/Reviewer가 "고정된 순서"로 흘러가는 파이프라인이었다면, Supervisor 패턴은 그보다 한 단계 유연합니다. Supervisor는 스스로 작업을 수행하지 않고, 매 턴마다 "다음에 누가 일해야 하는가"를 판단해서 적절한 워커 에이전트에게 작업을 위임하는 **라우터 겸 종료 판단자** 역할을 합니다.

```python
from typing import TypedDict, Literal
from langgraph.graph import StateGraph, END


class SupervisorState(TypedDict):
    task: str
    messages: list[dict]
    next_agent: str


WORKERS = ["researcher", "coder", "reviewer"]


def supervisor_node(state: SupervisorState) -> SupervisorState:
    # Supervisor는 지금까지의 대화/작업 내역을 보고 다음 워커를 결정
    decision = llm_route(
        system_prompt=(
            "당신은 팀 리더입니다. 아래 워커 중 다음에 일할 담당자를 고르거나, "
            "작업이 끝났으면 FINISH를 반환하세요: " + ", ".join(WORKERS)
        ),
        messages=state["messages"],
    )
    return {**state, "next_agent": decision}  # "researcher" | "coder" | "reviewer" | "FINISH"


def route(state: SupervisorState) -> str:
    return END if state["next_agent"] == "FINISH" else state["next_agent"]


graph = StateGraph(SupervisorState)
graph.add_node("supervisor", supervisor_node)
graph.add_node("researcher", researcher_node)
graph.add_node("coder", coder_node)
graph.add_node("reviewer", reviewer_node)

graph.set_entry_point("supervisor")
for worker in WORKERS:
    graph.add_edge(worker, "supervisor")  # 워커는 작업 후 항상 Supervisor로 복귀
graph.add_conditional_edges("supervisor", route)

app = graph.compile()
```

핵심 차이는 이것입니다: 고정 파이프라인은 "A 다음엔 항상 B"라는 정적인 그래프인 반면, Supervisor 패턴은 매번 상황을 판단해 동적으로 다음 담당자를 고릅니다. 예를 들어 Researcher가 조사한 내용이 불충분하면 Supervisor가 Coder로 넘기지 않고 Researcher를 한 번 더 호출할 수 있습니다.

**Supervisor가 매 턴 판단해야 하는 두 가지:**

1. **라우팅** — 지금 상황에서 어떤 워커의 전문성이 필요한가
2. **종료 조건** — 목표가 달성되었는가, 아니면 계속 반복해야 하는가 (무한 루프 방지를 위해 최대 턴 수 같은 안전장치를 반드시 병행)

> 💡 **실무 팁**: Supervisor 자체도 LLM 호출이므로 매 턴마다 지연시간과 비용이 추가됩니다. 워커가 3개 미만이고 흐름이 거의 고정적이라면 Day 25의 고정 파이프라인이 더 저렴하고 예측 가능합니다. Supervisor 패턴은 "워커 조합이나 순서가 작업마다 달라질 수 있을 때"에 가치가 커집니다.

---

## 2. 단기 메모리 — 대화 버퍼(Conversation Buffer)

단기 메모리는 현재 세션 동안의 대화 맥락을 유지하는 것입니다. 가장 단순한 형태는 지금까지 주고받은 메시지 리스트를 그대로 다음 호출의 컨텍스트에 포함시키는 것입니다.

```python
class ConversationBuffer:
    def __init__(self, max_turns: int = 10):
        self.messages: list[dict] = []
        self.max_turns = max_turns

    def add(self, role: str, content: str):
        self.messages.append({"role": role, "content": content})
        # 오래된 턴부터 잘라내 컨텍스트 길이 관리
        if len(self.messages) > self.max_turns * 2:
            self.messages = self.messages[-self.max_turns * 2:]

    def as_context(self) -> list[dict]:
        return self.messages
```

이 방식은 구현이 단순하지만 컨텍스트 윈도우가 유한하다는 근본적 한계를 가집니다. 대화가 길어지면:

- **잘라내기(truncation)** — 오래된 턴을 버림 (구현 간단하지만 초반 맥락 손실)
- **요약(summarization)** — 오래된 턴을 LLM으로 요약해 압축 보관 (맥락 보존하지만 요약 비용과 정보 손실 트레이드오프)
- **슬라이딩 윈도우 + 요약 혼합** — 최근 N턴은 원문 그대로, 그 이전은 요약본으로 유지 (실무에서 가장 널리 쓰임)

---

## 3. 장기 메모리 — 벡터 저장소 회상(Recall)

단기 메모리가 "이번 세션"에 국한된다면, 장기 메모리는 세션을 넘어 **사용자에 대한 정보, 과거 대화의 요지, 도메인 지식**을 영속적으로 저장하고 필요할 때 꺼내 씁니다. 구현 방식은 Day 20~22에서 다룬 벡터 검색과 동일합니다 — 기억할 내용을 임베딩해 벡터 DB에 저장하고, 새 요청이 들어오면 유사도 검색으로 관련 기억을 회상해 프롬프트에 주입합니다.

```python
class LongTermMemory:
    def __init__(self, vector_store, embedder):
        self.store = vector_store
        self.embedder = embedder

    async def remember(self, user_id: str, fact: str):
        vector = await self.embedder.embed(fact)
        await self.store.upsert(
            vector=vector,
            metadata={"user_id": user_id, "text": fact, "type": "fact"},
        )

    async def recall(self, user_id: str, query: str, top_k: int = 3) -> list[str]:
        query_vector = await self.embedder.embed(query)
        results = await self.store.search(
            vector=query_vector,
            filter={"user_id": user_id},
            top_k=top_k,
        )
        return [r.metadata["text"] for r in results]
```

**단기 메모리 vs 장기 메모리 비교:**

| 구분 | 단기 메모리 (대화 버퍼) | 장기 메모리 (벡터 회상) |
|---|---|---|
| 범위 | 현재 세션 | 세션을 넘어선 전체 이력 |
| 저장 위치 | 프로세스 메모리, Redis | 벡터 DB (Milvus, pgvector 등) |
| 조회 방식 | 순서대로 전부 포함 | 쿼리와의 유사도로 관련 항목만 선별 |
| 비용 | 토큰 수에 비례해 매 호출 증가 | 임베딩/검색 비용 + 회상된 항목만 토큰 사용 |
| 적합한 정보 | 지금 대화의 흐름, 직전 맥락 | 사용자 선호도, 과거 결정 사항, 도메인 지식 |

> 💡 **실무 팁**: 장기 메모리를 "모든 대화를 무조건 저장"하는 방식으로 설계하면 잡음(noise)이 쌓여 회상 품질이 오히려 떨어집니다. 저장 시점에 "이 정보가 나중에 재사용될 가치가 있는가"를 LLM으로 한 번 필터링(예: 사용자의 명시적 선호, 반복되는 요구사항)한 뒤 저장하는 편이 낫습니다.

---

## 4. 언제 영속화하고 언제 휘발시킬 것인가

모든 것을 장기 메모리에 저장할 필요는 없습니다. 판단 기준은 "이 정보가 이번 세션이 끝난 후에도 가치가 있는가"입니다.

| 정보 유형 | 처리 방식 | 이유 |
|---|---|---|
| 이번 턴의 중간 추론 과정 | 휘발 (세션 종료 시 폐기) | 재사용 가치 없음, 저장 비용만 발생 |
| 사용자의 고정 선호("항상 한국어로 답해줘") | 영속화 (장기 메모리) | 모든 미래 세션에 적용되어야 함 |
| 이번 작업에서 조사한 임시 데이터 | 세션 스코프 캐시 (단기, TTL 부여) | 이번 작업엔 필요하지만 장기 보관 가치는 낮음 |
| 반복적으로 나오는 도메인 사실(제품 스펙 등) | 영속화 (RAG 지식베이스) | 여러 세션·여러 사용자에게 공통으로 유용 |
| 민감 정보(카드번호, 비밀번호 등) | 저장 금지 | 보안/컴플라이언스 리스크 |

**실무 설계 원칙:**

1. **기본값은 휘발** — "저장해야 할 이유가 있는 것만" 명시적으로 장기 메모리에 승격시키는 것이 안전하고 비용 효율적
2. **저장 전 필터링 단계를 둔다** — 원문을 그대로 저장하지 말고 "요약된 사실(fact)" 단위로 추출해 저장하면 회상 품질과 저장 비용 모두 개선됨
3. **만료(TTL) 정책을 설계한다** — 장기 메모리도 무한정 쌓이면 오래된 정보가 최신 정보와 충돌할 수 있으므로, 갱신 시점이나 유효기간을 메타데이터로 관리

> 💡 **실무 팁**: Supervisor 패턴과 메모리 설계는 함께 갑니다 — Supervisor가 워커에게 작업을 위임할 때, 장기 메모리에서 회상한 사용자 컨텍스트를 워커의 시스템 프롬프트에 주입해주면 워커 각각이 별도로 회상 로직을 구현할 필요가 없어집니다.

---

## 📝 핵심 요약

1. Supervisor 패턴은 고정 파이프라인과 달리 매 턴마다 라우팅과 종료 여부를 동적으로 판단하는 오케스트레이터다
2. 단기 메모리(대화 버퍼)는 현재 세션의 맥락 유지에, 장기 메모리(벡터 회상)는 세션을 넘어선 지식 축적에 쓰인다
3. 대화 버퍼가 길어지면 잘라내기/요약/슬라이딩 윈도우 혼합 전략으로 컨텍스트 길이를 관리해야 한다
4. 모든 대화를 무조건 장기 저장하면 잡음이 쌓이므로, 재사용 가치를 필터링한 뒤 사실 단위로 저장해야 한다
5. 기본값은 휘발이며, 명시적으로 미래 가치가 있는 정보만 영속화하고 만료 정책까지 설계하는 것이 안전하다

---

## 🔗 참고 자료

- [LangGraph 공식 문서 — Multi-Agent Supervisor](https://langchain-ai.github.io/langgraph/tutorials/multi_agent/agent_supervisor/)
- [LangChain 공식 문서 — Memory Concepts](https://python.langchain.com/docs/concepts/memory/)
- [Zep — Long-term Memory for AI Agents](https://www.getzep.com/)

---

*⬅️ 이전: [Day 25 — Planner / Researcher / Coder / Reviewer 역할 분리](../day-25/)  |  다음: [Day 27 — Langfuse — Logging & Tracing](../day-27/) ➡️*
