---
title: "Day 34 — Humanoid Rig와 Avatar 설정"
date: 2026-09-01
weight: 34
---

> **Phase 5: 캐릭터와 애니메이션** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Rig 탭의 Generic/Humanoid/Legacy 애니메이션 타입 차이와 각각의 사용 시점을 설명할 수 있다
- Avatar Configuration 화면에서 본 매핑을 확인·수정하고, T-Pose 요구사항을 이해할 수 있다
- Humanoid Avatar의 리타겟팅(Retargeting) 원리를 활용해 서로 다른 캐릭터 간 애니메이션을 재사용할 수 있다

---

## 1. Animation Type — Generic vs Humanoid vs Legacy

FBX를 임포트하면 Inspector의 **Rig** 탭에서 Animation Type을 선택합니다. 이 선택이 이후 애니메이션 워크플로우 전체를 좌우합니다.

| Animation Type | 특징 | 적합한 대상 |
|---|---|---|
| None | 애니메이션 데이터를 사용하지 않음 | 정적 소품, 배경 모델 |
| Legacy | 구버전 Animation 컴포넌트 기반, Mecanim 이전 방식 | 레거시 프로젝트 유지보수용 (신규 프로젝트에는 권장 안 함) |
| Generic | 뼈대 구조를 그대로 사용, 사람이 아닌 임의의 스켈레톤도 지원 | 동물, 몬스터, 기계 등 휴머노이드가 아닌 리그 |
| Humanoid | Unity의 표준 인체 골격 템플릿(Avatar)에 매핑 | 두 팔·두 다리를 가진 사람형 캐릭터 |

Generic과 Humanoid의 가장 큰 차이는 **애니메이션 재사용성**입니다. Generic은 원본 리그 구조에 완전히 종속되어 있어서, 다른 모델의 애니메이션 클립을 가져다 쓸 수 없습니다. Humanoid는 Unity가 정의한 공통 골격(Avatar)을 거치기 때문에, 골격 비율이 달라도 같은 Humanoid 애니메이션 클립을 재생할 수 있습니다.

> 💡 **실무 팁**: 사람 캐릭터라도 반드시 Humanoid를 써야 하는 것은 아닙니다. Asset Store의 애니메이션 팩을 여러 캐릭터에 공유할 계획이 없고, 성능을 극한까지 아끼고 싶은 특수한 경우(대규모 군중 시뮬레이션 등)라면 Generic이 연산 비용이 약간 더 낮습니다. 하지만 대부분의 프로젝트에서는 Humanoid의 재사용성 이득이 훨씬 큽니다.

---

## 2. Avatar Configuration — 본 매핑 확인과 수동 보정

Animation Type을 Humanoid로 설정하고 Apply를 누르면, Unity는 FBX의 본 이름과 계층 구조를 분석해 자신의 표준 골격(머리, 척추, 상완, 하완, 손, 대퇴, 정강이, 발 등)에 자동으로 매핑을 시도합니다. 매핑이 애매하거나 실패하면 Avatar Definition 옆에 경고 아이콘이 뜹니다.

Rig 탭의 **Configure...** 버튼을 누르면 전용 Avatar 편집 화면으로 들어갑니다.

1. 화면 왼쪽 계층 구조에서 각 골격 슬롯(Head, Spine, LeftUpperArm, RightHand 등)을 선택
2. Scene 뷰에서 어떤 본이 매핑됐는지 초록색으로 하이라이트 확인
3. 자동 매핑이 잘못됐으면 계층 구조에서 슬롯을 클릭한 뒤 Scene/Hierarchy에서 올바른 본을 드래그해 재할당
4. 필수 슬롯(팔, 다리, 척추, 머리)이 모두 초록색이어야 하고, 손가락 본처럼 선택적인 슬롯은 없어도 무방

| 상태 색상 | 의미 |
|---|---|
| 초록 | 정상 매핑됨 |
| 노랑 | 매핑됐지만 필수는 아님(선택적 본) |
| 빨강 / 회색 | 매핑 실패 또는 미할당 (필수 슬롯이면 경고 발생) |

> 💡 **실무 팁**: 매핑 실패는 대부분 본 이름 규칙 문제입니다. Blender에서 좌우 본을 `_L`/`_R`이 아니라 `.L`/`.R`로 명명했거나, 이름에 공백이 섞이면 자동 인식률이 떨어집니다. Export 전에 본 이름을 `LeftUpperArm`, `Hand_L`처럼 일관된 규칙으로 정리해두면 자동 매핑 성공률이 크게 올라갑니다.

---

## 3. T-Pose 요구사항과 Pose 탭

Humanoid Avatar는 **최초 바인드 포즈가 T-Pose(또는 A-Pose)에 가까워야** 정확히 동작합니다. Unity의 근육(Muscle) 시스템이 팔다리의 회전 기준값을 이 초기 포즈에서 계산하기 때문에, 캐릭터가 이상한 자세(팔이 심하게 굽거나 다리가 꼬인 상태)로 Export되면 애니메이션 재생 시 관절이 뒤틀리는 문제가 생깁니다.

Configure 화면의 **Pose** 드롭다운에서 확인·보정할 수 있습니다.

- `Enforce T-Pose`: 현재 매핑을 기준으로 강제로 T-Pose를 재계산
- `Reset`: Import 시점의 원본 포즈로 되돌림
- `Sample Bind-Pose`: FBX의 바인드 포즈를 다시 샘플링

