---
title: "Day 08 — XML 태그 활용"
date: 2026-06-28
weight: 8
---


> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- XML 태그가 프롬프트 구조화에 왜 효과적인지 설명할 수 있다
- `<instructions>`, `<example>`, `<context>`, `<output>` 등 주요 태그 패턴을 실전에서 쓸 수 있다
- 복잡한 멀티파트 프롬프트를 XML 태그로 명확하게 구분하는 방법을 익힌다

---

## 1. 왜 XML 태그인가?

Claude는 자연어를 처리하지만, **구조화된 입력에 더 잘 반응**합니다. 특히 긴 프롬프트에서 "어디까지가 배경 설명이고, 어디서부터가 실제 지시인가"를 명확히 하지 않으면 모델이 혼동할 수 있습니다.

XML 태그를 사용하면 세 가지 이점이 생깁니다.

**1) 의미 경계 명확화** — 모델이 각 섹션의 역할을 파악하기 쉬워집니다.  
**2) 파싱 안정성** — 출력에 XML 태그를 요청하면 후처리 코드가 간단해집니다.  
**3) 프롬프트 유지보수** — 섹션별로 분리되어 있어 수정이 용이합니다.

Anthropic 공식 문서도 XML 태그를 "Claude가 프롬프트를 파싱하는 데 도움을 주는 가장 효과적인 방법 중 하나"로 권장합니다.

---

## 2. 핵심 태그 패턴

자주 쓰이는 태그 이름은 정해진 규격이 없습니다. 직관적인 이름이면 무엇이든 쓸 수 있습니다. 다만 실무에서 자주 쓰이는 컨벤션은 아래와 같습니다.

| 태그 | 용도 |
|------|------|
| `<instructions>` | 모델에게 무엇을 해야 하는지 지시 |
| `<context>` | 배경 정보, 도메인 지식 제공 |
| `<example>` | Few-shot 예시 삽입 |
| `<document>` | 분석/처리할 긴 문서 전달 |
| `<output_format>` | 응답 형식 명시 |
| `<thinking>` | 추론 과정을 분리할 때 (extended thinking과는 다름) |

### 기본 구조 예시

```xml
<context>
당신은 Sendbird의 고객 지원 전문가입니다.
Sendbird는 채팅, 음성, 영상 통화 API를 제공하는 B2B SaaS 회사입니다.
</context>

<instructions>
아래 고객 문의를 분석하고, 해결 방법을 단계별로 설명하세요.
기술적인 내용은 코드 예시를 포함하세요.
</instructions>

<customer_inquiry>
웹훅 이벤트가 간헐적으로 누락됩니다. 재시도 로직을 어떻게 구성해야 하나요?
</customer_inquiry>
```

---

## 3. 실전 패턴: 구조화된 출력 요청

XML 태그는 **출력 형식 제어**에도 강력합니다. 모델에게 특정 태그 안에 응답하도록 요청하면 파싱이 쉬워집니다.

```python
import anthropic
import re

client = anthropic.Anthropic()

prompt = """
다음 코드를 리뷰하고 결과를 지정된 형식으로 출력하세요.

<code>
def get_user(user_id):
    result = db.query(f"SELECT * FROM users WHERE id = {user_id}")
    return result[0]
</code>

<output_format>
<issues>발견된 문제점 목록</issues>
<severity>critical / high / medium / low 중 하나</severity>
<fixed_code>수정된 코드</fixed_code>
<explanation>수정 이유 설명</explanation>
</output_format>
"""

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}]
)

response = message.content[0].text

# 태그별로 파싱
def extract_tag(text, tag):
    pattern = rf"<{tag}>(.*?)</{tag}>"
    match = re.search(pattern, text, re.DOTALL)
    return match.group(1).strip() if match else None

issues = extract_tag(response, "issues")
severity = extract_tag(response, "severity")
fixed_code = extract_tag(response, "fixed_code")

print(f"심각도: {severity}")
print(f"문제점: {issues}")
```

---

## 4. Few-shot 예시를 태그로 분리하기

Day 07에서 다룬 few-shot 프롬프팅을 XML 태그와 결합하면 예시와 실제 입력의 경계가 명확해집니다.

```python
prompt = """
고객 문의를 '기술', '결제', '일반' 세 카테고리 중 하나로 분류하세요.

<examples>
  <example>
    <input>웹훅 이벤트가 수신되지 않습니다</input>
    <output>기술</output>
  </example>
  <example>
    <input>구독 요금이 이중으로 청구되었습니다</input>
    <output>결제</output>
  </example>
  <example>
    <input>영업 담당자와 미팅을 잡고 싶습니다</input>
    <output>일반</output>
  </example>
</examples>

<input>메시지 전송 API가 500 에러를 반환합니다</input>

카테고리만 출력하세요.
"""
```

모델이 `<examples>` 블록을 예시로, `<input>` 블록을 실제 처리 대상으로 명확히 인식합니다.

---

## 5. 시스템 프롬프트와 조합

긴 시스템 프롬프트에서 역할, 규칙, 제약을 태그로 분리하면 관리가 편해집니다.

```python
system_prompt = """
<role>
당신은 Sendbird API 전문 개발자 어시스턴트입니다.
Python과 JavaScript 예시를 선호합니다.
</role>

<rules>
- 공식 문서 링크를 항상 포함하세요
- 코드 예시는 실행 가능한 형태로 작성하세요
- 불확실한 내용은 "확인이 필요합니다"라고 명시하세요
</rules>

<constraints>
- Sendbird 외 경쟁사 제품을 직접 비교하지 마세요
- 내부 가격 정책에 대해 답변하지 마세요
</constraints>
"""

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=system_prompt,
    messages=[{"role": "user", "content": "채널 멤버를 일괄 초대하는 방법을 알려주세요"}]
)
```

---

## 📝 핵심 요약

1. XML 태그는 프롬프트의 의미 경계를 명확히 해 Claude의 이해도를 높인다
2. 태그 이름은 자유롭게 지정 가능 — `<context>`, `<instructions>`, `<example>`, `<document>` 등이 관례적으로 쓰임
3. 출력에도 XML 태그를 요청하면 `re.search()`로 간단하게 파싱할 수 있다
4. Few-shot 예시를 `<examples><example>...</example></examples>` 구조로 감싸면 입력과 구분이 명확해진다
5. 시스템 프롬프트가 길어질수록 태그 기반 섹션 분리의 효과가 커진다

---

## 🔗 참고 자료

- [Anthropic 프롬프트 엔지니어링: XML 태그 활용](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/use-xml-tags)
- [Anthropic 프롬프트 엔지니어링 개요](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)

---

*⬅️ 이전: [Day 07 — Few-shot / Chain-of-Thought](../day-07/)  |  다음: [Day 09 — 긴 문서 처리](../day-09/) ➡️*
