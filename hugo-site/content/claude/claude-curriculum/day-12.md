# Day 12 — 프롬프트 평가 및 반복 개선

> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 프롬프트 품질을 "감"이 아니라 측정 가능한 기준으로 평가할 수 있다
- 골든셋(golden set) 기반 회귀 테스트 구조를 설계할 수 있다
- 프롬프트 개선을 반복 실험으로 관리하는 워크플로를 구축할 수 있다

---

## 1. 왜 프롬프트를 "평가"해야 하는가?

Day 01~11에서 다양한 프롬프트 기법(역할 지정, Few-shot, CoT, XML 태그, 다단계 추론)을 배웠습니다. 문제는 이 기법들을 적용한 후 **정말 더 나아졌는지 확인할 방법이 없으면**, 프롬프트 수정이 감에 의존한 도박이 된다는 점입니다.

실무에서 자주 벌어지는 실패 패턴:

```
1. 프롬프트를 수정한다
2. 테스트 케이스 2~3개를 눈으로 확인한다
3. "괜찮아 보인다"며 배포한다
4. 프로덕션에서 이전에 잘 처리되던 엣지 케이스가 깨진다
```

이 패턴이 반복되는 이유는 **회귀(regression)를 감지할 장치가 없기 때문**입니다. 코드에 유닛 테스트가 있듯, 프롬프트에도 평가 세트(eval set)가 필요합니다.

---

## 2. 평가의 3가지 축

프롬프트 평가는 크게 세 가지 방식으로 나뉩니다.

| 방식 | 설명 | 적합한 경우 | 비용 |
|------|------|------------|------|
| **정확한 일치 (Exact match)** | 출력이 기대값과 문자열/구조적으로 일치하는지 확인 | 분류, 추출, 형식이 고정된 작업 | 낮음 |
| **규칙 기반 채점 (Rule-based)** | 정규식, 키워드 포함 여부, JSON 스키마 검증 등 | 형식은 유연하지만 필수 요소가 있는 작업 | 낮음 |
| **LLM 심판 (LLM-as-judge)** | 별도의 Claude 호출로 출력 품질을 채점 | 요약, 창작, 자유 형식 텍스트처럼 정답이 하나가 아닌 작업 | 높음 |

실무에서는 세 가지를 조합합니다. 예를 들어 "JSON 스키마 검증(규칙 기반) + 내용 품질(LLM 심판)"처럼 계층을 나누는 방식이 일반적입니다.

---

## 3. 골든셋 구축하기

**골든셋**은 입력과 "기대되는 출력(또는 채점 기준)"이 쌍으로 구성된 테스트 데이터입니다. 최소 15~30개 케이스로 시작하되, 다음 유형을 반드시 포함해야 합니다.

- **일반 케이스**: 가장 흔한 입력 패턴
- **엣지 케이스**: 빈 입력, 매우 긴 입력, 특수 문자
- **모호한 케이스**: 사람도 판단이 갈리는 입력 (Claude의 처리 방식을 관찰하기 위함)
- **실패했던 케이스**: 프로덕션에서 실제로 문제가 됐던 입력 (회귀 방지용)

```python
golden_set = [
    {
        "id": "case_001",
        "input": "이 리뷰가 긍정적인지 부정적인지 분류: '배송은 빨랐는데 제품이 파손되어 왔어요'",
        "expected": "부정",
        "category": "혼합 감정"
    },
    {
        "id": "case_002",
        "input": "이 리뷰가 긍정적인지 부정적인지 분류: ''",
        "expected": "판단불가",
        "category": "엣지케이스_빈입력"
    },
    # ... 15~30개
]
```

---

## 4. 평가 스크립트 만들기

아래는 Claude API를 사용해 골든셋 전체를 채점하는 최소 구현입니다.

```python
import anthropic
import json

client = anthropic.Anthropic()

def run_prompt(prompt_template: str, input_text: str) -> str:
    msg = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=100,
        messages=[{"role": "user", "content": prompt_template.format(input=input_text)}]
    )
    return msg.content[0].text.strip()


def evaluate(prompt_template: str, golden_set: list) -> dict:
    results = []
    correct = 0

    for case in golden_set:
        output = run_prompt(prompt_template, case["input"])
        is_correct = case["expected"] in output
        correct += is_correct
        results.append({
            "id": case["id"],
            "category": case["category"],
            "output": output,
            "expected": case["expected"],
            "pass": is_correct
        })

    return {
        "accuracy": correct / len(golden_set),
        "results": results
    }


prompt_v1 = "다음 리뷰의 감정을 '긍정', '부정', '판단불가' 중 하나로만 답하세요.\n\n리뷰: {input}"

report = evaluate(prompt_v1, golden_set)
print(f"정확도: {report['accuracy']:.1%}")

# 실패 케이스만 출력해 원인 분석
for r in report["results"]:
    if not r["pass"]:
        print(f"[FAIL] {r['id']} ({r['category']}): 기대={r['expected']}, 실제={r['output']}")
```

이 구조의 핵심은 **프롬프트를 변수로 분리**한 것입니다. `prompt_v1`, `prompt_v2`를 각각 같은 `golden_set`에 돌려 정확도를 비교하면, 어떤 변경이 실제로 개선인지 숫자로 확인할 수 있습니다.

---

## 5. LLM-as-judge로 자유 형식 출력 채점

요약이나 이메일 작성처럼 "정답이 하나가 아닌" 작업은 별도 Claude 호출로 채점합니다.

```python
def llm_judge(output: str, criteria: str) -> dict:
    judge_prompt = f"""다음 텍스트를 평가 기준에 따라 채점해주세요.

[평가 대상]
{output}

[평가 기준]
{criteria}

각 기준에 대해 1~5점을 매기고, JSON으로만 답하세요:
{{"명확성": 점수, "간결성": 점수, "톤_적절성": 점수, "총평": "한 줄 요약"}}
"""
    msg = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=300,
        messages=[{"role": "user", "content": judge_prompt}]
    )
    return json.loads(msg.content[0].text)


summary_output = run_prompt("다음을 3문장으로 요약: {input}", "긴 회의록 텍스트...")
score = llm_judge(summary_output, "명확성, 간결성, 톤의 적절성")
print(score)
```

> ⚠️ **주의**: LLM 심판도 완벽하지 않습니다(자기 일관성 편향, 길이 편향 등). 심판 프롬프트 자체도 골든셋으로 검증하고, 중요한 결정에는 사람의 샘플 검토를 병행하세요.

---

## 📝 핵심 요약

1. **프롬프트 변경 = 실험** — "괜찮아 보인다"가 아니라 골든셋 정확도로 판단할 것
2. **골든셋은 일반/엣지/모호/과거 실패 케이스를 모두 포함** — 최소 15~30개로 시작
3. **평가 방식 3종**: 정확한 일치(저비용), 규칙 기반(중비용), LLM 심판(고비용) — 작업 특성에 맞게 조합
4. **프롬프트를 변수로 분리**해 v1, v2를 같은 테스트셋에 돌려 정량 비교
5. **LLM 심판은 편향이 있음** — 심판 자체도 검증하고, 중요 결정은 사람이 최종 확인

---

## 🔗 참고 자료

- [Anthropic — Evaluate your prompts](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/evaluate)
- [Anthropic — Prompt engineering overview](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/overview)
- [Anthropic Cookbook — Evaluation examples](https://github.com/anthropics/anthropic-cookbook)

---

*⬅️ 이전: [Day 11 — 다단계 추론 패턴](./day-11.md)  |  다음: [Day 13 — Anthropic API 기초](./day-13.md) ➡️*
