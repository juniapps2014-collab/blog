---
title: "Day 26 — PBR(Physically Based Rendering) 텍스처링 워크플로우"
date: 2026-08-25
weight: 26
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- PBR의 핵심 원리(에너지 보존, Metallic/Roughness 워크플로우)를 설명할 수 있다
- Albedo, Metallic, Roughness, Normal, AO 등 각 텍스처 맵의 역할과 올바른 색 공간(sRGB/Linear)을 구분할 수 있다
- Unity 임포트 규칙에 맞춰 채널 패킹된 텍스처를 구성하고, Day 25에서 다룬 URP Lit 셰이더 슬롯에 정확히 연결할 수 있다

---

## 1. PBR이 해결하려는 문제

PBR 이전의 전통적인 셰이딩(Blinn-Phong 등)은 아티스트가 직접 "이 표면은 이 정도로 반짝여야 자연스럽다"는 값을 감으로 조정했습니다. 문제는 이 값들이 물리 법칙을 따르지 않다 보니, 라이팅 환경이 바뀌면(낮→밤, 실내→실외) 같은 머티리얼이 완전히 다르게 보이거나 부자연스러워졌습니다.

PBR은 실제 빛의 물리적 성질을 근사해서, **어떤 조명 환경에서도 일관되게 사실적으로 보이는** 셰이딩 모델입니다. 핵심 원칙은 두 가지입니다.

- **에너지 보존(Energy Conservation)**: 표면이 반사하는 빛의 총량은 입사한 빛의 총량을 넘을 수 없습니다. 확산 반사(diffuse)와 정반사(specular)가 서로 에너지를 나눠 가지므로, 금속처럼 반사가 강한 표면은 확산 반사가 거의 없어야 합니다.
- **미세면 이론(Microfacet Theory)**: 표면은 눈에 보이지 않는 아주 작은 면(microfacet)들의 집합이며, 이 미세면들의 거칠기 분포가 빛이 퍼지는 정도(하이라이트의 크기와 흐림 정도)를 결정합니다.

> 💡 **실무 팁**: "PBR을 쓴다"는 것은 특정 셰이더를 쓴다는 뜻이 아니라, 텍스처를 물리적으로 타당한 값으로 제작한다는 워크플로우 전체를 의미합니다. 셰이더가 PBR이어도 텍스처 값이 비현실적이면(예: 비금속 표면의 Albedo가 새까맣거나 새하얌) 결과물은 여전히 부자연스럽습니다.

---

## 2. Metallic 워크플로우 vs Specular 워크플로우

PBR을 구현하는 방식은 크게 두 가지가 있으며, URP의 `Lit` 셰이더(Day 25)는 기본적으로 Metallic 워크플로우를 사용합니다.

| 구분 | Metallic 워크플로우 | Specular 워크플로우 |
|---|---|---|
| 핵심 파라미터 | Base Color + Metallic(0~1) | Diffuse Color + Specular Color |
| 표현 방식 | "이 표면이 금속이냐 아니냐"를 스칼라 값 하나로 표현 | 반사율을 RGB 색상으로 직접 지정 |
| 텍스처 수 | 상대적으로 적음(Metallic은 흑백 1채널) | Specular 컬러맵이 추가로 필요 |
| 주 사용처 | 게임 엔진 전반(Unity, Unreal) 표준 | 일부 영화/오프라인 렌더링, 레거시 파이프라인 |

Metallic 워크플로우에서는 `Metallic` 값이 0이면 비금속(dielectric, 플라스틱·나무·피부 등), 1이면 금속입니다. 이 값 하나가 "Base Color를 확산 반사로 쓸지, 정반사 색으로 쓸지"를 결정합니다.

- Metallic = 0: Base Color가 확산 반사 색이 되고, 정반사는 모든 비금속에 공통적인 약한 흰색(약 4% 반사율)으로 고정
- Metallic = 1: Base Color가 그대로 정반사 색이 되고, 확산 반사는 0 (금속은 빛을 흡수해 산란시키지 않음)

> 💡 **실무 팁**: Metallic 값은 대부분의 오브젝트에서 0 아니면 1에 가까운 극단값이어야 합니다. 0.3, 0.5 같은 중간값은 "반쯤 금속인 표면"을 의미하지 않고 대부분 물리적으로 잘못된 결과(먼지 낀 금속 가장자리 등 특수한 경우 제외)를 만듭니다.

