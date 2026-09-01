---
title: "Day 32 — Unity Animator Controller와 State Machine"
date: 2026-08-31
weight: 32
---

> **Phase 5: 캐릭터와 애니메이션** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Animator Controller의 State, Transition, Parameter 개념을 이해하고 State Machine을 직접 구성할 수 있다
- C# 스크립트에서 `Animator.SetFloat`, `SetBool`, `SetTrigger` 등으로 애니메이션 상태를 제어할 수 있다
- Any State, Sub-State Machine, Layer를 활용해 복잡한 캐릭터 애니메이션 구조를 설계할 수 있다

---

## 1. Animator Controller란 무엇인가

Day 31에서 Blender NLA로 Idle, Walk, Run 같은 Action을 편집 시점에 조합했다면, Unity의 **Animator Controller**는 이 애니메이션 클립들을 **런타임에 조건에 따라 전환**하는 역할을 합니다.

FBX로 Import된 애니메이션 클립(Day 22-24에서 다룬 임포트 파이프라인 결과물)은 그 자체로는 그냥 "재생 가능한 데이터"일 뿐입니다. 이 클립들을 "지금 캐릭터가 걷고 있는가, 뛰고 있는가, 점프 중인가"에 따라 자동으로 바꿔 재생해주는 것이 Animator Controller의 State Machine입니다.

```
GameObject (캐릭터)
├─ Animator 컴포넌트
│   └─ Controller: PlayerAnimator.controller  ← 여기에 State Machine 정의
└─ Animation Clips: Idle, Walk, Run, Jump (FBX에서 추출됨)
```

Animator Controller 애셋은 `Assets` 우클릭 → `Create → Animator Controller`로 생성하며, `Window → Animation → Animator` 창에서 시각적으로 편집합니다.

---

## 2. State — 하나의 애니메이션 상태

**State**는 State Machine의 노드 하나하나로, 대부분 애니메이션 클립 하나와 1:1로 대응됩니다.

```
State Machine 그래프 예시

  [Entry] → [Idle] ⇄ [Walk] ⇄ [Run]
                 ↘  [Jump]  ↗
```

- **Entry**: State Machine에 진입했을 때 자동으로 연결되는 시작점 (보통 Idle로 연결)
- **Any State**: 현재 어떤 State에 있든 상관없이 특정 조건이 되면 강제로 전환할 수 있는 특수 노드 (예: 어느 상태에서든 "Hit" 트리거가 오면 피격 애니메이션으로 전환)
- 회색 State가 기본(Default) State이며, Inspector에서 우클릭 → `Set as Layer Default State`로 변경 가능

각 State의 Inspector에서 설정할 수 있는 주요 속성:

| 속성 | 설명 |
|---|---|
| Motion | 재생할 애니메이션 클립 |
| Speed | 재생 속도 배율 (1 = 원본 속도) |
| Multiplier | Speed를 파라미터 값으로 동적으로 제어할 때 사용 |
| Foot IK | Humanoid 캐릭터의 발이 지면에 맞도록 보정 (Day 34 Humanoid Rig에서 자세히) |

> 💡 **실무 팁**: State 이름은 반드시 명확하게(`Idle`, `Walk_Forward`처럼) 지어야 합니다. State가 많아질수록 그래프가 복잡해지는데, 이름이 모호하면 나중에 디버깅할 때 어떤 노드가 어떤 동작인지 구분하기 어려워집니다.

---

## 3. Parameter — State Machine을 제어하는 변수

Transition의 조건은 **Parameter**라는 변수 값으로 판단합니다. Animator 창 왼쪽 `Parameters` 탭에서 추가하며, 4가지 타입이 있습니다.

| 타입 | 용도 | 예시 |
|---|---|---|
| Float | 연속적인 값 (이동 속도 등) | `Speed = 0.0 ~ 1.0` |
| Int | 정수 값 (상태 번호 등) | `AttackIndex = 0, 1, 2` |
| Bool | 참/거짓 (지속 상태) | `IsGrounded = true/false` |
| Trigger | 한 번 발동하고 자동으로 꺼지는 신호 | `Jump` (버튼을 누른 순간만 true) |

**Bool과 Trigger의 차이**가 헷갈리기 쉬운데, Bool은 명시적으로 `false`로 되돌리기 전까지 값이 유지되고, Trigger는 Transition이 소비하는 즉시 자동으로 초기화됩니다. "점프"처럼 한 번의 이벤트에는 Trigger가, "달리는 중이다"처럼 지속되는 상태에는 Bool이나 Float이 적합합니다.

