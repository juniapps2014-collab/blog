---
title: "Day 16 — 기본 도형(Mesh) 모델링과 편집 모드"
date: 2026-08-15
weight: 16
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Edit Mode에서 Vertex/Edge/Face 선택 모드를 전환하고 상황에 맞게 활용할 수 있다
- 기본 Mesh(Cube, Sphere, Cylinder 등)를 추가하고 편집 모드에서 형태를 자유롭게 변형할 수 있다
- Extrude, Loop Cut, Bevel, Inset 등 핵심 모델링 도구로 간단한 소품을 만들 수 있다

---

## 1. Edit Mode 진입과 선택 모드

Day 15에서 `Tab` 키로 Object Mode와 Edit Mode를 전환한다는 개념만 짚었다면, 오늘은 Edit Mode 안에서 실제로 형태를 만드는 방법을 다룹니다.

Edit Mode에 들어가면 상단 헤더 왼쪽에 세 가지 선택 모드 아이콘이 나타납니다.

| 모드 | 단축키 | 선택 단위 | 주 용도 |
|---|---|---|---|
| Vertex Select | `1` | 정점(점) | 정밀한 형태 조정, 좌표 이동 |
| Edge Select | `2` | 모서리(선) | Loop Cut 결과 선택, Bevel 대상 지정 |
| Face Select | `3` | 면 | Extrude/Inset의 기준면 선택 |

세 모드는 서로 배타적이지 않고 언제든 숫자키로 즉시 전환할 수 있습니다. 예를 들어 큐브의 윗면을 밀어 올리고 싶다면 `3`(Face)으로 전환해 윗면을 클릭한 뒤 작업합니다.

> 💡 **실무 팁**: `Alt + 클릭`으로 Edge Loop(연결된 모서리 고리) 전체를 한 번에 선택할 수 있습니다. 원기둥의 특정 단면을 통째로 회전시키거나 이동할 때 자주 씁니다.

---

## 2. 기본 Mesh 추가하기

`Shift + A`(Add 메뉴) → `Mesh`에서 기본 도형을 씬에 추가합니다.

```
Add > Mesh > Cube / Sphere / Cylinder / Cone / Torus / Plane
```

기본 도형을 추가하면 화면 좌하단에 **Operator 패널**(F9로도 다시 열 수 있음)이 나타나며, 여기서 방금 추가한 오브젝트의 세부 옵션(Radius, Segments 등)을 사후 조정할 수 있습니다.

| 도형 | 조정 가능한 대표 파라미터 |
|---|---|
| UV Sphere | Segments(경도), Rings(위도) — 값이 클수록 매끄럽지만 폴리곤 수 증가 |
| Cylinder | Vertices(단면 각 수), Depth(높이), Cap Fill Type |
| Cube | Size만 존재 — 세부 형태는 Edit Mode에서 직접 편집 |

> 💡 **실무 팁**: Operator 패널은 **다음 조작을 하기 전까지만** 유효합니다. 클릭 한 번이라도 다른 작업을 하면 사라지므로, 세그먼트 수를 정밀하게 맞추고 싶다면 도형을 추가한 직후 바로 조정해야 합니다.

---

## 3. 핵심 편집 도구

### 3.1 Extrude (돌출)

`E` 키는 선택한 Vertex/Edge/Face를 복제해 이어 붙이며 밀어내는, Blender 모델링에서 가장 많이 쓰는 도구입니다.

```
Face Select 모드에서 윗면 선택 → E → 위 방향으로 드래그 → 좌클릭으로 확정
E → Z → 2 → Enter   (Z축으로 정확히 2 단위 돌출)
```

### 3.2 Loop Cut (루프 잘라내기)

`Ctrl + R`로 실행하며, 도형에 새로운 Edge Loop를 추가해 세부 편집이 가능한 지점을 늘립니다.

```
Ctrl + R → 마우스를 큐브 위에 올려 노란색 미리보기 확인 → 좌클릭으로 위치 확정 → 우클릭(또는 Esc)으로 중앙 고정
```

### 3.3 Bevel (모깎기)