---

## 3. PBR 텍스처 맵 한눈에 정리

Day 24에서 Blender ↔ Unity 머티리얼 슬롯을 대응시켰다면, 이번에는 그 슬롯에 들어갈 **텍스처 자체를 어떻게 만들고 임포트해야 하는지**를 다룹니다.

| 맵 | 저장 정보 | 색 공간 | 채널 |
|---|---|---|---|
| Albedo (Base Color) | 표면 고유의 색상 (그림자·하이라이트 정보 없이 순수한 색) | sRGB | RGB |
| Metallic | 금속 여부 (0=비금속, 1=금속) | Linear | 흑백 1채널 |
| Smoothness / Roughness | 표면 매끄러움/거칠기 정도 | Linear | 흑백 1채널 |
| Normal Map | 실제 지오메트리를 늘리지 않고 표면 굴곡을 표현 | Linear (Normal Map 전용 설정) | RGB (탄젠트 공간 벡터) |
| Ambient Occlusion (AO) | 주변 지오메트리에 의해 빛이 가려지는 정도 | Linear | 흑백 1채널 |
| Height / Displacement | 실제 높낮이 정보 (Parallax, Tessellation용) | Linear | 흑백 1채널 |

가장 중요한 실수 포인트는 **색 공간**입니다. Albedo처럼 사람 눈에 보이는 최종 색상을 담은 텍스처는 sRGB로 저장·해석되어야 하지만, Metallic/Roughness/Normal/AO처럼 순수한 수치 데이터를 담은 텍스처는 Linear로 해석해야 합니다. 이를 혼동하면 감마 보정이 이중으로 적용되어 거칠기나 금속성이 실제보다 밝거나 어둡게 계산됩니다.

```
Unity 텍스처 Import Settings 확인 사항
- Texture Type: Default
- sRGB (Color Texture) 체크박스
  → Albedo: 체크 (sRGB)
  → Metallic/Roughness/AO/Mask 맵: 체크 해제 (Linear)
- Normal Map 텍스처는 Texture Type을 "Normal Map"으로 지정
  → Unity가 자동으로 올바른 인코딩/디코딩 처리
```

> 💡 **실무 팁**: Normal Map을 "Default" 타입인 채로 임포트하면 노멀 벡터가 잘못 디코딩되어 표면 굴곡이 뒤틀려 보입니다. Inspector에서 "Fix Now" 버튼이 뜨면 반드시 눌러서 Texture Type을 Normal Map으로 변환하세요.

---

## 4. 채널 패킹(Channel Packing) — 텍스처 개수 줄이기

텍스처 맵을 각각 별도 파일로 두면 드로우콜당 샘플링해야 할 텍스처 수가 늘어나 메모리와 대역폭을 많이 씁니다. 그래서 실무에서는 흑백 1채널 맵들을 하나의 RGBA 텍스처에 채널별로 욱여넣는 **채널 패킹**을 씁니다.

URP `Lit` 셰이더가 기대하는 대표적인 패킹 방식(Metallic Map 슬롯 기준):

| 채널 | 담기는 정보 |
|---|---|
| R | Metallic |
| G | (사용 안 함, 또는 커스텀 마스크) |
| B | (사용 안 함, 또는 커스텀 마스크) |
| A | Smoothness |

즉 Metallic과 Smoothness를 하나의 텍스처(R채널=Metallic, A채널=Smoothness)로 합쳐서 임포트하면, 머티리얼 슬롯 1개(Metallic Map)만으로 두 정보를 모두 전달할 수 있습니다. Occlusion은 URP Lit에서는 별도의 Occlusion Map 슬롯을 쓰지만, HDRP나 커스텀 셰이더에서는 R=Metallic/G=AO/B=(미사용)/A=Smoothness처럼 3~4개 맵을 한 텍스처에 합치는 "Mask Map" 관례를 쓰기도 합니다.

```
Substance Painter / Photoshop에서 채널 패킹하는 대표적 방법
1. Metallic, Roughness(또는 1-Roughness=Smoothness), AO를 각각 흑백 이미지로 렌더
2. 이미지 편집 툴의 채널 믹서/채널 분리 기능으로
   R = Metallic, G = AO, B = 0, A = Smoothness 로 합성
3. PNG(무손실) 또는 프로젝트 압축 설정에 맞는 포맷으로 export
```

