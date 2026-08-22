---
title: "Day 23 — Unity Import Settings 파헤치기 (Scale, Normals, Pivot)"
date: 2026-08-22
weight: 23
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- FBX 모델을 Unity에 임포트했을 때 Inspector의 Model 탭 각 설정이 무엇을 제어하는지 설명할 수 있다
- Scale Factor, Normals/Tangents, Pivot 관련 설정을 상황에 맞게 조정할 수 있다
- Import Settings를 잘못 건드렸을 때 생기는 대표적인 문제(크기 왜곡, 그림자 깨짐, 회전 중심 어긋남)를 진단하고 고칠 수 있다

---

## 1. Model Import Settings는 왜 따로 존재하는가

Day 22에서 FBX Export 시점의 좌표계와 단위 문제를 다뤘습니다. 하지만 Export를 완벽하게 해도, **Unity가 그 파일을 어떻게 해석할지**는 또 다른 설정 영역입니다. Project 창에서 `.fbx` 파일을 선택하면 Inspector에 나타나는 `Model` / `Rig` / `Animation` / `Materials` 4개 탭 중, 오늘은 `Model` 탭에 집중합니다.

이 탭의 설정은 "파일 자체를 바꾸는 것"이 아니라 "Unity가 파일을 임포트하는 방식을 바꾸는 것"입니다. 즉 원본 FBX는 그대로 두고, Unity 쪽에서 스케일·노멀·피벗 해석 규칙만 재정의하는 구조라는 점을 먼저 이해해야 이후 설정들이 헷갈리지 않습니다.

---

## 2. Scale Factor와 Convert Units

`Model` 탭 최상단의 `Scale Factor`는 Day 22에서 다룬 단위 문제의 Unity 쪽 대응 지점입니다.

| 옵션 | 설명 |
|---|---|
| Scale Factor | FBX 파일의 단위를 Unity 단위(미터)로 변환할 때 곱하는 배율. 기본값 1 |
| Convert Units | 체크 시 FBX 메타데이터에 기록된 단위 정보를 읽어 자동으로 Scale Factor를 보정 |
| Use File Scale | 원본 파일의 스케일 정보를 얼마나 신뢰할지 결정하는 하위 옵션 |

Blender에서 `Apply All Transforms`로 크기를 1.0으로 확정하고 Export했다면, 대부분의 경우 `Convert Units`가 체크된 상태에서 Scale Factor가 자동으로 1에 맞춰집니다. 하지만 모델이 임포트 후 눈에 띄게 크거나 작다면, 원인은 십중팔구 여기 있습니다.

```
Inspector → Model 탭 → Scene 섹션
Scale Factor: 1
Convert Units: ✔
```

> 💡 **실무 팁**: Scale Factor를 임포트 단계에서 억지로 조정해 크기를 맞추기보다, Day 22에서 다룬 것처럼 Blender에서 Export 전에 크기를 확정하는 편이 항상 우선입니다. Import 단계의 Scale Factor 조정은 "원인 해결"이 아니라 "증상 완화"에 가깝고, 나중에 같은 모델을 다른 프로젝트에 다시 임포트할 때 똑같은 문제가 재발합니다.

---

## 3. Normals와 Tangents — 그림자와 라이팅이 깨지는 이유

`Model` 탭의 `Geometry` 섹션에 있는 `Normals`와 `Tangents` 설정은 표면이 빛을 받는 방향을 계산하는 데 쓰이는 벡터 데이터를 어떻게 처리할지 결정합니다.

| 옵션 | 값 | 설명 |
|---|---|---|
| Normals | Import | FBX에 저장된 노멀 데이터를 그대로 사용 |
| Normals | Calculate | Unity가 폴리곤 각도(Smoothing Angle 기준)로 노멀을 재계산 |
| Normals | None | 노멀 없이 임포트 (라이팅이 완전히 깨짐, 특수한 경우만 사용) |
| Tangents | Calculate Mikktspace | Normal Map을 쓰는 머티리얼에 권장되는 표준 탄젠트 계산 방식 |
| Tangents | Import | FBX에 저장된 탄젠트를 그대로 사용 |

모델 표면이 매끈해야 할 부분에서 각지게 보이거나, 반대로 각져야 할 모서리(하드 엣지)가 뭉개져 보인다면 대부분 `Normals` 설정과 `Smoothing Angle` 값의 불일치가 원인입니다.

```
Inspector → Model 탭 → Geometry 섹션
Normals: Calculate
Smoothing Angle: 60 (기본값, 엣지를 살리고 싶으면 낮추고 매끈하게 하려면 높인다)
Tangents: Calculate Mikktspace
```

