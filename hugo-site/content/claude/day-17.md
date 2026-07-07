---
title: "Day 17 — Vision API"
date: 2026-07-07
weight: 17
---


> **Phase 3: API 활용** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- base64, URL, Files API 세 가지 이미지 입력 방식의 차이를 이해하고 상황에 맞게 선택할 수 있다
- 이미지 해상도가 visual token 수와 비용으로 어떻게 환산되는지 계산할 수 있다
- 여러 이미지를 비교·분석하는 멀티모달 요청을 Python으로 구현할 수 있다

---

## 1. 이미지를 Claude에 전달하는 세 가지 방법

Claude는 메시지의 `content` 배열에 `image` 타입 블록을 넣는 방식으로 이미지를 입력받습니다. 이 블록의 `source`는 세 가지 타입 중 하나를 선택합니다.

| 방식 | 동작 | 적합한 상황 |
|-----|------|------------|
| `base64` | 이미지 바이트를 base64로 인코딩해 요청 본문에 직접 포함 | 일회성 이미지, 로컬 파일 |
| `url` | 온라인에 호스팅된 이미지의 URL을 참조 | 이미 웹에 있는 이미지, 인코딩 생략 |
| `file_id` (Files API) | 한 번 업로드하고 이후 요청에서 ID로 재참조 | 대화가 여러 턴 이어지거나 같은 이미지를 반복 사용할 때 |

멀티턴 대화에서는 매 요청마다 전체 대화 히스토리를 다시 전송하기 때문에, base64 방식을 쓰면 이미지 바이트가 턴마다 반복 전송되어 요청 크기와 지연 시간이 계속 늘어납니다. Files API로 한 번만 업로드하고 `file_id`를 참조하면 대화가 길어져도 요청 페이로드가 커지지 않습니다. 참고로 Amazon Bedrock과 Google Cloud를 통해 Claude를 사용하는 경우 현재 base64 방식만 지원됩니다.

```python
import anthropic

client = anthropic.Anthropic()

# 방법 1: base64
with open("chart.png", "rb") as f:
    import base64
    image_data = base64.standard_b64encode(f.read()).decode("utf-8")

message = client.messages.create(
    model="claude-opus-4-8",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": [
            {
                "type": "image",
                "source": {"type": "base64", "media_type": "image/png", "data": image_data},
            },
            {"type": "text", "text": "이 차트에서 가장 눈에 띄는 추세를 설명해줘."},
        ],
    }],
)
print(message.content[0].text)
```

```python
# 방법 2: URL 참조 — 인코딩 없이 바로 전달
message = client.messages.create(
    model="claude-opus-4-8",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "url", "url": "https://example.com/chart.png"}},
            {"type": "text", "text": "이 차트에서 가장 눈에 띄는 추세를 설명해줘."},
        ],
    }],
)
```

```python
# 방법 3: Files API — 반복 사용할 이미지에 유리
with open("chart.png", "rb") as f:
    uploaded = client.beta.files.upload(file=("chart.png", f, "image/png"))

message = client.beta.messages.create(
    model="claude-opus-4-8",
    max_tokens=1024,
    betas=["files-api-2025-04-14"],
    messages=[{
        "role": "user",
        "content": [
            {"type": "image", "source": {"type": "file", "file_id": uploaded.id}},
            {"type": "text", "text": "이 차트에서 가장 눈에 띄는 추세를 설명해줘."},
        ],
    }],
)
```

한 가지 배치 원칙도 기억할 필요가 있습니다. 긴 문서를 프롬프트 앞쪽에 두는 것이 결과를 개선하는 것처럼, 이미지도 텍스트보다 앞에 배치하는 편이 성능이 좋습니다. 텍스트 뒤나 텍스트 사이에 넣어도 동작은 하지만, 가능하다면 "이미지 → 텍스트" 순서를 우선하세요.

---

## 2. 해상도, 토큰, 비용의 관계

Claude는 이미지를 픽셀 단위가 아니라 28×28 픽셀짜리 "패치(patch)" 단위로 봅니다. 이 패치 하나가 visual token 하나에 대응하므로, 이미지 하나의 토큰 비용은 대략 다음 식으로 계산됩니다.

```
visual tokens ≈ ⌈width / 28⌉ × ⌈height / 28⌉
```

모델마다 처리 가능한 최대 해상도(긴 변 기준)와 최대 visual token 수가 다르며, 이를 넘는 이미지는 요청 전에 자동으로 다운스케일됩니다.

| 해상도 등급 | 대상 모델 | 최대 긴 변 | 최대 visual token |
|-----|------|------|------|
| 고해상도 | Claude Sonnet 5, Opus 4.8, Opus 4.7 등 최신 모델 | 2576px | 4784 |
| 표준 | 그 외 모델 | 1568px | 1568 |

같은 1000×1000 이미지는 두 등급에서 동일하게 약 1296 토큰이 들지만, 3840×2160 같은 4K 이미지는 표준 등급에서는 다운스케일되어 1560 토큰에 그치는 반면 고해상도 등급에서는 최대치인 4784 토큰까지 사용될 수 있습니다. 즉 고해상도 모델은 세밀한 디테일을 더 많이 보존하는 대신, 큰 이미지일수록 최대 3배 가까운 토큰을 소비할 수 있습니다.

