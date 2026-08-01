---
title: "Day 02 — GameObject와 Transform 이해하기"
date: 2026-08-01
weight: 2
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- GameObject와 Component의 관계를 설명하고, Transform이 모든 GameObject에 필수인 이유를 이해할 수 있다
- Position/Rotation/Scale의 Local 좌표와 World 좌표 차이를 구분해서 Inspector 값을 정확히 해석할 수 있다
- 부모-자식 관계(Parenting)가 Transform 값에 어떤 영향을 주는지 이해하고, 스크립트에서 Transform을 다룰 수 있다

---

## 1. GameObject는 빈 껍데기, Component가 기능을 채운다

Unity의 가장 근본적인 설계 철학은 **컴포지션(Composition)**입니다. `GameObject`는 그 자체로는 아무 기능이 없는 빈 컨테이너이고, 여기에 `Component`를 하나씩 붙여서 원하는 동작을 조립합니다.

예를 들어 "적 캐릭터"를 하나 만든다면 상속 구조로 `Enemy` 클래스를 만드는 게 아니라, 빈 GameObject에 다음과 같이 여러 Component를 부착합니다.

| Component | 역할 |
|---|---|
| Transform | 위치/회전/크기 (모든 GameObject에 자동 포함, 제거 불가) |
| Mesh Renderer | 3D 모델을 화면에 그림 |
| Box Collider | 충돌 감지 영역 정의 |
| Rigidbody | 물리 시뮬레이션 적용 |
| EnemyAI (직접 작성한 스크립트) | 행동 로직 |

이 방식의 장점은 **재사용성**입니다. `Rigidbody`나 `Collider`는 플레이어든 적이든 상자든 동일하게 붙여 쓸 수 있고, 필요 없어지면 떼어내면 그만입니다. 상속 트리를 미리 설계할 필요가 없습니다.

> 💡 **실무 팁**: "이 오브젝트에 어떤 클래스를 상속시킬까"가 아니라 "어떤 Component 조합으로 이 동작을 만들까"로 사고하는 습관을 들이세요. Unity 스크립팅 전체가 이 사고방식 위에 있습니다.

---

## 2. Transform — 유일하게 제거할 수 없는 Component

Hierarchy에서 아무 GameObject나 클릭해 Inspector를 보면, 맨 위에 항상 **Transform**이 있고 이것만은 우클릭해도 `Remove Component`가 비활성화되어 있습니다. 모든 GameObject는 3D 공간 어딘가에 존재해야 하기 때문에, Transform은 선택 사항이 아니라 GameObject의 정의 그 자체입니다.

Transform은 세 가지 값을 가집니다.

- **Position**: 공간상의 위치 (X, Y, Z)
- **Rotation**: 회전 값. Inspector에는 오일러 각(Euler Angle, X/Y/Z 도 단위)으로 표시되지만 내부적으로는 짐벌락(Gimbal Lock)을 피하기 위해 **Quaternion**으로 저장됩니다
- **Scale**: 크기 배율 (기본값 1, 1, 1)

```csharp
// Transform 값을 코드로 읽고 쓰는 기본 형태
Vector3 pos = transform.position;      // World 좌표 기준 위치
Quaternion rot = transform.rotation;   // World 좌표 기준 회전 (Quaternion)
Vector3 scale = transform.localScale;  // Scale은 항상 Local 값만 존재
```

> 💡 **실무 팁**: Rotation을 Inspector에서 직접 360, -360처럼 큰 값으로 입력해도 내부적으로는 Quaternion으로 정규화되어 저장됩니다. 코드에서 오일러 각을 여러 번 더하고 빼는 로직을 짜면 예상과 다른 값이 나올 수 있으니, 회전 누적이 필요하면 `Quaternion.Euler()`나 `transform.Rotate()`처럼 Unity가 제공하는 API를 쓰는 것이 안전합니다.

---

## 3. Local 좌표 vs World 좌표

Transform 값을 볼 때 가장 헷갈리는 부분이 "이 숫자가 어느 기준의 좌표인가"입니다.

- **World 좌표**: Scene 전체의 원점(0, 0, 0)을 기준으로 한 절대 위치
- **Local 좌표**: 부모 GameObject의 Transform을 기준으로 한 상대 위치

부모가 없는 최상위(Root) GameObject는 Local 좌표와 World 좌표가 동일합니다. 하지만 부모-자식 관계가 생기는 순간부터 둘은 달라집니다.

| API | 반환 기준 |
|---|---|
| `transform.position` | World 좌표 |
| `transform.localPosition` | 부모 기준 Local 좌표 |
| `transform.rotation` | World 회전 |
| `transform.localRotation` | 부모 기준 Local 회전 |
| `transform.localScale` | Scale은 World 버전 API가 없음 (항상 Local) |

Inspector 창에서 보이는 Position/Rotation 값은 **Local 값**입니다. 부모가 없는 오브젝트라면 신경 쓸 필요가 없지만, 부모가 있는 오브젝트의 Inspector 값이 예상한 위치와 다르게 느껴진다면 십중팔구 "부모 기준 상대 좌표를 World 좌표로 착각"한 경우입니다.

