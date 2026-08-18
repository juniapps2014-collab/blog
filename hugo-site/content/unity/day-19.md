---
title: "Day 19 — 텍스처링과 머티리얼 기초"
date: 2026-08-18
weight: 19
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- 머티리얼과 텍스처의 관계, 그리고 PBR 워크플로우의 기본 구조를 설명할 수 있다
- Principled BSDF 셰이더의 핵심 입력값(Base Color, Roughness, Metallic 등)을 이해하고 조정할 수 있다
- Shader Editor에서 Image Texture 노드와 UV Map 노드를 연결해 Day 18에서 만든 UV맵 위에 텍스처를 입힐 수 있다

---

## 1. 머티리얼과 텍스처는 무엇이 다른가

**머티리얼(Material)**은 표면이 빛을 어떻게 반사·흡수·투과하는지를 정의하는 "속성의 집합"입니다. 색상, 거칠기, 금속성, 투명도 같은 값들이 여기에 포함됩니다. **텍스처(Texture)**는 이런 속성값들을 표면 위치마다 다르게 지정하기 위해 사용하는 이미지 데이터입니다.

즉 머티리얼이 "이 표면은 이런 규칙으로 빛을 반사한다"는 설정이라면, 텍스처는 그 규칙을 표면의 각 지점마다 세밀하게 다르게 적용하기 위한 지도라고 볼 수 있습니다. Day 18에서 만든 UV맵이 바로 이 지도를 3D 표면 위에 정확히 붙이기 위한 좌표계 역할을 합니다.

| 구분 | 정의 | 예시 |
|---|---|---|
| 머티리얼 | 표면의 광학적 속성 설정 전체 | "이 오브젝트는 금속이고 거칠기는 0.3이다" |
| 텍스처 | 속성값을 위치별로 다르게 주기 위한 이미지 | 녹슨 부분만 거칠기를 높이는 이미지 맵 |
| UV맵 | 텍스처 이미지를 3D 표면에 붙이는 좌표 대응 관계 | Day 18에서 만든 언랩 결과 |

> 💡 **실무 팁**: 균일한 단색 플라스틱처럼 표면 전체가 똑같은 속성을 가진다면 텍스처 없이 머티리얼 값만으로 충분합니다. 텍스처는 표면에 "위치에 따른 변화"가 필요할 때만 추가하면 됩니다.

---

## 2. Principled BSDF — Blender의 기본 셰이더

Blender에서 새 머티리얼을 만들면 기본으로 연결되는 셰이더가 **Principled BSDF**입니다. 이 하나의 노드로 플라스틱, 금속, 유리, 고무 등 대부분의 실제 재질을 표현할 수 있도록 설계된 물리 기반(PBR) 셰이더입니다.

| 입력값 | 역할 | 비고 |
|---|---|---|
| Base Color | 표면의 기본 색상(고유색) | 텍스처 연결 시 가장 먼저 연결하는 슬롯 |
| Metallic | 0=비금속, 1=금속 | 대부분 0 또는 1에 가깝게 사용, 중간값은 드묾 |
| Roughness | 표면 거칠기 (0=매끈한 거울면, 1=완전 확산) | 하이라이트의 크기와 선명도를 결정 |
| Normal | 표면의 미세한 굴곡을 시뮬레이션 | Normal Map 텍스처를 Normal Map 노드 경유해 연결 |
| Alpha | 투명도 | 1=불투명, 0=완전 투명 |

Material Properties 탭(구슬 모양 아이콘)에서 Base Color 옆의 색상 스와치를 클릭하면 단색을 지정할 수 있고, 이 자리에 이미지 텍스처를 연결하면 위치별로 색이 달라지는 표면을 만들 수 있습니다.

> 💡 **실무 팁**: Metallic과 Roughness를 극단값(0 또는 1) 대신 어중간한 값으로 설정하면 실제로는 잘 존재하지 않는 "가짜 재질" 느낌이 납니다. 실제 사진 레퍼런스를 보면서 값을 잡는 습관을 들이면 훨씬 사실적인 결과가 나옵니다.

---

## 3. Shader Editor에서 이미지 텍스처 연결하기

