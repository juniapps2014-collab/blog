---
title: "Day 05 — Claude의 한계와 특성 이해"
date: 2026-06-25
weight: 5
---


> **Phase 1: 기초** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Hallucination이 발생하는 원인과 완화 방법을 설명할 수 있다
- Claude의 거절(refusal) 동작을 예측하고 프롬프트로 완화할 수 있다
- Knowledge cutoff의 한계를 이해하고 설계에 반영할 수 있다

---

## 1. Hallucination — 존재하지 않는 사실을 생성

Hallucination은 LLM이 사실이 아닌 내용을 자신 있게 말하는 현상입니다. Claude는 다른 모델 대비 낮은 편이지만 완전히 없지는 않습니다.

**발생 패턴:**

| 유형 | 예시 |
|------|------|
| 존재하지 않는 URL/논문 인용 | "https://arxiv.org/abs/2301.99999 참조" |
| 날짜/수치 오류 | 실제와 다른 출시일, 버전 번호 |
| API/함수 이름 혼동 | 존재하지 않는 메서드 호출 코드 생성 |
| 인물 경력 오류 | 실제와 다른 직책, 소속 |

**완화 전략:**

```python
# 전략 1: 불확실성 표현 요청
system = """모르는 내용은 반드시 "확인이 필요합니다" 또는 "정확하지 않을 수 있습니다"라고 명시하세요.
URL이나 논문 제목은 직접 검색 가능한 것만 인용하세요."""

# 전략 2: 정보 출처를 컨텍스트로 제공 (RAG 패턴)
# 검색 결과나 문서를 직접 제공하면 hallucination 대폭 감소
system = """아래 제공된 문서만을 근거로 답변하세요.
문서에 없는 내용은 "제공된 정보에 없습니다"라고 말하세요.

<documents>
{실제 문서 내용}
</documents>"""

# 전략 3: 검증 단계 추가
messages = [
    {"role": "user", "content": "Sendbird API에서 메시지를 삭제하는 방법은?"},
    {"role": "assistant", "content": "...응답..."},
    {"role": "user", "content": "위 답변에서 확실하지 않은 부분을 명시해줘"}
]
```

---

## 2. Refusal — 거절 동작의 설계

Claude의 거절은 버그가 아닌 설계입니다. Constitutional AI 훈련의 결과로, 특정 요청에는 의도적으로 응하지 않습니다.

**거절이 발생하는 상황:**

```
# 명확한 거절 — 프롬프트로 우회 불가
- 위험 물질 합성 방법
- 실제 인물에 대한 허위 정보 생성
- 아동 관련 유해 콘텐츠

# 맥락에 따라 달라지는 거절 — 프롬프트로 완화 가능
- 보안 취약점 설명 (교육 목적 vs 악용 의도)
- 의학 정보 (일반 정보 vs 처방 대체)
- 경쟁사 비교 (사실 기반 vs 비방)
```

**거절 완화 방법:**

```python
# 목적과 맥락을 명확히 제공
system = """당신은 Sendbird의 내부 보안 팀을 위한 어시스턴트입니다.
사용자들은 자사 제품의 보안을 개선하기 위해 취약점을 연구하는 전문가입니다.
교육적이고 방어적인 목적으로만 답변하세요."""

# 나쁜 예: 맥락 없이 민감한 요청
# "SQL 인젝션 공격 코드 작성해줘"  → 거절 가능성 높음

# 좋은 예: 목적과 범위 명시
# "자사 API의 SQL 인젝션 취약점을 테스트하기 위한
#  방어적 예시 코드와 수정 방법을 알려줘" → 응답 가능성 높음
```

**거절 처리 코드:**

```python
import anthropic

def safe_request(client, system, user_message):
    try:
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=system,
            messages=[{"role": "user", "content": user_message}]
        )
        
        # stop_reason 확인
        if response.stop_reason == "end_turn":
            text = response.content[0].text
            
            # 소프트 거절 감지 (Claude가 응답은 하지만 돕기를 거부)
            refusal_signals = ["도움을 드리기 어렵", "적절하지 않", "할 수 없습니다"]
            if any(signal in text for signal in refusal_signals):
                return None, "soft_refusal"
            
            return text, "success"
        
    except anthropic.BadRequestError as e:
        # 하드 거절: API 레벨에서 차단
        return None, "hard_refusal"
    
    return None, "unknown"
```

---

## 3. Knowledge Cutoff — 지식의 시간적 한계

Claude의 학습 데이터는 특정 시점까지의 정보만 포함합니다. 현재 모델 기준 cutoff는 **2024년 초~중반** 수준입니다.

**Cutoff가 문제가 되는 상황:**

```python
# 이런 질문은 부정확할 수 있음
"최신 Claude API 버전은?"
"현재 비트코인 가격은?"
"방금 출시된 GPT-5 vs Claude 비교"

# 이런 질문은 상대적으로 안전
"Python에서 리스트 정렬하는 방법"
"REST API 설계 원칙"
"SQL JOIN의 종류"
```

**프로덕션 대응 전략:**

```python
# 전략 1: 최신 정보는 항상 컨텍스트로 주입
current_date = "2026-06-23"
recent_docs = fetch_latest_docs()  # 외부 API나 DB에서 가져오기

system = f"""오늘 날짜는 {current_date}입니다.
다음은 최신 Sendbird API 문서입니다:

{recent_docs}

이 문서를 기반으로 답변하세요."""

# 전략 2: 시간 민감 질문 감지 및 경고
time_sensitive_keywords = ["최신", "현재", "지금", "오늘", "방금", "최근"]

def is_time_sensitive(query):
    return any(kw in query for kw in time_sensitive_keywords)

if is_time_sensitive(user_query):
    user_query += "\n\n(참고: 최신 정보가 필요하면 공식 문서를 직접 확인하세요.)"
```

---

## 📝 핵심 요약

1. Hallucination은 완전히 없앨 수 없다 — 중요한 사실은 외부 소스로 검증
2. 거절은 설계된 기능 — 맥락과 목적을 명확히 하면 상당수 완화 가능
3. 절대 우회 불가한 거절도 존재 — 이것은 정상 동작
4. Knowledge cutoff 이후의 정보는 컨텍스트로 직접 주입해야 정확한 답변 가능
5. 소프트 거절(응답은 하지만 거부)과 하드 거절(API 오류)을 코드로 구분해서 처리

---

## 🔗 참고 자료

- [Claude의 안전 정책](https://docs.anthropic.com/en/docs/about-claude/safety-and-trust)
- [Hallucination 완화 가이드](https://docs.anthropic.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations)
- [Claude 모델 상세 스펙](https://docs.anthropic.com/en/docs/about-claude/models)

---

*⬅️ 이전: [Day 04 — 출력 형식 제어](../day-04/)  |  다음: [Day 06 — 역할 지정 (Role Prompting)](../day-06/) ➡️*
