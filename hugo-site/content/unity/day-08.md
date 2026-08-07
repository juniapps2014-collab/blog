---
title: "Day 08 — Rigidbody와 물리 엔진 기초"
date: 2026-08-07
weight: 8
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Rigidbody 컴포넌트의 주요 속성(Mass, Drag, Is Kinematic 등)이 물리 시뮬레이션에 미치는 영향을 설명할 수 있다
- `AddForce`와 `velocity` 직접 대입의 차이를 이해하고, 상황에 맞는 ForceMode를 선택할 수 있다
- Day 07의 Transform 기반 이동 스크립트를 Rigidbody 기반으로 전환해 물리적으로 자연스러운 이동을 구현할 수 있다

---

## 1. Rigidbody란 무엇인가 — Transform 이동과의 차이

Day 07에서 `transform.position += direction * moveSpeed * Time.fixedDeltaTime;` 방식으로 공을 이동시켰습니다. 이 방식은 벽을 그냥 뚫고 지나가고, 충돌해도 아무 반응이 없었습니다. 이유는 간단합니다 — **Transform을 직접 옮기는 것은 물리 엔진에게 아무것도 알리지 않기 때문**입니다.

Rigidbody(리지드바디)는 GameObject를 Unity의 물리 엔진(PhysX) 시뮬레이션에 편입시키는 컴포넌트입니다. Rigidbody가 붙은 오브젝트는:

- 중력의 영향을 받고
- 다른 Collider와 충돌하면 물리적으로 반응하고(밀리기, 튕기기 등)
- 힘(Force)과 토크(Torque)를 가해 움직일 수 있습니다

| | Transform만 사용 | Rigidbody 사용 |
|---|---|---|
| 이동 방식 | `transform.position` 직접 수정 | `AddForce()` / `velocity` / `MovePosition()` |
| 충돌 반응 | 없음 (겹쳐도 그냥 통과) | PhysX가 자동으로 충돌 반응 계산 |
| 중력 | 직접 코드로 구현해야 함 | `useGravity`만 켜면 자동 적용 |
| 적합한 대상 | UI, 카메라, 순수 애니메이션 오브젝트 | 캐릭터, 물체, 발사체처럼 물리 법칙을 따라야 하는 오브젝트 |

> 💡 **실무 팁**: "이 오브젝트가 물리 법칙(중력, 충돌, 마찰)을 따라야 하는가?"가 Rigidbody 부착 여부를 결정하는 기준입니다. 메뉴 버튼처럼 물리와 무관한 오브젝트에 Rigidbody를 붙이는 것은 불필요한 연산 낭비입니다.

---

## 2. Rigidbody 컴포넌트의 주요 속성

Inspector에서 Rigidbody를 추가(Add Component → Physics → Rigidbody)하면 다음 속성들을 볼 수 있습니다.

| 속성 | 역할 | 실무 감각 |
|---|---|---|
| **Mass** | 질량(kg 단위 개념) | 충돌 시 상대적 힘의 크기에 영향. 절대값보다 오브젝트 간 "비율"이 중요 |
| **Drag** | 선형 이동에 대한 공기 저항 | 값이 클수록 힘을 줘도 빨리 멈춤. 0이면 저항 없이 미끄러짐 |
| **Angular Drag** | 회전에 대한 저항 | 회전이 자연스럽게 멈추게 하고 싶을 때 값을 올림 |
| **Use Gravity** | 중력 적용 여부 | 공중에 띄워둘 UI성 오브젝트는 끄는 경우가 많음 |
| **Is Kinematic** | 물리 시뮬레이션에서 제외하고 스크립트로만 제어 | 애니메이션으로 움직이는 문, 플랫폼 등에 사용 |
| **Collision Detection** | 충돌 감지 정밀도 (Discrete / Continuous 등) | 빠르게 움직이는 발사체가 충돌을 "통과"하는 문제(터널링) 방지 |
| **Interpolate** | 렌더링 프레임 사이를 보간 | 물리 스텝과 렌더 프레임 속도가 달라 움직임이 끊겨 보일 때 사용 |

**Is Kinematic의 두 얼굴:**

