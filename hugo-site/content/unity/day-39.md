---
title: "Day 39 — 스카이박스와 환경 분위기 연출"
date: 2026-09-06
weight: 39
---

> **Phase 6: 환경과 월드 빌딩** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Skybox의 종류(Procedural, 6 Sided, Cubemap, Panoramic)와 각각의 용도를 설명할 수 있다
- Lighting 창에서 Environment Lighting/Reflections 설정이 스카이박스와 어떻게 연결되는지 이해한다
- Fog, Ambient Light, Color Grading을 조합해 씬의 시간대·분위기를 연출할 수 있다

---

## 1. Skybox란 무엇인가

Skybox는 씬을 감싸는 거대한 가상의 "배경 껍질"입니다. 카메라가 아무리 이동해도 스카이박스는 항상 무한히 먼 배경처럼 보이며, 하늘·먼 지형·구름 같은 요소를 표현하는 데 씁니다.

Unity는 스카이박스를 단순한 배경 이미지가 아니라 **조명 계산의 입력값**으로도 사용합니다. 즉 스카이박스를 잘 설정하면 하늘색이 오브젝트의 그림자와 반사에도 자연스럽게 묻어납니다. 이 연결 고리가 이번 Day의 핵심입니다.

---

## 2. Skybox의 4가지 타입

`Window > Rendering > Lighting > Environment` 탭에서 `Skybox Material`을 지정할 때, 머티리얼의 Shader가 스카이박스 타입을 결정합니다.

| 타입 | Shader | 특징 | 용도 |
|---|---|---|---|
| Procedural | `Skybox/Procedural` (Built-in 전용) | 태양 위치, 대기 두께, 지평선 색 등을 파라미터로 절차적 생성 | 낮/밤 전환, 코드로 동적 제어가 필요한 씬 |
| 6 Sided | `Skybox/6 Sided` | 정육면체 6면에 각각 텍스처 매핑 (Front/Back/Left/Right/Up/Down) | 커스텀 아트로 그린 하늘, 스타일라이즈 씬 |
| Cubemap | `Skybox/Cubemap` | 하나의 Cubemap 텍스처(HDRI 변환본)로 6면을 표현 | HDRI 기반 사실적 하늘, 반사 품질이 중요한 씬 |
| Panoramic | `Skybox/Panoramic` | 등장방형(Equirectangular) 파노라마 이미지 1장 | HDRI를 그대로 사용, 가장 널리 쓰이는 방식 |

> URP를 쓰는 경우 Procedural Skybox는 지원되지 않으므로, URP 프로젝트에서는 Cubemap이나 Panoramic(HDRI) 방식을 기본으로 고려하는 것이 안전합니다.

**HDRI를 Panoramic Skybox로 쓰는 절차:**

1. HDRI 이미지(.hdr/.exr)를 프로젝트에 임포트
2. Import Settings에서 Texture Shape을 `Cube`로, Texture Type을 유지한 채 Import
3. 새 머티리얼 생성 → Shader를 `Skybox/Panoramic`으로 변경
4. 머티리얼의 `Spherical (HDR)` 슬롯에 해당 텍스처 연결
5. Lighting 창의 `Skybox Material`에 이 머티리얼 드래그

---

## 3. Environment Lighting과 스카이박스의 관계

`Lighting > Environment` 탭에는 `Environment Lighting`이라는 항목이 있고, `Source`를 `Skybox`로 두면 스카이박스 색상이 씬 전체의 **간접광(Ambient Light)** 소스가 됩니다.

- `Intensity Multiplier`: 스카이박스가 앰비언트 라이트에 기여하는 세기 조절
- `Ambient Mode`(Baked/Realtime): 앰비언트 계산을 언제 갱신할지 결정. 스카이박스를 런타임에 바꾸는 씬이라면 `Realtime`이 필요할 수 있음

`Environment Reflections` 항목의 `Source`도 `Skybox`로 두면, 금속/유리처럼 반사가 강한 머티리얼이 스카이박스를 반사 소스로 사용합니다. 이때 `Resolution`을 올리면 반사 디테일이 좋아지지만 빌드 크기와 메모리가 늘어납니다.

```
Lighting 창 체크리스트
├─ Environment Lighting
│   ├─ Source: Skybox
│   └─ Intensity Multiplier: 1.0 (분위기에 맞춰 조절)
├─ Environment Reflections
│   ├─ Source: Skybox
│   └─ Resolution: 128~256 (모바일은 낮게)
└─ Fog
    ├─ Fog Color: 스카이박스 지평선 색과 유사하게
    └─ Mode: Linear / Exponential / Exponential Squared
```

> 💡 **실무 팁**: 반사가 스카이박스와 하나도 안 맞아 보이면, 대부분 Environment Reflections의 Source가 `Custom`으로 남아있거나 Reflection Probe가 스카이박스를 덮어쓰고 있는 경우입니다. Reflection Probe를 배치했다면 그 Probe가 우선 적용된다는 점을 기억하세요.

