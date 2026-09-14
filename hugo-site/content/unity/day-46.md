---
title: "Day 46 — Ragdoll Physics와 물리 기반 애니메이션"
date: 2026-09-14
weight: 46
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Ragdoll이 필요한 이유와 Animator 기반 애니메이션과의 근본적인 차이를 설명할 수 있다
- Ragdoll Wizard로 휴머노이드 캐릭터에 Rigidbody/Collider/Joint를 구성하고 물리 시뮬레이션을 동작시킬 수 있다
- 애니메이션과 물리를 전환·혼합하는 실전 패턴(사망 처리, 피격 리액션, Get Up)을 구현할 수 있다

---

## 1. Ragdoll이 필요한 이유

지금까지 다룬 캐릭터 애니메이션(Day 31~35)은 전부 **미리 만들어진 동작을 재생**하는 방식이었습니다. 걷기, 뛰기, 점프 — 모두 애니메이터가 손으로 키프레임을 찍거나 모션 캡처로 녹화한 고정된 데이터입니다.

문제는 "예측 불가능한 물리적 사건"입니다. 캐릭터가 폭발에 맞아 날아가거나, 계단에서 굴러 떨어지거나, 총에 맞아 쓰러지는 상황은 경우의 수가 무한합니다. 이걸 전부 애니메이션 클립으로 미리 만드는 건 불가능합니다.

**Ragdoll**은 이 문제를 "캐릭터의 뼈대(Bone) 하나하나를 Rigidbody로 만들어 물리 엔진이 직접 계산하게" 하는 방식으로 해결합니다. 애니메이션이 아니라 중력, 충돌, 충격량이 캐릭터의 자세를 실시간으로 결정합니다.

| 구분 | Animator 기반 애니메이션 | Ragdoll Physics |
|---|---|---|
| 동작 결정 방식 | 미리 제작된 클립 재생 | 물리 시뮬레이션(중력/충돌/힘) |
| 예측 가능성 | 항상 동일하게 재생됨 | 매번 다르게 반응(같은 힘을 줘도 결과가 미묘하게 다를 수 있음) |
| 적합한 상황 | 걷기, 공격 모션 등 정형화된 동작 | 사망, 피격 날아감, 추락 등 비정형 반응 |
| 제어 난이도 | 애니메이터/State Machine으로 제어 용이 | Joint 각도 제한, 질량 배분 등 물리 튜닝 필요 |

> 💡 **실무 팁**: Ragdoll은 "죽는 순간"에만 켜는 게 정석입니다. 평소엔 Animator가 캐릭터를 제어하다가, 특정 이벤트(사망, 강한 피격)에서만 물리로 전환하는 하이브리드 구조가 실무 표준입니다.

---

## 2. Ragdoll 뼈대 구성 — Rigidbody, Collider, Joint

Ragdoll의 핵심 구조는 세 가지 컴포넌트의 조합입니다.

1. **Rigidbody**: 각 뼈(팔, 다리, 몸통, 머리 등)마다 하나씩 붙여서 물리 연산의 대상으로 만듭니다.
2. **Collider**: 뼈의 형태에 맞는 충돌 영역(보통 Capsule Collider)을 부여해 다른 오브젝트와 부딪힐 수 있게 합니다.
3. **Character Joint** (또는 Configurable Joint): 인접한 두 뼈를 연결하면서, 관절이 움직일 수 있는 각도 범위를 제한합니다. 이게 없으면 팔다리가 관절 방향과 무관하게 아무렇게나 꺾입니다.

**Ragdoll Wizard 사용법 (`GameObject > 3D Object > Ragdoll...`):**

Unity는 휴머노이드 리그(Day 34에서 다룬 Avatar 설정)에 필요한 Rigidbody/Collider/Joint를 한 번에 세팅해주는 마법사를 제공합니다.

1. 메뉴에서 Ragdoll Wizard를 엽니다.
2. 캐릭터의 각 본(Hips, Spine, Head, 양쪽 UpperArm/LowerArm/Hand, UpperLeg/LowerLeg/Foot 등)을 슬롯에 드래그로 채웁니다.
3. `Create`를 누르면 각 본에 자동으로 Rigidbody, Collider, Character Joint가 생성되고 부모-자식 계층에 맞춰 관절이 연결됩니다.

