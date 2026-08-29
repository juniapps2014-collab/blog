---
title: "Day 30 — 리깅(Rigging) 기초 - 본 구조 이해"
date: 2026-08-29
weight: 30
---

> **Phase 5: 캐릭터와 애니메이션** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 리깅(Rigging)이 무엇이며, 스켈레톤(Armature)과 스키닝(Skinning)이 어떻게 연결되는지 설명할 수 있다
- 계층적 본(Bone) 구조와 부모-자식 관계, Forward Kinematics(FK) 개념을 이해하고 간단한 본 체인을 구성할 수 있다
- 웨이트 페인팅(Weight Painting)의 원리를 이해하고, Day 29의 토폴로지 설계가 왜 리깅 품질에 직접 영향을 주는지 설명할 수 있다

---

## 1. 리깅이란 무엇인가 — 모델과 애니메이션을 잇는 다리

Day 29에서 만든 캐릭터 메쉬는 그 자체로는 **정적인 하나의 덩어리**입니다. 팔을 들어올리거나 걷게 만들려면, 메쉬 내부에 "이 부분은 이렇게 움직인다"는 제어 구조를 심어야 합니다. 이 작업이 바로 **리깅(Rigging)**입니다.

리깅은 크게 두 단계로 나뉩니다.

1. **Armature(스켈레톤) 제작** — 캐릭터 내부에 뼈대(Bone) 구조를 배치
2. **Skinning(스키닝)** — 메쉬의 각 정점이 어떤 본에 얼마나 영향을 받을지 연결(Weight Painting)

이 둘이 합쳐지면, 본을 회전시키는 것만으로 메쉬 표면이 자연스럽게 따라 변형됩니다. Day 31에서 다룰 애니메이션 제작, Day 32의 Unity Animator는 모두 이 리깅 구조 위에서 동작합니다.

> 💡 **실무 팁**: 리깅은 "한 번 잘 만들면 계속 재사용"하는 자산입니다. Humanoid Rig(Day 34)로 표준화해두면 다른 캐릭터의 애니메이션을 그대로 재활용(리타겟팅)할 수 있으므로, 지금 배우는 기본 구조를 정확히 이해해두는 것이 이후 작업 속도를 크게 좌우합니다.

---

## 2. Armature와 본(Bone)의 계층 구조

Blender에서 스켈레톤은 **Armature**라는 오브젝트 타입으로 존재하며, 그 안에 여러 개의 **Bone**이 계층적으로 연결됩니다.

### 2.1 부모-자식 관계(Parent-Child Hierarchy)

본은 서로 독립적이지 않고, 인체 구조처럼 부모-자식으로 연결됩니다.

```
Root (전체 캐릭터의 기준점)
 └─ Spine (척추 하단)
     └─ Chest (가슴)
         ├─ Shoulder.L → UpperArm.L → LowerArm.L → Hand.L
         ├─ Shoulder.R → UpperArm.R → LowerArm.R → Hand.R
         └─ Neck → Head
     └─ Hip.L → Thigh.L → Shin.L → Foot.L
     └─ Hip.R → Thigh.R → Shin.R → Foot.R
```

부모 본이 회전하면 자식 본도 함께 따라 움직입니다. 예를 들어 `UpperArm.L`을 회전시키면 `LowerArm.L`과 `Hand.L`도 어깨를 축으로 함께 회전합니다 — 이것이 바로 **Forward Kinematics(FK)**입니다.

> 실제 어깨→팔꿈치→손이 움직이는 순서(부모→자식 방향으로 회전이 전파되는 방식)와 동일합니다. 반대로 손의 위치를 먼저 정하고 팔꿈치·어깨가 자동으로 따라오게 하는 방식은 **Inverse Kinematics(IK)**라 하며, Day 32 이후 애니메이션 심화 과정에서 다룹니다.

### 2.2 본의 좌표 정보 — Head와 Tail

Blender의 본은 하나의 직선으로 표현되며, 두 개의 기준점을 가집니다.

| 요소 | 의미 |
|---|---|
| Head | 본이 시작되는 지점 (보통 관절의 회전 축 위치) |
| Tail | 본이 끝나는 지점 (다음 본의 Head와 연결됨) |
| Roll | 본이 자신의 길이 방향 축을 기준으로 회전된 정도 |

```
UpperArm.L.Tail == LowerArm.L.Head   (팔꿈치 위치에서 정확히 맞물림)
```

> 💡 **실무 팁**: Head/Tail이 정확히 관절 회전축에 위치하지 않으면, 구부릴 때 메쉬가 이상한 지점을 중심으로 접힙니다. 배치 전에 앞/옆 뷰(Numpad 1, 3)를 번갈아 확인하며 본을 배치하는 습관이 중요합니다.

