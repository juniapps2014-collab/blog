---
title: "Day 09 — Collider와 충돌 감지"
date: 2026-08-08
weight: 9
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Box, Sphere, Capsule, Mesh Collider의 차이를 이해하고 상황에 맞게 선택할 수 있다
- Collision(충돌)과 Trigger(감지)의 차이를 구분하고 각각의 생명주기 콜백을 구현할 수 있다
- Layer Collision Matrix와 Continuous Collision Detection으로 충돌 문제를 진단하고 해결할 수 있다

---

## 1. Collider란 무엇인가

Day 08에서 Rigidbody가 "물체가 물리 법칙에 따라 움직이게" 만드는 컴포넌트였다면, Collider는 "그 물체가 다른 물체와 부딪혔는지 판단하는 경계선"을 정의하는 컴포넌트입니다. Rigidbody만 있고 Collider가 없으면 물체는 중력을 받아 떨어지긴 하지만 바닥을 그대로 통과해버립니다.

Unity의 충돌 감지는 실제 메시(Mesh)가 아니라 Collider가 정의하는 단순화된 형태(primitive shape)를 기준으로 계산됩니다. 이는 성능 때문입니다 — 복잡한 3D 모델의 정확한 표면끼리 매 프레임 충돌을 계산하면 연산량이 폭발적으로 늘어나므로, 박스나 구 같은 단순 도형으로 근사해서 빠르게 판정합니다.

---

## 2. Collider의 종류

| Collider | 형태 | 연산 비용 | 주 용도 |
|---|---|---|---|
| Box Collider | 직육면체 | 낮음 | 상자, 벽, 바닥, 플랫폼 |
| Sphere Collider | 구 | 가장 낮음 | 공, 총알, 캐릭터 머리 판정 |
| Capsule Collider | 캡슐(원기둥+반구) | 낮음 | 캐릭터 컨트롤러(사람 모양에 가까움) |
| Mesh Collider | 실제 메시 형태 | 높음 | 복잡한 정적 지형, 배경 오브젝트 |
| Wheel Collider | 바퀴 전용 | 중간 | 차량 시뮬레이션 |

Box, Sphere, Capsule은 "Primitive Collider"라고 부르며 수학적으로 계산되기 때문에 매우 빠릅니다. 반면 Mesh Collider는 원본 메시의 정점 정보를 그대로 사용하므로 정확하지만 연산 비용이 훨씬 큽니다.

> 💡 **실무 팁**: 캐릭터에는 Mesh Collider 대신 Capsule Collider를 쓰는 것이 관례입니다. 사람 형태와 비슷하면서도 연산이 훨씬 가볍고, 계단이나 턱에 걸리는 문제도 적기 때문입니다.

Mesh Collider는 기본적으로 `Convex` 옵션이 꺼져 있으면 다른 Mesh Collider와는 충돌하지 못합니다(Non-convex끼리는 충돌 연산이 정의되지 않음). 움직이는 오브젝트에 Mesh Collider를 쓰려면 반드시 `Convex`를 체크해야 하며, 이 경우 실제로는 원본 메시를 감싸는 볼록 껍질(convex hull)로 단순화되어 사용됩니다.

```csharp
// 코드로 Collider 크기 조정하기 (Box Collider 예시)
BoxCollider box = GetComponent<BoxCollider>();
box.size = new Vector3(2f, 1f, 1f);
box.center = new Vector3(0f, 0.5f, 0f);
```

---

## 3. Collision vs Trigger — 밀어낼 것인가, 감지만 할 것인가

Collider의 `Is Trigger` 체크박스 하나로 동작 방식이 완전히 달라집니다.

| 구분 | Collision (충돌) | Trigger (감지) |
|---|---|---|
| Is Trigger | 꺼짐 | 켜짐 |
| 물리적 반응 | 서로 밀어내며 튕겨나감 | 그대로 통과함 |
| 콜백 함수 | `OnCollisionEnter/Stay/Exit` | `OnTriggerEnter/Stay/Exit` |
| 대표 사용처 | 캐릭터-바닥, 공-벽 | 아이템 획득 존, 스테이지 클리어 존, 적 감지 범위 |

