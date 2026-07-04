---
title: "Day 14 — Messages API 파라미터 심화"
date: 2026-07-04
weight: 14
---


> **Phase 3: API 활용** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- `temperature`, `top_p`, `top_k`가 각각 어떤 방식으로 출력의 무작위성을 조절하는지 설명할 수 있다
- `stop_sequences`와 `metadata` 파라미터를 실제 요청에 적용할 수 있다
- 최신 Claude 모델(Opus 4.7 이상)에서 샘플링 파라미터가 어떻게 달라졌는지 이해하고 대안을 적용할 수 있다

---

## 1. temperature — 무작위성의 기본 다이얼

`temperature`는 다음 토큰을 고를 때 확률 분포를 얼마나 "평평하게" 만들지 결정합니다. 값이 낮을수록 가장 확률이 높은 토큰을 거의 항상 선택하고, 값이 높을수록 낮은 확률의 토큰도 선택될 여지가 커집니다.

| 값 | 특성 | 적합한 용도 |
|-----|------|------------|
| 0에 가까움 | 결정적(deterministic), 반복 실행 시 결과가 거의 동일 | 코드 생성, 데이터 추출, 분류 |
| 기본값(1) | 균형 잡힌 다양성 | 일반적인 대화, 요약 |
| 1에 가까움 | 창의적이고 예측 불가능 | 브레인스토밍, 카피라이팅, 소설 |

```python
import anthropic

client = anthropic.Anthropic()

# 데이터 추출 작업 — 낮은 temperature로 일관성 확보
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=200,
    temperature=0,
    messages=[{"role": "user", "content": "다음 문장에서 날짜만 추출해줘: '회의는 3월 15일이고 마감은 4월 2일이다.'"}]
)
print(response.content[0].text)
```

중요한 점은 `temperature=0`이어도 완전히 100% 동일한 출력이 보장되지는 않는다는 것입니다. GPU 연산의 병렬 처리 특성상 미세한 부동소수점 차이가 결과를 바꿀 수 있습니다. "거의 결정적"이라고 이해하는 것이 정확합니다.

---

## 2. top_p / top_k — 후보군을 좁히는 또 다른 방법

`temperature`가 분포 자체의 모양을 바꾼다면, `top_p`와 `top_k`는 애초에 고려할 후보 토큰의 범위를 제한합니다.

- **top_k**: 확률 순으로 상위 K개의 토큰만 후보로 남깁니다. 예를 들어 `top_k=40`이면 41번째로 확률이 높은 토큰은 절대 선택되지 않습니다.
- **top_p (nucleus sampling)**: 확률을 높은 순서대로 누적하다가 지정한 임계값(예: 0.9)에 도달하면 그 지점에서 후보군을 자릅니다. 문맥에 따라 후보 개수가 유동적으로 변한다는 점이 `top_k`와 다릅니다.

```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 300,
    "temperature": 0.7,
    "top_p": 0.9,
    "messages": [
      {"role": "user", "content": "여름 신제품 출시 이벤트 문구를 3가지 톤으로 제안해줘"}
    ]
  }'
```

**실무 조언**: `temperature`와 `top_p`를 동시에 크게 바꾸는 것은 권장되지 않습니다. 공식 문서도 둘 중 하나만 조정하고 나머지는 기본값을 유지하라고 안내합니다. 두 파라미터가 서로 다른 방식으로 분포를 조작하기 때문에, 동시에 극단적으로 설정하면 결과를 예측하기 어려워집니다.

**중요한 최신 변경사항**: Claude Opus 4.7 이상 모델(Opus 4.8 포함)에서는 `temperature`, `top_p`, `top_k` 세 파라미터가 아예 지원되지 않습니다. 요청에 기본값이 아닌 값을 넣으면 400 에러가 반환됩니다. 이런 모델에서 출력 스타일을 조절하려면 파라미터 대신 프롬프트로 직접 지시해야 합니다. 예를 들어 "간결하고 사실 위주로 답하라" 또는 "여러 창의적인 대안을 제시하라"처럼 시스템 프롬프트나 사용자 메시지에 명시하는 방식으로 대체합니다. Sonnet, Haiku 계열은 여전히 세 파라미터를 지원하므로, 모델별로 지원 여부를 확인하고 코드를 분기 처리하는 것이 안전합니다.

---

## 3. stop_sequences와 metadata — 실행을 제어하는 보조 파라미터

`stop_sequences`는 지정한 문자열이 생성되는 순간 응답을 즉시 중단시킵니다. 구조화된 출력을 만들 때 특정 구분자 이후의 불필요한 텍스트를 잘라내는 데 유용합니다.

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=500,
    stop_sequences=["</answer>"],
    messages=[
        {"role": "user", "content": "정답만 <answer></answer> 태그 안에 담아 답해줘. 1+1은?"}
    ]
)

print(response.stop_reason)      # "stop_sequence"
print(response.stop_sequence)    # "</answer>"
print(response.content[0].text)  # 태그가 열리는 지점까지의 텍스트
```

`stop_reason`이 `"stop_sequence"`로 나오면 어떤 문자열에서 멈췄는지 `stop_sequence` 필드로 확인할 수 있습니다. 참고로 매칭된 시퀀스 자체는 응답 텍스트에 포함되지 않으므로, 후처리 시 태그를 다시 붙여야 하는 경우도 있습니다.

`metadata`는 요청 자체에 부가 정보를 실어 보내는 선택적 객체입니다. 대표적으로 `user_id`를 익명화된 식별자로 넣어두면, Anthropic 쪽에서 남용 탐지나 문제 상황 조사 시 요청을 추적하는 데 활용됩니다. 실제 사용자 이름이나 이메일 같은 개인정보를 직접 넣는 용도가 아니라, 내부 시스템에서 생성한 해시 값 등을 넣는 것이 권장됩니다.

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=300,
    metadata={"user_id": "user_8f2a91c3"},
    messages=[{"role": "user", "content": "환불 정책을 요약해줘"}]
)
```

---

## 📝 핵심 요약

1. `temperature`는 확률 분포의 모양을, `top_p`/`top_k`는 후보 토큰의 범위를 제한하며 서로 다른 축에서 무작위성을 조절한다
2. 결정적 결과가 필요한 작업(코드, 추출, 분류)은 낮은 `temperature`, 창의적 작업은 높은 `temperature`를 사용한다
3. `temperature`와 `top_p`는 동시에 극단적으로 조정하지 말고 하나만 바꾸는 것이 안전하다
4. Claude Opus 4.7 이상 모델은 세 샘플링 파라미터를 지원하지 않으므로 프롬프트 지시로 대체해야 한다
5. `stop_sequences`로 출력 종료 지점을 제어하고, `metadata.user_id`로 요청 추적성을 확보할 수 있다

---

## 🔗 참고 자료

- [Messages API 사용 가이드](https://platform.claude.com/docs/en/build-with-claude/working-with-messages)
- [Messages API 레퍼런스](https://platform.claude.com/docs/en/api/messages/create)
- [모델 마이그레이션 가이드](https://platform.claude.com/docs/en/about-claude/models/migration-guide)

---

*⬅️ 이전: [Day 13](../day-13/)  |  다음: [Day 15](../day-15/) ➡️*
