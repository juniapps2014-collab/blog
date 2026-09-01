---
title: "Day 33 — Blend Tree로 자연스러운 애니메이션 전환"
date: 2026-08-31
weight: 33
---

> **Phase 5: 캐릭터와 애니메이션** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 1D Blend Tree로 여러 애니메이션 클립을 하나의 연속적인 파라미터로 자연스럽게 보간할 수 있다
- 2D Blend Tree(Freeform Directional/Cartesian)로 이동 방향까지 반영한 8방향 이동 애니메이션을 구성할 수 있다
- Blend Tree의 Threshold, Compute Thresholds, Adjust Time Scale 옵션의 동작 원리를 이해하고 상황에 맞게 설정할 수 있다

---

## 1. Blend Tree가 필요한 이유

Day 32에서 State와 Transition만으로 Idle ↔ Walk ↔ Run을 구성하면 문제가 하나 생깁니다. Speed가 0.3일 때 "Walk를 재생할지 Run을 재생할지"는 명확히 나눌 수 있지만, 그 사이의 애매한 속도(예: 0.45)에서는 캐릭터가 뚝뚝 끊기듯 전환됩니다. 실제 걷기에서 뛰기로 넘어가는 움직임은 연속적인데, State 전환은 본질적으로 "이산적인 On/Off"이기 때문입니다.

**Blend Tree**는 여러 애니메이션 클립을 하나의 State처럼 취급하면서, 파라미터 값에 따라 클립들을 실시간으로 **가중 평균(blend)** 해서 재생합니다. Idle(속도 0), Walk(속도 0.5), Run(속도 1.0) 세 클립을 하나의 Blend Tree에 넣으면, Speed = 0.7일 때 Walk와 Run이 자동으로 비율에 맞게 섞여 재생됩니다.

```
State Machine 그래프에서 Blend Tree는 State 하나처럼 보인다

[Entry] → [Locomotion (Blend Tree)] → [Jump]
              │
              ├─ Idle  (Speed = 0.0)
              ├─ Walk  (Speed = 0.5)
              └─ Run   (Speed = 1.0)
```

Blend Tree는 Animator 창에서 State 우클릭 → `Create State → From New Blend Tree`로 생성하며, 더블클릭하면 전용 편집 화면으로 들어갑니다.

---

## 2. 1D Blend Tree — 파라미터 하나로 보간하기

가장 기본적인 형태로, **Motion Field**를 하나의 Float Parameter로 제어합니다. Speed 하나로 Idle/Walk/Run을 잇는 예시를 만들어 보겠습니다.

| Motion | Threshold |
|---|---|
| Idle | 0.0 |
| Walk | 0.5 |
| Run | 1.0 |

Blend Tree Inspector에서 설정 흐름:

1. Blend Type을 `1D`로 선택
2. Parameter 드롭다운에서 `Speed` 선택 (없으면 Animator 창의 Parameters 탭에서 먼저 생성)
3. `+` 버튼으로 Motion Field 3개 추가 후 각각 Idle/Walk/Run 클립 연결
4. 각 Motion의 Threshold 값을 0.0 / 0.5 / 1.0으로 지정

런타임에는 Speed 값이 두 Threshold 사이에 있으면 인접한 두 클립만 보간되고, 그 바깥의 클립은 영향을 주지 않습니다. 예를 들어 Speed = 0.3이면 Idle(0.0)과 Walk(0.5) 사이의 비율(0.6:0.4 정도)로만 섞이고 Run(1.0)은 전혀 반영되지 않습니다.

```csharp
// Blend Tree의 Speed 파라미터를 갱신하는 코드는 Day 32의 SetFloat 호출과 동일하다
animator.SetFloat(SpeedHash, currentSpeed, 0.1f, Time.deltaTime);
```

> 💡 **실무 팁**: `Compute Thresholds` 버튼을 누르면 각 클립의 실제 이동 속도(Root Motion 기반)를 분석해 Threshold를 자동으로 채워줍니다. 손으로 대충 0/0.5/1을 넣는 것보다, 실제 클립 속도와 Threshold를 일치시켜야 다리가 미끄러지는(foot sliding) 현상을 줄일 수 있습니다.

---

## 3. 2D Blend Tree — 방향까지 반영하기

전후좌우 이동처럼 두 축(예: 좌우 Horizontal, 전후 Vertical)을 동시에 반영하려면 **2D Blend Tree**를 사용합니다. Blend Type에는 세 가지가 있습니다.

| Blend Type | 특징 | 적합한 상황 |
|---|---|---|
| 2D Simple Directional | 방향 벡터가 겹치지 않는 경우에 적합, 계산량 적음 | 8방향 이동처럼 방향이 고르게 분포 |
| 2D Freeform Directional | 방향과 크기가 모두 의미 있을 때 (예: 걷기/뛰기가 방향별로 존재) | 방향별로 Walk/Run이 모두 있는 경우 |
| 2D Freeform Cartesian | X, Y 값 자체가 서로 다른 의미를 가질 때 (방향 개념이 아닌 경우) | 조준 방향 X, 몸 기울기 Y처럼 독립적인 두 값 |

8방향 이동 예시(2D Freeform Directional)를 구성한다면 다음처럼 Motion Field에 (VelX, VelZ) 좌표를 지정합니다.

```
Motion         Pos X   Pos Y
Idle            0.0     0.0
Walk_Forward    0.0     0.5
Walk_Back       0.0    -0.5
Walk_Left      -0.5     0.0
Walk_Right      0.5     0.0
Run_Forward     0.0     1.0
Run_Back        0.0    -1.0
Run_Left       -1.0     0.0
Run_Right       1.0     0.0
```