```
정상적인 T-Pose 기준
- 팔: 양옆으로 수평(지면과 평행)으로 뻗음
- 다리: 골반 아래로 곧게, 발끝은 정면
- 손바닥: 아래를 향함(또는 모델링 규칙에 따라 통일)
```

> 💡 **실무 팁**: Blender에서 캐릭터를 A-Pose(팔을 45도 정도 내린 자세)로 모델링하는 경우가 흔한데, Humanoid는 A-Pose도 허용합니다. 다만 좌우 팔다리의 각도가 비대칭이면 매핑 오차가 커지므로, 반드시 좌우 대칭을 맞춘 상태로 Export해야 합니다.

---

## 4. Muscles & Settings — 관절 가동 범위 제한

Configure 화면의 **Muscles & Settings** 탭에서는 각 관절의 회전 가능 범위를 슬라이더로 조정합니다. 이는 리타겟팅된 애니메이션이 해부학적으로 불가능한 각도(팔이 몸을 관통하는 등)로 꺾이는 것을 막는 안전장치입니다.

| 항목 | 역할 |
|---|---|
| Spine Front-Back / Left-Right / Twist | 척추의 굽힘·비틀림 범위 |
| Left/Right Arm Down-Up, Front-Back, Twist | 팔의 가동 범위 |
| Left/Right Leg Down-Up, Front-Back, Twist | 다리의 가동 범위 |
| Per-Muscle Range 슬라이더 | 개별 근육 단위로 최소/최대 각도 미세 조정 |

하단의 **Test** 슬라이더로 극단적인 포즈를 미리 재생해보며, 관절이 부자연스럽게 꺾이는 지점을 찾아 Range 값을 좁혀줄 수 있습니다.

> 💡 **실무 팁**: 이 설정은 캐릭터 하나하나가 아니라 "이 Avatar로 재생될 모든 애니메이션"에 공통 적용됩니다. 특정 클립 하나만 이상하게 재생된다면 Muscle 설정보다는 해당 클립 자체나 본 매핑을 먼저 의심하는 것이 순서에 맞습니다.

---

## 5. Avatar 재사용과 리타겟팅(Retargeting)

Humanoid의 진짜 힘은 **Avatar를 다른 모델과 공유**할 때 나타납니다. 두 캐릭터 A(원본 애니메이션 보유)와 B(다른 비율의 모델)가 있을 때:

1. A의 애니메이션 클립을 B의 Animator Controller에도 그대로 연결
2. B의 Rig 탭 Animation Type도 Humanoid로 설정, Avatar Definition은 `Create From This Model`
3. Unity가 런타임에 A의 골격 비율 → Unity 표준 Avatar → B의 골격 비율 순으로 자동 변환(리타겟팅)해 재생

```
A 캐릭터 애니메이션 클립
        ↓ (A의 Avatar 기준으로 인코딩)
   Unity 표준 Humanoid 골격 (중간 표현)
        ↓ (B의 Avatar 기준으로 디코딩)
B 캐릭터에서 동일한 동작으로 재생
```

키가 크거나 팔다리 비율이 다른 캐릭터라도 상대적인 관절 각도가 유지되므로, Mixamo나 Asset Store에서 구매한 애니메이션 팩을 자신의 커스텀 캐릭터에 그대로 붙일 수 있는 것도 이 원리 덕분입니다.

> 💡 **실무 팁**: 리타겟팅 품질은 두 캐릭터의 팔다리 비율 차이가 클수록 떨어집니다(예: 성인 캐릭터의 걷기 애니메이션을 그대로 어린이/드워프 캐릭터에 적용하면 보폭이 부자연스러움). 비율 차이가 큰 캐릭터는 Animator의 **Additional Settings**에서 Foot IK를 켜고 발이 지면에 닿는 위치를 보정하면 어색함이 줄어듭니다.

---

## 📝 핵심 요약

1. Animation Type은 Generic(비인체 리그)과 Humanoid(사람형, 애니메이션 재사용 가능)의 목적이 다르며, 대부분의 사람 캐릭터는 재사용성 때문에 Humanoid를 선택한다
2. Avatar Configuration 화면에서 필수 골격 슬롯이 모두 초록색으로 매핑됐는지 확인하고, 실패 시 본 이름 규칙부터 점검한다
3. Humanoid Avatar는 T-Pose(또는 좌우 대칭 A-Pose) 기준으로 근육 회전값을 계산하므로 바인드 포즈의 대칭성이 중요하다
4. Muscles & Settings의 관절 가동 범위는 캐릭터 전체가 아니라 Avatar 단위로 공통 적용되는 안전장치다
5. Humanoid 리타겟팅 덕분에 서로 다른 비율의 캐릭터 간에도 같은 애니메이션 클립을 공유할 수 있으며, 비율 차이가 클 때는 Foot IK로 보정한다

---

## 🔗 참고 자료

- [Unity Manual — Humanoid Avatars](https://docs.unity3d.com/Manual/AvatarCreationandSetup.html)
- [Unity Manual — Configuring Avatars](https://docs.unity3d.com/Manual/ConfiguringtheAvatar.html)
- [Unity Manual — Retargeting Animation](https://docs.unity3d.com/Manual/Retargeting.html)

---

*⬅️ 이전: [Day 33 — Blend Tree로 자연스러운 애니메이션 전환](../day-33/)  |  다음: [Day 35 — 5주차 정리: 걷기/뛰기 애니메이션 캐릭터 완성](../day-35/) ➡️*
