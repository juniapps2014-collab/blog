---
title: "Day 45 — 오브젝트 상호작용 - 애니메이션 이벤트와 스크립트 연동"
date: 2026-09-13
weight: 45
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Animation Event를 추가해 애니메이션 클립의 특정 프레임에서 C# 메서드를 호출할 수 있다
- Animation Event의 4가지 파라미터 타입(float, int, string, Object)과 각각의 활용 시나리오를 구분할 수 있다
- StateMachineBehaviour를 이용해 State 진입/종료/업데이트 시점에 로직을 연동하는 방법을 설명할 수 있다

---

## 1. 왜 애니메이션과 스크립트를 "이벤트"로 연동해야 하는가

캐릭터가 검을 휘두르는 애니메이션을 재생한다고 가정해봅시다. 실제로 적에게 데미지를 주는 판정은 애니메이션 전체 구간이 아니라 "칼날이 적을 스치는" 아주 짧은 프레임 구간에서만 발생해야 자연스럽습니다. `Update()`에서 매 프레임 애니메이션 재생 시간을 체크해 `if (animationTime > 0.4f && animationTime < 0.5f)` 같은 방식으로 처리할 수도 있지만, 이는 다음과 같은 문제가 있습니다.

- 애니메이션 클립을 수정(타이밍 조정)할 때마다 스크립트의 매직 넘버도 같이 수정해야 함
- 애니메이터와 프로그래머가 협업할 때 서로의 영역을 침범하게 됨
- 애니메이션 재생 속도가 바뀌면(예: `Animator.speed` 조정) 시간 기반 체크가 어긋남

Unity의 **Animation Event**는 이 문제를 해결합니다. 애니메이션 클립 자체에 "이 프레임에서 이 메서드를 호출하라"는 마커를 심어두면, 애니메이터(아티스트)가 타이밍을 조정해도 프로그래머의 코드는 그대로 유지됩니다. 즉 타이밍의 책임을 애니메이션 데이터 쪽으로 옮기는 것이 핵심입니다.

> 💡 **실무 팁**: "언제 실행할지"는 애니메이션 클립(Animation Event)이 결정하고, "무엇을 할지"는 스크립트(MonoBehaviour 메서드)가 결정하는 역할 분리가 유지보수의 핵심입니다.

---

## 2. Animation 창에서 이벤트 추가하기

Animation Event는 **Animation 창**(Import된 클립이 아닌 프로젝트 내 생성 클립 기준)에서 추가합니다.

```
Window → Animation → Animation
→ 대상 GameObject 선택 (Animator 컴포넌트 필요)
→ 상단 드롭다운에서 편집할 Clip 선택
→ 타임라인 눈금자(Ruler) 위에서 원하는 프레임으로 이동
→ 타임라인 상단의 이벤트 추가 버튼(작은 깃발 아이콘) 클릭
```

Import된 FBX 애니메이션(Blender에서 가져온 클립 등)에 이벤트를 추가하려면 별도 경로를 씁니다.

```
FBX 파일 선택 → Inspector → Animation 탭
→ 클립 선택 → 하단 미리보기 타임라인에서 이벤트 추가
→ Apply 버튼으로 저장
```

이벤트를 추가하면 Inspector에 다음 항목을 입력하는 창이 뜹니다.

| 필드 | 설명 |
|---|---|
| Function | 호출할 메서드 이름 (대상 GameObject에 붙은 컴포넌트의 public 메서드) |
| Float | float 타입 파라미터 1개 |
| Int | int 타입 파라미터 1개 |
| String | string 타입 파라미터 1개 |
| Object | UnityEngine.Object를 상속하는 참조 1개 (예: AudioClip, GameObject) |

> 💡 **실무 팁**: 파라미터는 4개 타입 중 **하나씩만** 동시에 넘길 수 있습니다(엄밀히는 AnimationEvent 객체 하나에 모든 필드가 존재하지만, 메서드 시그니처는 하나의 파라미터만 받도록 설계하는 것이 관례입니다). 여러 값을 함께 넘겨야 한다면 다음 섹션의 AnimationEvent 파라미터 방식을 사용하세요.

---

## 3. 메서드 시그니처와 파라미터 타입별 활용

이벤트가 호출하는 메서드는 반드시 **해당 GameObject(또는 자식)에 붙은 컴포넌트의 public 메서드**여야 하며, 파라미터는 0개 또는 1개만 가능합니다.

