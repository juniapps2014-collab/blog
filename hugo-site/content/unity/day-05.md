---
title: "Day 05 — 기본 C# 스크립팅 - MonoBehaviour 생명주기"
date: 2026-08-04
weight: 5
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- `MonoBehaviour`를 상속한 스크립트가 GameObject의 동작을 어떻게 제어하는지 설명할 수 있다
- Awake → OnEnable → Start → Update → FixedUpdate → LateUpdate로 이어지는 생명주기 순서와 각 함수의 용도를 구분할 수 있다
- OnDisable/OnDestroy 시점과 스크립트 실행 순서(Script Execution Order) 설정 방법을 활용할 수 있다

---

## 1. MonoBehaviour란 무엇인가

Unity에서 GameObject에 "행동"을 부여하려면 스크립트를 작성해 Component로 붙여야 합니다. 이때 작성하는 C# 클래스는 반드시 `MonoBehaviour`를 상속해야 Unity 엔진이 인식하고 Inspector에서 GameObject에 드래그해 붙일 수 있습니다.

```csharp
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    // MonoBehaviour를 상속하는 순간 Unity 엔진이
    // 이 클래스의 특정 메서드 이름들을 "생명주기 함수"로 자동 인식한다
}
```

`MonoBehaviour`는 일반 C# 클래스와 달리 직접 `new PlayerController()`로 생성할 수 없습니다. 반드시 GameObject에 Component로 붙이거나(에디터에서 드래그, 또는 `AddComponent<T>()`), Prefab을 `Instantiate()`해야 인스턴스가 생성됩니다. 이는 MonoBehaviour의 생명주기 전체가 "자신이 붙어 있는 GameObject의 활성화 상태"에 종속되어 있기 때문입니다.

| 특징 | 설명 |
|---|---|
| 상속 대상 | `UnityEngine.MonoBehaviour` |
| 생성 방법 | GameObject에 Component로 부착 (직접 `new` 불가) |
| 생명주기 | Unity 엔진이 정해진 순서대로 특정 이름의 메서드를 자동 호출 |
| 대표 메서드 | `Awake`, `OnEnable`, `Start`, `Update`, `FixedUpdate`, `LateUpdate`, `OnDisable`, `OnDestroy` |

> 💡 **실무 팁**: 생명주기 함수는 이름과 시그니처가 정확히 일치해야 Unity가 인식합니다. `void Update()`를 `void update()`나 `void Update(int x)`로 잘못 쓰면 컴파일 에러 없이 그냥 호출되지 않으므로, 오타는 디버깅하기 까다로운 버그의 흔한 원인입니다.

---

## 2. 생명주기 전체 흐름 — Awake, OnEnable, Start

Unity는 씬이 로드되고 오브젝트가 활성화될 때 정해진 순서대로 초기화 함수를 호출합니다. 이 순서를 정확히 아는 것이 스크립트 간 의존성 버그를 피하는 핵심입니다.

```
씬 로드/오브젝트 생성
      │
      ▼
   Awake()        ← 씬에 존재하는 "모든" 오브젝트의 Awake가 먼저 한 차례 다 끝난다
      │
      ▼
  OnEnable()      ← 오브젝트/컴포넌트가 활성화될 때마다 (재활성화 포함) 호출
      │
      ▼
   Start()        ← 첫 프레임이 시작되기 직전, 딱 한 번만 호출
      │
      ▼
  (매 프레임 Update 루프로 진입)
```

- **`Awake()`**: GameObject가 생성되거나 씬이 로드될 때 가장 먼저 호출됩니다. 중요한 특징은 **씬 안의 모든 오브젝트의 Awake가 서로 다른 오브젝트의 Start보다 먼저 전부 끝난다는 것**입니다. 그래서 "다른 오브젝트의 참조를 캐싱"하거나 "자기 자신의 초기 상태를 설정"하는 코드는 Awake에 두는 것이 안전합니다.
- **`OnEnable()`**: 오브젝트가 활성화(active)될 때마다 호출됩니다. 처음 생성될 때뿐 아니라 `SetActive(false)` 후 다시 `SetActive(true)` 할 때도 매번 호출된다는 점이 Awake와 다릅니다.
- **`Start()`**: Awake가 모두 끝난 뒤, 첫 Update 프레임 직전에 딱 한 번 호출됩니다. **다른 오브젝트가 Awake에서 초기화한 값을 안전하게 참조**하려면 Start에서 접근해야 합니다.

```csharp
using UnityEngine;

public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    private void Awake()
    {
        // 싱글턴 초기화는 다른 스크립트가 Start에서 참조하기 전에 끝나야 하므로 Awake에서 처리
        Instance = this;
    }
}

public class ScoreUI : MonoBehaviour
{
    private void Start()
    {
        // GameManager.Instance는 이미 모든 Awake가 끝난 뒤이므로 null이 아님을 보장할 수 있다
        GameManager.Instance.RegisterScoreUI(this);
    }
}
```

