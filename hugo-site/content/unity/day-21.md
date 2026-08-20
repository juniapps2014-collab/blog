---
title: "Day 21 — 3주차 정리: 간단한 소품 모델링 완성"
date: 2026-08-20
weight: 21
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Day 15~20에서 배운 모델링·모디파이어·UV·텍스처링·라이팅 과정을 하나의 소품 제작 파이프라인으로 연결할 수 있다
- 실전 소품(머그컵 또는 나무 상자) 하나를 처음부터 끝까지 직접 모델링·언랩·머티리얼링·렌더링할 수 있다
- 완성된 결과물을 스스로 점검할 수 있는 체크리스트 기준으로 품질을 검증할 수 있다

---

## 1. 이번 정리 프로젝트의 목표와 소품 선정

3주차(Day 15~20) 동안 배운 것을 나열하면 다음과 같습니다.

| Day | 배운 내용 |
|---|---|
| 15 | Blender 설치와 인터페이스 |
| 16 | 기본 Mesh 모델링과 편집 모드 |
| 17 | Modifier 스택(Subdivision, Mirror 등) |
| 18 | UV 언랩 기초 |
| 19 | 텍스처링과 머티리얼 기초 |
| 20 | 라이팅과 렌더링 개념 |

오늘은 이 여섯 가지를 **하나의 짧은 파이프라인**으로 묶어, 실제로 손에 잡히는 소품 하나를 완성합니다. 초보자가 다루기 좋은 난이도와 대칭성을 고려해 아래 두 가지 중 하나를 추천합니다.

- **머그컵**: 원통 기반 모델링 + Mirror/Subdivision 모디파이어 + 손잡이 돌출 연습에 적합
- **나무 상자(Crate)**: 큐브 기반 모델링 + 베벨 + 반복 패턴 텍스처링 연습에 적합

이 글에서는 **머그컵**을 기준으로 설명합니다. 곡면과 손잡이가 있어 Day 16~20의 기법을 골고루 써볼 수 있기 때문입니다.

> 💡 **실무 팁**: 정리 프로젝트는 "새로운 것을 배우는 시간"이 아니라 "이미 배운 것을 연결하는 시간"입니다. 새 기능이 필요할 것 같으면 일단 넘어가고, Day 22 이후 Unity 임포트 단계에서 다시 다듬어도 늦지 않습니다.

---

## 2. 모델링 단계 (Day 16, 17 복습)

1. `Add > Mesh > Cylinder`로 원통을 추가하고, Object Data Properties에서 Vertices를 24~32 정도로 설정해 부드러운 곡면을 확보합니다.
2. Edit Mode(Tab)로 들어가 상단 면을 선택 후 `I`(Inset)로 안쪽 면을 만들고, `E`(Extrude) + 아래 방향 이동으로 컵 내부 공간을 파냅니다.
3. 벽 두께를 만들기 위해 안쪽 면을 다시 살짝 안쪽으로 Inset한 뒤 아래로 Extrude하여 바닥과의 두께를 확보합니다.
4. 손잡이는 별도의 `Cube`를 추가해 컵 옆면 형태에 맞게 스케일·회전한 뒤, Edit Mode에서 가운데 구멍을 뚫듯 Loop Cut(`Ctrl+R`)과 Extrude로 다듬습니다.
5. `Modifier Properties` 탭에서 **Subdivision Surface** 모디파이어를 추가해 Viewport/Render Levels을 2 정도로 설정하면, 각진 폴리곤이 부드러운 곡면으로 보정됩니다.

```
Add > Mesh > Cylinder (Vertices: 28)
Edit Mode → 상단 면 Inset(I) → Extrude(E) 내부 파기
Modifier Properties → Add Modifier → Generate → Subdivision Surface (Levels: 2)
```

> 💡 **실무 팁**: Subdivision Surface를 적용하기 전에 `Ctrl+A > Apply > Scale`로 오브젝트 스케일을 1.0으로 초기화해두면, 나중에 비대칭 왜곡 없이 균일하게 부드러워집니다.

---

## 3. UV 언랩 단계 (Day 18 복습)

1. 오브젝트를 전체 선택(`A`)한 뒤 Edge Mode에서 필요한 부분(손잡이와 컵 몸통의 경계, 바닥 둘레)에 `Ctrl+E > Mark Seam`으로 심(Seam)을 표시합니다.
2. `U > Unwrap`으로 UV를 펼치고, UV Editing 워크스페이스에서 결과를 확인합니다.
3. UV 섬(island)이 서로 겹치지 않는지, 왜곡(늘어남)이 심한 부분은 없는지 육안으로 점검합니다.

```
Edge Mode 선택 → 손잡이 경계 + 바닥 둘레 엣지 선택
Ctrl+E → Mark Seam
전체 선택(A) → U → Unwrap
```

