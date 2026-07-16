---
title: "Day 24 — 프로덕션 배포 고려사항"
date: 2026-07-16
weight: 24
---


> **Phase 4: 고급/프로덕션** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Claude API의 HTTP 에러 코드를 재시도 가능(transient) / 재시도 불가(non-transient)로 분류하고 각각에 맞는 처리 전략을 설계할 수 있다
- 지수 백오프(exponential backoff)와 `retry-after` 헤더를 존중하는 재시도 로직을 구현하고, SDK 기본 동작을 조정할 수 있다
- 타임아웃·레이턴시·폴백(fallback)을 고려한 프로덕션급 호출 래퍼를 Python으로 작성할 수 있다

---

## 1. 에러 코드부터 이해한다 — 무엇을 재시도할 것인가

프로덕션에서 가장 먼저 결정해야 하는 것은 "어떤 에러를 재시도하고, 어떤 에러는 즉시 실패시킬 것인가"입니다. Claude API는 예측 가능한 HTTP 상태 코드 체계를 따르며, 이를 두 부류로 나누는 것이 핵심입니다.

| 코드 | 타입 | 성격 | 대응 |
|------|------|------|------|
| 400 | `invalid_request_error` | 요청 자체가 잘못됨 | 재시도 금지 — 요청을 고쳐야 함 |
| 401 | `authentication_error` | API 키 문제 | 재시도 금지 — 키 교체 |
| 403 | `permission_error` | 권한 없음 | 재시도 금지 |
| 413 | `request_too_large` | 요청이 32MB 초과 | 재시도 금지 — 입력 축소 |
| 429 | `rate_limit_error` | 레이트 리밋 초과 | **재시도** — `retry-after` 존중 |
| 500 | `api_error` | 서버 내부 오류 | **재시도** — 백오프 |
| 504 | `timeout_error` | 처리 중 타임아웃 | **재시도** 또는 streaming 전환 |
| 529 | `overloaded_error` | API 전체가 과부하 | **재시도** — 내 사용량과 무관 |

여기서 4xx(429 제외)는 **요청·자격증명·계정 상태를 바꾸기 전에는 재시도해도 똑같이 실패**합니다. 무한 재시도는 오히려 레이트 리밋만 악화시킵니다. 반면 429·500·504·529는 일시적(transient)이므로 백오프 후 재시도가 정답입니다.

특히 **429와 529를 구분**하는 것이 중요합니다. 429는 내 조직이 tier 한도(RPM·ITPM·OTPM 중 하나)를 초과한 것이고 응답에 `retry-after`(초 단위) 헤더가 포함됩니다. 529는 Anthropic 인프라 전체가 과부하 상태라는 뜻으로 내 사용량과 무관합니다. 모든 에러 응답에는 `request_id` 필드가 포함되므로, 로깅 시 반드시 함께 남겨 두면 지원 문의나 디버깅이 훨씬 수월해집니다.

---

## 2. 재시도 — SDK 기본값과 지수 백오프

좋은 소식은 공식 SDK가 일시적 실패(연결 오류, 레이트 리밋, 5xx)를 **기본 2회까지 지수 백오프로 자동 재시도**하며 `retry-after` 헤더를 존중한다는 점입니다. 따라서 대부분의 경우 직접 재시도 루프를 짤 필요가 없고, 클라이언트 생성 시 재시도 횟수만 조정하면 됩니다.

```python
from anthropic import Anthropic

# 재시도 횟수를 5회로 상향, 타임아웃 30초로 설정
client = Anthropic(max_retries=5, timeout=30.0)

# 요청 단위로 재정의도 가능
message = client.with_options(max_retries=2).messages.create(
    model="claude-sonnet-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "안녕 Claude"}],
)
```

직접 백오프 로직을 구현해야 하는 경우(예: 다른 언어, 커스텀 게이트웨이)라면 다음 원칙을 지킵니다. 첫째, 대기 시간을 지수적으로 늘립니다(1s → 2s → 4s → 8s …). 둘째, **지터(jitter, 무작위 요소)를 추가**해 여러 클라이언트가 동시에 재시도하며 몰리는 thundering herd를 방지합니다. 셋째, `retry-after` 헤더가 있으면 계산된 백오프보다 우선합니다.