> 💡 **실무 팁**: "이 오브젝트가 필요로 하는 다른 컴포넌트/매니저의 참조를 가져오는 코드"를 Start에 넣었다가, 실행 순서가 꼬여 참조가 아직 준비되지 않아 `NullReferenceException`이 나는 경우가 매우 흔합니다. 싱글턴이나 매니저 초기화는 반드시 Awake에서, 그 매니저를 "사용"하는 코드는 Start에서 작성하는 습관을 들이는 것이 좋습니다.

---

## 3. 매 프레임 실행되는 함수들 — Update, FixedUpdate, LateUpdate

게임 로직의 대부분은 매 프레임 반복 호출되는 세 함수 중 하나에 들어갑니다. 셋의 차이는 "언제, 얼마나 자주 호출되는가"입니다.

| 함수 | 호출 주기 | 용도 |
|---|---|---|
| `Update()` | 매 렌더링 프레임마다 (프레임률에 따라 간격이 달라짐) | 입력 감지, 일반 게임 로직, UI 갱신 |
| `FixedUpdate()` | 고정된 시간 간격마다 (기본 0.02초 = 50Hz, 프레임률과 무관) | 물리 연산(Rigidbody 힘 적용, 이동) |
| `LateUpdate()` | 모든 `Update()` 호출이 끝난 뒤, 같은 프레임 안에서 한 번 더 | 카메라 추적처럼 "다른 오브젝트가 다 움직인 뒤"에 실행되어야 하는 로직 |

```csharp
using UnityEngine;

public class MovementExample : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    private Rigidbody rb;
    private Vector3 inputDirection;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    private void Update()
    {
        // 입력은 프레임마다 최대한 자주 읽어야 반응성이 좋다
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        inputDirection = new Vector3(h, 0f, v);
    }

    private void FixedUpdate()
    {
        // 물리 이동은 고정 간격으로 처리해야 프레임률이 달라져도 일관된 결과가 나온다
        rb.MovePosition(rb.position + inputDirection * moveSpeed * Time.fixedDeltaTime);
    }
}

public class CameraFollow : MonoBehaviour
{
    [SerializeField] private Transform target;
    [SerializeField] private Vector3 offset;

    private void LateUpdate()
    {
        // 플레이어가 Update에서 다 이동한 뒤에 카메라를 옮겨야 한 프레임 밀리는 현상이 없다
        transform.position = target.position + offset;
    }
}
```

**왜 물리는 FixedUpdate에서 처리해야 하는가**: `Update()`는 프레임률(FPS)에 따라 호출 간격이 들쭉날쭉합니다. 60FPS면 약 0.0166초마다, 30FPS면 약 0.033초마다 호출되죠. 물리 연산을 `Update()`에서 `Time.deltaTime`으로 처리하면 기기 성능에 따라 결과가 미세하게 달라지고, 특히 힘/속도 계산의 오차가 누적되어 불안정해질 수 있습니다. `FixedUpdate()`는 항상 고정된 `Time.fixedDeltaTime` 간격으로 호출되므로 물리 시뮬레이션의 일관성이 보장됩니다.

> 💡 **실무 팁**: `Time.deltaTime`은 `Update()`용, `Time.fixedDeltaTime`은 `FixedUpdate()`용으로 짝을 맞춰 써야 합니다. `FixedUpdate()` 안에서 실수로 `Time.deltaTime`을 쓰면 물리 갱신 주기와 어긋나 미묘하게 부정확한 이동 속도가 나옵니다.

---

## 4. 오브젝트 종료 시점 — OnDisable, OnDestroy

오브젝트가 비활성화되거나 파괴될 때도 정해진 순서로 함수가 호출됩니다. 리소스 정리, 이벤트 구독 해제를 놓치면 메모리 누수나 예외로 이어지므로 반드시 짝을 맞춰야 합니다.

```
SetActive(false) 호출
      │
      ▼
  OnDisable()     ← 비활성화되는 순간 호출 (다시 활성화하면 OnEnable부터 재시작)

GameObject.Destroy() 호출 또는 씬 전환
      │
      ▼
  OnDisable()     ← Destroy 직전에도 호출됨
      │
      ▼
  OnDestroy()     ← 실제로 메모리에서 제거되기 직전, 마지막으로 한 번 호출
```