- `false` (Dynamic) — PhysX가 힘, 중력, 충돌을 모두 계산해서 움직이는 "일반적인" 물리 오브젝트
- `true` (Kinematic) — 물리 힘의 영향을 받지 않고, 오직 스크립트(`Transform` 또는 `MovePosition`)로만 움직임. 대신 다른 Dynamic Rigidbody와 충돌은 여전히 감지되어 상대를 밀어낼 수 있음

> 💡 **실무 팁**: 엘리베이터나 자동으로 열리는 문처럼 "정해진 경로로만 움직이지만 플레이어를 밀어내야 하는" 오브젝트에는 Kinematic Rigidbody + `MovePosition()`을 씁니다. Dynamic으로 두면 다른 물체와 부딪혀 경로가 틀어질 수 있습니다.

---

## 3. 힘을 가하는 방법 — AddForce vs velocity 직접 대입

Rigidbody를 움직이는 방법은 크게 두 갈래로 나뉩니다.

**방법 1: `AddForce()` — 힘을 "누적"시켜 가속**

```csharp
private Rigidbody rb;

private void Awake()
{
    rb = GetComponent<Rigidbody>();
}

private void FixedUpdate()
{
    Vector3 direction = new Vector3(moveInput.x, 0f, moveInput.y);
    rb.AddForce(direction * accelForce, ForceMode.Force);
}
```

`AddForce`는 매 물리 스텝마다 힘을 더해 점진적으로 속도를 올립니다. 가속/감속이 자연스럽고 관성이 느껴지는 이동에 적합합니다.

**방법 2: `velocity` 직접 대입 — 즉각적인 속도 지정**

```csharp
private void FixedUpdate()
{
    Vector3 direction = new Vector3(moveInput.x, 0f, moveInput.y);
    rb.linearVelocity = direction * moveSpeed; // Unity 6 기준, 이전 버전은 rb.velocity
}
```

`velocity`를 직접 대입하면 관성 없이 즉시 원하는 속도로 전환됩니다. 반응성이 중요한 아케이드 스타일 캐릭터 컨트롤에 자주 쓰입니다.

**ForceMode 종류 정리:**

| ForceMode | 질량 고려 | 적용 방식 | 용도 예시 |
|---|---|---|---|
| `Force` | 고려함 | 지속적으로, 프레임마다 누적 | 지속적인 가속 (자동차, 걷기) |
| `Acceleration` | 무시함 | 지속적으로 | 질량과 무관하게 동일한 가속을 주고 싶을 때 |
| `Impulse` | 고려함 | 한 번에 즉시 | 점프, 폭발, 타격 |
| `VelocityChange` | 무시함 | 한 번에 즉시 | 질량과 무관한 즉발성 속도 변화 (점프 높이를 일정하게 유지) |

```csharp
// 점프 구현 예시 - 즉발성 힘이므로 Impulse 사용
if (jumpPressed && isGrounded)
{
    rb.AddForce(Vector3.up * jumpPower, ForceMode.Impulse);
}
```

> 💡 **실무 팁**: 점프처럼 "한 번에 확 튀어 오르는" 동작에 `ForceMode.Force`를 쓰면 매 프레임 힘이 누적되어 의도한 높이보다 훨씬 높이 튀어 오르는 버그가 흔합니다. 순간적인 힘은 반드시 `Impulse` 계열을 사용하세요.

---

## 4. FixedUpdate와 물리 타임스텝

Day 05에서 배운 생명주기 중 `FixedUpdate()`가 왜 물리 처리에 적합한지 다시 짚어봅니다.

- `Update()`는 렌더링 프레임마다 호출되며, 프레임레이트가 60fps든 144fps든 호출 간격이 들쭉날쭉합니다
- `FixedUpdate()`는 **고정된 시간 간격**(기본 0.02초, 즉 50Hz)으로 호출되어 물리 연산의 일관성을 보장합니다
- Rigidbody를 다루는 모든 코드(`AddForce`, `velocity` 대입, `MovePosition`)는 반드시 `FixedUpdate()` 안에서 실행해야 합니다

```
Project Settings → Time → Fixed Timestep (기본값 0.02)
```