---

## 3. 간단한 본 체인 만들기 (Blender 실습)

이번 Day는 팔 하나로 축소한 간단한 본 체인을 직접 만들어보는 것을 권장합니다.

```
1. Shift+A → Armature → Single Bone 추가
2. Edit Mode 진입 (Tab)
3. 본의 Tail(끝점)을 선택 → E(Extrude)로 다음 본을 이어서 생성
   → 팔꿈치 위치에서 Extrude → 손목 위치에서 다시 Extrude
   결과: UpperArm → LowerArm → Hand, 3개의 본이 자동으로 부모-자식 연결됨
4. Pose Mode로 전환 (Ctrl+Tab 또는 모드 드롭다운)
5. LowerArm 본을 선택하고 R(Rotate)로 회전
   → Hand 본이 함께 따라 회전하는지 확인 (FK 동작 확인)
```

이 상태에서는 아직 메쉬와 연결되지 않았기 때문에 본만 따로 움직입니다. 다음 단계인 스키닝을 거쳐야 실제 메쉬가 반응합니다.

---

## 4. 스키닝과 웨이트 페인팅 — 본과 메쉬를 연결하기

본 구조가 완성되면, 메쉬의 정점들이 "어느 본을 얼마나 따라갈지"를 지정해야 합니다. 이 과정이 **Skinning**이고, 그 결과 값이 **Weight(가중치)**입니다.

### 4.1 자동 웨이트와 수동 보정

```
1. 메쉬와 Armature를 모두 선택 (Armature를 마지막에 선택)
2. Ctrl+P → With Automatic Weights
   → Blender가 본과 정점 사이의 거리를 기반으로 초기 웨이트를 자동 계산
3. Weight Paint Mode 진입 → 관절 주변을 확인
   → 파란색(웨이트 0) ~ 빨간색(웨이트 1)로 시각화됨
4. 문제가 있는 부위(예: 팔꿈치를 구부렸는데 가슴 쪽 메쉬가 같이 늘어남)를
   브러시로 직접 웨이트 재조정
```

| 웨이트 값 | 의미 |
|---|---|
| 1.0 | 해당 본의 움직임에 100% 따라감 |
| 0.5 | 두 본 사이에서 절반씩 영향받음 (관절 중간 지대에 흔함) |
| 0.0 | 해당 본의 영향을 전혀 받지 않음 |

> 💡 **실무 팁**: 자동 웨이트는 항상 "초안"으로 생각해야 합니다. 특히 겨드랑이, 골반처럼 여러 본이 가까이 모이는 부위는 자동 계산이 자주 틀리므로, Weight Paint에서 반드시 직접 구부려보며 검증(Pose Mode 토글로 확인)하는 과정이 필요합니다.

### 4.2 Day 29 토폴로지가 왜 여기서 중요한가

웨이트 페인팅은 정점 단위로 이루어지기 때문에, Day 29에서 다룬 엣지 루프 배치가 그대로 웨이트 경계선의 품질을 결정합니다. 관절 부위에 루프가 부족하면, 웨이트를 아무리 정교하게 조정해도 구부러지는 지점의 정점 수가 부족해 핀칭이 그대로 남습니다. 즉 **좋은 토폴로지는 리깅을 쉽게 만들고, 나쁜 토폴로지는 리깅으로 고칠 수 없는 문제를 만듭니다.**

---

## 📝 핵심 요약

1. 리깅은 Armature(뼈대) 제작과 Skinning(메쉬-본 연결)의 두 단계로 이루어진다
2. 본은 부모-자식 계층 구조를 가지며, 부모의 회전이 자식에게 전파되는 방식이 Forward Kinematics(FK)다
3. 본은 Head/Tail 두 기준점으로 정의되며, 관절 회전축에 정확히 배치해야 자연스러운 변형이 나온다
4. 자동 웨이트는 초안일 뿐이며, Weight Paint Mode에서 직접 구부려보며 보정하는 과정이 필수다
5. Day 29의 토폴로지 설계 품질이 리깅·웨이트 페인팅 결과를 직접 좌우한다

---

## 🔗 참고 자료

- [Blender Manual — Armatures](https://docs.blender.org/manual/en/latest/animation/armatures/index.html)
- [Blender Manual — Skinning](https://docs.blender.org/manual/en/latest/animation/armatures/skinning/index.html)
- [Unity Manual — Rigging Characters](https://docs.unity3d.com/Manual/RiggingCharacter.html)

---

*⬅️ 이전: [Day 29 — 캐릭터 모델링 기초와 토폴로지](../day-29/)  |  다음: [Day 31 — Blender에서 애니메이션 만들기 기초](../day-31/) ➡️*
