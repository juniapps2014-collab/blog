---
title: "Day 18 — UV 언랩(Unwrapping) 기초"
date: 2026-08-17
weight: 18
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- UV 언랩의 개념과 텍스처링 파이프라인에서의 역할을 설명할 수 있다
- Seam을 표시하고 Unwrap을 실행해 3D 메시의 UV맵을 생성할 수 있다
- UV Editor에서 UV 좌표를 확인하고 겹침·왜곡을 기본적으로 정리할 수 있다

---

## 1. UV 언랩이란 무엇인가

3D 메시에 이미지(텍스처)를 입히려면, 3D 표면의 각 지점이 2D 이미지의 어느 좌표에 대응하는지 정의해야 합니다. 이 대응 관계를 **UV 좌표**라 하고, 3D 표면을 2D 평면으로 펼치는 작업을 **UV 언랩(Unwrapping)**이라 부릅니다.

이름 자체는 종이 상자를 뜯어서 평평하게 펼치는 것과 같은 원리에서 왔습니다. 실제로 정육면체의 UV를 펼치면 상자를 분해한 전개도와 매우 비슷한 모양이 나옵니다.

| 용어 | 의미 |
|---|---|
| U, V | 텍스처 이미지의 가로(U)·세로(V) 좌표축 (3D의 X, Y, Z와 구분하기 위해 U, V 사용) |
| UV Map | 메시의 각 정점이 텍스처 이미지의 어느 (U, V) 좌표에 대응하는지 저장한 데이터 |
| UV Island | 펼쳐진 UV 조각들의 개별 덩어리 (Seam으로 구분됨) |

> 💡 **실무 팁**: UV 언랩은 "귀찮지만 생략할 수 없는" 단계입니다. Day 19의 텍스처링, Day 26의 PBR 워크플로우 모두 정확한 UV가 전제되어야 의도한 대로 텍스처가 입혀집니다. 여기서 왜곡되거나 겹친 UV는 이후 단계에서 텍스처가 늘어지거나 이상하게 보이는 원인이 됩니다.

---

## 2. Seam 표시하기

**Seam(심)**은 "여기를 잘라서 펼치겠다"는 표시로, 마치 옷본을 재단하는 재봉선과 같은 역할을 합니다. Seam이 없으면 Blender가 자동으로 각도 차이가 큰 모서리를 기준으로 펼치지만, 결과가 왜곡되거나 UV Island가 너무 잘게 쪼개지는 경우가 많습니다.

### 2.1 Seam 표시 절차

```
1. Edit Mode 진입, 2(Edge Select)로 전환
2. 자르고 싶은 모서리들을 선택 (Alt+클릭으로 Edge Loop 전체 선택 가능)
3. Edge 메뉴(Ctrl+E) > Mark Seam
```

Seam으로 지정된 모서리는 뷰포트에서 **빨간색 선**으로 강조되어, 어디를 기준으로 펼칠지 시각적으로 확인할 수 있습니다.

### 2.2 어디에 Seam을 넣어야 하는가

| 원칙 | 이유 |
|---|---|
| 눈에 잘 안 띄는 위치(뒷면, 밑면)에 배치 | Seam 경계는 텍스처 이음매가 미세하게 어긋날 수 있어 시각적으로 티가 남 |
| 각도 변화가 큰 모서리를 우선 고려 | 자연스러운 전개(왜곡 최소화)를 위해 |
| 대칭 모델은 대칭축을 따라 배치 | Mirror Modifier로 만든 모델과 자연스럽게 어울림 |

> 💡 **실무 팁**: 원기둥이라면 옆면 세로선 하나 + 위/아래 원 둘레, 이렇게 최소한의 Seam만으로도 깔끔하게 펼쳐집니다. Seam을 과하게 많이 넣으면 UV Island가 너무 잘게 쪼개져 텍스처 작업이 오히려 번거로워집니다.

---

## 3. Unwrap 실행과 UV Editor

### 3.1 Unwrap 실행

```
전체 선택(A) > U(UV Mapping 메뉴) > Unwrap
```

`U` 키를 누르면 여러 펼치기 방식이 나타나는데, 가장 기본이자 범용적인 선택지는 **Unwrap**입니다.

