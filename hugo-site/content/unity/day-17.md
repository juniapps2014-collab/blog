---
title: "Day 17 — Modifier 스택 활용하기 (Subdivision, Mirror 등)"
date: 2026-08-16
weight: 17
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Modifier의 개념과 비파괴적(Non-destructive) 워크플로우의 장점을 설명할 수 있다
- Mirror Modifier로 좌우 대칭 오브젝트를 효율적으로 모델링할 수 있다
- Subdivision Surface Modifier로 형태를 매끄럽게 만들고, Apply 시점을 판단할 수 있다

---

## 1. Modifier란 무엇인가 — 비파괴적 워크플로우

Day 16에서 배운 Extrude, Bevel 같은 도구는 **메시 데이터 자체를 직접 바꾸는(파괴적)** 편집입니다. 한번 Extrude하면 그 결과를 취소(`Ctrl+Z`) 하지 않는 이상 원래 형태로 되돌릴 수 없습니다.

**Modifier**는 이와 반대로, 원본 메시는 그대로 둔 채 "표시할 때만 적용되는 효과"를 스택 형태로 쌓는 방식입니다. Properties 패널의 렌치 모양 아이콘(Modifier Properties) 탭에서 관리합니다.

| 구분 | 파괴적 편집 (Extrude 등) | Modifier |
|---|---|---|
| 원본 데이터 | 직접 변경됨 | 그대로 유지 |
| 되돌리기 | Undo(`Ctrl+Z`)만 가능 | 언제든 값 수정·순서 변경·삭제 가능 |
| 대표 예시 | Bevel(도구), Inset | Mirror, Subdivision Surface, Array |
| 최종 적용 | 즉시 반영 | 필요할 때만 `Apply`로 메시에 확정 |

> 💡 **실무 팁**: 모델링 초반에는 최대한 Modifier로 작업하고, 형태가 확정된 뒤 마지막에 Apply하는 습관을 들이세요. 나중에 "대칭을 조금 틀고 싶다", "더 매끄럽게 하고 싶다" 같은 요청이 와도 파라미터 값만 바꾸면 되므로 재작업 비용이 크게 줄어듭니다.

---

## 2. Mirror Modifier

좌우(또는 상하) 대칭인 오브젝트—캐릭터, 무기, 가구 등—를 만들 때 절반만 모델링하고 나머지 절반을 자동으로 생성해주는 Modifier입니다.

### 2.1 기본 사용법

```
Properties > Modifier Properties(렌치 아이콘) > Add Modifier > Generate > Mirror
```

기본값은 X축 기준 대칭입니다. Object의 원점(Origin)이 대칭 기준선이 되므로, 작업 전에 `Object > Set Origin`으로 원점 위치를 원하는 대칭축에 맞춰두는 것이 중요합니다.

| 옵션 | 역할 |
|---|---|
| Axis (X/Y/Z) | 대칭 기준 축 선택 (다중 선택 가능) |
| Clipping | 대칭 중심선 근처 정점이 서로 붙도록 스냅 — 이음새 벌어짐 방지 |
| Merge | 중심선에서 겹치는 정점을 하나로 합침 |

> 💡 **실무 팁**: Clipping을 꺼둔 채로 중심선 근처 정점을 이동하면 반대편 대칭 메시와 사이가 벌어져 구멍이 생깁니다. 캐릭터나 얼굴처럼 중심선을 넘나드는 편집이 많은 모델에서는 Clipping을 항상 켜두세요.

### 2.2 절반만 모델링하는 실전 흐름

```
1. Edit Mode에서 대칭축 반대편(예: -X 방향) 절반의 정점을 모두 삭제
2. Mirror Modifier 추가, Clipping 체크
3. 남은 절반만 편집 — 반대편은 실시간으로 자동 반영됨
```

---

## 3. Subdivision Surface Modifier

각진 저폴리곤 메시를 매끄러운 곡면처럼 보이게 만드는 Modifier로, 실무에서 캐릭터·유기적 형태 모델링에 필수적으로 쓰입니다.

```
Add Modifier > Generate > Subdivision Surface
```