```csharp
public class SwordAttack : MonoBehaviour
{
    [SerializeField] private Collider swordCollider;
    [SerializeField] private AudioSource audioSource;

    // 파라미터 없음 - 단순 트리거용
    public void EnableSwordCollider()
    {
        swordCollider.enabled = true;
    }

    public void DisableSwordCollider()
    {
        swordCollider.enabled = false;
    }

    // int 파라미터 - 콤보 단계별 데미지 배율
    public void ApplyComboDamage(int comboStep)
    {
        float damage = baseDamage * (1f + comboStep * 0.3f);
        Debug.Log($"콤보 {comboStep}단계, 데미지: {damage}");
    }

    // string 파라미터 - 사운드 이름을 문자열로 전달
    public void PlayFootstep(string surfaceType)
    {
        AudioClip clip = surfaceType == "grass" ? grassClip : stoneClip;
        audioSource.PlayOneShot(clip);
    }

    // Object 파라미터 - 이펙트 프리팹을 직접 연결
    public void SpawnHitEffect(GameObject effectPrefab)
    {
        Instantiate(effectPrefab, transform.position, Quaternion.identity);
    }
}
```

여러 값을 동시에 넘기고 싶다면, Function 이름만 지정하고 `AnimationEvent` 타입 하나를 파라미터로 받으면 Unity가 자동으로 채워진 객체를 넘겨줍니다.

```csharp
public void OnComplexEvent(AnimationEvent evt)
{
    // evt.floatParameter, evt.intParameter, evt.stringParameter,
    // evt.objectReferenceParameter 모두 동시에 접근 가능
    Debug.Log($"Float: {evt.floatParameter}, Int: {evt.intParameter}, String: {evt.stringParameter}");
}
```

| 파라미터 방식 | 장점 | 단점 |
|---|---|---|
| 단일 타입 (float/int/string/Object) | 메서드 시그니처가 명확하고 읽기 쉬움 | 값 하나만 전달 가능 |
| `AnimationEvent` 통째로 전달 | 4개 필드를 한 번에 모두 활용 가능 | 호출부 코드가 다소 장황해짐 |

---

## 4. StateMachineBehaviour - State 단위의 생명주기 연동

Animation Event가 "클립의 특정 프레임"에 묶인다면, **StateMachineBehaviour**는 Animator Controller의 "State" 자체에 스크립트를 붙이는 방식입니다. 즉 "이 애니메이션의 3프레임째"가 아니라 "이 State에 진입했을 때 / 머무는 동안 / 빠져나갈 때"를 기준으로 로직을 실행합니다.

```csharp
using UnityEngine;

public class AttackStateBehaviour : StateMachineBehaviour
{
    public override void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // 공격 State에 진입하는 순간 - 예: 무적 판정 시작
        animator.SetBool("IsAttacking", true);
    }

    public override void OnStateUpdate(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // State가 재생되는 매 프레임 - 예: normalizedTime 기반 판정 구간 체크
        if (stateInfo.normalizedTime >= 0.3f && stateInfo.normalizedTime <= 0.5f)
        {
            // 판정 활성 구간 (Animation Event 대신 여기서 처리할 수도 있음)
        }
    }

    public override void OnStateExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        // State를 빠져나갈 때 - 예: 무적 판정 종료
        animator.SetBool("IsAttacking", false);
    }
}
```

State에 붙이는 방법은 다음과 같습니다.

```
Animator 창 → 대상 State 클릭
→ Inspector 하단 "Add Behaviour" 버튼
→ 작성한 StateMachineBehaviour 스크립트 선택
```

| 구분 | Animation Event | StateMachineBehaviour |
|---|---|---|
| 기준 단위 | 클립(Clip)의 특정 프레임 | Animator Controller의 State |
| 편집 위치 | Animation 창 타임라인 | Animator 창의 State Inspector |
| 대상 컴포넌트 | 같은 GameObject의 컴포넌트 메서드 | StateMachineBehaviour 자체가 로직을 가짐 |
| 적합한 상황 | "정확히 이 프레임에 한 번" 실행 | State 진입/체류/종료 전체 생명주기 관리 |
| Blend Tree 안에서 | 개별 클립마다 다르게 동작 가능 | State(Blend Tree 전체) 단위로 동일하게 적용 |