> 💡 **실무 팁**: Blender에서 이미 Custom Split Normals(엣지별로 노멀을 세밀하게 조정한 데이터)를 만들어 Export했다면 `Normals`를 `Import`로 설정해야 그 작업이 유지됩니다. `Calculate`로 두면 Unity가 각도 기준으로 노멀을 새로 계산해버려 애써 다듬은 셰이딩이 사라집니다.

---

## 4. Pivot과 오브젝트 원점 문제

Pivot(피벗, 회전·이동의 기준점)은 Import Settings 화면에 직접적인 슬라이더로 노출되지는 않지만, `Model` 탭의 `Materials` 위쪽 옵션들과 Blender 쪽 원점 설정이 함께 작용해 결정됩니다. 실무에서 가장 자주 겪는 문제는 "문을 열려고 회전시켰더니 문짝이 아니라 벽 전체가 돌아가는 것처럼 보이는" 현상인데, 이는 대부분 오브젝트의 피벗이 원하는 위치(예: 경첩)가 아니라 메시의 임의 중심(보통 Bounding Box 중심이나 월드 원점)에 잡혀 있기 때문입니다.

**피벗 문제를 해결하는 두 가지 접근:**

1. **Blender에서 미리 잡기**: `Object > Set Origin > Origin to 3D Cursor`로 3D 커서를 원하는 위치(경첩 등)에 두고 원점을 옮긴 뒤 Export합니다. 가장 근본적인 해결책입니다.
2. **Unity에서 빈 GameObject로 감싸기**: 이미 임포트된 모델의 피벗을 바꿀 수 없을 때, 원하는 위치에 빈 GameObject를 만들어 모델을 자식으로 넣고, 그 빈 오브젝트를 회전/이동 기준으로 삼습니다.

```
방법 2 예시 계층 구조:
Door_Pivot (Empty, 경첩 위치로 이동)
 └ Door_Mesh (실제 FBX 모델, 로컬 좌표만 조정)
```

> 💡 **실무 팁**: 문, 뚜껑, 회전하는 손잡이처럼 "특정 축을 기준으로 회전해야 하는" 오브젝트는 모델링 단계에서부터 피벗 위치를 염두에 두고 작업하는 것이 좋습니다. Unity에서 빈 GameObject로 감싸는 방법은 유효하지만, 계층 구조가 늘어나 프로젝트 규모가 커질수록 관리 부담이 커집니다.

---

## 5. Materials 탭 — 자재 검색을 위한 최소 지식

오늘 다룬 Scale/Normals/Pivot과 별개로, `Materials` 탭에는 임포트 시 머티리얼을 어떻게 생성할지 결정하는 `Material Creation Mode` 옵션이 있습니다. 이 부분은 Day 24(Material 재구성 워크플로우)에서 본격적으로 다루므로, 오늘은 다음 한 가지만 기억해두면 충분합니다.

```
Inspector → Model 탭 → Materials 섹션
Material Creation Mode: Standard (Import via MaterialDescription)
```

이 값이 `None`으로 되어 있으면 Unity가 머티리얼을 아예 생성하지 않고 기본 회색 재질만 적용하므로, 모델이 "질감 없이 밋밋하게 회색으로 보인다"면 가장 먼저 확인할 지점입니다.

---

## 📝 핵심 요약

1. Model Import Settings는 원본 FBX 파일을 바꾸는 것이 아니라, Unity가 그 파일을 해석하는 방식을 재정의하는 설정이다
2. 크기 문제는 `Scale Factor`와 `Convert Units`로 조정할 수 있지만, 근본 해결은 Day 22처럼 Export 전 단계에서 크기를 1.0으로 확정하는 것이다
3. 그림자·라이팅이 깨지면 `Normals`(Import/Calculate)와 `Smoothing Angle`, Normal Map을 쓴다면 `Tangents: Calculate Mikktspace`를 확인한다
4. 피벗은 Blender에서 `Set Origin`으로 미리 잡는 것이 근본적이며, 이미 임포트된 모델은 빈 GameObject로 감싸 우회할 수 있다
5. 모델이 회색으로 보이면 `Materials` 탭의 `Material Creation Mode`가 `None`으로 되어 있지 않은지부터 확인한다

---

## 🔗 참고 자료

- [Unity Manual — Model Import Settings](https://docs.unity3d.com/Manual/FBXImporter-Model.html)
- [Unity Manual — Model 파일의 노멀과 탄젠트](https://docs.unity3d.com/Manual/FBXImporter-Model.html#NormalsAndTangents)
- [Blender Manual — Set Origin](https://docs.blender.org/manual/en/latest/scene_layout/object/editing/origin.html)

---

*⬅️ 이전: [Day 22 — FBX/OBJ 포맷 이해와 Export 설정](../day-22/)  |  다음: [Day 24 — Material 재구성 - Blender to Unity 워크플로우](../day-24/) ➡️*
