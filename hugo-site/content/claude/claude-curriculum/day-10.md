# Day 10 — 코드 생성 및 리뷰 프롬프트

> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 코드 생성 품질을 높이는 프롬프트 구조를 설계할 수 있다
- 코드 리뷰 요청을 체계적으로 구성하여 실질적인 피드백을 얻을 수 있다
- 반복적인 코드 작업을 위한 재사용 가능한 프롬프트 패턴을 만들 수 있다

---

## 1. 코드 생성 프롬프트의 핵심 요소

"Python 함수 만들어줘"와 "다음 조건을 만족하는 Python 함수를 만들어줘"는 결과가 전혀 다릅니다. 코드 생성에서 Claude가 좋은 출력을 내려면 **컨텍스트 4가지**가 필요합니다.

| 요소 | 설명 | 예시 |
|------|------|------|
| **목적** | 이 코드가 무엇을 해야 하는가 | "CSV를 읽어 중복 행을 제거하고 저장" |
| **환경** | 언어, 프레임워크, 버전 | "Python 3.11, pandas 2.x" |
| **제약** | 외부 라이브러리 제한, 성능 요구사항 | "표준 라이브러리만 사용" |
| **입출력** | 예상 입력값과 반환값 형태 | "입력: str 리스트, 출력: dict" |

**나쁜 예:**
```
API 클라이언트 클래스 만들어줘
```

**좋은 예:**
```
Python 3.11로 REST API 클라이언트 클래스를 작성해줘.

요구사항:
- httpx 라이브러리 사용 (async 지원)
- base_url과 api_key를 생성자 인자로 받음
- GET, POST 메서드 지원
- 응답이 4xx/5xx면 커스텀 APIError 예외 발생
- type hint 완전히 적용

반환 타입: dict (JSON 파싱된 응답)
```

---

## 2. 코드 리뷰 요청 패턴

코드 리뷰를 요청할 때 "이 코드 리뷰해줘"는 너무 막연합니다. 리뷰 **관점**을 명시하면 훨씬 구체적인 피드백을 받을 수 있습니다.

### 관점 분리 전략

리뷰를 단일 요청으로 보내는 것보다 관점을 분리해서 요청하면 더 깊은 분석을 얻습니다.

```python
# 리뷰할 코드
def get_user_orders(user_id, db_conn):
    query = f"SELECT * FROM orders WHERE user_id = {user_id}"
    cursor = db_conn.cursor()
    cursor.execute(query)
    result = cursor.fetchall()
    return result
```

**보안 관점 리뷰 요청:**
```
아래 Python 함수의 보안 취약점만 집중적으로 분석해줘.
발견된 각 이슈에 대해:
1. 취약점 종류
2. 공격 시나리오
3. 수정된 코드

[코드 붙여넣기]
```

**성능 관점 리뷰 요청:**
```
아래 함수가 대규모 데이터(100만 건)를 처리할 때의 성능 문제를 분석해줘.
병목 지점과 개선된 버전을 함께 제시해줘.

[코드 붙여넣기]
```

**가독성/유지보수성 관점:**
```
아래 코드를 주니어 개발자가 유지보수한다고 가정하고,
가독성과 구조 개선점을 피드백해줘. 변경 이유도 설명해줘.

[코드 붙여넣기]
```

---

## 3. 실습: 고품질 코드 생성 워크플로우

단순히 코드를 한 번에 요청하는 것보다 **단계적 접근**이 더 나은 결과를 만듭니다.

### Step 1: 인터페이스 먼저 설계

```
다음 기능의 Python 클래스 인터페이스(메서드 시그니처와 docstring만)를 설계해줘.
실제 구현은 하지 마.

기능: 이메일 발송 서비스
- 단건 발송
- 배치 발송 (최대 100건)
- 발송 이력 조회
- 실패 시 재시도 (최대 3회)
```

### Step 2: 구현 요청

```
위에서 설계한 인터페이스를 구현해줘.
- smtplib 사용 (외부 라이브러리 없이)
- 각 메서드에 logging 추가
- 예외는 EmailError 커스텀 클래스로 래핑
```

### Step 3: 테스트 코드 생성

```
위 EmailService 클래스에 대한 pytest 테스트를 작성해줘.
- unittest.mock으로 SMTP 서버 모킹
- 성공 케이스, 실패 케이스, 재시도 로직 각각 테스트
- 픽스처(fixture) 활용
```

실제 실행 예시:

```python
import anthropic

client = anthropic.Anthropic()

# 단계별 프롬프트를 대화로 이어가기
messages = []

def chat(user_message: str) -> str:
    messages.append({"role": "user", "content": user_message})
    
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        system="당신은 시니어 Python 개발자입니다. 코드는 항상 type hint와 docstring을 포함합니다.",
        messages=messages
    )
    
    assistant_message = response.content[0].text
    messages.append({"role": "assistant", "content": assistant_message})
    return assistant_message

# 인터페이스 설계
interface = chat("EmailService 클래스 인터페이스를 설계해줘. (메서드 시그니처와 docstring만)")
print("=== 인터페이스 ===")
print(interface)

# 구현 요청
implementation = chat("위 인터페이스를 smtplib으로 구현해줘. 재시도 로직 포함.")
print("=== 구현 ===")
print(implementation)

# 테스트 요청
tests = chat("위 구현에 대한 pytest 테스트를 작성해줘.")
print("=== 테스트 ===")
print(tests)
```

> 💡 **핵심 패턴**: 대화 이력(`messages`)을 유지하면 이전 맥락을 참조하여 일관성 있는 코드를 생성합니다. 매번 새로 시작하면 코드 스타일이 달라질 수 있습니다.

### 디버깅 요청 패턴

코드가 에러를 내는 경우:

```
다음 코드에서 에러가 발생합니다.

에러 메시지:
```
TypeError: unsupported operand type(s) for +: 'int' and 'str'
  File "main.py", line 12, in calculate_total
    total = price + tax_rate
```

코드:
[코드 붙여넣기]

1. 에러 원인을 설명해줘
2. 수정된 코드를 제시해줘
3. 같은 실수를 방지하는 방법도 알려줘
```

---

## 📝 핵심 요약

1. 코드 생성 프롬프트에는 목적·환경·제약·입출력 4가지를 명시한다
2. 리뷰는 보안/성능/가독성 등 관점을 분리해서 요청할수록 깊은 피드백을 얻는다
3. 인터페이스 설계 → 구현 → 테스트 순의 단계적 접근이 품질을 높인다
4. 멀티턴 대화로 `messages` 이력을 유지하면 일관된 코드 스타일이 유지된다
5. 에러 디버깅 요청 시 에러 메시지, 코드, 원하는 출력을 함께 제공한다

---

## 🔗 참고 자료

- [Anthropic 프롬프트 엔지니어링 가이드](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)
- [코드 생성 사용 사례](https://docs.anthropic.com/en/docs/about-claude/use-case-guides/coding)
- [Messages API 레퍼런스](https://docs.anthropic.com/en/api/messages)

---

*⬅️ 이전: [Day 09 — 긴 문서 처리](./day-09.md)  |  다음: [Day 11 — 다단계 추론 패턴](./day-11.md) ➡️*