> 💡 **실무 팁**: 여러 State에서 반복되는 로직(예: "공격 계열 State에 진입하면 무조건 IsAttacking을 true로")은 StateMachineBehaviour로 공통화하고, 클립별로 미세하게 다른 타이밍(예: 발소리 프레임이 클립마다 다름)은 Animation Event로 개별 지정하는 조합이 일반적입니다.

---

## 5. 실전 예제 - 콤보 공격 시스템 통합

Animation Event와 StateMachineBehaviour를 함께 써서 콤보 공격 시스템을 구성하는 흐름을 정리하면 다음과 같습니다.

```
1. Attack1/Attack2/Attack3 State에 AttackStateBehaviour 부착
   → OnStateEnter에서 "공격 입력 버퍼링 창" 타이머 초기화
   → OnStateExit에서 다음 콤보 입력이 없으면 Idle로 전이

2. 각 Attack 클립에 Animation Event 추가
   → 타격 프레임: EnableSwordCollider() 호출
   → 타격 종료 프레임: DisableSwordCollider() 호출
   → 발소리가 필요한 스텝 프레임: PlayFootstep("stone") 호출
```

```csharp
public class ComboController : MonoBehaviour
{
    private int comboIndex = 0;
    private bool inputBuffered = false;

    // Animation Event에서 호출: 콤보 입력 가능 구간 시작
    public void OpenComboWindow()
    {
        inputBuffered = false; // 이 구간부터 입력을 받기 시작
    }

    // 플레이어 입력 시 호출 (Input System 콜백 등에서)
    public void OnAttackInput()
    {
        if (comboIndex < 3)
        {
            inputBuffered = true;
        }
    }

    // Animation Event에서 호출: 콤보 판정 구간 종료
    public void CloseComboWindow(Animator animator = null)
    {
        if (inputBuffered)
        {
            comboIndex++;
            GetComponent<Animator>().SetInteger("ComboIndex", comboIndex);
        }
        else
        {
            comboIndex = 0;
        }
    }
}
```

이런 구조를 쓰면 "타격 판정 시작/종료", "콤보 입력 창 열림/닫힘" 같은 게임플레이 타이밍이 전부 애니메이션 클립 안에 데이터로 존재하게 되어, 애니메이터가 타이밍감을 조정해도 프로그래머가 매번 코드를 고칠 필요가 없습니다.

> 💡 **실무 팁**: Animation Event로 호출되는 메서드는 반드시 존재해야 합니다. 대상 컴포넌트를 제거하거나 메서드 이름을 바꾸면 콘솔에 `MissingMethodException` 경고가 뜨니, 리팩터링 시 Animation 창에서 이벤트를 함께 점검하는 습관이 필요합니다.

---

## 📝 핵심 요약

1. Animation Event는 애니메이션 클립의 특정 프레임에서 같은 GameObject의 컴포넌트 메서드를 호출하는 기능으로, 타이밍의 책임을 코드가 아닌 애니메이션 데이터 쪽에 둔다
2. 이벤트 메서드는 float, int, string, Object 중 하나의 파라미터만 받거나, `AnimationEvent` 객체 전체를 받아 여러 값을 한 번에 처리할 수 있다
3. StateMachineBehaviour는 클립이 아닌 Animator State 단위로 OnStateEnter/Update/Exit 생명주기 로직을 연동한다
4. 반복되는 State 단위 로직은 StateMachineBehaviour로, 클립마다 다른 세밀한 타이밍은 Animation Event로 나눠 처리하는 것이 실무 패턴이다
5. 콤보 공격, 발소리, 히트박스 On/Off 같은 게임플레이 로직은 이 두 기능을 조합해 애니메이션과 스크립트의 결합도를 낮추면서 구현한다

---

## 🔗 참고 자료

- [Unity Manual — Animation Events](https://docs.unity3d.com/Manual/script-AnimationWindowEvent.html)
- [Unity Scripting API — StateMachineBehaviour](https://docs.unity3d.com/ScriptReference/StateMachineBehaviour.html)
- [Unity Scripting API — AnimationEvent](https://docs.unity3d.com/ScriptReference/AnimationEvent.html)

---

*⬅️ 이전: [Day 44 — 커스텀 셰이더로 머티리얼 표현력 높이기](../day-44/)  |  다음: [Day 46 — Ragdoll Physics와 물리 기반 애니메이션](../day-46/) ➡️*
