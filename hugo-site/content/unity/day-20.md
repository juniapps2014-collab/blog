---
title: "Day 20 — 라이팅 기초와 렌더링 개념"
date: 2026-08-19
weight: 20
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Blender의 4가지 라이트 타입(Point, Sun, Spot, Area)의 특성과 용도를 구분해 설명할 수 있다
- Eevee와 Cycles 렌더 엔진의 동작 방식 차이를 이해하고 상황에 맞게 선택할 수 있다
- 3점 조명(Key/Fill/Rim) 구도를 직접 배치해 Day 19에서 만든 머티리얼을 자연스럽게 보이도록 렌더링할 수 있다

---

## 1. Blender의 라이트 타입 4가지

Blender는 `Add > Light` 메뉴에서 4가지 라이트 오브젝트를 제공합니다. 실제 조명 장비의 특성을 본떠 만들어졌기 때문에, 각각의 물리적 은유를 이해하면 선택이 쉬워집니다.

| 라이트 타입 | 물리적 은유 | 특징 | 주 용도 |
|---|---|---|---|
| Point | 전구 | 한 점에서 모든 방향으로 균일하게 빛 발산, 거리에 따라 감쇠 | 실내 조명, 촛불, 소품 하이라이트 |
| Sun | 태양광 | 거리 개념 없이 한 방향으로 평행하게 입사, 씬 크기와 무관하게 균일 | 야외 씬, 전역 주광원 |
| Spot | 스포트라이트 | 원뿔 형태로 좁게 조사, Spot Size와 Blend로 경계 조절 | 무대 조명, 특정 지점 강조 |
| Area | 소프트박스/판넬 | 평면 형태 광원, 크기가 클수록 그림자가 부드러워짐 | 스튜디오 촬영 느낌, 부드러운 인물/제품 조명 |

각 라이트는 공통적으로 **Power**(광량, 단위는 Point/Spot은 Watt, Sun은 Irradiance)와 **Color** 속성을 가지며, Light Properties 탭(전구 아이콘)에서 조정합니다.

> 💡 **실무 팁**: "이 빛이 실제로 어떤 조명 장비를 흉내 내고 있는가"를 먼저 정하고 타입을 고르면 헤매지 않습니다. 특히 초보자가 Point 하나로 모든 걸 해결하려다 밋밋한 그림자가 나오는 경우가 많은데, Area나 Sun을 섞어 쓰면 훨씬 입체감이 생깁니다.

---

## 2. Eevee vs Cycles — 두 렌더 엔진의 근본적 차이

Blender는 두 개의 렌더 엔진을 내장하고 있으며, Render Properties 탭 상단에서 전환합니다.

| 구분 | Eevee | Cycles |
|---|---|---|
| 방식 | 래스터라이제이션 기반 실시간 렌더러 | 레이 트레이싱 기반 물리 시뮬레이션 렌더러 |
| 속도 | 매우 빠름 (실시간에 가까움) | 상대적으로 느림 (샘플 수에 비례) |
| 정확도 | 근사치 위주 (간접광, 반사가 제한적) | 빛의 물리적 거동을 실제로 시뮬레이션 |
| 그림자/반사 | Screen Space 기법 사용 → 화면 밖 정보는 부정확 | 광선을 실제로 추적 → 물리적으로 정확 |
| 적합한 용도 | 뷰포트 프리뷰, 실시간 게임 엔진과 유사한 워크플로우, 빠른 반복 작업 | 최종 렌더링, 사실적인 라이팅/글로벌 일루미네이션이 중요한 결과물 |

Unity로 가져갈 3D 에셋을 만드는 이 커리큘럼의 맥락에서는, Eevee가 **Unity의 실시간 렌더링과 결과물이 더 비슷하기 때문에** 작업 중 확인용으로 유용합니다. 반면 포트폴리오용 정적 이미지나 텍스처 굽기(baking) 전 참고용 렌더는 Cycles가 더 신뢰할 수 있는 결과를 줍니다.

```
Render Properties 탭 > Render Engine 드롭다운
- Eevee (또는 Eevee Next, 버전에 따라 명칭 차이)
- Cycles
```

> 💡 **실무 팁**: Cycles는 Device 설정(CPU/GPU)에 따라 속도 차이가 크게 납니다. GPU가 있다면 `Preferences > System > Cycles Render Devices`에서 GPU(CUDA/OptiX/Metal)를 활성화하면 렌더 시간이 크게 줄어듭니다.

---

## 3. 3점 조명(Three-Point Lighting) 구도 실전

사진/영상 촬영에서 유래한 3점 조명은 3D 렌더링에서도 표준적인 출발점입니다. 소품 하나를 자연스럽고 입체감 있게 보여주고 싶을 때 아래 구도로 시작하면 됩니다.

| 조명 | 역할 | 배치 | 세기 |
|---|---|---|---|
| Key Light (주광) | 오브젝트의 형태를 규정하는 가장 강한 빛 | 카메라 기준 30~45도 옆, 약간 위쪽 | 가장 강함 (기준 100%) |
| Fill Light (보조광) | Key가 만든 그림자를 부드럽게 채움 | Key 반대편, 낮은 각도 | Key보다 약함 (약 30~50%) |
| Rim/Back Light (역광) | 배경과 오브젝트를 분리하는 윤곽선 강조 | 피사체 뒤쪽 | Key와 비슷하거나 약간 약하게 |

