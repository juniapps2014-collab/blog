---
title: "Day 18 — 비용 최적화"
date: 2026-07-08
weight: 18
---


> **Phase 3: API 활용** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 모델 선택, 프롬프트 캐싱, Batch API라는 세 가지 축으로 API 비용을 구조적으로 줄이는 방법을 이해한다
- 프롬프트 캐싱의 write/read 배수를 계산해 캐싱이 실제로 이득인 시점을 판단할 수 있다
- Python으로 토큰 사용량을 추적하고, 캐싱과 배치 처리를 결합한 견적을 낼 수 있다

---

## 1. 비용 최적화의 세 가지 축

Claude API 비용은 결국 "어떤 모델을 쓰는가 × 얼마나 많은 토큰을 보내는가 × 얼마나 자주 같은 내용을 반복하는가"로 요약됩니다. 최적화도 이 세 지점을 각각 공략합니다.

| 축 | 전략 | 절감 효과 |
|-----|------|------|
| 모델 선택 | 작업 난이도에 맞는 가장 작은 모델 사용 | 모델 간 최대 5–10배 가격 차이 |
| 반복 콘텐츠 | 프롬프트 캐싱으로 재사용 구간 압축 | 캐시 히트 시 90% 할인 |
| 처리 시급성 | 실시간이 필요 없는 작업은 Batch API로 | 입출력 토큰 모두 50% 할인 |

모델 등급별 가격 차이가 가장 크게 벌어지는 지점입니다. 예를 들어 Claude Haiku 4.5는 입력 $1 / MTok, 출력 $5 / MTok인 반면 Claude Opus 4.8은 입력 $5 / MTok, 출력 $25 / MTok으로 정확히 5배입니다. 분류, 추출, 형식 변환처럼 정형화된 작업은 Haiku로도 충분한 경우가 많으므로, 파이프라인을 설계할 때 "가장 어려운 단계만 Opus, 나머지는 Haiku/Sonnet"으로 계층을 나누는 것이 비용 구조를 크게 바꿉니다.

```python
# 작업 유형별 모델 라우팅 예시
def choose_model(task_type: str) -> str:
    routing = {
        "classification": "claude-haiku-4-5",
        "summarization": "claude-sonnet-5",
        "complex_reasoning": "claude-opus-4-8",
    }
    return routing.get(task_type, "claude-sonnet-5")
```

---

## 2. 프롬프트 캐싱으로 반복 컨텍스트 압축하기

시스템 프롬프트, 긴 참고 문서, 도구 정의처럼 요청마다 반복되는 내용은 `cache_control`로 캐싱할 수 있습니다. 캐시는 두 가지 방식으로 걸 수 있는데, 요청 최상단에 `cache_control`을 한 번 넣는 자동 캐싱이 가장 간단하고, 개별 콘텐츠 블록에 직접 지정하는 명시적 브레이크포인트는 캐싱 구간을 세밀하게 제어할 때 씁니다.

가격 구조는 기본 입력 가격을 기준으로 배수가 붙습니다. 5분 캐시는 쓰기 시 1.25배, 1시간 캐시는 쓰기 시 2배, 그리고 읽기(캐시 히트)는 어느 경우든 0.1배입니다. 즉 5분 캐시는 단 한 번만 재사용해도 손익이 맞고(1.25배 쓰기 + 0.1배 읽기 < 2 × 1배), 1시간 캐시는 두 번 이상 재사용할 때부터 이득이 됩니다.

```python
import anthropic

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-opus-4-8",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "당신은 Sendbird 고객 지원 문서를 기반으로 답하는 어시스턴트입니다...(긴 참고 문서)",
            "cache_control": {"type": "ephemeral"},  # 기본 5분 TTL
        }
    ],
    messages=[{"role": "user", "content": "환불 정책이 어떻게 되나요?"}],
)

usage = response.usage
print(f"cache_read: {usage.cache_read_input_tokens}")
print(f"cache_creation: {usage.cache_creation_input_tokens}")
print(f"input(비캐시): {usage.input_tokens}")
```

멀티턴 대화가 5분보다 길게 이어지거나 응답 간격이 불규칙하다면 `ttl: "1h"`로 1시간 캐시를 쓰는 편이 재작성 비용을 줄여줍니다. 캐싱 최소 토큰 수는 모델마다 다른데, Claude Opus 4.8과 Sonnet 5는 1,024 토큰, Haiku 4.5는 4,096 토큰이 하한선이라 이보다 짧은 프롬프트는 캐싱이 적용되지 않고 조용히 무시됩니다. 캐시 적중 여부는 항상 `usage` 필드로 확인하는 습관을 들이는 것이 좋습니다.