두 콜백 모두 최소 한쪽 오브젝트에는 Rigidbody가 있어야 호출됩니다(둘 다 static collider면 Unity가 매 프레임 검사하지 않으므로 이벤트가 발생하지 않음).

```csharp
public class DamageZone : MonoBehaviour
{
    // 물리적으로 부딪혔을 때 (Is Trigger = false)
    private void OnCollisionEnter(Collision collision)
    {
        Debug.Log($"{collision.gameObject.name}와 충돌, 충격력: {collision.relativeVelocity.magnitude}");

        // 충돌 지점(ContactPoint) 정보 활용
        ContactPoint contact = collision.GetContact(0);
        Debug.Log($"충돌 지점: {contact.point}, 법선 벡터: {contact.normal}");
    }

    // 통과하며 감지만 할 때 (Is Trigger = true)
    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            Debug.Log("플레이어가 데미지 존에 진입했습니다.");
        }
    }
}
```

> 💡 **실무 팁**: `other.tag == "Player"` 대신 `other.CompareTag("Player")`를 쓰세요. 문자열 비교(`==`)는 내부적으로 메모리 할당이 발생할 수 있지만, `CompareTag`는 내부적으로 태그 ID를 비교해 가비지 컬렉션 부담이 없습니다.

`OnCollisionStay`/`OnTriggerStay`는 접촉이 유지되는 동안 매 물리 프레임(FixedUpdate 주기) 호출되므로, 지속 데미지 존 같은 기능에 적합하지만 무거운 로직을 넣으면 성능에 영향을 줄 수 있습니다.

---

## 4. 충돌이 감지되려면 필요한 조합

Unity의 충돌 이벤트는 아래 표의 조합에 따라 호출 여부가 달라집니다. 특히 초보자가 자주 겪는 "OnTriggerEnter가 호출이 안 돼요" 문제의 대부분이 이 표 때문입니다.

| A 오브젝트 | B 오브젝트 | 이벤트 발생 여부 |
|---|---|---|
| Rigidbody + Collider | Collider만 (static) | ✅ 발생 |
| Rigidbody + Collider | Rigidbody + Collider | ✅ 발생 |
| Collider만 (static) | Collider만 (static) | ❌ 발생 안 함 |
| Rigidbody(Kinematic) + Collider | Rigidbody + Collider | ✅ 발생 |

즉, 최소 한쪽에는 **움직일 수 있는(Kinematic이든 아니든) Rigidbody**가 붙어 있어야 합니다. 예를 들어 바닥과 벽처럼 둘 다 정적인 오브젝트끼리는 충돌 이벤트 자체가 발생하지 않습니다 — Unity가 애초에 두 static collider 쌍을 매 프레임 검사 대상에서 제외하기 때문입니다.

또한 두 Collider 모두 Trigger인 경우 `OnTriggerEnter`만 호출되고, 하나는 Trigger이고 하나는 일반 Collider인 경우에도 `OnTriggerEnter`가 호출됩니다(Trigger가 하나라도 있으면 물리적 충돌이 아니라 감지로 처리).

---

## 5. Collision Detection Mode — 빠른 물체가 벽을 통과하는 문제

총알이나 빠르게 움직이는 오브젝트가 얇은 벽을 그대로 뚫고 지나가는 현상을 "터널링(Tunneling)"이라고 합니다. 원인은 Unity의 물리 연산이 고정된 시간 간격(FixedUpdate)마다 이산적으로(discrete) 위치를 검사하기 때문입니다 — 한 프레임 전에는 벽 앞에, 다음 프레임에는 이미 벽을 지나쳐 있으면 그 사이 충돌을 놓칩니다.

Rigidbody의 `Collision Detection` 옵션으로 해결합니다.