```python
import math

def estimate_visual_tokens(width, height):
    return math.ceil(width / 28) * math.ceil(height / 28)

print(estimate_visual_tokens(1000, 1000))  # 1296
print(estimate_visual_tokens(3840, 2160))  # 약 8880 → 모델별 상한선에 따라 다운스케일됨
```

컴퓨터 사용(computer use)이나 스크린샷 분석, 밀도 높은 문서처럼 세밀함이 꼭 필요한 경우가 아니라면, 업로드 전에 이미지를 미리 리사이즈해서 토큰 비용을 통제하는 것이 좋습니다. 요청 크기 제한도 함께 고려해야 합니다. API는 요청당 최대 100장(200K 컨텍스트 모델 기준)의 이미지를 허용하지만, 표준 엔드포인트의 요청 크기 상한(32MB)에 먼저 걸릴 수 있으므로 이미지가 많다면 Files API로 페이로드를 줄이는 편이 안전합니다. 지원 포맷은 JPEG, PNG, GIF, WebP이며 애니메이션은 첫 프레임만 사용됩니다.

---

## 3. 실습: 여러 이미지 비교 분석하기

여러 이미지를 한 요청에 담아 Claude가 종합적으로 분석하게 할 수 있습니다. 이미지가 여러 장일 때는 각 이미지 앞에 "Image 1:", "Image 2:" 같은 짧은 라벨을 붙여두면, 이후 답변이나 후속 질문에서 특정 이미지를 명확히 지칭할 수 있어 유용합니다.

```python
import anthropic, base64

client = anthropic.Anthropic()

def load_image(path):
    with open(path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")

message = client.messages.create(
    model="claude-opus-4-8",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "Image 1:"},
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": load_image("before.png")}},
            {"type": "text", "text": "Image 2:"},
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": load_image("after.png")}},
            {"type": "text", "text": "두 UI 스크린샷의 차이점을 표로 정리해줘."},
        ],
    }],
)
print(message.content[0].text)
```

멀티턴 대화에서는 이전 턴에 넣은 이미지를 Claude가 계속 기억하므로, 다음 턴에서 "처음 두 이미지와 비슷한가요?" 같은 후속 질문을 할 때 이미지를 다시 첨부할 필요가 없습니다. curl로도 동일한 구조를 사용할 수 있습니다.

```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-opus-4-8",
    "max_tokens": 1024,
    "messages": [{
      "role": "user",
      "content": [
        {"type": "image", "source": {"type": "url", "url": "https://example.com/receipt.jpg"}},
        {"type": "text", "text": "이 영수증에서 총 결제 금액과 날짜만 추출해줘."}
      ]
    }]
  }'
```

Vision을 실무에 적용할 때 몇 가지 한계도 염두에 두어야 합니다. Claude는 이미지 속 인물의 신원을 특정하는 데 사용할 수 없고, 200픽셀 미만의 아주 작거나 회전되거나 저화질인 이미지에서는 오인식이 늘어납니다. 좌표나 개수를 세는 답변도 근사치로 취급해야 하며, CT나 MRI 같은 정밀 의료 영상 판독에는 적합하지 않습니다. 고정밀이 요구되는 작업일수록 Claude의 해석을 그대로 신뢰하지 말고 반드시 사람이 검증하는 절차를 두는 것이 안전합니다.

---

## 📝 핵심 요약

1. 이미지 입력은 `base64`, `url`, `file_id`(Files API) 세 방식이 있으며, 멀티턴 대화나 반복 사용 시에는 Files API가 페이로드 크기를 줄여준다
2. 이미지는 텍스트보다 앞에 배치할 때 성능이 더 좋다
3. Claude는 이미지를 28×28 패치 단위(visual token)로 처리하며, 토큰 수는 대략 `⌈width/28⌉ × ⌈height/28⌉`로 계산된다
4. 최신 고해상도 등급 모델(Sonnet 5, Opus 4.8 등)은 최대 2576px·4784토큰까지, 그 외 표준 등급은 1568px·1568토큰까지 처리하며 초과분은 자동 다운스케일된다
5. 세밀함이 필요 없다면 업로드 전 리사이즈로 토큰 비용을 낮추고, 인물 식별·정밀 의료 판독·정확한 계수처럼 고정밀이 필요한 작업은 사람이 반드시 검증해야 한다

---

## 🔗 참고 자료

- [Vision — Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/vision)
- [Coordinates and bounding boxes](https://platform.claude.com/docs/en/build-with-claude/vision-coordinates)
- [Files API](https://platform.claude.com/docs/en/build-with-claude/files)
- [Multimodal cookbook](https://platform.claude.com/cookbook/multimodal-getting-started-with-vision)

---

*⬅️ 이전: [Day 16 — Tool Use (Function Calling)](../day-16/)  |  다음: [Day 18 — 비용 최적화](../day-18/) ➡️*
