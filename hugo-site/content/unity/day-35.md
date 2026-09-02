---
title: "Day 35 — 5주차 정리: 걷기/뛰기 애니메이션 캐릭터 완성"
date: 2026-09-02
weight: 35
---

> **Phase 5: 캐릭터와 애니메이션** | 예상 학습 시간: 45분

---

## 🎯 학습 목표

- Day 29~34에서 배운 모델링·리깅·애니메이션·Animator·Blend Tree·Avatar 설정을 하나의 캐릭터 파이프라인으로 연결해 재현할 수 있다
- Idle → Walk → Run이 자연스럽게 전환되는 Blend Tree 기반 로코모션(locomotion) 시스템을 직접 구성할 수 있다
- 캐릭터 애니메이션에서 흔히 발생하는 문제(발 미끄러짐, 전환 튐, Avatar 매핑 오류)를 체크리스트로 진단하고 수정할 수 있다

---

## 1. 5주차 전체 그림 — 모델에서 걷는 캐릭터까지

Phase 5는 정적인 3D 모델이 실제로 "걷고 뛰는 캐릭터"가 되기까지의 전체 여정입니다. Day 22~28(Phase 4)이 모델을 Unity로 옮기는 파이프라인이었다면, 이번 주는 그 모델에 뼈대와 움직임을 불어넣는 단계입니다.

| Day | 주제 | 파이프라인 단계 |
|---|---|---|
| 29 | 캐릭터 모델링 기초와 토폴로지 | ① 애니메이션에 적합한 메쉬 구조 만들기 |
| 30 | 리깅(Rigging) 기초 - 본 구조 이해 | ② 메쉬에 뼈대(Armature) 심기 |
| 31 | Blender에서 애니메이션 만들기 기초 | ③ 키프레임으로 동작 제작 |
| 32 | Unity Animator Controller와 State Machine | ④ 여러 동작을 상태로 관리 |
| 33 | Blend Tree로 자연스러운 애니메이션 전환 | ⑤ 상태 간 부드러운 보간 |
| 34 | Humanoid Rig와 Avatar 설정 | ⑥ Unity가 인식하는 표준 골격으로 매핑 |

이번 실습은 이 6단계를 실제로 밟아 "Idle → Walk → Run"이 자연스럽게 전환되는 캐릭터 하나를 완성하는 것이 목표입니다.

---

## 2. 실습 개요 — 무엇을 만드는가

Day 29~31에서 만든(또는 Mixamo 등에서 받은) 캐릭터 모델과 Walk/Run/Idle 애니메이션 클립을 대상으로 다음 결과물을 완성합니다.

- Humanoid Avatar로 정상 매핑된 캐릭터가 Unity 씬에 배치된 상태
- Idle, Walk, Run 세 상태가 하나의 Blend Tree로 연결되어 입력 값에 따라 부드럽게 전환되는 상태
- 방향키(또는 WASD) 입력에 따라 걷기/뛰기 속도가 자연스럽게 변하는 간단한 이동 스크립트

특정 캐릭터 하나를 정해 아래 절차를 순서대로 따라가는 것이 이번 정리의 핵심입니다.

---

## 3. 단계별 실습 절차

### 3.1 캐릭터 메쉬 점검 (Day 29 복습)

애니메이션이 예정된 캐릭터는 관절 부위(팔꿈치, 무릎, 어깨)의 루프가 충분히 촘촘해야 구부러질 때 메쉬가 찌그러지지 않습니다.

```
Blender Edit Mode → 관절 주변 Loop Cut(Ctrl+R) 2~3줄 추가
→ 팔꿈치/무릎이 90도 구부러질 때 메쉬가 매끄럽게 휘는지 Pose 모드에서 미리 확인
```

> 💡 **실무 팁**: 토폴로지를 이번 단계에서 다시 손보는 것이 리깅 이후에 고치는 것보다 훨씬 빠릅니다. 리깅 후 발견된 토폴로지 문제는 웨이트 페인팅을 처음부터 다시 해야 하는 경우가 많습니다.

