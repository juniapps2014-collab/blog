---
title: "Day 27 — Langfuse: Logging & Tracing"
date: 2026-07-30
weight: 27
---

> **Phase 11: 관찰성** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- LLM 애플리케이션에서 로깅/트레이싱이 일반 웹 서비스보다 훨씬 중요한 이유를 설명할 수 있다
- Langfuse로 LangGraph/LangChain 에이전트의 실행을 trace/span/generation 단위로 계측할 수 있다
- 호출당 비용, 지연시간, 토큰 사용량을 추적하고 대시보드에서 분석할 수 있다

---

## 1. 왜 LLM 앱은 "블랙박스 디버깅"이 되는가

일반적인 백엔드 서비스는 입력이 같으면 출력도 같습니다(결정적, deterministic). 하지만 LLM 기반 에이전트는 다음과 같은 특성 때문에 전통적인 디버깅 방식이 통하지 않습니다.

- **비결정성** — 같은 프롬프트라도 temperature > 0이면 매번 다른 답이 나올 수 있음
- **다단계 실행** — LangGraph 에이전트 하나가 라우터 노드 → 도구 호출 → RAG 검색 → 재작성 → 최종 응답까지 5~10단계를 거치는 경우가 흔함
- **중간 상태의 불투명성** — "왜 이 답이 나왔는가?"에 답하려면 각 단계에서 모델에게 실제로 어떤 프롬프트가 들어갔는지, 어떤 도구가 어떤 인자로 호출됐는지를 봐야 함
- **실패가 조용함** — 예외를 던지지 않고 그냥 "그럴듯하지만 틀린" 답을 내놓는 실패 모드(hallucination, 잘못된 도구 선택)가 로그만으로는 안 보임

즉, `print()`나 일반 APM(Application Performance Monitoring) 도구로는 "이 응답이 왜 이렇게 나왔는지"를 재구성하기 어렵습니다. 이 문제를 풀기 위해 등장한 것이 **LLM 관측성(observability) 플랫폼**이며, Langfuse는 오픈소스로 가장 널리 쓰이는 도구 중 하나입니다.

> 💡 **실무 팁**: 프로덕션에 트레이싱 없이 에이전트를 배포하는 것은 로그 없이 마이크로서비스를 운영하는 것과 같습니다. "이번 주 응답 품질이 떨어진 것 같다"는 사용자 컴플레인이 들어왔을 때, 트레이싱이 없으면 원인 파악에 며칠이 걸리지만 있으면 몇 분이면 됩니다.

---

## 2. Trace / Span / Generation — 관측성의 기본 단위

Langfuse(및 대부분의 LLM 트레이싱 도구)는 계층적 구조로 실행을 기록합니다.

| 단위 | 의미 | 예시 |
|---|---|---|
| **Trace** | 사용자 요청 하나의 전체 실행 (최상위 단위) | "사용자가 '환불 정책 알려줘'라고 물은 요청 전체" |
| **Span** | Trace 내부의 하위 작업 단위 (LLM 호출이 아닌 일반 로직) | "RAG 검색 단계", "라우팅 로직 실행" |
| **Generation** | LLM/임베딩 모델 호출 그 자체 (프롬프트, 응답, 토큰, 비용 포함) | "GPT-4o에 시스템 프롬프트 + 컨텍스트를 넣어 호출" |
| **Observation** | Span과 Generation을 아우르는 상위 개념 | — |

하나의 Trace 안에 여러 Span이 있고, 각 Span 안에 다시 Generation이나 하위 Span이 중첩될 수 있습니다. LangGraph처럼 그래프 구조로 동작하는 에이전트는 노드 하나하나가 보통 Span 또는 Generation에 매핑됩니다.

```text
Trace: "환불 정책 알려줘" (전체 요청, 2.3초, $0.004)
├─ Span: router_node (0.1초)
├─ Span: rag_retrieval_node (0.4초)
│   └─ Generation: embedding-3-small (쿼리 임베딩, 0.05초)
├─ Span: tool_call_node — get_refund_policy() (0.2초)
└─ Generation: gpt-4o-mini (최종 응답 생성, 1.6초, 320 tokens)
```

이 구조 덕분에 "전체 응답이 느렸다"는 문제가 생겼을 때, 어느 노드가 병목인지(RAG 검색? 도구 호출? 모델 생성 자체?) 한눈에 파악할 수 있습니다.

---

## 3. LangGraph 에이전트에 Langfuse 계측하기

Langfuse는 LangChain/LangGraph용 콜백 핸들러를 제공해서, 코드를 거의 건드리지 않고 자동 계측이 가능합니다.

```bash
pip install langfuse langgraph langchain-openai
```

