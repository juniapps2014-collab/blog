---
title: "Day 23 — 평가(Evals) 프레임워크"
date: 2026-07-15
weight: 23
---


> **Phase 4: 고급/프로덕션** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- SMART(구체적·측정 가능·달성 가능·관련성) 원칙에 따라 LLM 애플리케이션의 성공 기준을 정의할 수 있다
- code-based, human, LLM-based 세 가지 grading 방식의 트레이드오프를 비교하고 상황에 맞게 선택할 수 있다
- Claude Haiku를 grader로 사용하는 rubric 기반 LLM-graded eval 파이프라인을 Python으로 구현할 수 있다

---

## 1. 성공 기준부터 정의한다

프롬프트를 다듬기 전에 먼저 "무엇을 잘하는 것으로 볼 것인가"를 명확히 해야 합니다. Anthropic 공식 문서는 좋은 성공 기준의 조건으로 다음 네 가지를 제시합니다.

| 조건 | 나쁜 예 | 좋은 예 |
|------|---------|---------|
| 구체적 (Specific) | "좋은 성능" | "정확한 감정 분류" |
| 측정 가능 (Measurable) | "안전한 출력" | "10,000회 시행 중 콘텐츠 필터가 toxicity로 플래그한 비율이 0.1% 미만" |
| 달성 가능 (Achievable) | 현재 프론티어 모델 능력을 넘어서는 목표 | 업계 벤치마크·과거 실험·연구 결과에 근거한 목표 |
| 관련성 (Relevant) | 앱의 목적과 무관한 지표 | 의료 앱이면 인용 정확도, 캐주얼 챗봇이면 어조 |

윤리나 안전처럼 "애매하다"고 여겨지는 항목도 수치화할 수 있다는 점이 중요합니다. 대부분의 실제 애플리케이션은 task fidelity, consistency, relevance/coherence, tone/style, privacy preservation, context utilization, latency, price처럼 여러 기준을 동시에 평가하는 다차원 평가(multidimensional evaluation)가 필요합니다.

---

## 2. Eval 설계 원칙과 세 가지 grading 방식

Eval을 만들 때는 실제 프로덕션에서 마주칠 입력 분포를 그대로 반영해야 합니다. 특히 엣지 케이스를 빠뜨리지 않는 것이 중요하며, 가능한 한 자동 채점이 가능하도록 문제를 구성합니다(객관식, 문자열 매칭, 코드 채점, LLM 채점). 손으로 하나하나 고품질 테스트 케이스를 만드는 것보다, 신호가 약간 떨어지더라도 자동 채점 가능한 문항을 대량으로 확보하는 쪽이 낫습니다. Claude에게 소수의 예시 케이스를 주고 나머지를 생성하게 하거나, 어떤 평가 방법이 적합할지 브레인스토밍을 요청하는 것도 좋은 전략입니다.

채점 방식은 속도·신뢰성·확장성이 가장 높은 것부터 선택합니다.

| 방식 | 장점 | 단점 | 적합한 경우 |
|------|------|------|-------------|
| Code-based (exact match, string match) | 가장 빠르고 신뢰도 높음, 완전 자동화 | 복잡한 판단에는 유연성 부족 | 정답이 명확한 분류·추출 작업 |
| Human grading | 가장 유연하고 품질 높음 | 느리고 비용이 큼 | 소규모 정성 검증, 최종 확인 |
| LLM-based grading | 빠르고 유연, 복잡한 판단도 확장 가능 | 신뢰성을 먼저 검증해야 함 | 어조·일관성 등 정성적 기준 |

Code-based grading은 다음처럼 단순하게 구현합니다.

```python
# exact match — 감정 분류처럼 정답이 명확한 경우
def exact_match_eval(output: str, golden_answer: str) -> bool:
    return output.strip() == golden_answer.strip()

# string match — 응답에 특정 키워드가 포함되어야 하는 경우
def string_match_eval(output: str, key_phrase: str) -> bool:
    return key_phrase in output
```

---

## 3. 실습 — Claude Haiku로 LLM-based grading 파이프라인 구현

