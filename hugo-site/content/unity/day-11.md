---
title: "Day 11 — 카메라 시스템과 시네마틱 기초"
date: 2026-08-10
weight: 11
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Camera 컴포넌트의 Projection(Perspective/Orthographic), Clipping Planes, Culling Mask, Depth의 역할을 설명할 수 있다
- 여러 대의 카메라를 Depth와 Viewport Rect로 조합해 미니맵, 스플릿 스크린 같은 화면 구성을 만들 수 있다
- 스크립트로 부드러운 카메라 추적(Follow)과 시선 고정(LookAt), 간단한 화면 흔들림 연출을 구현할 수 있다

---

## 1. Camera 컴포넌트 기본 속성

Unity에서 씬을 화면에 그리는 주체는 `Camera` 컴포넌트가 붙은 GameObject입니다. 새 씬을 만들면 `Main Camera`가 자동으로 존재하며, `MainCamera` 태그가 붙어 있어 `Camera.main`으로 어디서든 참조할 수 있습니다.

| 속성 | 설명 |
|---|---|
| Projection | Perspective(원근 투영) 또는 Orthographic(직교 투영) |
| Field of View (FOV) | Perspective일 때 시야각(도 단위). 값이 클수록 넓게, 왜곡도 커짐 |
| Size | Orthographic일 때 화면 절반 높이(월드 단위). FOV 대신 이 값으로 확대/축소를 제어 |
| Clipping Planes (Near/Far) | 이 범위 밖의 오브젝트는 렌더링에서 제외됨 |
| Culling Mask | 특정 Layer만 이 카메라가 그리도록 필터링 |
| Depth | 여러 카메라가 있을 때 그려지는 순서(낮은 값 먼저) |

**Perspective vs Orthographic**은 단순히 "3D냐 2D냐"의 문제가 아닙니다. 3D 게임에서도 미니맵이나 아이소메트릭 스타일 연출에는 Orthographic을 쓰고, 반대로 2D 게임에서 배경에 깊이감을 주고 싶을 때 Perspective를 쓰는 경우도 있습니다.

```
Perspective  → 멀리 있는 물체가 작게 보임 (원근감 있음) → 대부분의 3D 게임
Orthographic → 거리와 무관하게 크기 동일 → 전략 게임, 미니맵, 2D 게임
```

> 💡 **실무 팁**: Near Clipping Plane을 너무 작게(0.01 이하) 두면 카메라에 물체가 아주 가까이 붙었을 때 z-fighting(면이 깜빡이는 렌더링 오류)이 발생하기 쉽습니다. 1인칭 카메라라도 0.05~0.3 사이에서 시작해 조정하는 것이 안전합니다.

---

## 2. 여러 대의 카메라 조합하기

씬에 카메라가 하나뿐이라는 법은 없습니다. 미니맵, 스플릿 스크린 멀티플레이, UI 전용 카메라 등 실무에서는 카메라를 2~4대 동시에 쓰는 경우가 흔합니다. 이때 세 가지 속성이 화면 구성을 결정합니다.

- **Depth**: 값이 낮은 카메라가 먼저 그려지고, 값이 높은 카메라가 그 위에 겹쳐 그려짐
- **Viewport Rect**: 화면에서 이 카메라가 차지할 영역을 (0~1) 비율로 지정 (X, Y, W, H)
- **Clear Flags**: 카메라가 그리기 전에 화면을 무엇으로 지울지 — `Skybox`(기본), `Solid Color`, `Depth Only`, `Don't Clear`

```
예: 우상단 미니맵 카메라 설정
- Projection: Orthographic
- Viewport Rect: X 0.75, Y 0.75, W 0.2, H 0.2
- Depth: 메인 카메라보다 높은 값 (나중에 그려져 위에 겹침)
- Culling Mask: "Minimap" 레이어만 체크
```

스플릿 스크린(2인 플레이)은 Viewport Rect를 좌/우 또는 상/하로 절반씩 나눠 두 카메라에 각각 할당하면 됩니다.

```
Player 1 카메라: Viewport Rect X 0, Y 0, W 0.5, H 1
Player 2 카메라: Viewport Rect X 0.5, Y 0, W 0.5, H 1
```

> 💡 **실무 팁**: 카메라가 여러 대일 때 오디오 리스너(`AudioListener`)는 씬에 **단 하나만** 있어야 합니다. 카메라 프리팹을 복제하면 AudioListener가 중복으로 따라와 콘솔에 경고가 뜨는 경우가 많으니, 서브 카메라에서는 이 컴포넌트를 제거하세요.

---

## 3. 스크립트로 카메라 추적하기 — Follow와 LookAt

플레이어를 따라다니는 3인칭 카메라의 기본 원리는 "목표 위치와의 거리를 매 프레임 부드럽게 줄여나가는 것"입니다. `Transform.position = target.position`처럼 즉시 이동시키면 뚝뚝 끊기는 느낌이 나므로, 보간(interpolation) 함수를 씁니다.

```csharp
using UnityEngine;

public class SmoothFollowCamera : MonoBehaviour
{
    [SerializeField] private Transform target;
    [SerializeField] private Vector3 offset = new Vector3(0f, 3f, -6f);
    [SerializeField] private float followSpeed = 5f;
    [SerializeField] private float lookSpeed = 8f;

    private void LateUpdate()
    {
        if (target == null) return;

        // 목표 위치 = 타겟 위치 + 오프셋
        Vector3 desiredPosition = target.position + offset;
        transform.position = Vector3.Lerp(transform.position, desiredPosition, followSpeed * Time.deltaTime);

        // 항상 타겟을 바라보도록 회전도 부드럽게 보간
        Quaternion desiredRotation = Quaternion.LookRotation(target.position - transform.position);
        transform.rotation = Quaternion.Slerp(transform.rotation, desiredRotation, lookSpeed * Time.deltaTime);
    }
}
```

