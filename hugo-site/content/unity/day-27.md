---
title: "Day 27 — 폴리곤 수 최적화와 LOD 개념"
date: 2026-08-26
weight: 27
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- 폴리곤 수가 렌더링 성능에 영향을 미치는 원리(정점 처리, 드로우콜)를 설명할 수 있다
- Blender의 Decimate Modifier와 리토폴로지 기법으로 폴리곤 수를 줄일 수 있다
- Unity의 LOD Group 컴포넌트를 설정해 거리별로 다른 해상도의 모델을 자동 전환할 수 있다

---

## 1. 폴리곤 수가 왜 성능에 영향을 주는가

3D 모델의 메쉬는 정점(Vertex)과 삼각형(Triangle/폴리곤)으로 구성됩니다. 화면에 오브젝트를 그릴 때 GPU는 모든 정점에 대해 변환·조명 연산(Vertex Shader)을 수행하고, 그 결과로 만들어진 모든 픽셀에 대해 셰이딩 연산(Fragment Shader)을 수행합니다.

폴리곤 수가 늘어나면 늘어날수록 다음 두 지점에서 비용이 커집니다.

- **정점 처리 비용**: 정점이 많을수록 Vertex Shader 호출 횟수가 늘어남 (스키닝 애니메이션이 있는 캐릭터는 특히 부담이 큼)
- **오버드로우/실루엣 세밀도 대비 비용**: 화면상에서 아주 작게 보이는 오브젝트에 고폴리곤 모델을 쓰면, 실제 보이는 디테일에 비해 낭비되는 연산이 큼

> 💡 **실무 팁**: 폴리곤 수 자체보다 "화면에서 차지하는 픽셀 크기 대비 폴리곤 밀도"가 더 중요한 지표입니다. 카메라에서 멀리 있는 오브젝트는 고해상도 모델이어도 실제로는 몇 픽셀밖에 차지하지 않으므로, 그 디테일은 낭비됩니다. 이 낭비를 줄이는 것이 이번 글의 핵심 주제인 LOD의 존재 이유입니다.

---

## 2. Blender에서 폴리곤 수 줄이기 — Decimate Modifier

Day 17에서 다룬 Modifier 스택의 하나인 **Decimate Modifier**는 메쉬의 형태를 최대한 유지하면서 폴리곤 수를 자동으로 줄여주는 도구입니다.

| 모드 | 동작 방식 | 적합한 상황 |
|---|---|---|
| Collapse | 정점을 병합(edge collapse)하며 점진적으로 단순화 | 일반적인 폴리곤 감소, 가장 널리 사용 |
| Un-Subdivide | Subdivision 이전 상태를 역으로 추정해 복원 | 원래 낮은 폴리곤이었다가 Subdivision을 적용한 메쉬 |
| Planar | 평평한 면들을 하나의 큰 면으로 병합 | 건물, 상자처럼 평면이 많은 하드서피스 모델 |

```
Blender Decimate 사용 절차
1. 오브젝트 선택 → Properties 패널 → Modifier(렌치 아이콘) → Add Modifier → Generate → Decimate
2. 모드를 Collapse로 선택
3. Ratio 슬라이더로 목표 폴리곤 비율 조정 (예: 0.5 = 원본의 50%)
4. 뷰포트에서 실루엣과 디테일 손실 여부를 확인하며 조정
5. Apply(Ctrl+A 또는 Modifier 드롭다운 → Apply)로 확정
```

> 💡 **실무 팁**: Decimate는 빠르지만 UV 경계나 하드 엣지 근처에서 메쉬가 찢어지거나 왜곡되는 경우가 많습니다. 캐릭터처럼 토폴로지 품질이 중요한 모델은 자동 Decimate보다 수동 리토폴로지(Retopology)를 권장하며, Decimate는 배경 소품이나 빠른 프로토타이핑용 LOD 생성에 더 적합합니다.

---

## 3. 수동 리토폴로지와 폴리곤 예산

자동 Decimate만으로는 부족한 경우, 아티스트가 직접 저폴리곤 메쉬를 새로 그리는 **리토폴로지**를 진행합니다. Blender의 Poly Build, Shrinkwrap 모디파이어, Retopoflow 애드온 등이 이 작업을 돕습니다.

리토폴로지를 시작하기 전에는 프로젝트 성격에 맞는 **폴리곤 예산(Poly Budget)**을 정해두는 것이 실무에서 흔한 접근입니다.

| 플랫폼/용도 | 캐릭터 1개 대략적 삼각형 수 | 소품(Prop) 1개 대략적 삼각형 수 |
|---|---|---|
| 모바일 게임 | 3,000 ~ 8,000 | 200 ~ 1,000 |
| PC/콘솔 (일반) | 15,000 ~ 40,000 | 500 ~ 3,000 |
| VR | 5,000 ~ 15,000 | 300 ~ 1,500 |
| 시네마틱/컷신 전용 | 제한 거의 없음 (실시간 렌더링 아님) | - |

> 위 수치는 프로젝트마다 크게 달라지는 대략적인 가이드일 뿐이며, 실제 예산은 타겟 프레임레이트와 화면에 동시에 보이는 오브젝트 수를 기준으로 프로파일링(Day 51에서 다룰 Profiler)하며 정해야 합니다.

---