```csharp
// Ragdoll 전체를 켜고 끄는 유틸리티 스크립트
using UnityEngine;

public class RagdollController : MonoBehaviour
{
    private Rigidbody[] ragdollRigidbodies;
    private Collider[] ragdollColliders;
    private Animator animator;

    void Awake()
    {
        animator = GetComponent<Animator>();
        // 루트 오브젝트를 제외한, 뼈대에 붙은 모든 Rigidbody/Collider를 수집
        ragdollRigidbodies = GetComponentsInChildren<Rigidbody>();
        ragdollColliders = GetComponentsInChildren<Collider>();

        // 시작 시에는 물리 비활성화 (Animator가 제어)
        SetRagdollActive(false);
    }

    public void SetRagdollActive(bool active)
    {
        animator.enabled = !active;

        foreach (var rb in ragdollRigidbodies)
            rb.isKinematic = !active;

        foreach (var col in ragdollColliders)
            col.enabled = active;
    }
}
```

`isKinematic = true`인 Rigidbody는 물리 엔진의 영향을 받지 않고 Transform으로만 움직입니다. 즉 평소엔 `isKinematic = true` + `animator.enabled = true`로 두어 애니메이션이 캐릭터를 제어하다가, Ragdoll을 켤 때 `isKinematic = false` + `animator.enabled = false`로 전환해 물리가 넘겨받게 합니다.

---

## 3. Character Joint 세부 설정 — 관절 각도 제한

Character Joint는 실제 인체 관절처럼 회전 범위를 제한하는 세 가지 각도 값을 가집니다.

| 파라미터 | 의미 | 예시 (팔꿈치) |
|---|---|---|
| Swing 1 Limit | 한 축 방향으로 굽힐 수 있는 최대 각도 | 0° (팔꿈치는 한쪽으로만 굽음) |
| Swing 2 Limit | 다른 축 방향 회전 제한 | 0° |
| Twist Limit (Low/High) | 축을 중심으로 비트는 회전 범위 | -10° ~ 10° |

무릎과 팔꿈치처럼 한 방향으로만 굽는 관절(Hinge)은 Swing Limit을 0에 가깝게, 어깨나 고관절처럼 여러 방향으로 움직이는 관절(Ball-and-socket)은 Swing Limit을 넓게 설정합니다.

```csharp
// 코드로 Character Joint의 각도 제한을 조정하는 예시
CharacterJoint elbowJoint = elbowBone.GetComponent<CharacterJoint>();

SoftJointLimit swing1 = elbowJoint.swing1Limit;
swing1.limit = 5f; // 거의 굽히지 못하게 제한 (팔꿈치는 한 방향으로만 굽음)
elbowJoint.swing1Limit = swing1;
```

> 💡 **실무 팁**: 각도 제한을 너무 느슨하게 두면 캐릭터가 쓰러졌을 때 팔다리가 뒤로 꺾이는 등 부자연스러운 "스파게티 인형" 현상이 생깁니다. 실제 인체 가동 범위를 참고해 보수적으로 좁게 잡는 편이 안전합니다.

---

## 4. 애니메이션 ↔ 물리 전환 실전 패턴

실무에서 Ragdoll은 대부분 아래 세 시나리오 중 하나로 쓰입니다.

**① 완전 사망 처리 (Animator → Ragdoll, 복귀 없음)**

```csharp
void OnDeath()
{
    ragdollController.SetRagdollActive(true);
    // 죽는 순간의 마지막 힘(피격 방향)을 상체에 가해 자연스러운 쓰러짐 연출
    Rigidbody hipsRb = hips.GetComponent<Rigidbody>();
    hipsRb.AddForce(hitDirection * hitForce, ForceMode.Impulse);
}
```

**② 넉백 후 재기립 (Animator → Ragdoll → Animator, "Get Up")**

강한 피격으로 잠깐 쓰러졌다가 다시 일어나는 연출입니다. 핵심은 Ragdoll이 멈춘 뒤 캐릭터의 실제 자세(엎어졌는지 뒤집혔는지)를 판별해 알맞은 Get Up 애니메이션을 선택하는 것입니다.

