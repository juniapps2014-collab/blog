# Day 11 — 다단계 추론 패턴

> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 다단계 추론(Multi-step reasoning)이 필요한 상황을 식별할 수 있다
- Chain-of-Thought와 단계적 분해(Step Decomposition) 패턴을 실전에 적용할 수 있다
- 복잡한 작업을 서브태스크로 나누어 Claude에게 위임하는 워크플로를 설계할 수 있다

---

## 1. 왜 다단계 추론이 필요한가?

LLM은 단순 질의에는 강하지만, **복잡한 문제를 한 번에 처리**하려 하면 품질이 급격히 떨어집니다. 이유는 두 가지입니다.

첫째, 생성 과정은 토큰을 왼쪽에서 오른쪽으로 순차 생성합니다. 한 번 생성된 토큰은 수정되지 않으므로, 초반 방향이 잘못되면 전체가 틀립니다.

둘째, 컨텍스트 안에 있는 중간 계산 결과가 모델의 "작업 메모리" 역할을 합니다. 단계별로 답을 명시하면 모델이 올바른 중간 상태를 참고할 수 있습니다.

**비유**: 암산으로 3자리 곱셈을 하는 것보다 종이에 풀어 쓰는 게 정확한 것과 같습니다.

---

## 2. 핵심 패턴 3가지

### 패턴 A: Chain-of-Thought (CoT)

모델이 답 전에 **생각 과정을 출력**하도록 유도합니다. Day 07에서 다뤘지만, 여기서는 명시적 단계 레이블을 붙이는 방법을 심화합니다.

```python
prompt = """다음 코드의 버그를 찾아주세요.

코드:
def calculate_discount(price, discount_pct):
    return price - price * discount_pct

calculate_discount(100, 20)  # 기대값: 80, 실제값: -1900

단계별로 분석해주세요:
1단계) 함수가 의도한 동작 파악
2단계) 실제 계산 과정 추적
3단계) 버그 원인 특정
4단계) 수정 코드 제시
"""
```

레이블(`1단계`, `2단계`)을 명시하면 모델이 각 단계를 건너뛰지 않습니다.

---

### 패턴 B: 작업 분해 (Task Decomposition)

복잡한 작업을 **별도 API 호출로 분리**합니다. 각 단계의 출력이 다음 단계의 입력이 됩니다.

```python
import anthropic

client = anthropic.Anthropic()

def run(prompt: str) -> str:
    msg = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}]
    )
    return msg.content[0].text

# 요구사항 문서 → 개발 태스크 분해 파이프라인
requirements = """
사용자가 CSV 파일을 업로드하면 자동으로 데이터를 정제하고
이상치를 탐지한 뒤, 요약 리포트를 이메일로 발송하는 시스템
"""

# Step 1: 핵심 컴포넌트 추출
components = run(f"""
다음 요구사항에서 독립적인 기능 컴포넌트를 목록으로 추출해주세요.
요구사항: {requirements}
형식: 번호 매긴 목록, 각 항목은 한 문장
""")

# Step 2: 각 컴포넌트를 개발 태스크로 변환
tasks = run(f"""
다음 컴포넌트 목록을 Jira 태스크 형식으로 변환해주세요.
각 태스크: 제목, 수락 기준 2개, 예상 공수(시간)

컴포넌트 목록:
{components}
""")

print(tasks)
```

---

### 패턴 C: 검토-수정 루프 (Critique-and-Revise)

모델에게 자신의 초안을 **비판하고 개선**하도록 요청합니다.

```python
draft = run("""
Python으로 이진 탐색 함수를 작성해주세요.
정렬된 리스트에서 target 값을 찾아 인덱스를 반환합니다.
없으면 -1을 반환합니다.
""")

final = run(f"""
다음 코드를 검토하고 개선해주세요.

[초안 코드]
{draft}

검토 기준:
1. 엣지 케이스 처리 (빈 리스트, 단일 원소 등)
2. 시간/공간 복잡도
3. Pythonic한 스타일
4. 독스트링 완성도

개선된 버전을 제시해주세요.
""")

print(final)
```

---

## 3. 실전 예시: 코드 리뷰 파이프라인

다음은 세 패턴을 조합해 PR 코드 리뷰를 자동화하는 예시입니다.

```python
import anthropic

client = anthropic.Anthropic()

def multi_step_code_review(code: str, language: str = "Python") -> dict:
    """3단계 코드 리뷰 파이프라인"""

    def run(prompt: str) -> str:
        msg = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2048,
            messages=[{"role": "user", "content": prompt}]
        )
        return msg.content[0].text

    # Step 1: 코드 이해
    summary = run(f"""
다음 {language} 코드가 무엇을 하는지 3문장으로 요약해주세요.
기술적 세부사항보다 비즈니스 목적 중심으로 설명해주세요.

```{language.lower()}
{code}
```
""")

    # Step 2: 잠재적 문제 탐지
    issues = run(f"""
다음 코드의 잠재적 문제를 찾아주세요.

코드 요약: {summary}

```{language.lower()}
{code}
```

아래 카테고리별로 분류해주세요:
- [버그] 실제 오류 가능성
- [보안] 취약점
- [성능] 비효율
- [가독성] 유지보수 어려움

문제가 없는 카테고리는 "없음"으로 표기하세요.
""")

    # Step 3: 개선 우선순위 결정
    priority = run(f"""
다음 코드 리뷰 결과를 바탕으로 수정 우선순위를 결정해주세요.

발견된 이슈:
{issues}

출력 형식:
1. [즉시 수정] ...
2. [다음 PR에서 수정] ...
3. [기술 부채로 등록] ...
""")

    return {
        "summary": summary,
        "issues": issues,
        "priority": priority
    }


# 사용 예시
code = """
def get_user(user_id):
    query = f"SELECT * FROM users WHERE id = {user_id}"
    result = db.execute(query)
    return result[0]
"""

review = multi_step_code_review(code)
for step, content in review.items():
    print(f"=== {step.upper()} ===")
    print(content)
    print()
```

> 💡 **실무 팁**: 각 단계 사이에 검증 로직을 추가하세요. 예를 들어 Step 1의 요약이 너무 짧으면 (`len(summary) < 50`) 재시도하는 방어 코드를 넣으면 파이프라인 안정성이 높아집니다.

---

## 📝 핵심 요약

1. **복잡한 문제 = 여러 단계로 분해** — 한 번의 프롬프트로 해결하려 하지 말 것
2. **단계 레이블 명시** — `1단계`, `2단계` 등 레이블이 있으면 Claude가 단계를 건너뛰지 않음
3. **중간 결과를 다음 프롬프트에 주입** — 각 API 호출 결과가 다음 입력의 컨텍스트가 됨
4. **검토-수정 루프** — 모델 스스로 비판하게 하면 초안 품질이 크게 향상됨
5. **단계별 분리의 부작용**: API 호출 횟수 증가 → 비용/지연 증가, 트레이드오프를 인식할 것

---

## 🔗 참고 자료

- [Chain-of-Thought Prompting — Anthropic 가이드](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought)
- [Extended Thinking](https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking)
- [Long Context Tips](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/long-context-tips)

---

*⬅️ 이전: [Day 10 — 코드 생성 및 리뷰](./day-10.md)  |  다음: [Day 12 — 프롬프트 평가 및 개선](./day-12.md) ➡️*
