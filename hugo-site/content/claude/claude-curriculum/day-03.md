---
title: "Day 03 — 컨텍스트와 대화 흐름"
date: 2026-06-23
weight: 3
---

# Day 03 — 컨텍스트와 대화 흐름

> **Phase 1: 기초** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 컨텍스트 윈도우의 개념과 작동 방식을 설명할 수 있다
- 멀티턴 대화에서 `messages` 배열을 올바르게 구성할 수 있다
- 대화 흐름 설계 시 컨텍스트 관리 전략을 적용할 수 있다

---

## 1. 컨텍스트 윈도우란?

Claude는 대화를 처음부터 끝까지 **전부 읽고** 응답합니다. 이전 대화를 "기억"하는 것이 아니라, API 호출 시마다 전체 대화 이력을 입력으로 받습니다.

```
[system prompt] + [user: 메시지1] + [assistant: 응답1] + [user: 메시지2] + ...
                ↑ 이 전체가 매 호출마다 토큰으로 소비됨
```

**핵심 제약:**

| 항목 | 값 |
|------|-----|
| 최대 컨텍스트 | 200,000 토큰 |
| 한국어 약 1토큰 | ~0.5–1 글자 |
| 영어 약 1토큰 | ~4 글자 |
| 대화가 길어질수록 | 비용 ↑, 속도 ↓ |

> 💡 **실무 팁**: 컨텍스트는 누적됩니다. 10턴 대화라면 10번의 `user + assistant` 쌍이 모두 매 호출에 포함됩니다. 장기 대화는 비용이 선형이 아니라 2차적으로 증가합니다.

---

## 2. Messages 배열 구조

Anthropic API의 `messages` 파라미터는 역할이 교대로 나오는 배열입니다.

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

# 멀티턴 대화 예시
messages = [
    {"role": "user", "content": "파이썬에서 리스트를 역순으로 만드는 방법은?"},
    {"role": "assistant", "content": "list.reverse() 또는 슬라이싱 [::-1]을 사용할 수 있습니다."},
    {"role": "user", "content": "둘의 차이점은 뭐야?"},  # 이전 맥락을 참조
]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="당신은 파이썬 전문가입니다. 간결하게 답변하세요.",
    messages=messages
)

print(response.content[0].text)
```

**규칙:**
- 첫 번째 메시지는 반드시 `user` 역할
- `user`와 `assistant`가 반드시 교대
- `system` 프롬프트는 `messages` 배열 밖에 별도 파라미터로

---

## 3. 컨텍스트 관리 전략

대화가 길어지면 세 가지 전략으로 컨텍스트를 관리합니다.

### 전략 1: 슬라이딩 윈도우

최근 N턴만 유지합니다.

```python
MAX_TURNS = 10  # 최근 10턴만 유지

def trim_messages(messages, max_turns=MAX_TURNS):
    # user+assistant 쌍 단위로 유지
    pairs = []
    for i in range(0, len(messages) - 1, 2):
        if i + 1 < len(messages):
            pairs.append((messages[i], messages[i + 1]))
    
    # 최근 max_turns 쌍만 유지
    recent_pairs = pairs[-max_turns:]
    return [msg for pair in recent_pairs for msg in pair]
```

### 전략 2: 요약 삽입

오래된 대화를 Claude에게 요약시켜 압축합니다.

```python
def summarize_old_messages(client, old_messages):
    summary_prompt = f"""
    다음 대화를 핵심 정보만 남겨 3문장 이내로 요약하세요:
    
    {old_messages}
    """
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",  # 요약엔 Haiku면 충분
        max_tokens=200,
        messages=[{"role": "user", "content": summary_prompt}]
    )
    return response.content[0].text

# 대화가 20턴을 넘으면 앞부분을 요약으로 대체
def manage_context(client, messages, threshold=20):
    if len(messages) > threshold:
        old = messages[:-10]  # 최근 10개 제외한 나머지
        recent = messages[-10:]
        summary = summarize_old_messages(client, old)
        
        # 요약 메시지 삽입
        summary_message = {
            "role": "user",
            "content": f"[이전 대화 요약: {summary}]"
        }
        # 요약 다음에 assistant 응답 하나 추가 필요
        ack_message = {
            "role": "assistant",
            "content": "이전 대화 내용을 파악했습니다. 계속 진행하겠습니다."
        }
        return [summary_message, ack_message] + recent
    return messages
```

### 전략 3: 상태 외부 저장

대화에서 추출한 중요 정보를 별도 저장소에 보관하고 system prompt에 주입합니다.

```python
# 사용자 상태를 별도 딕셔너리로 관리
user_state = {
    "name": "Yongjun",
    "programming_language": "Python",
    "current_task": "Sendbird AI Agent 연동",
    "completed_steps": ["API 키 발급", "SDK 설치"]
}

def build_system_prompt(state):
    return f"""당신은 개발자 어시스턴트입니다.

현재 사용자 컨텍스트:
- 이름: {state['name']}
- 주 언어: {state['programming_language']}
- 현재 작업: {state['current_task']}
- 완료된 단계: {', '.join(state['completed_steps'])}

이 정보를 바탕으로 맞춤 답변을 제공하세요."""
```

---

## 📝 핵심 요약

1. Claude는 매 API 호출 시 전체 대화 이력을 입력으로 받는다 — 진짜 "기억"이 아님
2. `messages` 배열은 `user` → `assistant` → `user` 순서로 교대 구성
3. 컨텍스트가 길어지면 비용과 지연 모두 증가 — 적극적인 관리 필요
4. 슬라이딩 윈도우, 요약 압축, 외부 상태 저장 세 가지 전략을 상황에 맞게 선택
5. `system` 파라미터에 사용자별 상태를 주입하면 무상태 API를 유상태처럼 활용 가능

---

## 🔗 참고 자료

- [Messages API 공식 문서](https://docs.anthropic.com/en/api/messages)
- [컨텍스트 윈도우 가이드](https://docs.anthropic.com/en/docs/build-with-claude/context-windows)
- [토큰 계산 방법](https://docs.anthropic.com/en/docs/resources/token-counting)

---

*⬅️ 이전: [Day 02 — 기본 프롬프트 작성법](./day-02.md)  |  다음: [Day 04 — 출력 형식 제어](./day-04.md) ➡️*