```csharp
IEnumerator KnockdownRoutine()
{
    ragdollController.SetRagdollActive(true);
    yield return new WaitForSeconds(2f); // Ragdoll이 안정될 때까지 대기

    // 엎어진 방향 판별 (몸통의 forward/up 벡터 내적으로 대략 추정)
    bool faceDown = Vector3.Dot(hips.transform.up, Vector3.up) < 0;

    // 물리 위치/회전을 애니메이션 루트로 되돌리기 위해 임시로 루트 위치 보정
    transform.position = hips.transform.position;

    ragdollController.SetRagdollActive(false);
    animator.SetTrigger(faceDown ? "GetUpFront" : "GetUpBack");
}
```

**③ 부분 Ragdoll (Ragdoll + 상체만 물리, 하체는 Animator 유지)**

Configurable Joint의 `Drive` 기능을 활용하면 관절이 완전히 물리에만 의존하지 않고, 목표 각도(애니메이션 포즈)를 향해 스프링처럼 끌어당기게 만들 수 있습니다. 이 방식은 "맞아도 완전히 쓰러지지 않고 비틀거리는" 연출에 주로 쓰입니다.

> 💡 **실무 팁**: Get Up 애니메이션으로 전환할 때 캐릭터가 순간이동하듯 튀는 현상이 자주 발생합니다. Ragdoll이 멈춘 최종 위치에 루트 본을 맞추고, Animator의 Root Motion을 활용해 자연스럽게 이어지도록 보정하는 작업이 실무에서 가장 손이 많이 가는 부분입니다.

---

## 5. 성능과 안정성 고려사항

Ragdoll은 뼈 개수만큼 Rigidbody와 Joint가 생성되므로(휴머노이드 기준 보통 15~20개) 다수의 캐릭터가 동시에 Ragdoll 상태가 되면 물리 연산 비용이 급격히 늘어납니다.

- **Solver Iteration 조정**: Rigidbody의 `Solver Iterations` 값을 낮추면 관절이 덜 정확하게 계산되지만 성능은 좋아집니다. 다수의 배경 캐릭터에는 낮은 값을, 주인공/보스에는 높은 값을 사용하는 식으로 구분합니다.
- **Collider 단순화**: 각 뼈의 Collider는 정밀한 메시가 아니라 Capsule/Box처럼 단순한 프리미티브를 사용해야 합니다.
- **Ragdoll 개수 제한**: 동시에 활성화되는 Ragdoll 수에 상한을 두고, 오래된 Ragdoll은 일정 시간 후 비활성화하거나 풀(Pool)로 회수합니다.
- **Interpolate 설정**: Rigidbody의 `Interpolate` 옵션을 켜면 물리 프레임과 렌더 프레임 사이의 불일치로 인한 떨림(Jitter)을 줄일 수 있습니다.

---

## 📝 핵심 요약

1. Ragdoll은 애니메이션 클립 재생이 아니라 뼈대 각각을 Rigidbody로 만들어 물리 엔진이 자세를 실시간 계산하게 하는 기법이며, 예측 불가능한 반응(사망, 피격, 추락)에 적합하다
2. Ragdoll Wizard로 휴머노이드 리그에 Rigidbody/Collider/Character Joint를 자동 구성할 수 있고, `isKinematic` 토글로 Animator 제어와 물리 제어를 전환한다
3. Character Joint의 Swing/Twist Limit으로 실제 관절 가동 범위를 제한해야 자연스러운 쓰러짐을 만들 수 있다
4. 실무에서는 완전 사망, 넉백 후 재기립(Get Up), Configurable Joint Drive를 이용한 부분 Ragdoll 세 가지 패턴이 자주 쓰인다
5. 다수 캐릭터의 동시 Ragdoll은 비용이 크므로 Solver Iteration, Collider 단순화, 활성 개수 제한으로 성능을 관리해야 한다

---

## 🔗 참고 자료

- [Unity Manual — Ragdoll Wizard](https://docs.unity3d.com/Manual/wizard-RagdollWizard.html)
- [Unity Manual — Character Joint](https://docs.unity3d.com/Manual/class-CharacterJoint.html)
- [Unity Manual — Configurable Joint](https://docs.unity3d.com/Manual/class-ConfigurableJoint.html)

---

*⬅️ 이전: [Day 45 — 오브젝트 상호작용 - 애니메이션 이벤트와 스크립트 연동](../day-45/)  |  다음: [Day 47 — Cinemachine으로 카메라 연출 고도화](../day-47/) ➡️*
