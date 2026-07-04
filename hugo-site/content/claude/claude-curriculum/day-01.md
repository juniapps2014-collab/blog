---
title: "Day 01 — Claude란 무엇인가?"
date: 2026-06-21
weight: 1
---

# Day 01 — Claude란 무엇인가?

> **Phase 1: 기초** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Claude의 설계 철학과 다른 LLM과의 차별점을 설명할 수 있다
- Claude 모델 계열 (Haiku / Sonnet / Opus)의 특징과 사용 목적을 구분할 수 있다
- Constitutional AI가 무엇인지 개념적으로 이해한다

---

## 1. Claude는 어떤 모델인가?

Claude는 Anthropic이 만든 대형 언어 모델(LLM)입니다. GPT 계열(OpenAI)과 Gemini(Google)와 함께 현재 상용 LLM의 3대 축 중 하나입니다.

**핵심 특징:**

- **긴 컨텍스트 윈도우** — 최대 200K 토큰 (약 15만 단어) 처리 가능
- **강한 지시 따르기 (instruction following)** — 복잡하고 상세한 시스템 프롬프트를 잘 따름
- **낮은 hallucination율** — 모르는 것을 모른다고 잘 말함 (완벽하진 않음)
- **코드 품질** — 코드 생성 및 디버깅 벤치마크에서 상위권

---

## 2. 모델 계열

| 모델 | 특징 | 적합한 용도 |
|------|------|------------|
| **Claude Haiku** | 가장 빠르고 저렴 | 실시간 응답, 간단한 분류/추출 |
| **Claude Sonnet** | 속도와 성능의 균형 | 대부분의 프로덕션 용도 |
| **Claude Opus** | 최고 성능 | 복잡한 추론, 중요한 의사결정 |

> 💡 **실무 팁**: 대부분의 경우 Sonnet으로 시작하세요. 속도가 부족하면 Haiku로, 품질이 부족하면 Opus로 전환합니다.

현재 최신 버전 (2026년 기준):
- `claude-haiku-4-5-20251001`
- `claude-sonnet-4-6`
- `claude-opus-4-8`

---

## 3. Constitutional AI (CAI)

Anthropic은 Claude를 훈련할 때 **Constitutional AI**라는 방법론을 사용합니다.

기존 RLHF(인간 피드백 강화학습)와의 차이:

```
RLHF:  모델 출력 → 인간이 좋다/나쁘다 라벨링 → 재훈련
CAI:   모델 출력 → 원칙(헌법) 기반 자기 비평 → 수정 → 재훈련
```

**핵심 원칙 예시:**
- 도움이 되어야 한다 (Helpful)
- 해롭지 않아야 한다 (Harmless)
- 정직해야 한다 (Honest)

개발자 관점에서 중요한 함의: Claude는 **거절을 학습**했습니다. 특정 요청에 거절하는 것이 버그가 아니라 설계입니다.

---

## 4. Claude vs GPT-4 vs Gemini — 실용적 비교

| 항목 | Claude | GPT-4o | Gemini |
|------|--------|--------|--------|
| 컨텍스트 길이 | ✅ 200K | 128K | 1M |
| 코드 생성 | ✅ 강함 | ✅ 강함 | 보통 |
| 지시 따르기 | ✅ 매우 강함 | 강함 | 보통 |
| 멀티모달 | 이미지 | 이미지+오디오 | 이미지+오디오+비디오 |
| API 가격 | 중간 | 중간 | 저렴 |

---

## 5. API 접근 방법

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Claude에 대해 한 문장으로 설명해줘"}
    ]
)

print(message.content[0].text)
```

> 설치: `pip install anthropic`
> API 키 발급: https://console.anthropic.com

---

## 📝 핵심 요약

1. Claude = Anthropic의 LLM, Constitutional AI로 훈련
2. Haiku(빠름/저렴) → Sonnet(균형) → Opus(고성능) 3단계 계열
3. 긴 컨텍스트 + 강한 지시 따르기가 주요 강점
4. 거절 동작은 설계된 기능 — 프롬프트로 완화 가능하나 우회 불가

---

## 🔗 참고 자료

- [Anthropic 공식 문서](https://docs.anthropic.com)
- [Claude 모델 비교](https://docs.anthropic.com/en/docs/about-claude/models)
- [Constitutional AI 논문](https://arxiv.org/abs/2212.08073)

---

*⬅️ 이전: —  |  다음: [Day 02 — 기본 프롬프트 작성법](./day-02.md) ➡️*