| 방식 | 특징 |
|---|---|
| **Unwrap** | Seam 기준으로 표준 알고리즘 전개 — 대부분의 상황에서 기본 선택 |
| Smart UV Project | Seam 없이 각도 기준 자동 분할 — 빠르지만 왜곡·이음새 관리가 어려움 |
| Cube/Cylinder/Sphere Projection | 단순한 형태에 도형 기준으로 빠르게 투영 |

### 3.2 UV Editor에서 확인하기

`UV Editing` 워크스페이스 탭으로 전환하면 좌측에 2D UV Editor, 우측에 3D Viewport가 함께 표시됩니다. 3D Viewport에서 Face를 선택하면 UV Editor에 해당 부분의 UV가 하이라이트되어, 3D 형태와 2D 전개도 사이의 대응 관계를 직접 확인할 수 있습니다.

UV Editor 하단에는 0~1 범위의 정사각형 격자(**UV 공간**, Texture Space)가 표시되며, 텍스처 이미지는 항상 이 0~1 범위에 매핑됩니다.

---

## 4. UV 레이아웃 정리 팁

Unwrap 직후의 UV는 대체로 정리가 필요합니다.

| 작업 | 방법 |
|---|---|
| UV Island 재배치 | UV Editor에서 직접 `G`(이동)/`R`(회전)/`S`(스케일)로 도구 사용 (3D 뷰포트와 동일한 단축키) |
| 자동 정렬 | UV Editor의 `UV > Pack Islands` — 겹치지 않게 자동으로 공간을 채워 재배치 |
| 왜곡 확인 | Overlay 옵션의 **Stretching** 체크 — 빨간색이 많을수록 텍스처 왜곡이 심한 부분 |
| 격자 텍스처로 점검 | Checker Deform 텍스처를 임시로 입혀 정사각형 격자가 고르게 유지되는지 육안 확인 |

> 💡 **실무 팁**: `Pack Islands`는 UV를 다 펼친 뒤 마지막에 한 번씩 실행하는 습관을 들이면 좋습니다. 텍스처 해상도를 최대한 낭비 없이 활용하도록 UV Island 사이의 여백을 자동으로 최적화해줍니다.

---

## 5. 다음 단계 예고

오늘 만든 UV맵은 아직 "빈 도화지" 상태입니다. Day 19에서는 이 UV 위에 실제 색상·질감을 입히는 **텍스처링과 머티리얼 기초**를 다루고, Day 26에서는 PBR(물리 기반 렌더링) 워크플로우로 한 단계 더 심화합니다. UV가 정확히 잡혀 있어야 이후 단계의 텍스처가 의도한 위치에 정확히 표시된다는 점을 기억해두세요.

---

## 📝 핵심 요약

1. UV 언랩은 3D 표면을 2D 텍스처 좌표에 대응시키는 작업으로, 텍스처링의 전제 조건이다
2. Seam은 "여기를 잘라 펼치겠다"는 표시이며, 눈에 안 띄는 위치·각도 변화가 큰 모서리에 배치하는 것이 원칙이다
3. `U > Unwrap`이 가장 범용적인 전개 방식이며, UV Editor에서 3D-2D 대응을 실시간으로 확인할 수 있다
4. `Pack Islands`로 UV Island의 배치를 자동 최적화하고, Stretching Overlay로 왜곡 정도를 점검한다
5. 정확한 UV맵은 Day 19 텍스처링, Day 26 PBR 워크플로우의 결과 품질을 좌우하는 기초 작업이다

---

## 🔗 참고 자료

- [Blender Manual — UV Editing Introduction](https://docs.blender.org/manual/en/latest/editors/uv/introduction.html)
- [Blender Manual — Unwrapping Meshes](https://docs.blender.org/manual/en/latest/modeling/meshes/uv/unwrapping.html)
- [Blender Manual — Seams](https://docs.blender.org/manual/en/latest/modeling/meshes/select_mode.html)

---

*⬅️ 이전: [Day 17 — Modifier 스택 활용하기 (Subdivision, Mirror 등)](../day-17/)  |  다음: [Day 19 — 텍스처링과 머티리얼 기초](../day-19/) ➡️*