단색이 아니라 이미지를 표면에 입히려면 Shader Editor(셰이더 에디터)에서 노드를 직접 연결해야 합니다.

### 3.1 기본 연결 절차

```
1. Shading 워크스페이스 탭으로 전환
2. Shader Editor에서 Add > Texture > Image Texture 노드 추가
3. Image Texture 노드에서 "New" 또는 "Open"으로 이미지 불러오기
4. Add > Input > UV Map 노드 추가 후, UV Map 노드의 출력(Vector)을
   Image Texture 노드의 입력(Vector)에 연결
5. Image Texture 노드의 출력(Color)을 Principled BSDF의 Base Color에 연결
```

UV Map 노드를 생략해도 Blender가 기본 UV맵을 자동으로 사용하지만, 오브젝트에 UV맵이 여러 개 있는 경우 UV Map 노드로 어떤 UV셋을 쓸지 명시하는 것이 안전합니다.

### 3.2 색공간(Color Space) 설정 주의

Image Texture 노드 하단에는 Color Space 설정이 있습니다. 이 값을 텍스처 용도에 맞게 지정하지 않으면 색상이 왜곡되어 보입니다.

| 텍스처 종류 | Color Space | 이유 |
|---|---|---|
| Base Color, Emission | sRGB (기본값) | 사람 눈에 보이는 색 그대로 표시되는 감마 보정된 이미지 |
| Roughness, Metallic, Normal, Height | Non-Color | 색상이 아니라 수치 데이터이므로 감마 보정을 적용하면 안 됨 |

> 💡 **실무 팁**: Roughness 맵을 sRGB로 잘못 불러오면 밝기 값이 왜곡되어 거칠기 표현이 실제와 달라집니다. "색으로 보이는 텍스처인가, 수치 데이터인가"를 항상 구분해서 Color Space를 지정하세요.

---

## 4. 뷰포트에서 결과 확인하기

노드를 연결해도 Solid 셰이딩 모드에서는 텍스처가 보이지 않습니다. 뷰포트 우측 상단의 셰이딩 모드 아이콘(구체 4개)에서 확인 방식을 바꿀 수 있습니다.

| 모드 | 표시 내용 |
|---|---|
| Solid | 텍스처 없이 단색/기본 음영만 표시 |
| Material Preview | 머티리얼 노드 연결 결과를 간이 조명으로 실시간 표시 |
| Rendered | 실제 렌더 엔진(Eevee/Cycles) 기준으로 조명·그림자까지 반영해 표시 |

작업 중에는 **Material Preview** 모드로 텍스처가 UV에 맞게 잘 붙었는지 빠르게 확인하고, 최종 라이팅 결과는 Day 20에서 다룰 **Rendered** 모드에서 점검하는 흐름이 일반적입니다.

---

## 📝 핵심 요약

1. 머티리얼은 표면의 광학적 속성 설정이고, 텍스처는 그 속성을 위치별로 다르게 부여하는 이미지 데이터다
2. Principled BSDF는 Base Color, Metallic, Roughness, Normal 등의 입력값으로 대부분의 실제 재질을 표현하는 PBR 기반 셰이더다
3. Shader Editor에서 UV Map → Image Texture → Principled BSDF 순서로 노드를 연결해 텍스처를 표면에 입힌다
4. Base Color 계열은 sRGB, Roughness/Normal 등 수치 데이터 텍스처는 Non-Color로 Color Space를 구분해 설정해야 한다
5. Material Preview 모드로 UV 정합성을 빠르게 확인하고, Rendered 모드는 Day 20의 라이팅 학습에서 본격적으로 활용한다

---

## 🔗 참고 자료

- [Blender Manual — Principled BSDF](https://docs.blender.org/manual/en/latest/render/shader_nodes/shader/principled.html)
- [Blender Manual — Image Texture Node](https://docs.blender.org/manual/en/latest/render/shader_nodes/textures/image.html)
- [Blender Manual — Color Management](https://docs.blender.org/manual/en/latest/render/color_management.html)

---

*⬅️ 이전: [Day 18 — UV 언랩(Unwrapping) 기초](../day-18/)  |  다음: [Day 20 — 라이팅 기초와 렌더링 개념](../day-20/) ➡️*
