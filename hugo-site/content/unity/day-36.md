---
title: "Day 36 — Terrain 시스템으로 지형 만들기"
date: 2026-09-03
weight: 36
---

> **Phase 6: 환경과 월드 빌딩** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Unity Terrain 컴포넌트의 구조와 기본 조작(높이 조절, 스무딩, 페인팅)을 할 수 있다
- Terrain Layer를 이용해 여러 텍스처를 자연스럽게 혼합할 수 있다
- Tree/Detail(Grass) 브러시와 Terrain 설정값(Heightmap Resolution 등)이 성능에 미치는 영향을 설명할 수 있다

---

## 1. Terrain 오브젝트 생성과 기본 구조

`GameObject > 3D Object > Terrain`으로 생성하면 거대한 평면 하나가 만들어집니다. 이 오브젝트는 일반 Mesh가 아니라 **Terrain 컴포넌트**와 **TerrainData 애셋**으로 이루어져 있습니다.

- **Terrain 컴포넌트**: Scene에 배치된 지형 인스턴스. Inspector에서 조각 도구, 페인팅 도구, 나무/디테일 배치 도구에 접근하는 창구 역할을 합니다.
- **TerrainData**: 실제 높이맵, 텍스처 레이어, 나무/디테일 정보를 담고 있는 애셋 파일(`.asset`). 여러 Terrain 컴포넌트가 같은 TerrainData를 공유할 수도 있습니다(타일링 지형에서 자주 사용).

Inspector 상단의 톱니바퀴 아이콘이 **Terrain Settings**이며, 여기서 다음 값들을 조정합니다.

| 설정 | 의미 | 주의점 |
|---|---|---|
| Terrain Width / Length | 지형의 가로/세로 크기(월드 단위) | 너무 크면 디테일이 뭉개짐 |
| Terrain Height | 최고 높이값 | 산맥처럼 높이 차가 큰 지형은 크게 설정 |
| Heightmap Resolution | 높이맵 해상도(예: 513×513) | 높을수록 정교하지만 메모리·연산량 증가 |
| Detail Resolution | 잔디/디테일 오브젝트 배치 해상도 | 성능에 직접적인 영향 |

> 💡 **실무 팁**: Heightmap Resolution은 2ⁿ+1 값(129, 257, 513, 1025...)을 사용합니다. 이는 Unity Terrain이 내부적으로 쿼드트리 기반 LOD 분할을 하기 때문이며, 임의의 값을 넣으면 자동으로 가장 가까운 유효값으로 보정됩니다.

---

## 2. 지형 조각하기 — Raise/Lower, Smooth, Stamp

Terrain 툴바(Inspector 상단 아이콘들)는 크게 다음 기능으로 나뉩니다.

1. **Create Neighbor Terrains**: 인접한 Terrain 타일을 자동 생성 — 대규모 오픈월드를 여러 타일로 나눠 관리할 때 사용
2. **Paint Terrain** 드롭다운 안에:
   - `Raise or Lower Terrain`: 브러시로 지형을 올리거나(클릭) 내림(Shift+클릭)
   - `Paint Height`: 특정 절대 높이값으로 지형을 고정시킴 (평평한 대지 만들 때 유용)
   - `Smooth Height`: 주변 높이값의 평균을 내어 급격한 경사를 부드럽게 처리
   - `Stamp Terrain`: 미리 만든 높이맵 브러시(바위, 크레이터 모양 등)를 그대로 찍어냄
3. **Paint Trees**: 나무 프리팹을 브러시로 배치
4. **Paint Details**: 풀, 돌 등 작은 디테일 오브젝트나 텍스처 배치

브러시는 **Brush Size**(영향 범위)와 **Opacity/Strength**(한 번 클릭당 변화량)를 조절할 수 있고, 여러 브러시 모양(원형, 노이즈 패턴 등)을 선택할 수 있습니다.

```
작업 순서 예시:
1. Raise/Lower로 큰 지형 윤곽(언덕, 계곡) 잡기
2. Smooth Height로 경사면을 부드럽게 다듬기
3. Stamp Terrain으로 바위 디테일 추가
4. Paint Height로 평평한 건물 부지 확보
```

> 💡 **실무 팁**: 지형을 만들 때는 큰 형태부터 작은 디테일 순서로 작업하는 게 원칙입니다. 처음부터 세밀한 디테일을 넣으면 전체 실루엣을 나중에 바꾸기 어렵습니다.

---

## 3. Terrain Layer로 텍스처 혼합하기

Terrain 표면 텍스처는 **Terrain Layer** 애셋(`.terrainlayer`)으로 관리합니다. `Paint Texture` 도구에서 `Edit Terrain Layers > Create Layer`로 새 레이어를 추가하고, Diffuse/Normal 텍스처를 지정합니다.

- 각 Layer는 Albedo(색상), Normal Map, Metallic, Smoothness, Tiling(반복 크기) 값을 가집니다.
- 브러시로 특정 Layer를 칠하면, Unity가 내부적으로 **Splatmap**(각 픽셀이 어떤 레이어를 얼마나 섞을지 나타내는 알파 채널 맵)을 생성해 여러 텍스처를 혼합합니다.
- 보통 4개 레이어까지는 하나의 Splatmap(RGBA 채널)으로 처리되며, 그 이상은 추가 Splatmap 패스가 필요해 렌더링 비용이 늘어납니다.