### 3.2 리깅 상태 확인 (Day 30 복습)

```
Blender → Armature가 메쉬 내부 관절 위치에 정확히 맞춰져 있는지 확인
Weight Paint 모드 → 관절 경계 부위(어깨, 골반)의 가중치 그라데이션 점검
```

- 본(bone) 하나에 가중치가 100% 쏠려 다른 부위가 전혀 안 움직이는 곳이 없는지 확인
- Pose 모드에서 팔을 크게 돌려보며 스킨이 뚫리거나(clipping) 찢어지는 부분이 없는지 시각적으로 검사

### 3.3 애니메이션 클립 준비 (Day 31 복습)

Idle, Walk, Run 세 개의 애니메이션을 각각 별도 Action으로 분리해 FBX로 Export합니다.

```
Blender → Action Editor에서 Idle/Walk/Run을 독립된 Action으로 분리
→ File → Export → FBX (Bake Animation 체크)
```

> 각 클립의 시작 프레임과 끝 프레임이 정확히 루프되도록(첫 프레임과 마지막 프레임의 포즈가 자연스럽게 이어지도록) Graph Editor에서 확인합니다.

### 3.4 Animator Controller 구성 (Day 32 복습)

```
Assets → Create → Animator Controller
→ Idle, Walk, Run 상태를 각각 State로 추가
→ Parameters에 Speed(Float) 추가
```

Idle → Walk, Walk → Run 사이에 Transition을 만들고 Speed 파라미터를 조건으로 설정합니다(예: Speed > 0.1이면 Walk로 전환).

### 3.5 Blend Tree로 전환 부드럽게 만들기 (Day 33 복습)

State를 하나씩 잇는 대신, Idle/Walk/Run을 하나의 Blend Tree(1D)로 묶고 Speed 값에 따라 세 애니메이션이 보간되도록 구성합니다.

```
Animator 창 → 빈 State 우클릭 → Create New Blend Tree
Blend Tree 더블클릭 → Motion Field에 Idle(Speed 0), Walk(Speed 0.5), Run(Speed 1) 등록
Blend Type: 1D, Parameter: Speed
```

> 💡 **실무 팁**: Walk와 Run 사이의 Speed 값(예: 0.5~1 구간)에서 발 스텝이 겹쳐 보이는 "더블 스텝" 현상이 흔합니다. 두 클립의 스텝 타이밍(왼발이 닿는 프레임)을 맞춰두면 훨씬 자연스럽게 보간됩니다.

### 3.6 Humanoid Avatar 매핑 확인 (Day 34 복습)

```
Inspector → Rig 탭 → Animation Type: Humanoid
→ Configure... 버튼으로 Avatar 매핑 창 열기
→ 초록색(정상 매핑)인지, 빨간/노란 경고가 없는지 확인
```

Avatar가 초록색으로 전부 매핑되면 Mixamo 등 외부 애니메이션 클립도 그대로 재사용할 수 있습니다.

---

## 4. 이동 스크립트로 Speed 파라미터 연결

```csharp
using UnityEngine;

public class CharacterLocomotion : MonoBehaviour
{
    [SerializeField] private Animator animator;
    [SerializeField] private float walkSpeed = 2f;
    [SerializeField] private float runSpeed = 5f;
    [SerializeField] private float smoothTime = 0.1f;

    private float currentSpeed;
    private float speedVelocity;

    void Update()
    {
        float input = Input.GetAxis("Vertical"); // -1 ~ 1
        bool isRunning = Input.GetKey(KeyCode.LeftShift);

        float targetSpeed = Mathf.Abs(input) * (isRunning ? runSpeed : walkSpeed);
        // 0(Idle) ~ 1(Run) 범위로 정규화해 Blend Tree Speed 파라미터에 전달
        float normalizedTarget = targetSpeed / runSpeed;

        currentSpeed = Mathf.SmoothDamp(currentSpeed, normalizedTarget, ref speedVelocity, smoothTime);
        animator.SetFloat("Speed", currentSpeed);
    }
}
```