```
1. Area 라이트를 Key로 배치 (Power 높게, 예: 1000W)
2. 반대편에 Area 라이트를 Fill로 배치 (Power 낮게, 예: 300W)
3. 피사체 뒤쪽 위에 Spot 또는 Area를 Rim으로 배치
4. Rendered 셰이딩 모드(Numpad 0으로 카메라 뷰 전환 후)에서 실시간으로 그림자와 하이라이트 확인
```

> 💡 **실무 팁**: Fill Light를 아예 빼고 Key와 Rim만으로 촬영하면 그림자가 진하게 남아 드라마틱한 느낌이 나고, Fill을 강하게 넣으면 평면적이고 밝은 "제품 사진" 느낌이 납니다. 목적에 따라 Fill의 세기를 조절하는 것이 3점 조명의 핵심입니다.

---

## 4. World(환경광)와 HDRI

개별 라이트 오브젝트 외에도, Blender는 씬 전체를 감싸는 배경 조명인 **World**를 별도로 관리합니다. Properties 패널의 지구본 아이콘(World Properties)에서 설정합니다.

- 기본값은 균일한 회색 **Background Color**로, 은은한 전역 조명 역할을 합니다.
- **Color** 슬롯을 단색 대신 **Environment Texture** 노드로 바꾸고 HDRI(High Dynamic Range Image) 파일을 불러오면, 실제 촬영된 하늘/실내 공간의 조명 정보를 그대로 씬에 입힐 수 있습니다.

```
Shading 워크스페이스에서 World 탭 선택
Add > Texture > Environment Texture 노드 추가
Environment Texture의 Color 출력을 Background 노드의 Color 입력에 연결
Open 버튼으로 .hdr / .exr 파일 불러오기
```

HDRI 한 장으로 사실적인 반사와 은은한 전역 조명을 동시에 얻을 수 있어, 개별 라이트를 여러 개 배치하는 것보다 훨씬 빠르게 그럴듯한 결과를 낼 수 있습니다. 특히 금속/유리처럼 주변 환경이 반사되는 재질(Day 19의 Metallic 값이 높은 머티리얼)을 검토할 때 HDRI 없이는 반사가 텅 비어 보이므로 필수에 가깝습니다.

> 💡 **실무 팁**: Poly Haven(polyhaven.com) 같은 사이트에서 CC0 라이선스 HDRI를 무료로 받을 수 있습니다. 다만 Unity로 넘어갈 최종 에셋은 HDRI 반사 결과 자체가 텍스처에 구워지지 않도록 주의해야 합니다 — HDRI는 어디까지나 Blender 내 검토용 조명입니다.

---

## 5. 렌더 설정과 출력 기본기

라이팅을 잡은 후 최종 이미지를 뽑으려면 Render Properties에서 몇 가지 값을 확인해야 합니다.

| 설정 | Eevee | Cycles |
|---|---|---|
| 품질 조절 | Sampling > Render Samples | Sampling > Samples (Noise Threshold와 함께) |
| 그림자 품질 | Shadow > Cube/Cascade Size | Light Paths > Bounces (반사/굴절 횟수) |
| 출력 해상도 | Output Properties > Resolution X/Y | 동일 |
| 렌더 실행 | `Render > Render Image` (F12) | 동일 |

Cycles는 Samples 값이 낮으면 이미지에 노이즈(알갱이 얼룩)가 남습니다. Noise Threshold를 설정해 두면 필요한 만큼만 샘플링하고 자동으로 멈춰 렌더 시간을 절약할 수 있습니다.

> 💡 **실무 팁**: 최종 렌더 전에는 항상 작은 해상도(예: 50% 스케일)로 먼저 테스트 렌더를 돌려 라이팅과 노이즈 수준을 확인한 뒤, 문제가 없으면 100% 해상도로 최종 렌더를 걸치는 습관을 들이면 시간을 크게 아낄 수 있습니다.

---

## 📝 핵심 요약

1. Blender의 라이트 타입(Point, Sun, Spot, Area)은 각각 실제 조명 장비의 물리적 특성을 흉내내며, 용도에 맞게 선택해야 자연스러운 결과가 나온다
2. Eevee는 빠른 근사 렌더링으로 실시간 확인과 Unity 유사 결과에, Cycles는 물리적으로 정확한 최종 렌더링에 적합하다
3. 3점 조명(Key/Fill/Rim) 구도는 소품을 입체감 있게 보여주는 표준 출발점이며, Fill의 세기로 분위기를 조절할 수 있다
4. World와 HDRI는 씬 전체의 전역 조명과 반사 정보를 한 번에 제공하며, 금속/유리 재질 검토에 특히 중요하다
5. Cycles의 Samples/Noise Threshold와 저해상도 테스트 렌더를 활용하면 렌더 시간을 효율적으로 관리할 수 있다

---

## 🔗 참고 자료

- [Blender Manual — Light Objects](https://docs.blender.org/manual/en/latest/render/lights/light_object.html)
- [Blender Manual — Eevee Render Engine](https://docs.blender.org/manual/en/latest/render/eevee/index.html)
- [Blender Manual — World Properties](https://docs.blender.org/manual/en/latest/render/world/index.html)

---

*⬅️ 이전: [Day 19 — 텍스처링과 머티리얼 기초](../day-19/)  |  다음: [Day 21 — 3주차 정리: 간단한 소품 모델링 완성](../day-21/) ➡️*