```
레이어 구성 예시 (산악 지형):
- Layer 0: 잔디 (낮은 고도, 완만한 경사)
- Layer 1: 바위 (급경사)
- Layer 2: 눈 (높은 고도)
- Layer 3: 흙길 (경로 부분만 수동 페인팅)
```

높이나 경사각에 따라 자동으로 텍스처를 배치하고 싶다면 스크립트로 `TerrainData.SetAlphamaps`를 사용해 절차적으로 Splatmap을 생성할 수도 있습니다.

```csharp
// 경사각이 30도 이상인 영역에 Layer 1(바위)을 자동 배치하는 예시
float steepness = terrainData.GetSteepness(normX, normY);
if (steepness > 30f)
{
    splatWeights[1] = 1f; // 바위 레이어 가중치 최대
}
else
{
    splatWeights[0] = 1f; // 잔디 레이어
}
```

> 💡 **실무 팁**: Tiling 값을 너무 작게 설정하면 텍스처가 반복되는 패턴이 눈에 띄게 드러납니다(texture tiling artifact). Normal Map을 함께 사용하고, Tiling 크기를 여러 레이어마다 다르게 주면 반복 패턴이 덜 도드라집니다.

---

## 4. Tree와 Detail(Grass) 배치, 그리고 성능

**Paint Trees**는 3D 프리팹(주로 Speed Tree나 일반 메쉬)을 지형 위에 배치하며, 배치된 나무는 거리에 따라 Billboard로 자동 전환되어 성능을 절약합니다(Tree Distance, Billboard Start 설정으로 조절).

**Paint Details**는 두 종류로 나뉩니다.
- **Grass Texture**: 실제 3D 메쉬가 아니라 카메라를 향하는 빌보드 형태의 풀 텍스처. GPU Instancing으로 대량 렌더링되어 가볍습니다.
- **Detail Mesh**: 작은 돌, 꽃처럼 실제 메쉬가 필요한 오브젝트.

| 항목 | 성능에 미치는 영향 |
|---|---|
| Tree Distance / Billboard Start | 값이 클수록 고폴리곤 나무가 오래 보여 GPU 부하 증가 |
| Detail Distance | 잔디가 렌더링되는 최대 거리 — 너무 멀면 오브젝트 수 급증 |
| Detail Density | 단위 면적당 잔디 개수 — 밀도가 높을수록 드로우콜/오버드로우 증가 |
| Wind Settings | 잔디 흔들림 애니메이션 — 셰이더 연산 비용 소폭 증가 |

> 💡 **실무 팁**: 모바일 대상 프로젝트라면 Detail(잔디)은 Density를 낮추고 Detail Distance를 짧게 잡는 것이 가장 효과적인 최적화 지점입니다. Day 52에서 다룰 모바일 최적화 내용과 직결됩니다.

---

## 5. Terrain vs 커스텀 Mesh — 언제 무엇을 쓸까

Terrain 시스템은 넓은 야외 지형에 최적화되어 있지만 만능은 아닙니다.

| 상황 | 추천 방식 |
|---|---|
| 넓은 오픈월드, 산·평야·언덕 | Unity Terrain |
| 동굴, 던전처럼 오버행(암반이 뒤집혀 튀어나온 구조)이 필요한 지형 | 커스텀 3D Mesh (Blender 등에서 제작) |
| 정밀한 건축 구조물, 인공 구조 | 커스텀 Mesh + Modular 에셋 (Day 37에서 다룸) |
| 대규모 지형 + 정밀 구조물 혼합 | Terrain으로 기본 지형 + 커스텀 Mesh를 얹어 조합 |

Terrain은 Heightmap 기반이라 구조적으로 "위에서 내려다본 높이"만 표현할 수 있어 동굴 천장이나 아치 같은 형태는 표현하지 못합니다. 이런 경우 Blender로 만든 Mesh를 Terrain 위에 배치해 조합하는 하이브리드 방식이 일반적입니다.

---

## 📝 핵심 요약

1. Terrain은 Terrain 컴포넌트(도구 창구)와 TerrainData 애셋(실제 높이맵/텍스처/나무 데이터)으로 구성된다
2. Raise/Lower → Smooth → Stamp → Paint Height 순으로 큰 형태부터 디테일 순서로 조각하는 것이 원칙
3. 텍스처는 Terrain Layer와 Splatmap으로 혼합되며, 레이어 수가 많아질수록 렌더링 비용이 늘어난다
4. Tree는 거리별 Billboard 전환, Grass는 GPU Instancing으로 성능을 확보하며 Density/Distance 설정이 최적화의 핵심이다
5. 오버행이나 정밀 구조가 필요한 지형은 Terrain이 아닌 커스텀 Mesh와 조합해야 한다

---

## 🔗 참고 자료

- [Unity Manual — Terrain Engine](https://docs.unity3d.com/Manual/script-Terrain.html)
- [Unity Manual — Terrain Layers](https://docs.unity3d.com/Manual/terrain-layers.html)
- [Unity Scripting API — TerrainData](https://docs.unity3d.com/ScriptReference/TerrainData.html)

---

*⬅️ 이전: [Day 35 — 5주차 정리: 걷기/뛰기 애니메이션 캐릭터 완성](../day-35/)  |  다음: [Day 37 — 모듈형(Modular) 3D 에셋으로 레벨 디자인](../day-37/) ➡️*
