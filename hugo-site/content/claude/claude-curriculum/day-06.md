---
title: "Day 06 — 역할 지정 (Role Prompting)"
date: 2026-06-26
weight: 6
---

# Day 06 — 역할 지정 (Role Prompting)

> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- System prompt의 구조와 역할을 이해하고 설계할 수 있다
- Role prompting이 응답 품질에 미치는 영향을 설명할 수 있다
- 프로덕션 수준의 system prompt 템플릿을 작성할 수 있다

---

## 1. System Prompt란?

System prompt는 Claude의 **동작 방식**을 규정하는 최상위 지시문입니다. 매 대화가 시작되기 전에 주입되며, user 메시지보다 높은 우선순위를 갖습니다.

```
[system prompt]  ← 역할, 제약, 맥락 정의
     ↓
[user: "질문"]   ← 실제 요청
     ↓
[assistant: "응답"]
```

System prompt 없이도 Claude는 동작하지만, 프로덕션 앱에서는 **반드시** 정의해야 합니다. 없으면 Claude는 범용 어시스턴트 모드로 동작하여 예측 불가능한 톤과 스타일로 응답합니다.

---

## 2. Role Prompting의 효과

"당신은 X입니다" 패턴은 단순해 보이지만 응답 품질에 실질적인 영향을 미칩니다.

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

# 역할 없음 — 범용 응답
response_generic = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=512,
    messages=[{"role": "user", "content": "코드 리뷰해줘: def add(a,b): return a+b"}]
)

# 역할 지정 — 전문적이고 일관된 응답
response_expert = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=512,
    system="""당신은 10년 경력의 시니어 파이썬 개발자입니다.
코드 리뷰 시 다음 순서로 피드백합니다:
1. 버그 및 오류 (있을 경우)
2. 타입 힌트 및 문서화
3. 성능 및 파이써닉한 스타일
각 항목을 명확히 구분하여 작성하세요.""",
    messages=[{"role": "user", "content": "코드 리뷰해줘: def add(a,b): return a+b"}]
)
```

**역할이 응답에 미치는 영향:**
- 어휘 선택 (전문 용어 vs 일상 언어)
- 답변 깊이 (개요 vs 세부 분석)
- 기본 가정 (초보자 vs 전문가 독자)
- 형식 (산문 vs 구조화된 목록)

---

## 3. 프로덕션 System Prompt 설계 패턴

잘 설계된 system prompt는 다음 5가지 요소를 포함합니다.

```python
SYSTEM_PROMPT = """## 역할 (Role)
당신은 Sendbird의 AI 개발자 지원 어시스턴트입니다.
Sendbird Chat, Calls, AI Agent API에 대한 전문 지식을 갖추고 있습니다.

## 대상 (Audience)
사용자는 Sendbird SDK를 통합하는 개발자입니다.
기본적인 REST API와 SDK 사용법은 알고 있다고 가정합니다.

## 행동 규칙 (Rules)
- 코드 예시는 항상 Python 또는 JavaScript로 제공합니다
- 공식 Sendbird 문서 URL을 명시할 때는 존재하는 것만 인용합니다
- 확실하지 않은 API 동작은 "공식 문서를 확인하세요"로 안내합니다
- 경쟁사 제품과의 비교는 하지 않습니다

## 출력 형식 (Format)
- 코드는 언어 지정 코드 블록으로 감쌉니다
- 단계가 필요한 경우 번호 매긴 목록을 사용합니다
- 답변은 간결하게, 최대 400단어 이내로 유지합니다

## 제약 (Constraints)
- Sendbird 범위 외 질문(예: 다른 회사 제품, 일반 상식)은
  "Sendbird 관련 질문만 도와드릴 수 있습니다"라고 안내합니다
"""
```

**5가지 요소 요약:**

| 요소 | 설명 | 예시 |
|------|------|------|
| Role | 누구인가 | "시니어 파이썬 개발자" |
| Audience | 누구에게 말하는가 | "SDK 통합 개발자" |
| Rules | 어떻게 행동하는가 | "코드 예시 항상 포함" |
| Format | 어떤 형식으로 | "코드 블록 사용" |
| Constraints | 무엇을 하지 않는가 | "범위 외 질문 거절" |

---

## 4. 역할 지정 심화 — 페르소나 vs 전문가

두 가지 접근법이 있습니다.

```python
# 방법 1: 페르소나 방식 — 특정 인물처럼
system_persona = """당신은 "Ari"라는 이름의 Sendbird 기술 지원 담당자입니다.
친근하고 공감적인 톤으로 소통하며, 항상 먼저 문제를 이해하려 합니다."""

# 방법 2: 전문가 방식 — 역량 중심
system_expert = """당신은 분산 메시징 시스템과 실시간 통신 프로토콜(WebSocket, XMPP)
전문가입니다. 기술적 정확성을 최우선으로 하며, 근거를 명확히 제시합니다."""
```

**언제 어떤 방식을?**

- **페르소나**: 고객 대면 챗봇, 온보딩 어시스턴트 → 친밀감, 브랜드 일관성 중요
- **전문가**: 내부 개발 도구, 코드 리뷰, 기술 분석 → 정확성과 깊이가 중요

---

## 📝 핵심 요약

1. System prompt는 Claude의 동작을 규정하는 최상위 지시문 — 프로덕션에서는 항상 정의
2. Role prompting은 어휘, 깊이, 형식, 가정에 실질적인 영향을 미침
3. 프로덕션 system prompt = 역할 + 대상 + 규칙 + 형식 + 제약 5요소
4. 페르소나 방식(친밀감)과 전문가 방식(정확성)을 용도에 맞게 선택
5. System prompt는 길수록 좋은 게 아님 — 핵심만 명확하게, 모순 없이

---

## 🔗 참고 자료

- [System Prompt 설계 가이드](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/system-prompts)
- [Claude의 역할 지정 모범 사례](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)
- [Anthropic 프롬프트 라이브러리](https://docs.anthropic.com/en/resources/prompt-library/library)

---

*⬅️ 이전: [Day 05 — Claude의 한계와 특성](./day-05.md)  |  다음: [Day 07 — Few-shot / Chain-of-Thought](./day-07.md) ➡️*
