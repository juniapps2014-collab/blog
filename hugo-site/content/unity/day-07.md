---
title: "Day 07 — 1주차 정리: 미니 씬 만들기 실습"
date: 2026-08-06
weight: 7
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Day 01~06에서 배운 GameObject/Transform, Hierarchy, Prefab, MonoBehaviour 생명주기, Input System을 하나의 씬에 통합할 수 있다
- 재사용 가능한 오브젝트를 Prefab으로 설계하고, 스크립트로 플레이어 입력을 게임 로직에 연결할 수 있다
- 작은 규모의 씬이라도 "계층 구조 설계 → 프리팹화 → 스크립팅 → 테스트"의 실무 작업 순서를 스스로 반복할 수 있다

---

## 1. 이번 주 배운 개념 정리와 오늘의 목표

1주차에서 다룬 내용을 표로 정리하면 다음과 같습니다.

| Day | 주제 | 오늘 실습에서의 역할 |
|---|---|---|
| 01 | Unity 에디터 인터페이스 | Scene/Game/Inspector/Hierarchy 창을 오가며 작업 |
| 02 | GameObject와 Transform | 공, 바닥, 장애물의 위치·회전·크기 배치 |
| 03 | Scene 구성과 Hierarchy | 오브젝트를 논리적 그룹(폴더처럼)으로 정리 |
| 04 | Prefab | 장애물과 체크포인트를 재사용 가능한 단위로 제작 |
| 05 | MonoBehaviour 생명주기 | `Awake`/`Start`/`Update`/`FixedUpdate` 활용 |
| 06 | Input System | 방향키/WASD로 공을 굴리는 입력 처리 |

오늘 만들 것은 **"공을 굴려 목표 지점(체크포인트)까지 이동시키는 미니 씬"** 입니다. 복잡한 게임 로직 없이, 지금까지 배운 개념을 "눈에 보이는 결과물"로 엮는 것이 목적입니다.

> 💡 **실무 팁**: 실무에서도 스프린트 말미에 "그 동안 만든 기능을 하나의 데모 씬으로 통합"하는 작업을 자주 합니다. 오늘 실습은 그 축소판이라고 생각하면 됩니다.

---

## 2. 씬 설계와 Hierarchy 구조 잡기

먼저 Hierarchy를 아래처럼 빈 GameObject(폴더 역할)로 구조화합니다. Day 03에서 배운 것처럼, 실제 로직이 없는 빈 GameObject를 그룹핑 용도로 쓰는 것은 흔한 관례입니다.

```
MiniScene (Hierarchy)
├── --- ENVIRONMENT ---   (빈 GameObject, 구분용 헤더)
│   ├── Floor              (Plane, Transform: Scale 5,1,5)
│   └── Walls              (빈 GameObject로 그룹핑)
│       ├── Wall_North
│       ├── Wall_South
│       ├── Wall_East
│       └── Wall_West
├── --- GAMEPLAY ---
│   ├── Player (Sphere)
│   ├── Obstacles           (빈 GameObject로 그룹핑)
│   │   ├── Obstacle_Prefab (Clone) x N
│   └── Checkpoint_Prefab (Clone)
├── --- SYSTEM ---
│   ├── GameManager
│   └── Main Camera
└── Directional Light
```

바닥(Floor)은 Plane, 벽(Wall)은 늘린 Cube, 플레이어는 Sphere로 충분합니다. 지금은 3D 모델링 이전 단계이므로 기본 도형(Primitive)만 사용합니다.

**Transform 배치 체크리스트 (Day 02 복습):**

- Floor의 Position은 `(0, 0, 0)`, Scale은 바닥 크기에 맞게 조정
- 각 Wall은 Floor 가장자리에 맞춰 Position/Rotation/Scale을 개별 조정 (부모를 `Walls`로 지정하면 로컬 좌표 기준으로 관리하기 쉬움)
- Player의 초기 Position은 시작 지점, Checkpoint는 목표 지점에 배치

> 💡 **실무 팁**: Wall처럼 비슷한 오브젝트가 여러 개일 때는 하나를 완성한 뒤 Ctrl+D(복제)로 늘리고 위치만 조정하는 것이 빠릅니다. 다만 이런 반복 요소가 앞으로도 계속 쓰인다면 Prefab으로 만드는 편이 낫습니다 — 그게 다음 섹션 내용입니다.

---

## 3. Obstacle와 Checkpoint를 Prefab으로 만들기

Day 04에서 배운 Prefab 워크플로우를 그대로 적용합니다. 장애물(Obstacle)과 체크포인트(Checkpoint)는 씬에 여러 개 배치될 가능성이 높은 오브젝트이므로 Prefab 후보로 적합합니다.

**Obstacle Prefab 만드는 순서:**

1. Hierarchy에 Cube를 하나 생성하고 이름을 `Obstacle`로 변경
2. Inspector에서 Material 색상을 빨간 계열로 지정해 "피해야 할 대상"임을 시각적으로 표시
3. `Assets/Prefabs/` 폴더로 드래그하여 Prefab 애셋 생성
4. 씬에 남은 `Obstacle` 인스턴스를 필요한 개수만큼 복제 배치

**Checkpoint Prefab에는 트리거 로직을 추가합니다:**

```csharp
using UnityEngine;

public class Checkpoint : MonoBehaviour
{
    [SerializeField] private string playerTag = "Player";

    private void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag(playerTag)) return;

        Debug.Log("체크포인트 도달! 미니 씬 클리어");
        // Day 09에서 배울 Collider 심화 내용과 연결되는 지점입니다.
    }
}
```