LLM-based grading을 신뢰성 있게 만들려면 세 가지를 지켜야 합니다. 첫째, rubric을 구체적이고 명확하게 작성합니다(예: "답변은 반드시 첫 문장에 'Acme Inc.'를 언급해야 하며, 그렇지 않으면 자동으로 'incorrect'로 채점한다"). 둘째, 채점 결과를 empirical하게 강제합니다 — "correct/incorrect"만 출력하게 하거나 1~5점 척도로 제한하고, 순수 정성 평가는 지양합니다. 셋째, grader 모델이 먼저 근거를 추론한 뒤 점수를 내도록 유도하고(reasoning), 최종 결과만 파싱해 사용합니다. 이 방식은 복잡한 판단이 필요한 과제일수록 채점 정확도를 크게 높입니다.

아래는 고객 서비스 응답의 tone/style을 Likert 척도로 채점하는 예시입니다. 빠르고 저렴한 Claude Haiku 4.5를 grader로 사용하고, 프로덕션 채점에는 확장성을 위해 Batches API를 함께 고려할 수 있습니다.

```python
from anthropic import Anthropic
import re

client = Anthropic()

GRADER_RUBRIC = """당신은 고객 서비스 응답의 어조를 채점하는 평가자입니다.
다음 응답이 "공손하고, 공감하며, 전문적인 어조"를 지켰는지 1~5점으로 평가하세요.

- 5점: 세 가지 기준을 모두 충족
- 3점: 일부만 충족하거나 어조가 다소 딱딱함
- 1점: 무례하거나 기계적인 어조

먼저 근거를 2문장 이내로 설명한 뒤, 마지막 줄에 반드시 "SCORE: N" 형식으로 점수만 출력하세요.
"""

def llm_graded_eval(customer_response: str) -> int:
    """Haiku를 grader로 사용해 어조를 1~5점으로 채점"""
    result = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=200,
        system=GRADER_RUBRIC,
        messages=[{"role": "user", "content": f"응답:\n{customer_response}"}],
    )
    text = result.content[0].text
    match = re.search(r"SCORE:\s*(\d)", text)
    if not match:
        raise ValueError(f"채점 결과를 파싱할 수 없습니다: {text}")
    return int(match.group(1))

sample_response = "네, 불편을 드려 죄송합니다. 바로 확인해서 오늘 안에 처리해 드리겠습니다."
score = llm_graded_eval(sample_response)
print(f"어조 점수: {score}/5")
```

이 함수를 테스트 케이스 수백 개에 대해 반복 실행하고 점수 분포를 집계하면, 프롬프트를 수정하기 전후의 어조 품질 변화를 정량적으로 추적할 수 있습니다. Console의 Evaluation 도구를 쓰면 이런 반복 채점을 코드 없이도 수행할 수 있는데, 프롬프트에 `{{variable}}` 형태의 동적 변수를 1~2개 포함시키면 'Generate Test Case'로 케이스를 자동 생성하고, 프롬프트 버전 간 결과를 5점 척도로 나란히 비교할 수 있습니다.

---

## 📝 핵심 요약

1. 프롬프트를 개선하기 전에 구체적(Specific)·측정 가능(Measurable)·달성 가능(Achievable)·관련성 있는(Relevant) 성공 기준부터 정의한다
2. 대부분의 실제 과제는 task fidelity, consistency, tone, privacy 등 여러 기준을 함께 보는 다차원 평가가 필요하다
3. Grading은 code-based(가장 빠르고 신뢰도 높음) → LLM-based(유연하고 확장 가능) → human(가장 유연하지만 느림) 순으로 가능한 한 자동화된 방식을 우선한다
4. LLM-based grading은 명확한 rubric, empirical한 출력 형식(예/아니오, 1~5점), 추론 후 점수 산출이라는 세 가지를 갖출 때 신뢰도가 올라간다
5. Console의 Evaluation 도구를 쓰면 동적 변수가 포함된 프롬프트에 대해 테스트 케이스 생성부터 프롬프트 버전 비교까지 코드 없이 수행할 수 있다

---

## 🔗 참고 자료

- [Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)
- [Using the Evaluation Tool in Console](https://platform.claude.com/docs/en/test-and-evaluate/eval-tool)
- [Reducing latency](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-latency)
- [Increase output consistency](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/increase-consistency)

---

*⬅️ 이전: [Day 22 — 프롬프트 인젝션 방어 및 보안](../day-22/)  |  다음: [Day 24 — 프로덕션 배포 고려사항](../day-24/) ➡️*