몇 가지 핵심 포인트가 있습니다.

- 카메라 이동/회전은 **`Update`가 아니라 `LateUpdate`**에서 처리합니다. 플레이어가 `Update`에서 먼저 이동을 마친 뒤 카메라가 그 결과를 따라가야 한 프레임 지연 없이 자연스럽기 때문입니다.
- 위치 보간에는 `Vector3.Lerp` 대신 `Vector3.SmoothDamp`를 쓰면 가속/감속이 있는 더 자연스러운 움직임을 만들 수 있습니다.
- 회전에는 `Slerp`(구면 선형 보간)를 씁니다. 회전값(Quaternion)은 `Lerp`보다 `Slerp`가 일정한 각속도로 보간되어 더 자연스럽습니다.

> 💡 **실무 팁**: `followSpeed * Time.deltaTime`을 `Lerp`의 t값으로 그대로 쓰는 방식은 프레임레이트에 따라 체감 속도가 살짝 달라지는 근사치입니다. 완전히 프레임레이트에 독립적인 보간이 필요하다면 `1f - Mathf.Exp(-followSpeed * Time.deltaTime)`을 t값으로 쓰는 지수 감쇠(exponential decay) 방식이 더 정확합니다.

---

## 4. 간단한 시네마틱 연출 — 화면 흔들림과 FOV 전환

카메라 연출의 기초는 크게 두 가지로 시작하는 경우가 많습니다: 충격/타격감을 위한 **화면 흔들림(Screen Shake)**, 그리고 속도감/긴장감을 위한 **FOV 전환**입니다.

```csharp
using UnityEngine;
using System.Collections;

public class CameraShake : MonoBehaviour
{
    public IEnumerator Shake(float duration, float magnitude)
    {
        Vector3 originalPos = transform.localPosition;
        float elapsed = 0f;

        while (elapsed < duration)
        {
            float x = Random.Range(-1f, 1f) * magnitude;
            float y = Random.Range(-1f, 1f) * magnitude;

            transform.localPosition = originalPos + new Vector3(x, y, 0f);

            elapsed += Time.deltaTime;
            yield return null;
        }

        transform.localPosition = originalPos;
    }
}
```

FOV를 순간적으로 넓히면 속도감이나 타격의 강렬함을 표현할 수 있습니다. 예를 들어 대시(dash) 스킬을 쓸 때 FOV를 60 → 75로 살짝 넓혔다가 원래대로 복귀시키는 식입니다.

```csharp
private IEnumerator FovKick(Camera cam, float targetFov, float duration)
{
    float startFov = cam.fieldOfView;
    float elapsed = 0f;

    while (elapsed < duration)
    {
        cam.fieldOfView = Mathf.Lerp(startFov, targetFov, elapsed / duration);
        elapsed += Time.deltaTime;
        yield return null;
    }

    cam.fieldOfView = targetFov;
}
```

> 💡 **실무 팁**: 화면 흔들림은 카메라 본체(부모)가 아니라 **자식 오브젝트**(실제 Camera 컴포넌트가 붙은 오브젝트)의 `localPosition`에 적용하는 것이 좋습니다. 그러면 흔들림이 끝나고 원래 위치로 복귀할 때 Follow 스크립트가 갖고 있던 "진짜" 카메라 위치 값과 충돌하지 않습니다. 이 구조(카메라 리그 = 부모 Follow + 자식 Shake)는 Day 47에서 다룰 Cinemachine에서도 비슷한 개념(Noise, Impulse)으로 이어집니다.

---

## 📝 핵심 요약

1. Camera의 Projection(Perspective/Orthographic), Clipping Planes, Culling Mask, Depth는 "무엇을, 어떤 방식으로, 어떤 순서로 그릴지"를 결정하는 기본 축이다
2. Depth와 Viewport Rect를 조합하면 미니맵, 스플릿 스크린 등 여러 카메라를 동시에 화면에 구성할 수 있으며, AudioListener는 씬에 하나만 남겨야 한다
3. 카메라 추적/회전은 `LateUpdate`에서 `Lerp`/`Slerp` 또는 `SmoothDamp`로 보간해야 끊김 없이 자연스럽다
4. 화면 흔들림과 FOV 전환은 코드 몇 줄로 구현 가능한 가장 기초적인 시네마틱 연출 기법이며, 흔들림은 자식 오브젝트에 적용해 Follow 로직과 분리하는 것이 안전하다

---

## 🔗 참고 자료

- [Unity Manual — Camera](https://docs.unity3d.com/Manual/class-Camera.html)
- [Unity Scripting API — Camera](https://docs.unity3d.com/ScriptReference/Camera.html)
- [Unity Scripting API — Vector3.SmoothDamp](https://docs.unity3d.com/ScriptReference/Vector3.SmoothDamp.html)

---

*⬅️ 이전: [Day 10 — Unity UI 시스템(Canvas, UI 요소) 기초](../day-10/)  |  다음: [Day 12 — 오디오 시스템 다루기](../day-12/) ➡️*