| 설정 | 역할 |
|---|---|
| Levels Viewport | 3D 뷰포트에서 미리보기에 적용되는 세분화 단계 (보통 1~2) |
| Levels Render | 최종 렌더링 시 적용되는 세분화 단계 (Viewport보다 높게 설정 가능) |
| Optimal Display | 세분화된 와이어프레임 대신 원본 케이지만 표시 (뷰포트 성능 향상) |

세분화 단계가 1 올라갈 때마다 폴리곤 수는 대략 4배씩 증가하므로, Level 2~3 이상은 실시간 작업 성능에 영향을 줄 수 있습니다.

> 💡 **실무 팁**: Subdivision Surface를 적용하기 전에 **원본 메시의 형태(케이지)를 미리 다듬어 두는 것**이 핵심입니다. 케이지가 이미 원하는 형태의 실루엣을 잡고 있어야 세분화 후에도 의도한 모양이 나옵니다. 케이지만 보고 세분화 결과를 예측하는 감각은 연습이 필요합니다.

---

## 4. 기타 자주 쓰는 Modifier

| Modifier | 용도 |
|---|---|
| **Array** | 오브젝트를 일정 간격/개수로 반복 배치 (울타리, 계단 등) |
| **Solidify** | 두께가 없는 평면 메시에 균일한 두께를 부여 (종이, 판넬 표현) |
| **Bevel (Modifier 버전)** | Day 16의 Bevel 도구와 달리, 모든 모서리에 자동·비파괴적으로 라운드 적용 |
| **Boolean** | 두 메시 간 합집합/교집합/차집합 연산 (구멍 뚫기 등) |

---

## 5. Modifier 순서와 Apply 시점

Modifier 스택은 **위에서 아래로 순차 적용**되며, 순서를 바꾸면 결과가 완전히 달라질 수 있습니다.

```
예: Mirror → Subdivision Surface (권장)
    대칭 후 세분화 → 이음새 부분까지 매끄럽게 처리됨

예: Subdivision Surface → Mirror (비권장인 경우가 많음)
    세분화 후 대칭 → 중심선 이음새가 매끄럽게 이어지지 않을 수 있음
```

모델링이 끝나고 Export(Day 22 예정) 전 단계에서는 `Apply`(Modifier 패널의 드롭다운 메뉴)로 스택을 실제 메시 데이터에 확정합니다. Apply 이후에는 파라미터를 더 이상 슬라이더로 조정할 수 없으므로, 형태가 완전히 확정된 뒤에만 실행합니다.

> 💡 **실무 팁**: Apply하기 전에 항상 `.blend` 파일을 별도로 저장(또는 백업)해두세요. Apply는 되돌리기 어려운 작업이라, 나중에 파라미터를 다시 조정해야 할 상황이 생기면 저장해둔 이전 버전이 유일한 복구 수단이 됩니다.

---

## 📝 핵심 요약

1. Modifier는 원본 메시를 바꾸지 않고 효과를 스택으로 쌓는 비파괴적 편집 방식이다
2. Mirror Modifier는 절반만 모델링해도 대칭 오브젝트를 완성해주며, Clipping 옵션으로 중심선 이음새를 방지한다
3. Subdivision Surface는 저폴리곤 케이지를 매끄럽게 보이게 하며, 세분화 전 케이지 형태 다듬기가 핵심이다
4. Array/Solidify/Boolean 등도 자주 쓰이는 대표 Modifier로, 각각 반복 배치·두께 부여·불리언 연산을 담당한다
5. Modifier 순서는 결과에 직접 영향을 주며, 형태가 확정된 뒤에만 Apply로 메시에 확정한다

---

## 🔗 참고 자료

- [Blender Manual — Modifiers Introduction](https://docs.blender.org/manual/en/latest/modeling/modifiers/introduction.html)
- [Blender Manual — Mirror Modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/mirror.html)
- [Blender Manual — Subdivision Surface Modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/subdivision_surface.html)

---

*⬅️ 이전: [Day 16 — 기본 도형(Mesh) 모델링과 편집 모드](../day-16/)  |  다음: [Day 18 — UV 언랩(Unwrapping) 기초](../day-18/) ➡️*
