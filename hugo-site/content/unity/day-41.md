---
title: "Day 41 — Post-processing으로 비주얼 완성도 높이기"
date: 2026-09-08
weight: 41
---

> **Phase 6: 환경과 월드 빌딩** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- URP의 Volume 시스템 구조(Global/Local Volume, Volume Profile, Layer)를 이해하고 Post-processing을 세팅할 수 있다
- Bloom, Color Adjustments, Tone Mapping, Vignette, Depth of Field 등 핵심 효과의 역할과 파라미터를 설명할 수 있다
- 스크립트로 Volume 가중치를 조절해 상황별(피격, 실내/실외 전환 등) 연출을 구현하고, 모바일 성능을 고려해 효과를 선별할 수 있다

---

## 1. Post-processing이란, 그리고 URP Volume 시스템

Post-processing(후처리)은 카메라가 씬을 렌더링한 **최종 이미지에 추가로 적용하는 화면 효과**입니다. 오브젝트나 라이팅 자체를 바꾸는 것이 아니라, 이미 그려진 프레임 버퍼를 필터링해서 색감, 노출, 초점, 화면 왜곡 등을 조정합니다. 같은 씬이라도 후처리 유무에 따라 "저예산 프로토타입"과 "완성도 있는 게임"만큼의 인상 차이가 납니다.

URP(Universal Render Pipeline)에서는 **Volume 시스템**을 통해 후처리를 관리합니다. 핵심 개념은 세 가지입니다.

| 개념 | 역할 |
|---|---|
| Volume Profile | 어떤 효과를 얼마나 적용할지 정의하는 데이터 에셋(ScriptableObject) |
| Volume 컴포넌트 | 씬에 배치되어 Profile을 실제로 적용하는 컴포넌트 |
| Volume Blending | 여러 Volume이 겹칠 때 우선순위/거리에 따라 효과를 섞는 방식 |

Volume은 크게 두 종류로 나뉩니다.

- **Global Volume**: `Is Global` 체크박스가 켜진 Volume. 씬 전역에 항상 적용됩니다. 기본 분위기(전체 톤, 기본 Bloom 등)를 잡을 때 사용합니다.
- **Local Volume**: Collider(Box/Sphere 등)를 가진 영역에만 적용되는 Volume. 카메라가 해당 콜라이더 안에 들어왔을 때만 효과가 켜지거나 강해집니다. 동굴 안에 들어가면 Vignette가 강해지고 채도가 낮아지는 식의 연출에 씁니다.

```
GameObject > Volume > Global Volume
GameObject > Volume > Box Volume   (Local Volume 예시)
```

> 💡 **실무 팁**: 프로젝트 세팅에서 URP Asset의 `Post-processing` 항목이 활성화되어 있어야 Volume 효과가 실제로 렌더링에 반영됩니다. Volume Profile을 아무리 세팅해도 이 옵션이 꺼져 있으면 아무 변화가 없어 초기 설정 시 자주 놓치는 부분입니다.

---

## 2. Volume Profile 만들고 카메라에 연결하기

Volume Profile은 별도의 에셋 파일로 저장되어 여러 씬/Volume에서 재사용할 수 있습니다. 설정 순서는 다음과 같습니다.

1. 씬에 `Global Volume` GameObject 생성
2. 인스펙터의 `Volume` 컴포넌트에서 `Profile` 필드 옆 `New` 버튼으로 Profile 에셋 생성 (또는 기존 Profile 할당)
3. `Add Override` 버튼으로 원하는 효과(Bloom, Vignette 등)를 하나씩 추가
4. 각 효과의 파라미터 좌측 체크박스를 켜야 해당 값이 "override"되어 실제로 적용됨 (체크 안 하면 기본값 무시)

카메라 쪽에서는 URP의 `Camera` 컴포넌트에 있는 **Rendering > Post Processing** 체크박스가 켜져 있어야 하며, `Volume Mask` 레이어가 Volume의 GameObject 레이어를 포함해야 합니다. 기본값은 `Everything`이라 대부분은 별도 설정이 필요 없지만, 여러 카메라(미니맵, UI 카메라 등)를 쓸 때는 특정 카메라만 후처리를 받도록 레이어로 분리하는 경우가 많습니다.

```
Camera 컴포넌트
  Rendering
    Post Processing: ✔
    Anti-aliasing: SMAA / TAA (원하는 방식)
    Volume Mask: PostFX (커스텀 레이어)
```

> 💡 **실무 팁**: Local Volume은 `Blend Distance`를 0보다 크게 주면 콜라이더 경계 부근에서 효과가 서서히 나타나거나 사라져, 갑자기 화면이 바뀌는 어색함을 없앨 수 있습니다.

