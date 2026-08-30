---
title: "Day 31 — Blender에서 애니메이션 만들기 기초"
date: 2026-08-30
weight: 31
---

> **Phase 5: 캐릭터와 애니메이션** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 키프레임(Keyframe)과 타임라인의 개념을 이해하고, Pose Mode에서 본에 키프레임을 삽입할 수 있다
- Dope Sheet와 Graph Editor의 역할 차이를 이해하고, 보간(Interpolation) 방식을 조정해 애니메이션 품질을 개선할 수 있다
- Action과 NLA(Non-Linear Animation)의 개념을 이해하고, 간단한 루프 애니메이션을 직접 만들 수 있다

---

## 1. 애니메이션의 기본 단위 — 키프레임과 타임라인

Day 30에서 만든 본 체인은 Pose Mode에서 손으로 회전시키면 그 순간만 자세가 바뀝니다. 이 자세를 **시간의 특정 지점에 저장**하는 것이 바로 **키프레임(Keyframe)**입니다.

애니메이션은 결국 "몇 번째 프레임에 어떤 자세였는가"를 여러 개 저장해두고, 그 사이 구간은 Blender가 자동으로 보간(Interpolation)해서 채워주는 방식으로 만들어집니다.

```
Frame 1   : 팔이 내려간 자세   (키프레임 A)
Frame 12  : 팔이 올라간 자세   (키프레임 B)
Frame 24  : 팔이 내려간 자세   (키프레임 A와 동일 → 루프 완성)
```

Blender 화면 하단의 **Timeline**(또는 Dope Sheet가 겹친 영역)에서 현재 프레임 위치와 키프레임 마커(◆)를 확인할 수 있습니다. 기본 프레임 레이트는 24fps이며, `Output Properties` 탭에서 변경할 수 있습니다.

> 💡 **실무 팁**: 게임용 애니메이션은 대부분 짧은 루프(걷기, 대기 동작 등)로 구성됩니다. 처음부터 긴 시퀀스를 만들기보다, 12~24프레임 정도의 짧은 루프를 정확히 만드는 연습이 훨씬 효율적입니다.

---

## 2. Pose Mode에서 키프레임 삽입하기

애니메이션은 반드시 **Pose Mode**에서 작업합니다. Edit Mode에서 본의 구조 자체를 바꾸는 것과 달리, Pose Mode는 본을 "포즈만 바꾸는" 모드입니다.

```
1. Armature 선택 → Ctrl+Tab 또는 모드 드롭다운 → Pose Mode 진입
2. 원하는 본 선택 (예: UpperArm.L)
3. R(Rotate)로 원하는 자세로 회전
4. I(Insert Keyframe) → 삽입할 채널 선택
   - Location : 위치만
   - Rotation : 회전만 (관절 애니메이션에서 가장 흔히 사용)
   - Location & Rotation & Scale : 전체(LRS)
5. 타임라인에 다이아몬드 마커(◆)가 생성됨 → 현재 프레임에 키프레임 저장 완료
```

| 단축키 | 동작 |
|---|---|
| `I` | 현재 프레임에 키프레임 삽입 |
| `Alt + I` | 선택한 본의 키프레임 삭제 |
| `→` / `←` | 프레임 앞/뒤 이동 |
| `Shift + →` / `Shift + ←` | 마지막/처음 프레임으로 이동 |

> 💡 **실무 팁**: 매번 채널을 골라 삽입하기 번거롭다면, `Pose → Animation → Keying Set`을 미리 지정해두거나 자동 키잉(Auto Keying, 타임라인의 빨간 원 아이콘)을 켜서 자세를 바꿀 때마다 자동으로 키프레임이 저장되게 할 수 있습니다. 다만 자동 키잉은 의도치 않은 키가 많이 생길 수 있어 초반에는 수동 삽입을 권장합니다.

---

## 3. Dope Sheet와 Graph Editor — 타이밍과 이징 조정

키프레임을 찍는 것만으로는 뻣뻣하고 기계적인 움직임만 나옵니다. 좋은 애니메이션은 "언제, 얼마나 빠르게 변하는가"를 세밀하게 조정하는 데서 나오며, 이를 위한 두 가지 핵심 에디터가 있습니다.

### 3.1 Dope Sheet — 키프레임의 타이밍을 조정

Dope Sheet는 모든 본/채널의 키프레임을 한눈에 보여주는 트랙 뷰입니다.

```
- 키프레임을 좌우로 드래그 → 타이밍 조정 (예: 팔이 올라가는 시점을 앞당기기)
- 여러 키프레임을 선택 후 함께 이동 → 동작 전체의 타이밍 오프셋
- G(Grab)로 이동, S(Scale)로 키프레임 간격 늘리기/줄이기
```

### 3.2 Graph Editor — 보간 곡선(이징)을 조정

Graph Editor는 키프레임 사이의 **변화율**을 곡선으로 보여줍니다. 같은 두 키프레임이라도 곡선 모양에 따라 체감되는 움직임이 완전히 달라집니다.

| 보간 방식 | 특징 |
|---|---|
| Constant | 중간값 없이 다음 키프레임까지 그대로 유지되다가 순간 전환 (로봇/디지털 느낌) |
| Linear | 일정한 속도로 균일하게 변화 (기계적으로 보이기 쉬움) |
| Bezier (기본값) | 시작과 끝에서 느려지는 자연스러운 가감속(Ease In/Out) |