`Ctrl + B`(Edge 대상) 또는 `Ctrl + Shift + B`(Vertex 대상)로 모서리를 둥글게 깎아 각진 느낌을 완화합니다. 게임 에셋에서 완전히 날카로운 모서리는 실제 조명 아래 부자연스러워 보이는 경우가 많아 실무에서 매우 자주 사용됩니다.

### 3.4 Inset (면 안쪽으로 새 면 생성)

`I` 키로 선택한 면 안쪽에 축소된 새 면을 만듭니다. 이후 그 면을 Extrude하면 창문이나 버튼 같은 디테일을 표현할 수 있습니다.

| 도구 | 단축키 | 한 줄 요약 |
|---|---|---|
| Extrude | `E` | 선택 요소를 밀어 새 형태 생성 |
| Loop Cut | `Ctrl+R` | 새 Edge Loop 추가 |
| Bevel | `Ctrl+B` | 모서리를 둥글게 깎기 |
| Inset | `I` | 면 안쪽에 축소된 새 면 생성 |

---

## 4. 선택 관련 단축키와 팁

| 단축키 | 동작 |
|---|---|
| `A` | 전체 선택 |
| `Alt + A` | 전체 선택 해제 |
| `Ctrl + 클릭` (Face 모드) | 클릭 지점까지 최단 경로로 이어서 선택 |
| `L` | 마우스 아래 연결된 요소 전체 선택 (Linked) |
| `Ctrl + Numpad +/-` | 선택 영역을 인접 요소로 확장/축소 |

> 💡 **실무 팁**: 복잡한 모델에서 실수로 뒷면의 정점까지 같이 선택되는 것을 막으려면, 헤더 우측의 **X-ray 토글**(`Alt + Z`)을 끈 상태로 작업하세요. 꺼두면 화면에 보이는 앞쪽 요소만 선택됩니다.

---

## 5. 실습 예제 — 간단한 소품 만들기

이번 주(Phase 3) 목표인 "간단한 소품 모델링"의 기초 연습으로, 큐브 하나로 상자형 소품의 뼈대를 만들어봅니다.

```
1. Shift+A → Mesh → Cube 추가
2. Tab으로 Edit Mode 진입, 3(Face)로 전환
3. 윗면 선택 → I(Inset) → 축소된 면 생성
4. 안쪽 면 선택 상태에서 E → Z → -0.3 → Enter (안쪽으로 파인 홈 생성)
5. 전체 선택(A) → Ctrl+B(Bevel) → 살짝 드래그해 모서리 라운드 처리
```

이 다섯 단계만으로도 뚜껑이 파인 상자 형태의 소품을 만들 수 있습니다. Day 17에서는 이런 개별 조작 대신 **Modifier**를 활용해 대칭·매끄러움을 비파괴적으로 다루는 방법을 배웁니다.

---

## 📝 핵심 요약

1. Edit Mode의 세 가지 선택 모드(Vertex `1`/Edge `2`/Face `3`)는 숫자키로 즉시 전환하며 작업 목적에 맞게 선택한다
2. `Shift+A`로 기본 도형을 추가하고, 추가 직후 Operator 패널에서 세그먼트 등 세부 파라미터를 조정한다
3. Extrude(`E`)/Loop Cut(`Ctrl+R`)/Bevel(`Ctrl+B`)/Inset(`I`)은 실무에서 가장 많이 쓰는 4대 모델링 도구다
4. X-ray 토글(`Alt+Z`)을 꺼두면 화면에 보이는 앞쪽 요소만 선택되어 오선택을 방지할 수 있다
5. 간단한 소품도 Inset → Extrude → Bevel 조합만으로 기본 형태를 충분히 표현할 수 있다

---

## 🔗 참고 자료

- [Blender Manual — Mesh Modeling Basics](https://docs.blender.org/manual/en/latest/modeling/meshes/introduction.html)
- [Blender Manual — Mesh Tools (Extrude, Inset, Bevel)](https://docs.blender.org/manual/en/latest/modeling/meshes/editing/edge.html)
- [Blender Manual — Selecting](https://docs.blender.org/manual/en/latest/modeling/meshes/selecting/index.html)

---

*⬅️ 이전: [Day 15 — Blender 설치와 인터페이스 익히기](../day-15/)  |  다음: [Day 17 — Modifier 스택 활용하기 (Subdivision, Mirror 등)](../day-17/) ➡️*