`Mathf.SmoothDamp`로 Speed 값을 부드럽게 보간해 넘기면, 키를 뗐다 눌렀을 때 애니메이션이 뚝뚝 끊기지 않고 자연스럽게 가속/감속합니다.

---

## 5. 트러블슈팅 체크리스트

실습 중 흔히 마주치는 문제와 원인을 파이프라인 단계별로 정리합니다.

| 증상 | 가능한 원인 | 확인할 단계 |
|---|---|---|
| 걸을 때 발이 바닥에서 미끄러짐(foot sliding) | Root Motion 설정 미스매치 또는 이동 스크립트 속도와 애니메이션 실제 이동 거리 불일치 | 3.4, 4 |
| Walk-Run 전환 시 다리가 겹쳐 보임 | 두 클립의 스텝 타이밍 불일치 | 3.5 |
| 팔/다리가 이상한 각도로 꺾임 | Weight Paint 가중치 경계 문제 | 3.2 |
| Avatar Configure 창에 빨간 경고 표시 | 본 계층 구조가 Humanoid 표준과 다르게 명명되거나 누락됨 | 3.6 |
| Speed를 올려도 Blend Tree가 전환되지 않음 | Animator Parameter 이름 오타 또는 스크립트에서 다른 파라미터명 사용 | 3.4, 4 |
| 외부(Mixamo) 애니메이션이 이상하게 재생됨 | Avatar Definition이 "Create From This Model"이 아니라 별도 Avatar를 잘못 참조 | 3.6 |

---

## 6. 5주차를 마치며

Phase 5는 "정적인 모델"과 "움직이는 캐릭터" 사이를 잇는 구간이었습니다. 리깅과 웨이트 페인팅처럼 눈에 잘 안 띄는 기초 작업이 부실하면, Animator나 Blend Tree를 아무리 잘 짜도 결과물이 어색해 보입니다. 다음 Phase 6부터는 이 캐릭터가 실제로 돌아다닐 환경(Terrain, 조명, 이펙트)을 만드는 단계로 넘어갑니다. 이번 정리에서 완성한 걷기/뛰기 캐릭터는 이후 환경 씬 실습에서 계속 재사용되므로, 체크리스트를 통과한 결과물을 지금 확보해두는 것이 좋습니다.

---

## 📝 핵심 요약

1. 캐릭터 애니메이션 파이프라인은 토폴로지 → 리깅 → 애니메이션 제작 → Animator Controller → Blend Tree → Avatar 매핑의 6단계로 이어진다
2. Blend Tree(1D)는 Idle/Walk/Run을 하나의 State로 묶어 Speed 파라미터 값에 따라 부드럽게 보간한다
3. 발 미끄러짐과 더블 스텝은 각각 Root Motion 불일치와 클립 간 스텝 타이밍 불일치가 주된 원인이다
4. Humanoid Avatar가 초록색으로 완전히 매핑되어야 Mixamo 등 외부 애니메이션 클립을 그대로 재사용할 수 있다
5. 이번 실습에서 완성한 로코모션 시스템은 Phase 6(환경과 월드 빌딩)부터 계속 재사용되므로 지금 탄탄히 검증해두는 것이 중요하다

---

## 🔗 참고 자료

- [Unity Manual — Animation State Machines](https://docs.unity3d.com/Manual/AnimationStateMachines.html)
- [Unity Manual — Blend Trees](https://docs.unity3d.com/Manual/class-BlendTree.html)
- [Unity Manual — Humanoid Avatar 설정](https://docs.unity3d.com/Manual/ConfiguringtheAvatar.html)

---

*⬅️ 이전: [Day 34 — Humanoid Rig와 Avatar 설정](../day-34/)  |  다음: [Day 36 — Terrain 시스템으로 지형 만들기](../day-36/) ➡️*