---

## 4. Fog로 공간감과 거리감 만들기

Fog는 카메라에서 멀어질수록 오브젝트가 안개색으로 섞이는 효과로, `Lighting > Environment > Other Settings`에서 켤 수 있습니다.

| 모드 | 계산 방식 | 용도 |
|---|---|---|
| Linear | Start~End 거리 사이에서 선형 보간 | 정확한 가시거리 제어가 필요할 때 |
| Exponential | 거리에 따라 지수적으로 증가 | 자연스러운 대기감 |
| Exponential Squared | 지수의 제곱으로 더 급격하게 증가 | 짙은 안개, 던전/공포 분위기 |

Fog Color를 스카이박스의 지평선(Horizon) 색과 비슷하게 맞추면, 먼 지형이 하늘로 자연스럽게 녹아드는 느낌을 줄 수 있습니다. 반대로 일부러 다른 색(예: 초록빛 안개)을 쓰면 독성 늪지대 같은 특수한 분위기를 연출할 수 있습니다.

---

## 5. 시간대·분위기 연출 조합 레시피

실제로 "새벽", "정오", "노을", "밤" 같은 분위기를 만들 때는 스카이박스 하나만 바꾸는 게 아니라 여러 요소를 함께 조정합니다.

| 시간대 | Skybox 톤 | Directional Light 각도/색 | Fog | Ambient Intensity |
|---|---|---|---|---|
| 새벽 | 차분한 청보라 | 낮은 각도, 옅은 오렌지 | 옅게(Exponential) | 낮음 |
| 정오 | 밝은 하늘색 | 높은 각도, 흰색에 가까움 | 거의 없음 | 높음 |
| 노을 | 주황~보라 그라디언트 | 낮은 각도, 진한 오렌지/red | 약간 | 중간 |
| 밤 | 짙은 남색, 별/달 | 매우 낮은 강도, 푸른빛 | 짙게 가능 | 매우 낮음 (Skybox 대신 Color로 대체 고려) |

> 💡 **실무 팁**: 밤 씬에서는 스카이박스 기반 Ambient가 너무 어두워 오브젝트가 완전히 안 보일 수 있습니다. 이럴 땐 Environment Lighting Source를 `Color`로 바꿔 최소한의 밝기를 강제로 보장하거나, 약한 Fill Light를 추가하는 방식을 많이 씁니다.

시간대 전환을 코드로 자동화하려면, 위 파라미터들(태양 각도, Fog 색, Ambient Intensity)을 `Time.deltaTime` 기반으로 보간(Lerp)하는 스크립트를 작성해 하루 주기를 시뮬레이션할 수도 있습니다.

```csharp
public class DayNightCycle : MonoBehaviour
{
    public Light sun;
    public float dayLengthInSeconds = 120f;

    void Update()
    {
        float t = (Time.time % dayLengthInSeconds) / dayLengthInSeconds;
        float sunAngle = t * 360f;
        sun.transform.rotation = Quaternion.Euler(sunAngle - 90f, 170f, 0f);

        // 태양 고도에 따라 앰비언트 밝기를 함께 조절
        float elevation = Mathf.Sin(sunAngle * Mathf.Deg2Rad);
        RenderSettings.ambientIntensity = Mathf.Clamp01(elevation + 0.2f);
    }
}
```

---

## 📝 핵심 요약

1. Skybox는 배경일 뿐 아니라 Environment Lighting/Reflections의 입력값으로 쓰여 씬 전체 조명 톤에 영향을 준다
2. URP에서는 Procedural Skybox가 지원되지 않으므로 Cubemap/Panoramic(HDRI) 방식을 기본으로 고려한다
3. Fog Color를 스카이박스 지평선 색과 맞추면 먼 지형이 하늘로 자연스럽게 녹아든다
4. 시간대 연출은 스카이박스 하나가 아니라 태양 각도·색, Fog, Ambient Intensity를 함께 조정해야 완성도가 높아진다
5. 밤 씬처럼 Ambient가 지나치게 어두워지는 경우 Environment Lighting Source를 Color로 바꾸는 것도 실전에서 자주 쓰는 방법이다

---

## 🔗 참고 자료

- [Unity Manual — Skybox](https://docs.unity3d.com/Manual/class-Skybox.html)
- [Unity Manual — Environment Lighting](https://docs.unity3d.com/Manual/lighting-environment-lighting.html)
- [Unity Manual — Fog](https://docs.unity3d.com/Manual/EnvironmentFog.html)

---

*⬅️ 이전: [Day 38 — 라이트맵 베이킹과 글로벌 일루미네이션](../day-38/)  |  다음: [Day 40 — Particle System으로 이펙트 만들기](../day-40/) ➡️*
