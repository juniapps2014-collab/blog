---
title: "Day 19 — 에이전트 설계 패턴"
date: 2026-07-09
weight: 19
---


> **Phase 4: 고급/프로덕션** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 워크플로우(workflow)와 에이전트(agent)의 아키텍처적 차이를 설명할 수 있다
- ReAct(추론+행동) 루프의 동작 원리를 이해하고 Python으로 최소 구현을 작성할 수 있다
- Plan-and-Execute 패턴이 ReAct와 어떻게 다르며 언제 유리한지 판단할 수 있다

---

## 1. 워크플로우 vs 에이전트 — 먼저 구분부터

Anthropic은 "에이전트적 시스템(agentic system)"을 두 가지로 나눕니다. **워크플로우**는 LLM과 도구가 미리 정의된 코드 경로를 따라 오케스트레이션되는 시스템이고, **에이전트**는 LLM이 스스로 프로세스와 도구 사용을 동적으로 결정하며 작업 수행 방식에 대한 통제권을 갖는 시스템입니다.

| 구분 | 워크플로우 | 에이전트 |
|------|-----------|---------|
| 경로 결정 | 개발자가 사전 정의 | 모델이 매 스텝 판단 |
| 예측 가능성 | 높음 | 낮음 (유연함) |
| 적합한 작업 | 단계 수를 알 수 있는 작업 | 단계 수를 예측 불가능한 개방형 작업 |
| 비용/지연 | 상대적으로 낮음 | 반복 호출로 높아짐 |

핵심 원칙은 "필요할 때만 복잡도를 추가하라"는 것입니다. 많은 경우 검색(retrieval)과 예시를 곁들인 단일 LLM 호출만으로 충분하며, 에이전트는 실제로 단계 수를 예측할 수 없고 고정된 경로를 하드코딩할 수 없는 개방형 문제에만 투입해야 합니다. 자율성이 커질수록 비용과 오류 누적 가능성도 함께 커지기 때문입니다.

---

## 2. ReAct 패턴 — 추론과 행동의 반복 루프

ReAct(Reasoning + Acting)는 오늘날 대부분의 실전 에이전트, 특히 Claude Code와 같은 코딩 에이전트의 근간이 되는 패턴입니다. 동작 방식은 단순합니다.

1. 모델이 현재 상태를 바탕으로 **추론**하고 다음에 어떤 **도구를 호출**할지 결정한다
2. 하네스(harness)가 실제로 도구를 실행하고 결과를 얻는다
3. 도구 실행 결과(환경으로부터의 "ground truth")를 다시 모델에게 보여준다
4. 작업이 끝날 때까지, 혹은 정지 조건(최대 반복 횟수 등)에 도달할 때까지 1~3을 반복한다

```python
import anthropic

client = anthropic.Anthropic()

tools = [
    {
        "name": "search_docs",
        "description": "내부 문서에서 키워드로 검색한다",
        "input_schema": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"],
        },
    }
]

def run_tool(name, tool_input):
    if name == "search_docs":
        return f"'{tool_input['query']}' 관련 문서 3건 발견"
    return "알 수 없는 도구"

messages = [{"role": "user", "content": "환불 정책 관련 최신 변경사항을 찾아줘"}]

for step in range(5):  # 정지 조건: 최대 5회 반복
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        tools=tools,
        messages=messages,
    )
    messages.append({"role": "assistant", "content": response.content})

    if response.stop_reason != "tool_use":
        print(response.content[0].text)  # 최종 답변
        break

    tool_results = []
    for block in response.content:
        if block.type == "tool_use":
            result = run_tool(block.name, block.input)
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": result,
            })
    messages.append({"role": "user", "content": tool_results})
```

여기서 중요한 건 매 스텝마다 "환경으로부터의 실제 피드백"(도구 실행 결과, 코드 실행 결과 등)을 모델에 되돌려준다는 점입니다. 이 피드백이 없으면 모델은 자신의 진행 상황을 스스로 평가할 방법이 없습니다.

---