```csharp
using UnityEngine;

public class EventSubscriber : MonoBehaviour
{
    private void OnEnable()
    {
        GameEvents.OnPlayerDied += HandlePlayerDied;
    }

    private void OnDisable()
    {
        // OnEnable에서 구독한 이벤트는 반드시 OnDisable에서 해제해야 한다.
        // 해제하지 않으면 이 오브젝트가 파괴된 뒤에도 이벤트 시스템이 죽은 참조를 들고 있어
        // NullReferenceException이나 메모리 누수로 이어진다.
        GameEvents.OnPlayerDied -= HandlePlayerDied;
    }

    private void OnDestroy()
    {
        // 파일 핸들, 코루틴, 네이티브 리소스 등 최종 정리는 여기서
        Debug.Log($"{name} 오브젝트가 완전히 제거되었습니다.");
    }

    private void HandlePlayerDied()
    {
        Debug.Log("플레이어 사망 이벤트 수신");
    }
}
```

- **`OnDisable()`**: `SetActive(false)`, 컴포넌트의 `enabled = false`, 또는 오브젝트 파괴 직전에 호출됩니다. C# 이벤트 구독 해제, 코루틴 정지(`StopAllCoroutines()`) 등을 여기서 처리하는 것이 정석입니다.
- **`OnDestroy()`**: `Destroy()` 호출로 실제 메모리에서 제거되기 직전에 딱 한 번 호출됩니다. 씬 전환으로 오브젝트가 사라질 때도 호출됩니다.

> 💡 **실무 팁**: "구독은 OnEnable, 해제는 OnDisable"을 항상 짝으로 묶어서 작성하는 습관이 중요합니다. Awake에서 구독하고 OnDestroy에서 해제하는 식으로 짝을 어긋나게 쓰면, 오브젝트를 비활성화만 하고 파괴하지 않는 오브젝트 풀링 패턴에서 이벤트가 계속 살아있는 미묘한 버그가 생깁니다.

---

## 5. 스크립트 실행 순서 제어 — Script Execution Order

기본적으로 같은 생명주기 단계(예: 여러 오브젝트의 `Awake`)라도 스크립트 간 호출 순서는 보장되지 않습니다. 대부분의 경우 순서가 중요하지 않도록 설계하는 것이 좋지만, 불가피하게 "이 스크립트는 반드시 저 스크립트보다 먼저 실행되어야 한다"는 상황이 있습니다.

이럴 때는 **Edit > Project Settings > Script Execution Order**에서 특정 스크립트를 목록에 추가하고 순서를 지정할 수 있습니다.

| 설정 | 동작 |
|---|---|
| Default Time (목록에 없는 스크립트) | 순서 보장 없음, 일반적으로 이 상태를 유지하는 것이 이상적 |
| 목록에 추가 + 낮은 숫자 | 더 먼저 실행됨 (예: -100) |
| 목록에 추가 + 높은 숫자 | 더 나중에 실행됨 (예: 100) |

```
Script Execution Order 설정 예시
-100  GameManager      (다른 모든 스크립트보다 먼저 Awake 실행되어야 함)
 Default  (나머지 모든 스크립트)
 100   UIRefresher      (다른 모든 로직이 끝난 뒤 마지막에 UI 갱신)
```

> 💡 **실무 팁**: Script Execution Order 설정은 프로젝트 전역에 영향을 주고 "왜 이 순서로 실행되는지"가 코드만 봐서는 드러나지 않아 유지보수를 어렵게 만듭니다. 가능하면 이 설정에 의존하지 않고, Awake/Start 구조나 이벤트 기반 설계로 순서 의존성 자체를 없애는 방향을 우선 고려하는 것이 좋습니다. 정말 필요한 경우(예: 매니저 클래스의 최우선 초기화)에만 제한적으로 사용하세요.

---

## 📝 핵심 요약

1. `MonoBehaviour`를 상속한 스크립트만 GameObject에 Component로 붙어 생명주기 함수를 자동 호출받을 수 있다
2. 초기화 순서는 Awake(모든 오브젝트가 먼저 끝남) → OnEnable → Start이며, 다른 오브젝트 참조는 Start에서 안전하게 접근한다
3. `Update`는 프레임마다, `FixedUpdate`는 고정 간격마다(물리 연산용), `LateUpdate`는 Update가 다 끝난 뒤(카메라 추적용) 호출된다
4. 이벤트 구독은 OnEnable에서, 해제는 OnDisable에서 짝을 맞춰야 메모리 누수와 예외를 막을 수 있다
5. 스크립트 간 실행 순서가 꼭 필요하면 Script Execution Order로 제어할 수 있지만, 설계로 순서 의존성을 없애는 것이 먼저다

---

## 🔗 참고 자료

- [Order of Execution for Event Functions (Unity Manual)](https://docs.unity3d.com/Manual/ExecutionOrder.html)
- [MonoBehaviour 스크립팅 API](https://docs.unity3d.com/ScriptReference/MonoBehaviour.html)
- [Time.fixedDeltaTime 스크립팅 API](https://docs.unity3d.com/ScriptReference/Time-fixedDeltaTime.html)

---

*⬅️ 이전: [Day 04 — Prefab 개념과 활용](../day-04/)  |  다음: [Day 06 — Unity Input System 기초](../day-06/) ➡️*
