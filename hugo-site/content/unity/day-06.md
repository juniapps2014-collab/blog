---
title: "Day 06 — Unity Input System 기초"
date: 2026-08-05
weight: 6
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 레거시 `Input` 클래스와 새 Input System 패키지의 구조적 차이를 설명할 수 있다
- Input Actions 에셋에서 Action Map, Action, Binding의 관계를 이해하고 직접 구성할 수 있다
- `PlayerInput` 컴포넌트와 C# 이벤트 콜백을 이용해 키보드/게임패드 입력을 코드로 받아 처리할 수 있다

---

## 1. 레거시 Input vs 새 Input System — 왜 갈아탔는가

Unity에는 입력을 다루는 두 가지 체계가 존재합니다. 하나는 오래된 `UnityEngine.Input` 클래스(레거시), 다른 하나는 별도 패키지로 설치하는 **Input System**(`com.unity.inputsystem`)입니다.

```csharp
// 레거시 방식 — Update()에서 매 프레임 직접 폴링(polling)
using UnityEngine;

public class LegacyMovement : MonoBehaviour
{
    private void Update()
    {
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        transform.Translate(new Vector3(h, 0f, v) * Time.deltaTime * 5f);

        if (Input.GetKeyDown(KeyCode.Space))
        {
            Debug.Log("점프!");
        }
    }
}
```

레거시 방식은 간단하지만 몇 가지 한계가 있습니다. 키보드/마우스/게임패드/터치를 각각 다른 API로 처리해야 하고, "Horizontal"/"Vertical" 같은 축 이름은 **Project Settings > Input Manager**에 미리 등록해야 하며, 디바이스가 늘어날수록 분기 코드가 눈덩이처럼 커집니다.

새 Input System은 이 문제를 **데이터(Input Actions 에셋)와 코드(콜백)를 분리**하는 방식으로 해결합니다. "이동", "점프" 같은 의미 단위의 Action을 정의하고, 어떤 물리적 키/버튼이 그 Action을 트리거하는지는 Binding으로 매핑합니다. 코드는 "점프 Action이 눌렸다"는 이벤트만 받으면 되고, 실제로 스페이스바인지 게임패드 A 버튼인지는 신경 쓸 필요가 없습니다.

| 구분 | 레거시 Input | 새 Input System |
|---|---|---|
| 방식 | 폴링(매 프레임 상태 확인) | 이벤트 기반 + 폴링 둘 다 지원 |
| 디바이스 추상화 | 키보드/게임패드 API가 제각각 | Action 하나에 여러 디바이스 매핑 가능 |
| 리바인딩(키 재설정) | 직접 구현 필요 | `InputActionRebindingExtensions` 내장 지원 |
| 설정 방식 | Project Settings (텍스트 기반 축 이름) | Input Actions 에셋 (에디터 UI) |
| 설치 | Unity 기본 내장 | Package Manager로 별도 설치 |

> 💡 **실무 팁**: 새 프로젝트라면 특별한 이유가 없는 한 새 Input System을 기본으로 선택하는 것이 좋습니다. 레거시 방식은 유지보수 목적으로만 남아있고, 멀티플랫폼(게임패드, 모바일 터치, VR 컨트롤러)을 조금이라도 고려한다면 새 시스템의 디바이스 추상화가 훨씬 유리합니다.

---

## 2. Input System 패키지 설치와 Input Actions 에셋 만들기

**설치 경로**: `Window > Package Manager` → 좌측 상단 `Unity Registry` 선택 → 검색창에 `Input System` 입력 → `Install`.

설치 후 Unity가 "Input Handling을 새 시스템으로 전환하려면 재시작이 필요합니다"라는 팝업을 띄웁니다. `Project Settings > Player > Active Input Handling`에서 다음 세 옵션 중 하나를 고를 수 있습니다.

| 옵션 | 의미 |
|---|---|
| Input Manager (Old) | 레거시 방식만 사용 |
| Input System Package (New) | 새 시스템만 사용 (레거시 `Input.GetKey` 등은 동작 안 함) |
| Both | 두 시스템 동시 사용 가능 (마이그레이션 중 과도기적으로 유용) |

Input Actions 에셋은 실제 입력 매핑을 담는 파일입니다. Project 창에서 우클릭 → `Create > Input Actions`로 생성하면 `.inputactions` 파일이 만들어지고, 더블클릭하면 전용 에디터 창이 열립니다.