| 모드 | 설명 | 비용 | 사용 시점 |
|---|---|---|---|
| Discrete | 기본값, 프레임 단위로 위치만 검사 | 낮음 | 대부분의 일반 오브젝트 |
| Continuous | 정적 Collider에 대해 연속 충돌 감지 | 중간 | 벽, 바닥과의 터널링 방지 |
| Continuous Dynamic | 다른 Continuous Rigidbody와도 연속 감지 | 높음 | 빠른 발사체끼리 충돌 (총알, 미사일) |
| Continuous Speculative | 예측 기반의 저비용 연속 감지 | 낮음~중간 | Unity가 권장하는 범용 대안 |

```csharp
Rigidbody bulletRb = GetComponent<Rigidbody>();
bulletRb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
```

> 💡 **실무 팁**: 모든 오브젝트를 Continuous로 설정하면 성능이 크게 떨어집니다. 빠르게 움직이는 소수의 오브젝트(총알, 공)에만 적용하고, 벽·바닥처럼 정적인 오브젝트는 기본값(Discrete)으로 두세요.

---

## 6. Layer Collision Matrix로 충돌 대상 제어하기

모든 오브젝트가 서로 충돌 검사를 하면 낭비입니다. 예를 들어 "적의 공격 판정"과 "아군의 공격 판정"이 서로 부딪힐 필요는 없습니다. Unity는 GameObject에 **Layer**를 지정하고, `Edit > Project Settings > Physics`의 **Layer Collision Matrix**에서 어떤 레이어끼리 충돌 연산을 수행할지 체크박스로 설정할 수 있습니다.

이 매트릭스에서 체크를 해제한 레이어 조합은 물리 엔진이 애초에 충돌 검사 대상에서 제외하므로, 불필요한 연산을 줄이는 최적화 효과도 있습니다.

```csharp
// 코드에서 특정 레이어만 골라 Raycast 하기
int enemyLayerMask = LayerMask.GetMask("Enemy");

if (Physics.Raycast(transform.position, transform.forward, out RaycastHit hit, 10f, enemyLayerMask))
{
    Debug.Log($"레이어 필터링된 적 감지: {hit.collider.name}");
}
```

`Physics.Raycast`, `Physics.SphereCast`, `Physics.OverlapSphere` 같은 물리 쿼리 함수들도 마지막 인자로 LayerMask를 받아, 특정 레이어의 Collider만 감지 대상으로 좁힐 수 있습니다. 적 감지, 상호작용 가능한 오브젝트 탐색 등에 자주 쓰입니다.

---

## 📝 핵심 요약

1. Rigidbody가 "움직임"을 담당한다면 Collider는 "충돌 경계"를 정의하며, 캐릭터에는 연산이 가볍고 사람 형태에 가까운 Capsule Collider가 관례적으로 쓰인다
2. Is Trigger 설정에 따라 물리적으로 밀어내는 `OnCollisionEnter`와 통과하며 감지만 하는 `OnTriggerEnter`로 나뉘며, 충돌 이벤트는 최소 한쪽에 Rigidbody가 있어야 발생한다
3. 정적 Collider끼리는 충돌 이벤트가 발생하지 않는다는 점이 초보자가 자주 겪는 함정이다
4. 빠른 오브젝트의 터널링 문제는 Collision Detection Mode를 Continuous 계열로 바꿔 해결하되, 성능을 위해 필요한 오브젝트에만 선택적으로 적용해야 한다
5. Layer Collision Matrix와 LayerMask를 활용하면 불필요한 충돌 연산을 줄이고 Raycast 등의 쿼리 대상을 원하는 레이어로 좁힐 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Colliders](https://docs.unity3d.com/Manual/CollidersOverview.html)
- [Unity Manual — Collision and Trigger Messages](https://docs.unity3d.com/Manual/CollidersOverview.html)
- [Unity Scripting API — Rigidbody.collisionDetectionMode](https://docs.unity3d.com/ScriptReference/Rigidbody-collisionDetectionMode.html)

---

*⬅️ 이전: [Day 08 — Rigidbody와 물리 엔진 기초](../day-08/)  |  다음: [Day 10 — Unity UI 시스템(Canvas, UI 요소) 기초](../day-10/) ➡️*