> 💡 **실무 팁**: 원통형 오브젝트는 옆면 전체를 감싸는 심 하나 + 위/아래 둘레 심만 있어도 대부분 깔끔하게 펼쳐집니다. 심을 너무 많이 넣으면 오히려 UV 섬이 잘게 쪼개져 텍스처 이음매가 늘어납니다.

---

## 4. 머티리얼 & 텍스처링 단계 (Day 19 복습)

Shading 워크스페이스에서 Principled BSDF 노드를 기준으로 아래 값을 설정합니다.

| 속성 | 도자기 컵(광택) | 나무 손잡이(있다면) |
|---|---|---|
| Base Color | 밝은 아이보리색 | 진한 갈색 계열 |
| Roughness | 0.15~0.25 (매끈함) | 0.5~0.6 (약간 거침) |
| Metallic | 0 | 0 |

- 단색 재질이라면 Base Color만 조정해도 충분하지만, 실감을 더하고 싶다면 Poly Haven 등에서 받은 세라믹/나무 텍스처를 `Image Texture` 노드로 연결해 Base Color와 Roughness에 각각 입력합니다.
- Day 18에서 만든 UV 좌표가 이 단계의 텍스처 매핑 기준이 되므로, 이음매가 어색하다면 UV 단계로 돌아가 심 위치를 조정합니다.

> 💡 **실무 팁**: 색상보다 Roughness 값이 "재질처럼 보이는가"에 더 큰 영향을 줍니다. 색이 맞아도 Roughness가 틀리면 플라스틱처럼 보이는 경우가 많으니, Roughness 값을 먼저 맞추고 색을 미세 조정하는 순서를 권장합니다.

---

## 5. 라이팅과 최종 렌더 (Day 20 복습)

1. Day 20에서 배운 3점 조명 구도(Key/Fill/Rim)를 그대로 적용합니다. Area 라이트 두 개(Key, Fill)와 옵션으로 Rim 하나면 충분합니다.
2. World Properties에서 간단한 HDRI를 씌워 반사와 은은한 배경광을 확보합니다.
3. Render Engine을 Eevee로 두고 실시간으로 구도를 잡은 뒤, 최종 이미지가 필요하면 Cycles로 전환해 F12로 렌더링합니다.

```
Key(Area, 1000W) — 카메라 기준 좌측 위 45도
Fill(Area, 300W) — 반대편 낮은 각도
World → HDRI 적용
F12 → 최종 렌더 이미지 출력
```

완성된 렌더 이미지를 스크린샷 또는 PNG로 저장해두면, Day 22 이후 FBX/OBJ로 Export한 뒤 Unity에서 임포트한 결과와 비교하는 기준(레퍼런스)으로 쓸 수 있습니다.

---

## 6. 완성도 체크리스트

아래 다섯 가지를 스스로 점검하며 3주차를 마무리합니다.

| 항목 | 확인 기준 |
|---|---|
| 실루엣 | 회전시켜봤을 때 각 방향에서 형태가 자연스러운가 |
| 토폴로지 | Subdivision 적용 후 이상하게 찌그러지는 부분이 없는가 |
| UV | UV Editing 화면에서 섬이 겹치거나 심하게 늘어난 부분이 없는가 |
| 머티리얼 | 조명 아래에서 재질감(광택/거침)이 의도대로 보이는가 |
| 렌더 | 3점 조명으로 그림자와 하이라이트가 입체감 있게 표현되는가 |

5개 항목 중 막히는 부분이 있다면, 해당하는 Day(16~20)로 돌아가 다시 짚고 넘어가는 것을 권장합니다.

---

## 📝 핵심 요약

1. 3주차 정리는 새 지식을 배우기보다 Day 15~20의 모델링→UV→머티리얼→라이팅 파이프라인을 한 번에 연결해보는 과정이다
2. 머그컵처럼 곡면과 돌출부가 있는 소품은 Subdivision Surface, Mirror 등 모디파이어 활용을 연습하기 좋다
3. UV 심은 최소한으로, 재질은 Roughness 값을 우선으로 맞추는 것이 실전에서 더 빠르고 자연스러운 결과를 만든다
4. 3점 조명 + HDRI 조합의 최종 렌더 이미지는 Day 22 이후 Unity 임포트 결과와 비교할 기준 레퍼런스로 남겨둔다
5. 실루엣·토폴로지·UV·머티리얼·렌더 5개 항목 체크리스트로 완성도를 스스로 점검한다

---

## 🔗 참고 자료

- [Blender Manual — Modeling](https://docs.blender.org/manual/en/latest/modeling/index.html)
- [Blender Manual — UV Editing](https://docs.blender.org/manual/en/latest/modeling/meshes/uv/index.html)
- [Blender Manual — Principled BSDF](https://docs.blender.org/manual/en/latest/render/shader_nodes/shader/principled.html)

---

*⬅️ 이전: [Day 20 — 라이팅 기초와 렌더링 개념](../day-20/)  |  다음: [Day 22 — FBX/OBJ 포맷 이해와 Export 설정](../day-22/) ➡️*