```
1. Graph Editor에서 키프레임 선택
2. T(Interpolation) → Bezier / Linear / Constant 선택
3. Bezier 선택 시 핸들(손잡이)을 드래그해 가속/감속 정도를 세밀 조정
```

> 💡 **실무 팁**: 실무에서 "애니메이션이 뭔가 어색하다"는 피드백의 상당수는 타이밍보다 **보간 곡선** 문제입니다. 특히 Linear로 방치된 관절 회전은 기계적으로 보이기 쉬우므로, 기본값인 Bezier를 유지하고 Graph Editor에서 Ease In/Out 정도를 직접 확인하는 습관을 들이는 것이 좋습니다.

---

## 4. Action과 NLA — 여러 애니메이션을 관리하기

캐릭터 하나에는 걷기, 뛰기, 대기, 점프 등 여러 개의 독립적인 애니메이션이 필요합니다. Blender는 이 각각의 애니메이션 단위를 **Action**이라고 부릅니다.

```
Action 예시
├─ Idle       (대기 동작, 루프)
├─ Walk       (걷기, 루프)
├─ Run        (뛰기, 루프)
└─ Jump       (점프, 1회성)
```

- **Action Editor**(Dope Sheet 모드 중 하나)에서 새 Action을 생성하고 이름을 지정합니다.
- 각 Action은 독립적으로 저장되며, 나중에 Unity로 Export할 때 이 Action 단위가 그대로 애니메이션 클립으로 대응됩니다.

여러 Action을 순서대로 배치하거나 블렌딩하고 싶다면 **NLA(Non-Linear Animation) Editor**를 사용합니다. NLA는 각 Action을 "스트립(Strip)" 형태로 타임라인 위에 배치해, 마치 영상 편집 툴처럼 애니메이션들을 조합할 수 있게 해줍니다.

```
NLA Editor 트랙 예시
Track 1: [Idle 스트립]───[Walk 스트립]───[Idle 스트립]
```

> 이 개념은 Day 32에서 다룰 Unity Animator Controller의 **State Machine**과 사실상 목적이 같습니다. Blender NLA가 "여러 Action을 편집 시점에 조합"한다면, Unity Animator는 "런타임에 조건(State Machine)에 따라 Action을 전환"한다는 차이가 있습니다.

---

## 5. 실습 — 팔 흔들기 루프 애니메이션 만들기

Day 30에서 만든 3본(UpperArm → LowerArm → Hand) 체인으로 간단한 루프 애니메이션을 만들어봅니다.

```
1. Pose Mode 진입, 프레임을 1로 이동
2. 팔을 자연스러운 시작 자세로 배치 → UpperArm, LowerArm 선택 후 I → Rotation 키 삽입
3. 프레임을 12로 이동
4. UpperArm을 살짝 앞으로, LowerArm을 살짝 구부린 자세로 변경 → 다시 Rotation 키 삽입
5. 프레임을 24로 이동
6. 1번 프레임과 동일한 자세로 되돌림(1번 키프레임을 복사하거나 동일하게 회전) → Rotation 키 삽입
7. 타임라인 끝 프레임을 24로 설정(Output Properties → Frame End)
8. Spacebar로 재생 → 자연스럽게 반복되는지 확인
```

재생했을 때 24번 프레임에서 1번 프레임으로 넘어가는 지점이 툭 끊기는 느낌이 든다면, 두 키프레임의 회전값이 정확히 일치하는지, Graph Editor에서 보간 곡선이 매끄럽게 이어지는지 확인합니다.

> 💡 **실무 팁**: 루프 애니메이션은 시작과 끝 프레임의 포즈가 **완전히 동일**해야 이어붙였을 때 끊김이 없습니다. 시작 키프레임을 만든 뒤 그대로 복사(Ctrl+C → Ctrl+V)해서 마지막 프레임에 붙여넣으면 미세한 오차 없이 정확히 일치시킬 수 있습니다.

---

## 📝 핵심 요약

1. 애니메이션은 특정 프레임에 자세를 저장하는 키프레임과, 그 사이를 자동으로 채우는 보간으로 구성된다
2. 키프레임은 Pose Mode에서 `I`로 삽입하며, Rotation 채널만 삽입하는 것이 관절 애니메이션의 기본이다
3. Dope Sheet는 키프레임의 타이밍을, Graph Editor는 키프레임 사이의 변화율(보간 곡선)을 조정하는 도구다
4. 하나의 캐릭터는 Idle/Walk/Run 등 여러 Action으로 나뉘어 관리되며, NLA Editor로 이들을 조합할 수 있다
5. 루프 애니메이션은 시작과 끝 프레임의 포즈를 완전히 동일하게 만들어야 자연스럽게 반복된다

---

## 🔗 참고 자료

- [Blender Manual — Animation & Rigging](https://docs.blender.org/manual/en/latest/animation/index.html)
- [Blender Manual — Keyframes](https://docs.blender.org/manual/en/latest/animation/keyframes/index.html)
- [Blender Manual — NLA (Non-Linear Animation)](https://docs.blender.org/manual/en/latest/editors/nla/index.html)

---

*⬅️ 이전: [Day 30 — 리깅(Rigging) 기초 - 본 구조 이해](../day-30/)  |  다음: [Day 32 — Unity Animator Controller와 State Machine](../day-32/) ➡️*