## 3. Plan-and-Execute — 계획을 먼저, 실행은 그다음

ReAct는 매 스텝마다 "다음에 뭘 할지"를 즉흥적으로 결정합니다. 반면 **Plan-and-Execute**는 먼저 전체 작업을 하위 단계로 분해하는 계획을 세운 뒤, 그 계획을 순차적으로 실행합니다. Anthropic 문서에서 말하는 **오케스트레이터-워커(orchestrator-workers)** 워크플로우가 이 패턴에 가깝습니다. 중앙 LLM이 작업을 동적으로 쪼개고 워커 LLM들에게 위임한 뒤 결과를 종합합니다.

```python
planning_prompt = """다음 작업을 처리하기 위한 단계별 계획을 세워라.
각 단계는 독립적으로 실행 가능해야 한다.

작업: 지난 분기 고객 이탈 원인을 분석하고 개선안을 작성하라

계획을 JSON 배열로 출력하라: [{"step": 1, "action": "..."}, ...]"""

plan_response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=500,
    messages=[{"role": "user", "content": planning_prompt}],
)
# 이후 각 step을 별도의 LLM 호출(워커)로 실행하고 결과를 종합
```

**언제 무엇을 쓸까**: 하위 작업의 개수와 성격을 미리 예측할 수 없는 작업(예: 코드베이스 전반에 걸친 리팩터링, 여러 소스를 넘나드는 리서치)은 ReAct처럼 매 스텝 판단하는 방식이 유리합니다. 반대로 하위 작업을 미리 나눌 수 있고 병렬 실행이나 역할 분담이 가능한 작업은 Plan-and-Execute(오케스트레이터-워커)가 더 예측 가능하고 디버깅하기 쉽습니다. 두 패턴을 섞어서, 상위 계획은 Plan-and-Execute로 세우고 각 하위 단계 내부는 ReAct 루프로 실행하는 하이브리드 구조도 실무에서 자주 쓰입니다.

에이전트를 설계할 때 지켜야 할 세 가지 원칙은 다음과 같습니다: 설계를 **단순하게** 유지할 것, 에이전트의 계획 단계를 명시적으로 보여주어 **투명성**을 확보할 것, 그리고 도구 문서화와 테스트에 공을 들여 **에이전트-컴퓨터 인터페이스(ACI)**를 정교하게 설계할 것입니다. 실제로 Anthropic이 SWE-bench용 코딩 에이전트를 만들 때, 전체 프롬프트보다 도구 자체를 다듬는 데 더 많은 시간을 썼다고 밝힌 바 있습니다. 예를 들어 상대 경로 대신 절대 경로만 받도록 도구를 바꾸자 모델의 실수가 사라졌습니다.

---

## 📝 핵심 요약

1. 워크플로우는 사전 정의된 경로, 에이전트는 모델이 스스로 통제하는 동적 경로 — 필요할 때만 에이전트로 넘어간다
2. ReAct는 "추론 → 도구 실행 → 결과 피드백"을 반복하는 루프이며, 환경으로부터의 실제 피드백이 핵심이다
3. Plan-and-Execute(오케스트레이터-워커)는 계획을 먼저 세우고 하위 작업을 위임·종합하는 방식으로, 병렬화와 예측 가능성이 필요할 때 유리하다
4. 정지 조건(최대 반복 횟수 등)과 인간 개입 체크포인트를 반드시 설계에 포함해야 오류 누적을 막을 수 있다
5. 에이전트 성능은 프롬프트보다 도구 설계(ACI)에서 갈리는 경우가 많다 — 도구 이름, 설명, 파라미터를 신중히 다듬어야 한다

---

## 🔗 참고 자료

- [Building Effective AI Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [Claude Agent SDK 개요](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Tool Use 가이드](https://platform.claude.com/docs/en/build-with-claude/tool-use)
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

---

*⬅️ 이전: [Day 18 — 비용 최적화](../day-18/)  |  다음: [Day 20 — Multi-agent 시스템 설계](../day-20/) ➡️*