## 4. Unity LOD Group — 거리별 모델 자동 전환

**LOD(Level of Detail)**는 카메라와의 거리에 따라 같은 오브젝트를 다른 폴리곤 밀도의 메쉬로 자동 교체하는 기법입니다. 멀리 있는 오브젝트는 낮은 폴리곤 버전으로, 가까이 있는 오브젝트는 원래의 고폴리곤 버전으로 렌더링해서 전체 씬의 정점 처리 비용을 크게 줄입니다.

**설정 절차:**

1. Blender(또는 다른 DCC 툴)에서 같은 모델을 LOD0(원본, 고폴리곤), LOD1(중간), LOD2(저폴리곤) 3단계로 미리 준비해 각각 Export
2. Unity에서 세 메쉬를 모두 같은 부모 오브젝트 아래 자식 GameObject로 배치
3. 부모 오브젝트에 `LOD Group` 컴포넌트 추가
4. Inspector에서 LOD0/LOD1/LOD2 슬롯에 각 자식 오브젝트의 Renderer를 드래그
5. LOD 전환 거리(화면 대비 크기 비율, %)를 슬라이더로 조정

```csharp
// 런타임에 LOD Group 설정을 코드로 제어하는 예시
using UnityEngine;

public class RuntimeLODSetup : MonoBehaviour
{
    [SerializeField] private LODGroup lodGroup;

    private void Start()
    {
        // 각 LOD 단계가 화면을 차지하는 비율(screen relative height) 기준으로 전환
        LOD[] lods = lodGroup.GetLODs();
        lods[0].screenRelativeTransitionHeight = 0.5f;  // LOD0 -> LOD1 전환 지점
        lods[1].screenRelativeTransitionHeight = 0.2f;  // LOD1 -> LOD2 전환 지점
        lods[2].screenRelativeTransitionHeight = 0.01f; // LOD2 -> Culled(미표시) 전환 지점
        lodGroup.SetLODs(lods);
        lodGroup.RecalculateBounds();
    }
}
```

> 💡 **실무 팁**: LOD 단계 사이에서 모델이 갑자기 "팝(pop)"하듯 전환되는 것이 거슬린다면, LOD Group의 `Fade Mode`를 `Cross Fade`로 설정해 두 LOD가 서서히 크로스페이드되도록 만들 수 있습니다. 단, Cross Fade는 두 LOD를 동시에 잠깐 그리므로 전환 순간에 드로우콜이 일시적으로 늘어나는 트레이드오프가 있습니다.

---

## 5. LOD와 함께 고려할 추가 최적화 포인트

LOD는 정점/폴리곤 비용을 줄이는 대표적인 기법이지만, 폴리곤 최적화 전체 그림에서는 다음 요소들도 함께 고려해야 합니다.

- **Culling**: 카메라 시야 밖(Frustum Culling)이나 다른 오브젝트에 가려진 경우(Occlusion Culling) 아예 렌더링을 건너뛰는 기법으로, LOD와 상호 보완적으로 동작
- **Combine Meshes**: 정적인 소품 여러 개를 하나의 메쉬로 합쳐 드로우콜 수 자체를 줄이는 방식 (LOD를 적용한 뒤에도 여전히 유효한 최적화)
- **Impostor/Billboard**: 아주 먼 거리의 나무나 군중처럼 실루엣만 중요한 오브젝트는 3D 메쉬 대신 카메라를 향하는 평면 텍스처(Billboard)로 대체해 폴리곤 수를 0에 가깝게 줄이는 극단적인 LOD 최종 단계로 활용

> Unity의 SpeedTree나 Terrain 시스템의 나무 렌더링은 이 Impostor 기법을 기본으로 내장하고 있습니다.

---

## 📝 핵심 요약

1. 폴리곤 수는 Vertex Shader 처리 비용에 직접 영향을 주며, 화면상 실제 크기 대비 과도한 디테일은 낭비이므로 거리 기반 최적화가 필요하다
2. Blender의 Decimate Modifier는 빠른 폴리곤 감소에 유용하지만 토폴로지 품질이 중요한 캐릭터에는 수동 리토폴로지가 더 적합하다
3. 플랫폼(모바일/PC/VR)별로 대략적인 폴리곤 예산을 정해두고 프로파일링으로 검증하는 것이 실무 기준이다
4. Unity의 LOD Group 컴포넌트는 화면 대비 크기 비율에 따라 LOD0~LODn 메쉬를 자동 전환하며, Cross Fade로 전환을 부드럽게 만들 수 있다
5. LOD는 Culling, Mesh Combine, Impostor/Billboard 같은 다른 최적화 기법과 함께 사용될 때 효과가 극대화된다

---

## 🔗 참고 자료

- [Unity Manual — LOD (Level of Detail)](https://docs.unity3d.com/Manual/LevelOfDetail.html)
- [Unity Manual — Mesh Optimization for performance](https://docs.unity3d.com/Manual/OptimizingGraphicsPerformance.html)
- [Blender Manual — Decimate Modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/decimate.html)

---

*⬅️ 이전: [Day 26 — PBR(Physically Based Rendering) 텍스처링 워크플로우](../day-26/)  |  다음: [Day 28 — 4주차 정리: 모델 임포트 파이프라인 실습](../day-28/) ➡️*