> 💡 **실무 팁**: 코드에서 "이 오브젝트를 정확히 (0, 0, 0) 월드 좌표로 보내고 싶다"면 `transform.position = Vector3.zero;`를 쓰고, "부모 바로 위 원점에 붙이고 싶다"면 `transform.localPosition = Vector3.zero;`를 씁니다. 이 둘을 혼동하면 부모가 있는 오브젝트가 엉뚱한 곳에 배치되는 흔한 버그가 발생합니다.

---

## 4. 부모-자식 관계(Parenting)와 Transform 상속

Hierarchy 창에서 한 GameObject를 다른 GameObject 위로 드래그하면 부모-자식 관계가 만들어집니다. 이때 자식의 Transform은 부모의 Transform에 **상속**됩니다.

- 부모를 이동/회전/크기 조절하면 자식도 함께 따라 움직입니다 (자식의 Local 값은 그대로, World 값만 바뀜)
- 자식을 부모 안으로 드래그하는 순간, Unity는 기본적으로 **World 좌표상 위치를 유지**하도록 Local 값을 자동 재계산합니다 (Inspector에서 `Position` 우클릭 → `Reset`을 하지 않는 이상 화면상 위치는 그대로)

실무에서 부모-자식 구조를 쓰는 대표적인 이유:

1. **그룹 이동**: 방(Room) 하나를 통째로 옮기고 싶을 때, 방 안의 가구들을 빈 GameObject 하나의 자식으로 묶어두면 부모만 이동시키면 됩니다
2. **상대적 배치**: 캐릭터 손에 무기를 들리는 경우, 무기를 손 뼈(Bone)의 자식으로 붙이면 캐릭터가 움직여도 무기가 손을 따라다닙니다
3. **논리적 구조화**: Hierarchy를 빈 GameObject(흔히 "Empty Object"라 부름)로 폴더처럼 묶어 씬을 정리합니다

```csharp
// 코드로 부모-자식 관계 설정
child.transform.SetParent(parent.transform);

// worldPositionStays를 false로 주면 World 좌표를 유지하지 않고
// Local 좌표를 0으로 리셋한 것처럼 부모 원점에 딱 붙임
child.transform.SetParent(parent.transform, false);
```

> 💡 **실무 팁**: `SetParent(parent, false)`와 `SetParent(parent, true)`(기본값)의 차이를 반드시 구분하세요. 무기를 손에 붙일 때처럼 "정확히 특정 로컬 위치에 고정"하고 싶다면 `false`로 붙인 뒤 `localPosition`을 직접 설정하는 편이 예측 가능합니다.

---

## 5. 스크립트에서 Transform 이동·회전시키기

`Update()` 안에서 Transform을 직접 조작하는 가장 기본적인 패턴입니다.

```csharp
using UnityEngine;

public class SimpleMover : MonoBehaviour
{
    public float moveSpeed = 3f;
    public float rotateSpeed = 90f;

    void Update()
    {
        // Time.deltaTime을 곱해 프레임레이트에 무관하게 일정한 속도 유지
        transform.Translate(Vector3.forward * moveSpeed * Time.deltaTime);

        // Y축 기준 초당 rotateSpeed도씩 회전
        transform.Rotate(Vector3.up, rotateSpeed * Time.deltaTime);
    }
}
```

`transform.Translate()`는 기본적으로 **자기 자신의 Local 축** 기준으로 이동합니다. 즉 오브젝트가 회전되어 있으면 "앞으로 이동"의 방향도 그 회전을 따라갑니다. World 축 기준으로 고정해서 이동하고 싶다면 두 번째 인자로 `Space.World`를 명시합니다.

```csharp
transform.Translate(Vector3.forward * moveSpeed * Time.deltaTime, Space.World);
```

> 💡 **실무 팁**: `Time.deltaTime`을 곱하지 않고 고정값만 더하면 프레임레이트가 높은 기기에서 오브젝트가 비정상적으로 빠르게 움직입니다. 이동/회전 관련 코드에서 `Time.deltaTime` 누락은 초보자가 가장 자주 저지르는 실수 중 하나입니다.

---

## 📝 핵심 요약

1. GameObject는 빈 컨테이너이고 Component 조합으로 기능을 만드는 것이 Unity의 핵심 설계 철학이다
2. Transform은 Position/Rotation/Scale을 가지며, 모든 GameObject에 필수이고 제거할 수 없다
3. Inspector에 보이는 값은 Local 좌표이며, 부모가 있는 오브젝트는 Local과 World 좌표가 다르다는 점을 항상 의식해야 한다
4. 부모-자식 관계는 그룹 이동, 상대적 배치, 씬 정리에 쓰이며 `SetParent`의 `worldPositionStays` 인자 차이를 구분해야 한다
5. Transform을 코드로 조작할 때는 `Time.deltaTime`을 곱해 프레임레이트 독립적으로 움직이게 해야 한다

---

## 🔗 참고 자료

- [Transform 컴포넌트 (Unity Manual)](https://docs.unity3d.com/Manual/class-Transform.html)
- [Transform 스크립팅 API](https://docs.unity3d.com/ScriptReference/Transform.html)
- [GameObject와 Component 개념 (Unity Manual)](https://docs.unity3d.com/Manual/GameObjects.html)

---

*⬅️ 이전: [Day 01 — Unity 설치 및 에디터 인터페이스 익히기](../day-01/)  |  다음: [Day 03 — Scene 구성과 계층 구조(Hierarchy) 관리](../day-03/) ➡️*