```csharp
using UnityEngine;

public class PlayerAnimationController : MonoBehaviour
{
    private Animator animator;
    private CharacterController controller;

    // Animator 파라미터 이름을 문자열로 매번 비교하면 느리고 오타에 취약하므로
    // Animator.StringToHash로 미리 정수 ID로 변환해둔다
    private static readonly int SpeedHash = Animator.StringToHash("Speed");
    private static readonly int IsGroundedHash = Animator.StringToHash("IsGrounded");
    private static readonly int JumpHash = Animator.StringToHash("Jump");

    void Awake()
    {
        animator = GetComponent<Animator>();
        controller = GetComponent<CharacterController>();
    }

    void Update()
    {
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");
        float speed = new Vector2(horizontal, vertical).magnitude;

        animator.SetFloat(SpeedHash, speed, 0.1f, Time.deltaTime); // dampTime으로 부드러운 전환
        animator.SetBool(IsGroundedHash, controller.isGrounded);

        if (Input.GetButtonDown("Jump") && controller.isGrounded)
        {
            animator.SetTrigger(JumpHash);
        }
    }
}
```

> 💡 **실무 팁**: `SetFloat`의 세 번째 인자(`dampTime`)를 활용하면 Speed 값이 갑자기 튀어도 애니메이션이 부드럽게 보간되며 따라갑니다. 0으로 두면 즉시 반영되어 뚝뚝 끊기는 느낌을 줄 수 있습니다.

---

## 4. Transition — State 사이의 전환 규칙

**Transition**은 두 State를 잇는 화살표로, 어떤 조건에서 어떻게 전환할지를 정의합니다. Transition을 선택하면 Inspector에 다음 설정들이 나타납니다.

| 설정 | 설명 |
|---|---|
| Conditions | 전환 조건 (Parameter 비교, 여러 개면 AND로 결합) |
| Has Exit Time | 체크 시 현재 애니메이션이 일정 비율만큼 재생된 후에만 전환 허용 |
| Exit Time | Has Exit Time이 켜졌을 때, 전환이 가능해지는 재생 진행률(0~1) |
| Transition Duration | 두 애니메이션이 겹쳐서 크로스페이드되는 시간(초) |
| Interruption Source | 전환 도중 다른 Transition이 끼어들 수 있는지 여부 |

**Has Exit Time을 언제 켜고 끄는가**가 실무에서 자주 헷갈리는 포인트입니다.

- **꺼야 하는 경우**: 플레이어 입력에 즉각 반응해야 하는 전환 (Idle ↔ Walk, Jump 등). Exit Time이 켜져 있으면 입력 즉시가 아니라 애니메이션의 특정 진행 구간까지 기다려야 전환되어 조작감이 둔해집니다.
- **켜야 하는 경우**: 공격 모션처럼 "동작이 끝날 때까지는 다른 상태로 끊기면 안 되는" 연출성 애니메이션. 예를 들어 Attack 애니메이션이 80% 재생된 후에만 Idle로 복귀하도록 Exit Time을 0.8로 설정합니다.

```
Idle → Walk 전환 조건: Speed > 0.1   (Has Exit Time: OFF, Transition Duration: 0.15초)
Walk → Idle 전환 조건: Speed < 0.1   (Has Exit Time: OFF, Transition Duration: 0.15초)
Any State → Jump 조건: Jump (Trigger) (Has Exit Time: OFF, Transition Duration: 0.1초)
Attack → Idle 조건: 없음(자동)        (Has Exit Time: ON, Exit Time: 0.9)
```

> 💡 **실무 팁**: Idle ↔ Walk를 서로 다른 두 개의 Transition으로 따로 만드는 대신, Blend Tree(Day 33에서 다룸) 하나로 합치면 State 개수가 줄고 그래프가 훨씬 단순해집니다. State가 5개를 넘어가기 시작하면 Blend Tree로의 통합을 고려할 시점입니다.

---

## 5. Any State와 Sub-State Machine으로 구조 정리하기

캐릭터 State가 많아지면(이동 4종 + 전투 5종 + 반응 3종 등) 그래프 하나에 전부 펼쳐두기 어렵습니다. 두 가지 도구로 구조를 정리합니다.