---

## 3. 실습: Batch API와 캐싱을 결합한 비용 견적

실시간 응답이 필요 없는 대량 작업(예: 10만 건의 리뷰 감정 분석)은 Batch API로 보내면 입력·출력 토큰 모두 50% 할인이 적용되고, 여기에 프롬프트 캐싱까지 더할 수 있어 두 할인이 함께 적용됩니다.

```python
import anthropic

client = anthropic.Anthropic()

requests = [
    {
        "custom_id": f"review-{i}",
        "params": {
            "model": "claude-haiku-4-5",
            "max_tokens": 200,
            "system": [{
                "text": "리뷰를 긍정/중립/부정으로 분류하고 한 줄 이유를 설명하세요.",
                "type": "text",
                "cache_control": {"type": "ephemeral"},
            }],
            "messages": [{"role": "user", "content": review_text}],
        },
    }
    for i, review_text in enumerate(review_texts)
]

batch = client.messages.batches.create(requests=requests)
print(batch.id, batch.processing_status)

# 처리 완료 후 결과 조회
for result in client.messages.batches.results(batch.id):
    print(result.custom_id, result.result.message.content[0].text)
```

간단한 견적을 내보면, Haiku 4.5로 10만 건(건당 평균 입력 300토큰 + 출력 50토큰)을 표준 API로 처리하면 입력 3천만 토큰 × $1 + 출력 5백만 토큰 × $5로 약 $55입니다. 같은 작업을 Batch API로 보내면 각각 50% 할인되어 약 $27.5로 줄고, 여기에 시스템 프롬프트가 캐싱되어 매 요청 300토큰 중 250토큰이 캐시 히트로 처리된다면 입력 비용이 한 번 더 줄어듭니다. curl로도 배치 생성이 가능합니다.

```bash
curl https://api.anthropic.com/v1/messages/batches \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "requests": [
      {"custom_id": "req-1", "params": {"model": "claude-haiku-4-5", "max_tokens": 200,
        "messages": [{"role": "user", "content": "이 리뷰를 분류해줘: 배송이 너무 늦었어요"}]}}
    ]
  }'
```

Batch API는 실시간성이 없는 만큼 처리 완료까지 시간이 걸릴 수 있고(최대 24시간 SLA), `max_tokens: 0`을 이용한 캐시 프리워밍이나 스트리밍처럼 지연 시간에 민감한 기능과는 함께 쓸 수 없습니다. 따라서 "지금 당장 답이 필요한가"를 기준으로 실시간 API와 Batch API를 나누는 것이 첫 번째 설계 판단이 되어야 합니다.

---

## 📝 핵심 요약

1. 비용 최적화는 모델 선택, 프롬프트 캐싱, Batch API라는 세 축을 조합하는 문제이며, 각 축은 독립적으로도 적용 가능하고 함께 쓰면 할인이 중첩된다
2. 모델 등급 간 가격 차는 최대 5배 이상이므로, 작업 난이도별로 Haiku/Sonnet/Opus를 라우팅하는 것이 가장 큰 절감 효과를 낸다
3. 프롬프트 캐싱은 5분 캐시 1.25배 쓰기·1시간 캐시 2배 쓰기, 읽기는 항상 0.1배이며, 재사용 시스템 프롬프트나 긴 문서가 있을 때 특히 유리하다
4. Batch API는 입출력 토큰 모두 50% 할인되며 프롬프트 캐싱과 중첩 적용되지만, 즉시 응답이 필요 없는 작업에만 적합하다
5. 모든 최적화는 `usage.cache_read_input_tokens`, `usage.cache_creation_input_tokens`, `usage.input_tokens` 같은 응답 필드를 실제로 추적해야 효과를 검증할 수 있다

---

## 🔗 참고 자료

- [Pricing — Claude Platform Docs](https://platform.claude.com/docs/en/about-claude/pricing)
- [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Batch processing](https://platform.claude.com/docs/en/build-with-claude/batch-processing)
- [Token counting](https://platform.claude.com/docs/en/build-with-claude/token-counting)

---

*⬅️ 이전: [Day 17 — Vision API](../day-17/)  |  다음: [Day 19 — 에이전트 설계 패턴](../day-19/) ➡️*
