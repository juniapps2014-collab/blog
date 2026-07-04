---
title: "Day 07 — Few-shot / Chain-of-Thought 프롬프팅"
date: 2026-06-27
weight: 7
---


> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Few-shot 예시로 Claude의 출력 패턴을 원하는 방향으로 유도할 수 있다
- Chain-of-Thought(CoT) 프롬프팅이 추론 품질을 높이는 원리를 설명할 수 있다
- 두 기법을 조합해 복잡한 태스크에 적용할 수 있다

---

## 1. Few-shot 프롬프팅

Few-shot은 예시를 보여주어 Claude가 원하는 패턴을 학습하게 하는 기법입니다. "형식 설명"보다 "예시 제시"가 훨씬 효과적인 경우가 많습니다.

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

# Zero-shot: 설명만 — 형식이 불안정할 수 있음
zero_shot_system = "고객 피드백을 감정 분석하여 레이블을 붙이세요."

# Few-shot: 예시 포함 — 형식이 일관됨
few_shot_system = """고객 피드백을 분석하여 감정 레이블을 붙이세요.

예시:
입력: "연동이 너무 복잡해요. 문서가 부족합니다."
출력: {"sentiment": "negative", "category": "documentation", "urgency": "medium"}

입력: "실시간 메시지 전송이 정말 빠르네요! 만족합니다."
출력: {"sentiment": "positive", "category": "performance", "urgency": "low"}

입력: "SDK가 갑자기 크래시가 납니다. 즉시 수정 필요합니다."
출력: {"sentiment": "negative", "category": "bug", "urgency": "high"}

위 형식을 정확히 따르세요."""

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=256,
    system=few_shot_system,
    messages=[{
        "role": "user",
        "content": "API 응답 시간이 5초나 걸립니다. 언제 개선되나요?"
    }]
)
# 예상 출력: {"sentiment": "negative", "category": "performance", "urgency": "high"}
```

**Few-shot 예시 선택 기준:**

| 기준 | 설명 |
|------|------|
| 다양성 | 가능한 케이스를 골고루 커버 |
| 경계 케이스 포함 | 애매한 상황을 명확히 처리하는 예시 |
| 개수 | 보통 3-5개면 충분, 늘린다고 선형 향상 없음 |
| 순서 | 마지막 예시의 영향이 가장 큼 |

---

## 2. Chain-of-Thought (CoT) 프롬프팅

CoT는 Claude가 단계별로 추론 과정을 거쳐 결론에 도달하게 유도하는 기법입니다. 복잡한 판단이나 수학 연산에서 정확도가 크게 향상됩니다.

```python
# CoT 없음 — 단답 요청, 오류 가능성 높음
messages_no_cot = [{
    "role": "user",
    "content": "월 사용자 10,000명, 메시지당 평균 500바이트,
    하루 평균 50건 발송 시 월 데이터 전송량은?"
}]

# CoT 유도 — 단계별 풀이 요청
messages_with_cot = [{
    "role": "user",
    "content": """월 사용자 10,000명, 메시지당 평균 500바이트,
    하루 평균 50건 발송 시 월 데이터 전송량은?
    
    단계별로 계산하세요."""
}]
```

**CoT를 유도하는 표현들:**

```
"단계별로 생각해보세요" (Think step by step)
"추론 과정을 먼저 보여주세요"
"결론 전에 근거를 설명하세요"
"중간 계산 과정을 포함하세요"
```

---

## 3. Extended Thinking — Claude의 내부 CoT

Claude Sonnet 4.6 이상에서는 `thinking` 파라미터로 내부 추론 과정을 활성화할 수 있습니다. 모델이 응답 전에 더 많은 "생각"을 합니다.

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=16000,
    thinking={
        "type": "enabled",
        "budget_tokens": 10000  # 추론에 사용할 최대 토큰
    },
    messages=[{
        "role": "user",
        "content": """다음 Sendbird 아키텍처 설계를 검토하고
        잠재적 문제점과 개선안을 제시하세요:
        
        - 채널당 최대 10,000명 동시 접속
        - 메시지 히스토리 무제한 저장
        - 읽음 확인 기능 활성화
        - 단일 리전 배포"""
    }]
)

# thinking 블록과 응답 블록이 분리됨
for block in response.content:
    if block.type == "thinking":
        print("=== 내부 추론 ===")
        print(block.thinking)
    elif block.type == "text":
        print("=== 최종 응답 ===")
        print(block.text)
```

**Thinking 사용 시 주의사항:**
- `max_tokens`는 thinking budget보다 커야 함 (최소 budget_tokens + 1000)
- 토큰 비용이 크게 증가 — 복잡한 문제에만 사용
- streaming과 함께 사용 가능

---

## 4. Few-shot + CoT 조합

두 기법을 함께 쓰면 복잡한 태스크에서 최고의 효과를 냅니다.

```python
system = """고객 지원 티켓의 우선순위를 분류합니다.

예시 1:
티켓: "로그인이 안 됩니다"
추론: 로그인 불가 = 서비스 전체 차단, 모든 사용자 영향 가능
결론: {"priority": "critical", "team": "auth"}

예시 2:
티켓: "다크 모드가 없어요"
추론: UI 기능 요청, 서비스 이용에 지장 없음
결론: {"priority": "low", "team": "frontend"}

예시 3:
티켓: "메시지가 가끔 늦게 도착해요 (5% 정도)"
추론: 간헐적 성능 이슈, 일부 사용자 영향, 핵심 기능
결론: {"priority": "high", "team": "messaging"}

각 티켓에 대해 위처럼 추론 과정을 쓴 뒤 결론을 JSON으로 반환하세요."""

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=512,
    system=system,
    messages=[{
        "role": "user",
        "content": "결제 처리가 실패한다는 리포트가 10건 들어왔습니다"
    }]
)
```

---

## 📝 핵심 요약

1. Few-shot은 형식 설명보다 효과적 — 예시 3-5개로 패턴을 직접 보여준다
2. CoT는 "단계별로"라는 지시만으로도 추론 정확도를 크게 향상시킴
3. Extended Thinking(`thinking` 파라미터)은 Claude의 내부 추론을 심화 — 복잡한 분석에 사용
4. Few-shot + CoT 조합이 단독 사용보다 복잡한 판단 태스크에서 효과적
5. Few-shot 예시의 마지막 항목이 가장 큰 영향을 미치므로 가장 대표적인 케이스를 마지막에 배치

---

## 🔗 참고 자료

- [Few-shot 프롬프팅 가이드](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/multishot-prompting)
- [Extended Thinking 문서](https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking)
- [Chain of Thought 모범 사례](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought)

---

*⬅️ 이전: [Day 06 — 역할 지정 (Role Prompting)](../day-06/)  |  다음: [Day 08 — XML 태그 활용](../day-08/) ➡️*