**Any State**: 특정 State에서만이 아니라 "언제든" 발생할 수 있는 전환에 사용합니다. 피격(Hit), 사망(Death)처럼 어떤 동작 중이든 끼어들어야 하는 이벤트가 대표적입니다.

```
[Any State] --(조건: Hit Trigger)--> [Hit React]
[Any State] --(조건: HP <= 0)------> [Death]
```

**Sub-State Machine**: 관련된 State들을 하나의 폴더처럼 묶어 그래프를 계층화합니다. 예를 들어 "Locomotion"(Idle/Walk/Run) 그룹과 "Combat"(Attack1/Attack2/Block) 그룹을 각각 Sub-State Machine으로 묶으면 최상위 그래프는 두 개의 큰 블록만 보여 훨씬 읽기 쉬워집니다.

```
Base Layer (최상위)
├─ [Locomotion] (Sub-State Machine: Idle, Walk, Run 포함)
└─ [Combat] (Sub-State Machine: Attack1, Attack2, Block 포함)
```

Sub-State Machine 자체도 하나의 State처럼 다른 State와 Transition을 맺을 수 있으며, 내부로 들어가면 또 다른 독립된 State Machine 그래프가 펼쳐집니다.

---

## 6. Layer — 상반신/하반신을 독립적으로 제어하기

지금까지 다룬 State Machine은 모두 **Base Layer** 하나에 속합니다. 하지만 "하반신은 뛰고 있는데 상반신은 동시에 총을 쏘는" 것처럼 신체 부위별로 서로 다른 애니메이션을 동시에 재생해야 할 때는 **Layer**를 추가로 사용합니다.

```
Animator 창 좌측 Layers 탭
├─ Base Layer      (Weight: 1, 전신 - Idle/Walk/Run)
└─ Upper Body      (Weight: 1, Avatar Mask 적용 - Shoot/Reload)
```

Layer 추가 시 핵심 설정:

| 설정 | 설명 |
|---|---|
| Weight | 이 레이어가 최종 포즈에 얼마나 영향을 주는지(0~1) |
| Mask | Avatar Mask로 이 레이어가 영향을 미칠 신체 부위 한정 (예: 상반신만) |
| Blending | Override(덮어쓰기) 또는 Additive(기존 포즈에 더하기) |

Avatar Mask는 `Assets → Create → Avatar Mask`로 생성하고, Humanoid 리그의 각 본(상반신/하반신/머리 등)을 체크박스로 켜고 끌 수 있습니다. 상반신 Layer에 "상반신만 활성화"된 Mask를 적용하면, 하반신은 Base Layer의 Walk가 그대로 재생되고 상반신만 Upper Body Layer의 Shoot로 덮어써집니다.

> 💡 **실무 팁**: Additive Layer는 기존 애니메이션 위에 "미세하게 더하는" 용도(숨쉬기, 흔들림 등)에 적합하고, 완전히 다른 동작을 상반신에 재생하려면 Override가 적합합니다. 둘을 헷갈리면 캐릭터 자세가 이상하게 뒤틀리는 결과가 나올 수 있습니다.

---

## 📝 핵심 요약

1. Animator Controller는 애니메이션 클립을 State로, 전환 조건을 Transition으로 정의해 런타임에 자동으로 애니메이션을 바꿔주는 State Machine이다
2. Parameter는 Float/Int/Bool/Trigger 4종이 있으며, 지속 상태는 Bool/Float로, 일회성 이벤트는 Trigger로 표현한다
3. Has Exit Time은 입력 반응성이 중요한 전환(이동)에서는 끄고, 끝까지 재생되어야 하는 연출 애니메이션(공격)에서는 켠다
4. Any State는 어떤 상태에서든 발생 가능한 전환에, Sub-State Machine은 관련 State를 묶어 그래프를 계층화하는 데 사용한다
5. Layer와 Avatar Mask를 조합하면 상반신/하반신처럼 신체 부위별로 독립된 애니메이션을 동시에 재생할 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Animator Controllers](https://docs.unity3d.com/Manual/class-AnimatorController.html)
- [Unity Manual — State Machine Transitions](https://docs.unity3d.com/Manual/class-Transition.html)
- [Unity Scripting API — Animator](https://docs.unity3d.com/ScriptReference/Animator.html)

---

*⬅️ 이전: [Day 31 — Blender에서 애니메이션 만들기 기초](../day-31/)  |  다음: [Day 33 — Blend Tree로 자연스러운 애니메이션 전환](../day-33/) ➡️*