> 💡 **실무 팁**: 채널 패킹된 텍스처는 반드시 무손실 압축(PNG)이나 손실 압축 시에도 채널 간 블리딩이 적은 포맷을 사용해야 합니다. JPEG처럼 채널 간 색 정보를 섞어 압축하는 포맷은 패킹된 마스크 데이터를 손상시킬 수 있어 피해야 합니다.

---

## 5. 실전 워크플로우 — Blender/Substance에서 Unity까지

Day 15~21에서 Blender로 모델링했다면, PBR 텍스처링은 보통 다음 순서로 진행됩니다.

1. **UV 언랩** (Day 18에서 완료) — 텍스처가 왜곡 없이 펼쳐질 표면 좌표 확보
2. **베이킹(Baking)** — 고폴리곤 디테일(조각, 굴곡)을 저폴리곤 모델의 Normal Map으로 구워냄. AO 맵도 이 단계에서 함께 베이킹하는 경우가 많음
3. **텍스처 페인팅** — Substance Painter, Blender의 Texture Paint 모드 등에서 Albedo/Metallic/Roughness를 직접 칠하거나 스마트 머티리얼로 자동 생성
4. **Export 프리셋 설정** — 대부분의 텍스처링 툴은 "Unity URP/HDRP" export 프리셋을 기본 제공하며, 이 프리셋이 위에서 설명한 채널 패킹 규칙을 자동으로 적용
5. **Unity 임포트** — Day 23의 Import Settings, Day 24의 머티리얼 슬롯 매핑, 이번 글의 색 공간 설정을 순서대로 적용

```
Substance Painter export 프리셋 예시 (Unity URP용)
- BaseColor  → sRGB
- Metallic   → R 채널, Linear
- Smoothness → Metallic 텍스처의 A 채널 (Roughness를 반전해서 사용)
- Normal     → OpenGL 방식(Unity는 OpenGL 노멀 컨벤션 사용)
- AO         → 별도 Linear 텍스처 또는 Detail Map에 패킹
```

> 💡 **실무 팁**: Normal Map에는 OpenGL 방식과 DirectX 방식 두 가지 컨벤션이 있고 Y(초록) 채널의 방향이 반대입니다. Unity는 OpenGL 컨벤션을 기본으로 사용하므로, Substance Painter 등에서 export할 때 반드시 "OpenGL" 프리셋을 선택해야 합니다. DirectX로 잘못 export하면 굴곡이 움푹 파인 것처럼 반대로 보입니다.

---

## 📝 핵심 요약

1. PBR은 에너지 보존과 미세면 이론에 기반해 조명 환경이 달라져도 일관되게 사실적으로 보이는 셰이딩 방식이며, URP `Lit`은 Metallic 워크플로우를 사용한다
2. Albedo는 sRGB, Metallic/Roughness/AO/Normal은 Linear로 색 공간을 올바르게 설정해야 하며, Normal Map은 Texture Type을 반드시 "Normal Map"으로 지정해야 한다
3. 채널 패킹(예: Metallic=R, Smoothness=A)으로 여러 흑백 맵을 하나의 텍스처에 합쳐 드로우콜당 텍스처 샘플링 비용을 줄일 수 있다
4. 베이킹 → 텍스처 페인팅 → Export 프리셋 → Unity 임포트로 이어지는 파이프라인에서, Normal Map은 OpenGL 컨벤션으로 export해야 Unity에서 올바르게 보인다

---

## 🔗 참고 자료

- [Unity Manual — Physically Based Rendering (PBR) 개요](https://docs.unity3d.com/Manual/StandardShaderMaterialParameters.html)
- [Unity Manual — Universal Render Pipeline Lit shader](https://docs.unity3d.com/Manual/urp/lit-shader.html)
- [Unity Manual — Normal map (Bump mapping) 텍스처 임포트](https://docs.unity3d.com/Manual/StandardShaderMaterialParameterNormalMap.html)

---

*⬅️ 이전: [Day 25 — URP(Universal Render Pipeline) 기초](../day-25/)  |  다음: [Day 27 — 폴리곤 수 최적화와 LOD 개념](../day-27/) ➡️*