```
InputActions 에셋 구조
└── Action Maps (예: "Player", "UI")
      └── Actions (예: "Move", "Jump", "Fire")
            └── Bindings (예: WASD, 게임패드 좌스틱, 터치 조이스틱)
```

- **Action Map**: 관련 있는 Action들을 묶는 그룹입니다. 예를 들어 "Player" 맵에는 이동/점프/공격을, "UI" 맵에는 메뉴 탐색용 Action을 따로 묶어 상황에 맞게 활성화/비활성화합니다.
- **Action**: "무엇을 하고 싶은가"를 나타내는 의미 단위입니다. `Move`, `Jump`, `Fire` 등이 여기 해당합니다. Action Type은 `Button`(눌림/떨어짐), `Value`(연속 값, 예: 이동 벡터), `Pass Through`(모든 입력 값을 그대로 전달) 중 선택합니다.
- **Binding**: Action과 실제 물리적 입력을 연결하는 매핑입니다. 하나의 Action에 여러 Binding을 추가해 키보드와 게임패드를 동시에 지원할 수 있습니다.

> 💡 **실무 팁**: `Move` Action은 대부분 `Value` 타입 + `Vector2` Control Type으로 만들고, WASD는 `2D Vector Composite` Binding(Up/Down/Left/Right에 각각 W/S/A/D를 지정)으로 구성하는 것이 표준적인 패턴입니다. 이렇게 하면 게임패드 좌스틱 Binding을 추가해도 코드 한 줄도 바꿀 필요가 없습니다.

---

## 3. PlayerInput 컴포넌트로 코드와 연결하기

Input Actions 에셋을 만들었다면, 이를 GameObject에 실제로 연결하는 가장 쉬운 방법은 `PlayerInput` 컴포넌트입니다. GameObject를 선택하고 `Add Component > Input > Player Input`을 추가한 뒤, Inspector에서 방금 만든 `.inputactions` 에셋을 `Actions` 필드에 지정합니다.

`PlayerInput`의 Behavior 설정에는 두 가지 주요 방식이 있습니다.

| Behavior | 동작 |
|---|---|
| Send Messages | Action 이름 + "On" 접두사로 만들어진 함수(예: `OnMove`, `OnJump`)를 같은 GameObject의 컴포넌트에서 자동 호출 |
| Invoke C# Events | `PlayerInput.actions["Move"].performed` 같은 C# 이벤트에 직접 구독 |

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

// Behavior를 "Send Messages"로 설정했을 때의 콜백 방식
public class PlayerController : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    private Vector2 moveInput;
    private Rigidbody rb;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    // Action 이름이 "Move"면 Unity가 "OnMove(InputValue)"를 자동으로 찾아 호출한다
    private void OnMove(InputValue value)
    {
        moveInput = value.Get<Vector2>();
    }

    private void OnJump(InputValue value)
    {
        if (value.isPressed)
        {
            rb.AddForce(Vector3.up * 5f, ForceMode.Impulse);
        }
    }

    private void FixedUpdate()
    {
        Vector3 move = new Vector3(moveInput.x, 0f, moveInput.y) * moveSpeed * Time.fixedDeltaTime;
        rb.MovePosition(rb.position + move);
    }
}
```

Send Messages 방식은 메서드 이름 규칙만 지키면 되어 빠르게 시작하기 좋지만, 이름이 어긋나면 컴파일 에러 없이 조용히 호출되지 않는다는 단점이 있습니다. 더 명시적이고 안전한 방식은 C# 이벤트를 직접 구독하는 것입니다.

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerControllerEvents : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private InputActionReference moveAction;
    [SerializeField] private InputActionReference jumpAction;

    private Vector2 moveInput;
    private Rigidbody rb;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    private void OnEnable()
    {
        moveAction.action.performed += OnMovePerformed;
        moveAction.action.canceled += OnMoveCanceled;
        jumpAction.action.performed += OnJumpPerformed;
    }

    private void OnDisable()
    {
        // OnEnable에서 구독한 이벤트는 반드시 OnDisable에서 해제 (Day 05 참고)
        moveAction.action.performed -= OnMovePerformed;
        moveAction.action.canceled -= OnMoveCanceled;
        jumpAction.action.performed -= OnJumpPerformed;
    }

    private void OnMovePerformed(InputAction.CallbackContext ctx) => moveInput = ctx.ReadValue<Vector2>();
    private void OnMoveCanceled(InputAction.CallbackContext ctx) => moveInput = Vector2.zero;
    private void OnJumpPerformed(InputAction.CallbackContext ctx) => rb.AddForce(Vector3.up * 5f, ForceMode.Impulse);

    private void FixedUpdate()
    {
        Vector3 move = new Vector3(moveInput.x, 0f, moveInput.y) * moveSpeed * Time.fixedDeltaTime;
        rb.MovePosition(rb.position + move);
    }
}
```