```python
import os
from langfuse.callback import CallbackHandler
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI

os.environ["LANGFUSE_PUBLIC_KEY"] = "pk-lf-..."
os.environ["LANGFUSE_SECRET_KEY"] = "sk-lf-..."
os.environ["LANGFUSE_HOST"] = "https://cloud.langfuse.com"  # 셀프호스팅 시 자체 URL

langfuse_handler = CallbackHandler(
    user_id="user_1234",
    session_id="session_abcd",
    tags=["production", "refund-flow"],
)

llm = ChatOpenAI(model="gpt-4o-mini")

def call_model(state):
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

graph = StateGraph(dict)
graph.add_node("agent", call_model)
graph.set_entry_point("agent")
graph.add_edge("agent", END)
app = graph.compile()

# invoke 시 callbacks에 핸들러만 추가하면 전체 그래프 실행이 자동으로 계측됨
result = app.invoke(
    {"messages": [("user", "환불 정책 알려줘")]},
    config={"callbacks": [langfuse_handler]},
)
```

콜백 핸들러 하나만 `config`에 넘기면, 그래프의 모든 노드 실행과 그 안에서 발생하는 LLM 호출이 자동으로 trace/span/generation으로 기록됩니다. `user_id`, `session_id`, `tags`를 넘기면 대시보드에서 특정 사용자나 세션 단위로 필터링해서 볼 수 있습니다.

더 세밀한 제어가 필요하면 `@observe()` 데코레이터로 임의의 함수를 직접 span으로 감쌀 수도 있습니다.

```python
from langfuse.decorators import observe

@observe()
def retrieve_documents(query: str):
    # 벡터DB 검색 로직
    ...
    return docs

@observe(as_type="generation")
def rerank_with_llm(docs, query: str):
    # LLM 기반 재순위화 — generation으로 기록됨
    ...
```

> 💡 **실무 팁**: `session_id`를 대화 세션 단위로 고정해서 넘기면, 멀티턴 대화에서 이전 턴의 트레이스와 현재 턴의 트레이스를 Langfuse UI에서 하나의 타임라인으로 이어볼 수 있습니다. 멀티턴 버그(예: 이전 컨텍스트를 잘못 참조)를 잡을 때 필수적입니다.

---

## 4. 비용·지연시간·토큰 추적

Langfuse는 OpenAI/Anthropic 등 주요 프로바이더의 응답에서 `usage` 필드(prompt_tokens, completion_tokens)를 자동으로 파싱해 비용을 계산합니다. 대시보드에서 다음을 바로 확인할 수 있습니다.

| 지표 | 활용 예시 |
|---|---|
| 요청당 총 비용 (USD) | 어떤 사용자/기능이 비용을 가장 많이 쓰는지 파악 |
| 요청당 지연시간 (p50/p95/p99) | SLA 위반 여부, 병목 노드 식별 |
| 토큰 사용량 (input/output) | 프롬프트가 비대해지고 있는지 추세 확인 |
| 모델별 분포 | gpt-4o vs gpt-4o-mini 라우팅이 의도대로 되는지 확인 |
| 태그/세션별 필터 | 특정 기능(예: RAG 파이프라인)만 따로 분석 |

커스텀 모델(자체 호스팅 vLLM 등)을 쓰는 경우 Langfuse의 `model_cost` 설정에 직접 가격 테이블을 등록하면 동일하게 비용 추적이 가능합니다.

```python
langfuse_handler = CallbackHandler(
    trace_name="refund-agent",
    metadata={"model_provider": "self-hosted-vllm", "gpu": "A100-80GB"},
)
```

`metadata`에 인프라 정보를 같이 남겨두면, 나중에 "자체 호스팅 모델 전환 후 지연시간이 어떻게 변했는가?" 같은 비교 분석도 같은 대시보드에서 할 수 있습니다.

> 💡 **실무 팁**: 비용 추적은 개발 초기부터 켜두는 것이 좋습니다. 프로토타입 단계에서는 무시할 만한 금액이지만, 트래픽이 늘어난 뒤 "이번 달 청구서가 왜 이렇게 많이 나왔나"를 역추적하려면 처음부터 트레이스가 쌓여 있어야 합니다.

---

## 📝 핵심 요약

1. LLM 앱은 비결정적이고 다단계이기 때문에 일반 로깅으로는 디버깅이 불가능 — 전용 트레이싱이 필요
2. Langfuse는 Trace(전체 요청) → Span(하위 작업) → Generation(LLM 호출)의 계층 구조로 실행을 기록
3. LangGraph/LangChain에는 `CallbackHandler` 하나만 `config`에 넘기면 자동 계측이 가능
4. `@observe()` 데코레이터로 임의 함수를 세밀하게 span/generation으로 감쌀 수 있음
5. 비용·지연시간·토큰 추적은 배포 초기부터 켜서 트렌드를 누적해야 나중에 회고/디버깅이 가능

---

## 🔗 참고 자료

- [Langfuse 공식 문서](https://langfuse.com/docs)
- [Langfuse — LangChain/LangGraph Integration](https://langfuse.com/docs/integrations/langchain/tracing)
- [Langfuse — Tracing 개념 가이드](https://langfuse.com/docs/tracing)

---

*⬅️ 이전: [Day 26 — Supervisor 패턴 & Memory 설계](../day-26/)  |  다음: [Day 28 — Metrics & Evaluation](../day-28/) ➡️*