```csharp
using UnityEngine;

public class LocomotionBlend2D : MonoBehaviour
{
    private Animator animator;
    private static readonly int VelXHash = Animator.StringToHash("VelX");
    private static readonly int VelZHash = Animator.StringToHash("VelZ");

    void Awake()
    {
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        // 카메라 기준이 아니라 캐릭터 로컬 기준의 이동 입력을 그대로 사용
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");

        animator.SetFloat(VelXHash, h, 0.1f, Time.deltaTime);
        animator.SetFloat(VelZHash, v, 0.1f, Time.deltaTime);
    }
}
```

두 개의 Float Parameter(VelX, VelZ)가 2D 평면 위의 좌표를 이루고, Blend Tree는 이 좌표와 가장 가까운 Motion Field 2~3개를 자동으로 찾아 삼각형 보간(Delaunay Triangulation 기반)으로 섞습니다.

> 💡 **실무 팁**: 2D Blend Tree는 클립 개수가 많아질수록(8방향 x Walk/Run = 16개) 관리가 복잡해집니다. 처음에는 4방향(전후좌우)만으로 시작해서 동작을 검증한 뒤, 필요할 때만 대각선 방향을 추가하는 방식으로 점진적으로 확장하는 편이 디버깅에 유리합니다.

---

## 4. Adjust Time Scale — 보간 시 재생 속도 동기화

Blend Tree가 두 클립을 섞을 때, 두 클립의 길이(예: Walk 1초 주기, Run 0.6초 주기)가 다르면 발이 미끄러지듯 어색해 보일 수 있습니다. 이를 보정하는 옵션이 **Adjust Time Scale**입니다.

| 옵션 | 동작 |
|---|---|
| None | 각 클립을 원본 속도 그대로 재생하며 단순 보간 |
| By Speed | 클립의 실제 이동 속도(Root Motion 기준)에 맞춰 재생 시간을 조정, 자연스러운 이동에 적합 |
| By Speed and Duration | Speed 기준 조정에 더해 클립 길이(주기)까지 맞춰 발 딛는 타이밍을 동기화 |

Walk와 Run처럼 보폭 주기가 다른 클립을 섞을 때는 `By Speed and Duration`을 사용하면 발이 지면에 닿는 타이밍이 맞춰져 훨씬 자연스러운 전환을 얻을 수 있습니다.

> 💡 **실무 팁**: Blend Tree 편집 화면 하단의 미리보기 슬라이더로 파라미터 값을 직접 움직여보며 중간 보간 결과를 바로 확인할 수 있습니다. Play 모드에 들어가지 않고도 이상한 포즈(다리가 꼬이는 등)를 미리 잡아낼 수 있으니 반드시 활용하세요.

---

## 5. Blend Tree와 State Machine을 함께 쓰는 구조

실전에서는 Blend Tree 하나로 모든 것을 표현하지 않고, State Machine과 조합합니다. 이동은 Blend Tree로 연속적으로 처리하고, Jump나 Attack처럼 명확히 구분되는 동작은 별도 State로 분리하는 식입니다.

```
Base Layer
├─ [Locomotion] (1D 또는 2D Blend Tree: Idle/Walk/Run 보간)
│     └─ Any State --(Jump Trigger)--> [Jump] --(자동, Exit Time)--> [Locomotion]
└─ [Attack] (Any State에서 진입, Has Exit Time ON)
```

Locomotion Blend Tree 자체가 하나의 State이므로, Day 32에서 다룬 Transition 규칙(Has Exit Time, Any State 등)이 그대로 적용됩니다. 즉 Blend Tree는 "State 내부의 보간 방식을 정의하는 도구"이고, State 간 전환 로직은 여전히 Transition이 담당한다는 역할 분담을 기억해두면 구조가 헷갈리지 않습니다.

---

## 📝 핵심 요약

1. Blend Tree는 여러 클립을 하나의 State처럼 묶어 파라미터 값에 따라 실시간으로 가중 평균 보간하는 도구로, 이산적인 State 전환의 어색함을 해소한다
2. 1D Blend Tree는 파라미터 하나(Speed 등)로 Threshold 기반 보간을, 2D Blend Tree는 두 파라미터(방향 벡터 등)로 삼각형 보간을 수행한다
3. 2D Blend Type은 Simple Directional, Freeform Directional, Freeform Cartesian 세 가지가 있으며 클립 분포 특성에 맞게 선택한다
4. Compute Thresholds와 Adjust Time Scale(By Speed and Duration)을 활용하면 발 미끄러짐 없이 자연스러운 보간을 얻을 수 있다
5. Blend Tree는 State 내부의 보간 방식을, Transition은 State 간 전환 로직을 담당하는 역할 분담으로 구조를 단순하게 유지한다

---

## 🔗 참고 자료

- [Unity Manual — Blend Trees](https://docs.unity3d.com/Manual/class-BlendTree.html)
- [Unity Manual — 2D Blending](https://docs.unity3d.com/Manual/BlendTree-2DBlending.html)
- [Unity Scripting API — Animator.SetFloat](https://docs.unity3d.com/ScriptReference/Animator.SetFloat.html)

---

*⬅️ 이전: [Day 32 — Unity Animator Controller와 State Machine](../day-32/)  |  다음: [Day 34 — Humanoid Rig와 Avatar 설정](../day-34/) ➡️*