`InputAction.CallbackContext`에는 `started`(입력 시작), `performed`(값이 유효 조건을 만족한 시점), `canceled`(입력 종료) 세 가지 이벤트 단계가 있습니다. 버튼이라면 `performed`는 누른 순간, `canceled`는 뗀 순간에 대응합니다.

> 💡 **실무 팁**: Send Messages는 프로토타이핑 단계에서 빠르게 동작을 확인할 때, C# 이벤트 구독은 실제 제품 코드에서 명시적이고 타입 안전한 연결이 필요할 때 사용하는 것이 일반적인 구분입니다. 팀 프로젝트라면 후자를 기본값으로 두는 것을 권장합니다.

---

## 4. Action Map 전환 — 상황별 입력 활성화

게임에는 보통 "플레이 중"과 "메뉴/UI 조작 중"처럼 서로 다른 입력 맥락이 존재합니다. 이때 Action Map을 여러 개 만들고 상황에 따라 활성화/비활성화하면 충돌 없이 관리할 수 있습니다.

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class InputMapSwitcher : MonoBehaviour
{
    [SerializeField] private PlayerInput playerInput;

    public void EnterGameplay()
    {
        // "UI" 맵을 끄고 "Player" 맵을 켜서, 메뉴 탐색 입력과 이동 입력이 동시에 반응하지 않게 한다
        playerInput.SwitchCurrentActionMap("Player");
    }

    public void EnterMenu()
    {
        playerInput.SwitchCurrentActionMap("UI");
    }
}
```

`PlayerInput`은 기본적으로 `Default Map`으로 지정한 맵만 활성화된 상태로 시작합니다. `SwitchCurrentActionMap()`을 호출하면 이전 맵은 비활성화되고 지정한 맵만 활성화되어, 예를 들어 일시정지 메뉴가 열려 있는 동안 캐릭터가 이동하는 문제를 방지할 수 있습니다.

또한 Input Actions 에셋에는 **Control Scheme**(예: "Keyboard&Mouse", "Gamepad")을 정의할 수 있어, 어떤 디바이스가 연결되어 있는지에 따라 자동으로 적절한 Binding 그룹을 사용하게 만들 수도 있습니다. `PlayerInput`의 `onControlsChanged` 이벤트를 구독하면 디바이스가 바뀔 때(예: 키보드로 플레이하다가 게임패드를 연결) UI 힌트("스페이스바" → "A 버튼")를 실시간으로 갱신하는 것도 가능합니다.

---

## 📝 핵심 요약

1. 새 Input System은 "Action(의미)"과 "Binding(실제 입력)"을 분리해, 디바이스가 늘어나도 코드를 바꾸지 않고 대응할 수 있게 한다
2. Input Actions 에셋은 Action Map → Action → Binding의 계층 구조로 구성되며, `Move`처럼 연속 값이 필요한 Action은 `Value` 타입 + Vector2 Composite Binding으로 만드는 것이 표준 패턴이다
3. `PlayerInput` 컴포넌트는 Send Messages(간단, 이름 규칙 기반)와 C# 이벤트 구독(명시적, 타입 안전) 두 방식으로 Action을 코드와 연결할 수 있다
4. `started`/`performed`/`canceled` 세 단계로 입력의 생명주기를 세밀하게 다룰 수 있으며, 이벤트 구독은 OnEnable/OnDisable로 짝을 맞춰야 한다
5. Action Map을 상황별로 나누고 `SwitchCurrentActionMap()`으로 전환하면 플레이 중 입력과 UI 입력이 충돌하지 않는다

---

## 🔗 참고 자료

- [Input System 공식 매뉴얼](https://docs.unity3d.com/Packages/com.unity.inputsystem@latest)
- [PlayerInput 컴포넌트 문서](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.7/manual/PlayerInput.html)
- [InputAction 스크립팅 API](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.7/api/UnityEngine.InputSystem.InputAction.html)

---

*⬅️ 이전: [Day 05 — 기본 C# 스크립팅 - MonoBehaviour 생명주기](../day-05/)  |  다음: [Day 07 — 1주차 정리: 미니 씬 만들기 실습](../day-07/) ➡️*