---

## 3. 톤과 색감을 잡는 효과 — Color Adjustments & Tone Mapping

**Tone Mapping**은 HDR(High Dynamic Range) 렌더링 결과를 화면에 표시 가능한 범위(LDR)로 압축하는 과정입니다. URP는 `None`, `Neutral`, `ACES` 세 가지 모드를 제공합니다.

| 모드 | 특징 |
|---|---|
| None | 톤 매핑 없음, 밝은 부분이 그대로 클리핑(흰색으로 날아감) |
| Neutral | 색상 왜곡을 최소화하며 밝은 영역을 부드럽게 압축 |
| ACES | 영화적인 색감(대비 강조, 하이라이트 롤오프)을 만들어주는 산업 표준 필름 톤맵 |

대부분의 상업 프로젝트는 ACES를 기본값으로 두고 그 위에 미세 조정을 얹습니다.

**Color Adjustments** override는 전체적인 색 보정을 담당합니다.

- `Post Exposure`: 노출값(EV) 조정, 전체 밝기를 스톱 단위로 가감
- `Contrast`: 대비
- `Color Filter`: 특정 색을 곱해 전체 색감에 필터를 씌움 (석양 느낌의 주황 필터 등)
- `Hue Shift` / `Saturation`: 색조 회전과 채도

```csharp
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ColorGradeSwitcher : MonoBehaviour
{
    [SerializeField] private Volume volume;
    private ColorAdjustments colorAdjustments;

    private void Awake()
    {
        volume.profile.TryGet(out colorAdjustments);
    }

    public void SetNightMood(bool isNight)
    {
        if (colorAdjustments == null) return;
        colorAdjustments.saturation.value = isNight ? -30f : 0f;
        colorAdjustments.postExposure.value = isNight ? -0.5f : 0f;
    }
}
```

> 💡 **실무 팁**: `Volume.profile.TryGet<T>()`은 해당 Profile에 해당 override가 실제로 추가되어 있지 않으면 `false`를 반환합니다. Add Override로 미리 추가해두지 않은 효과는 스크립트로도 찾을 수 없다는 점을 기억하세요.

---

## 4. 빛과 초점 효과 — Bloom, Depth of Field, Vignette

**Bloom**은 밝은 영역 주변으로 빛이 번지는 효과입니다. 창문으로 들어오는 햇빛, 네온 사인, 마법 이펙트의 발광감을 표현할 때 사용합니다.

- `Threshold`: 이 밝기 이상인 픽셀만 번짐 효과의 대상이 됨
- `Intensity`: 번짐 강도
- `Scatter`: 빛이 퍼지는 반경(값이 클수록 더 넓고 부드럽게 번짐)

**Depth of Field(피사계 심도)**는 카메라 초점 거리 기준으로 앞/뒤를 흐리게 처리해 특정 대상에 시선을 집중시킵니다.

- `Focus Distance`: 선명하게 보일 초점 거리
- `Aperture` (F-Stop): 값이 작을수록(예: F1.4) 흐림이 강하고, 클수록(F16) 흐림이 약함 — 실제 카메라 렌즈와 동일한 개념
- `Focal Length`: 렌즈 화각, 값이 클수록 배경 흐림이 강조됨

컷신이나 대화 장면에서 배경을 흐리게 처리해 캐릭터에 집중시키는 용도로 자주 쓰입니다.

**Vignette**는 화면 가장자리를 어둡게(또는 원하는 색으로) 처리해 시선을 화면 중앙으로 모으는 효과입니다.

- `Intensity`, `Smoothness`: 어두워지는 강도와 경계의 부드러움
- 피격 시 화면 테두리를 붉게 만드는 연출에도 Vignette의 `Color` 파라미터를 활용합니다

```csharp
// 피격 시 빨간 Vignette를 순간적으로 강조하는 예시
using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class HitFlashVignette : MonoBehaviour
{
    [SerializeField] private Volume volume;
    [SerializeField] private float flashDuration = 0.3f;
    private Vignette vignette;

    private void Awake() => volume.profile.TryGet(out vignette);

    public void PlayHitFlash()
    {
        StartCoroutine(FlashRoutine());
    }

    private IEnumerator FlashRoutine()
    {
        vignette.color.value = Color.red;
        vignette.intensity.value = 0.5f;
        float t = 0f;
        while (t < flashDuration)
        {
            t += Time.deltaTime;
            vignette.intensity.value = Mathf.Lerp(0.5f, 0.2f, t / flashDuration);
            yield return null;
        }
    }
}
```

---

## 5. 그 외 효과와 상황별 Volume 전환 전략