```python
import time, random, httpx

def backoff_delay(attempt: int, retry_after: float | None) -> float:
    if retry_after is not None:      # 서버가 알려준 값이 최우선
        return retry_after
    base = min(2 ** attempt, 60)     # 상한 60초
    return base + random.uniform(0, base * 0.25)  # 지터 25%
```

---

## 3. 실습 — 타임아웃·재시도·폴백을 갖춘 프로덕션 래퍼

프로덕션에서는 세 가지를 함께 설계해야 합니다. (1) **타임아웃**: 응답이 오래 걸리는 요청은 streaming Messages API나 Message Batches API를 쓰고, 큰 `max_tokens`를 비스트리밍으로 보내지 않습니다(네트워크가 유휴 연결을 끊어 요청이 실패할 수 있음). SDK는 비스트리밍 요청이 10분을 넘길 것으로 예상되면 미리 검증하고 TCP keep-alive도 설정합니다. (2) **재시도**: 위의 분류에 따라 transient만 재시도. (3) **폴백**: 재시도가 모두 실패하면 상위 모델→하위 모델 전환, 캐시된 응답, 혹은 사람 개입(human-in-the-loop) 경로로 우아하게 degrade합니다.

```python
import anthropic

primary = anthropic.Anthropic(max_retries=4, timeout=30.0)

def robust_completion(prompt: str) -> str:
    """primary 모델 실패 시 더 가벼운 모델로 폴백"""
    models = ["claude-opus-4-8", "claude-haiku-4-5"]  # 폴백 체인
    last_err = None
    for model in models:
        try:
            msg = primary.messages.create(
                model=model,
                max_tokens=1024,
                messages=[{"role": "user", "content": prompt}],
            )
            return msg.content[0].text
        except anthropic.RateLimitError as e:      # 429
            last_err = e; continue                  # 다음 모델로
        except anthropic.APIStatusError as e:       # 5xx/529 등
            if e.status_code in (500, 529, 504):
                last_err = e; continue
            raise                                   # 4xx는 즉시 실패
    # 모든 경로 실패 → 폴백 응답 반환
    return "죄송합니다. 일시적으로 응답을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요."
```

핵심은 **타입이 있는 예외를 잡되, 문자열 매칭이 아니라 SDK의 예외 클래스로 분기**하는 것입니다(`RateLimitError`, `APIStatusError` 등). 가장 구체적인 클래스를 먼저 처리하고, 4xx 계열은 재시도 없이 곧바로 실패시켜 리소스 낭비를 막습니다. 또한 모든 실패 경로에서 `request_id`와 모델명, 지연 시간을 구조화된 로그로 남기면 프로덕션 관측성(observability)이 크게 향상됩니다.

---

## 📝 핵심 요약

1. 에러는 재시도 가능(429·500·504·529)과 재시도 불가(400·401·403·413)로 나뉘며, 4xx(429 제외)는 요청을 고치기 전에는 재시도해도 소용없다
2. 429(내 한도 초과, `retry-after` 포함)와 529(Anthropic 전체 과부하)는 원인이 다르므로 로깅·알림에서 구분한다
3. 공식 SDK는 기본 2회 지수 백오프 자동 재시도 + `retry-after` 존중 — `max_retries`·`timeout`으로 조정하고, 직접 구현 시 지터를 반드시 추가한다
4. 큰 `max_tokens`나 10분 초과 요청은 streaming 또는 Batches API로 처리해 유휴 연결 타임아웃을 피한다
5. 재시도가 모두 실패할 때를 대비해 모델 폴백 체인·캐시·사람 개입 경로를 두고, `request_id`를 포함한 구조화 로깅으로 관측성을 확보한다

---

## 🔗 참고 자료

- [Claude API errors](https://platform.claude.com/docs/en/api/errors)
- [Rate limits](https://platform.claude.com/docs/en/api/rate-limits)
- [Streaming Messages](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Message Batches API](https://platform.claude.com/docs/en/build-with-claude/batch-processing)
- [Reducing latency](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-latency)

---

*⬅️ 이전: [Day 23 — 평가(Evals) 프레임워크](../day-23/)  |  다음: [Day 25 — 실전 케이스 스터디](../day-25/) ➡️*