> 💡 **실무 팁**: `Update()`에서 Rigidbody를 직접 조작하면 프레임레이트에 따라 물리 반응이 달라지는 미묘한 버그가 생깁니다. "입력 읽기는 Update, 물리 반영은 FixedUpdate"라는 Day 07의 패턴을 계속 유지하세요.

---

## 5. 실습 — PlayerController를 Rigidbody 기반으로 전환

Day 07에서 만든 `PlayerController`를 Rigidbody 기반으로 개선합니다. 입력을 읽는 부분(Update)은 그대로 두고, 이동을 반영하는 부분(FixedUpdate)만 Transform 대신 Rigidbody를 사용하도록 바꿉니다.

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(Rigidbody))]
public class PlayerController : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 4f;
    [SerializeField] private float jumpPower = 5f;

    private Rigidbody rb;
    private InputAction moveAction;
    private Vector2 moveInput;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();

        moveAction = new InputAction("Move", binding: "<Gamepad>/leftStick");
        moveAction.AddCompositeBinding("2DVector")
            .With("Up", "<Keyboard>/w")
            .With("Down", "<Keyboard>/s")
            .With("Left", "<Keyboard>/a")
            .With("Right", "<Keyboard>/d");
    }

    private void OnEnable() => moveAction.Enable();
    private void OnDisable() => moveAction.Disable();

    private void Update()
    {
        moveInput = moveAction.ReadValue<Vector2>();
    }

    private void FixedUpdate()
    {
        // 즉각적인 반응이 필요한 아케이드 스타일 이동 -> velocity 직접 대입
        Vector3 direction = new Vector3(moveInput.x, 0f, moveInput.y);
        Vector3 horizontalVelocity = direction * moveSpeed;

        // y축(수직) 속도는 유지하고 수평 속도만 갱신 (중력/점프와 충돌 방지)
        rb.linearVelocity = new Vector3(horizontalVelocity.x, rb.linearVelocity.y, horizontalVelocity.z);
    }
}
```

바뀐 부분을 Day 07 코드와 비교하면:

1. `Transform`으로 직접 위치를 옮기던 코드가 `rb.linearVelocity` 대입으로 교체됨
2. 이제 벽(Wall)에 Collider만 있어도 물리적으로 충돌해 막힘 — Day 09에서 이 부분을 더 깊이 다룹니다
3. 중력이 자동 적용되므로 바닥(Floor)에 안착하는 동작도 별도 코드 없이 처리됨

> 💡 **실무 팁**: 수평 이동 속도를 갱신할 때 y축 속도를 `rb.linearVelocity.y`로 그대로 유지하는 패턴은 매우 흔합니다. 이걸 빼먹고 y까지 덮어써버리면 중력이 무시되거나 점프한 순간 이동 입력이 수직 속도를 지워버리는 버그가 생깁니다.

---

## 📝 핵심 요약

1. Transform 직접 조작은 물리 엔진과 무관하게 움직이지만, Rigidbody는 중력·충돌·힘을 모두 PhysX 시뮬레이션에 맡긴다
2. Mass, Drag, Is Kinematic 등 Rigidbody 속성은 오브젝트가 "얼마나 물리적으로 반응하는가"를 결정한다
3. 지속적인 가속에는 `ForceMode.Force`, 점프처럼 즉발성 힘에는 `ForceMode.Impulse`를 사용한다
4. Rigidbody 관련 코드는 반드시 `FixedUpdate()` 안에서 실행해야 프레임레이트와 무관하게 일관된 물리 반응을 얻는다
5. 수평 이동 속도만 갱신할 때는 y축 속도를 보존해야 중력/점프와 충돌하지 않는다

---

## 🔗 참고 자료

- [Unity Manual — Rigidbody](https://docs.unity3d.com/Manual/class-Rigidbody.html)
- [Unity Scripting API — Rigidbody.AddForce](https://docs.unity3d.com/ScriptReference/Rigidbody.AddForce.html)
- [Unity Manual — Time and Fixed Timestep](https://docs.unity3d.com/Manual/TimeFrameManagement.html)

---

*⬅️ 이전: [Day 07 — 1주차 정리: 미니 씬 만들기 실습](../day-07/)  |  다음: [Day 09 — Collider와 충돌 감지](../day-09/) ➡️*