- **Chromatic Aberration**: 화면 가장자리에서 RGB 채널이 살짝 어긋나 보이는 렌즈 왜곡 효과. 피격/충격 연출에 순간적으로 강하게 주면 효과적입니다.
- **Film Grain**: 필름 질감의 노이즈를 더해 아날로그/시네마틱한 느낌을 줍니다.
- **Motion Blur**: 카메라나 오브젝트의 빠른 움직임에 잔상을 추가합니다. 다만 모바일에서는 비용이 크고 멀미를 유발할 수 있어 신중하게 사용합니다.
- **White Balance**: 색온도(Temperature)와 색조(Tint)로 전체적인 "따뜻함/차가움"을 조정합니다.

여러 효과를 조합할 때는 하나의 Profile에 다 몰아넣기보다, **기본 분위기용 Global Volume + 상황별 Local/스크립트 제어용 override 세트**로 나누는 편이 유지보수하기 쉽습니다. 예를 들어:

1. Global Volume: ACES 톤매핑, 은은한 Bloom, 약한 Vignette (항상 유지되는 기본 톤)
2. 실내 진입 시 Local Volume: 채도 낮춤 + Vignette 강화 (Blend Distance로 자연스러운 전환)
3. 피격 시 스크립트: Vignette 색상/Chromatic Aberration을 순간적으로 강조 후 코루틴으로 원상 복귀

이렇게 계층을 나누면 "평소 톤은 그대로 두고 특정 이벤트만 강조"하는 구조를 깔끔하게 유지할 수 있습니다.

> 💡 **실무 팁**: `Volume Priority` 값이 높은 Volume이 낮은 Volume보다 우선 적용됩니다. Local Volume에는 Global Volume보다 높은 Priority를 줘서 "특수 영역이 기본값을 덮어쓰는" 구조를 명확히 하세요.

---

## 6. 성능 고려사항 (특히 모바일)

후처리는 화면 전체 픽셀에 추가 연산을 가하는 풀스크린 효과라, 특히 모바일/저사양 기기에서 프레임에 직접적인 영향을 줍니다.

- **Bloom, Tone Mapping, Color Adjustments, Vignette**는 비교적 저비용이라 모바일에서도 무난히 사용 가능
- **Depth of Field, Motion Blur, Chromatic Aberration**은 상대적으로 고비용 — 모바일 타겟에서는 끄거나 저사양 옵션에서 비활성화하는 것이 일반적
- URP Asset의 Quality 설정(저사양/고사양 프로필 분리)에서 플랫폼별로 다른 Volume Profile을 적용하는 방식으로 대응
- Depth of Field는 Depth Texture를 요구하므로, 사용하지 않는 플랫폼에서는 URP Asset의 `Depth Texture` 옵션도 함께 끄면 추가 절약 가능

> 개발 중에는 항상 Frame Debugger나 Profiler(Day 51에서 다룰 예정)로 후처리 패스가 실제로 프레임 타임에 얼마나 기여하는지 측정한 뒤 효과를 취사선택하는 습관이 중요합니다.

---

## 📝 핵심 요약

1. URP의 후처리는 Volume Profile(데이터) + Volume 컴포넌트(적용 범위)로 구성되며, Global/Local Volume과 Blend Distance로 영역별 분위기를 자연스럽게 전환할 수 있다
2. Tone Mapping(ACES 권장)과 Color Adjustments가 전체 색감의 기본 톤을 잡고, Bloom·Vignette·Depth of Field가 디테일한 시선 유도와 분위기를 완성한다
3. 스크립트에서는 `Volume.profile.TryGet<T>()`으로 override를 가져와 값을 직접 조정하며, 피격 효과처럼 순간적인 연출은 코루틴으로 값을 보간한다
4. Volume Priority로 어떤 Volume이 우선 적용될지 명확히 하고, 기본 톤과 이벤트성 강조를 계층적으로 분리하면 유지보수가 쉬워진다
5. Depth of Field, Motion Blur, Chromatic Aberration은 상대적 고비용이므로 모바일/저사양 타겟에서는 선별적으로 끄는 것이 성능상 안전하다

---

## 🔗 참고 자료

- [Unity Manual — Volume Overview](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest/manual/Volumes.html)
- [Unity Manual — Post-processing in URP](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest/manual/integration-with-post-processing.html)
- [Unity Manual — Tonemapping](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest/manual/post-processing-tonemapping.html)

---

*⬅️ 이전: [Day 40 — Particle System으로 이펙트 만들기](../day-40/)  |  다음: [Day 42 — 6주차 정리: 작은 환경 씬 완성](../day-42/) ➡️*