Checkpoint의 Collider 컴포넌트에서 `Is Trigger`를 체크해야 `OnTriggerEnter`가 호출됩니다. 이 부분은 Day 09(Collider와 충돌 감지)에서 자세히 다룰 예정이니, 오늘은 "트리거 체크박스를 켜면 물리적으로 막지 않으면서 겹침을 감지할 수 있다" 정도만 이해하고 넘어가도 충분합니다.

> 💡 **실무 팁**: 프리팹을 수정할 때는 씬에 있는 인스턴스가 아니라 Project 창의 원본 Prefab 애셋을 더블클릭해 Prefab 편집 모드로 들어가서 고치는 습관을 들이세요. 인스턴스에서 고치면 "오버라이드"가 걸려 나중에 헷갈립니다.

---

## 4. PlayerController 스크립트 — 생명주기와 Input System 결합

Day 05의 MonoBehaviour 생명주기와 Day 06의 Input System을 하나의 스크립트에서 결합합니다. `Rigidbody`는 Day 08에서 본격적으로 다루므로, 오늘은 `Transform`을 직접 이동시키는 단순한 방식으로 구현합니다.

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(Transform))]
public class PlayerController : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 4f;

    private InputAction moveAction;
    private Vector2 moveInput;

    // 생명주기 1: 컴포넌트가 활성화되기 전, 참조를 준비하는 단계
    private void Awake()
    {
        moveAction = new InputAction("Move", binding: "<Gamepad>/leftStick");
        moveAction.AddCompositeBinding("2DVector")
            .With("Up", "<Keyboard>/w")
            .With("Down", "<Keyboard>/s")
            .With("Left", "<Keyboard>/a")
            .With("Right", "<Keyboard>/d");
    }

    // 생명주기 2: 입력 액션은 반드시 Enable을 호출해야 값을 읽을 수 있음
    private void OnEnable() => moveAction.Enable();
    private void OnDisable() => moveAction.Disable();

    // 생명주기 3: 매 프레임 입력값만 읽어서 저장 (가벼운 처리만)
    private void Update()
    {
        moveInput = moveAction.ReadValue<Vector2>();
    }

    // 생명주기 4: 실제 이동은 물리 타이밍에 맞춰 처리 (Day 08 예고편)
    private void FixedUpdate()
    {
        Vector3 direction = new Vector3(moveInput.x, 0f, moveInput.y);
        transform.position += direction * moveSpeed * Time.fixedDeltaTime;
    }
}
```

**이 스크립트에서 다시 짚어야 할 Day 05~06 개념:**

| 생명주기 함수 | 이번 실습에서의 역할 |
|---|---|
| `Awake()` | InputAction 객체를 생성하고 바인딩을 구성 (다른 오브젝트보다 먼저 실행 보장) |
| `OnEnable()` / `OnDisable()` | InputAction은 명시적으로 Enable하지 않으면 값을 읽지 못함 |
| `Update()` | 입력값을 읽는 것처럼 "가벼운" 처리에 적합 |
| `FixedUpdate()` | 실제 이동/물리 연산처럼 "일정한 시간 간격"이 중요한 처리에 적합 |

> 💡 **실무 팁**: `Update()`에서 이동 로직을 직접 넣지 않고 입력값만 저장한 뒤 `FixedUpdate()`에서 실제로 움직이는 패턴은 실무에서도 자주 쓰입니다. 프레임레이트가 들쭉날쭉해도 이동이 일관되게 처리되기 때문입니다.

---

## 5. 최종 점검 체크리스트

씬을 Play 모드로 실행하기 전에 아래 항목을 확인합니다.

1. Player에 `PlayerController` 스크립트가 붙어 있고, Tag가 `Player`로 설정되어 있는가
2. Checkpoint Prefab의 Collider에 `Is Trigger`가 체크되어 있는가
3. WASD 입력 시 Console 창에 별도 에러 없이 공이 매끄럽게 이동하는가
4. 체크포인트에 닿았을 때 Console에 "체크포인트 도달!" 로그가 출력되는가
5. Hierarchy가 ENVIRONMENT / GAMEPLAY / SYSTEM 그룹으로 깔끔하게 정리되어 있는가

이 다섯 가지가 모두 통과하면 1주차 실습은 완료입니다. Rigidbody 없이 Transform만으로 이동시켰기 때문에 벽을 뚫고 지나가는 등 물리적으로 어색한 부분이 있을 수 있는데, 이는 자연스러운 현상입니다 — Day 08에서 Rigidbody와 물리 엔진을 배우면서 바로 개선하게 됩니다.

---

## 📝 핵심 요약

1. 1주차 실습은 새로운 개념을 배우는 대신, GameObject/Transform·Hierarchy·Prefab·MonoBehaviour·Input System을 하나의 씬으로 통합하는 데 집중한다
2. 반복되는 오브젝트(장애물, 체크포인트)는 Prefab으로 만들어 관리하고, 원본은 Project 창에서 직접 수정하는 습관을 들인다
3. Input System의 값은 `Update()`에서 읽고, 실제 이동/물리 처리는 `FixedUpdate()`에서 수행하는 패턴이 안정적이다
4. 지금은 Transform 기반의 단순 이동이지만, Day 08의 Rigidbody 학습을 거치면 훨씬 자연스러운 물리 기반 이동으로 개선할 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Prefabs](https://docs.unity3d.com/Manual/Prefabs.html)
- [Unity Manual — Execution Order of Event Functions](https://docs.unity3d.com/Manual/ExecutionOrder.html)
- [Unity Input System — Reading Values](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.7/manual/Actions.html)

---

*⬅️ 이전: [Day 06 — Unity Input System 기초](../day-06/)  |  다음: [Day 08 — Rigidbody와 물리 엔진 기초](../day-08/) ➡️*
