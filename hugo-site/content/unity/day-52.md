---
title: "Day 52 — 모바일/저사양 기기를 위한 3D 에셋 최적화"
date: 2026-09-20
weight: 52
---

> **Phase 8: 최적화와 실전 워크플로우** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 모바일/저사양 기기에서 3D 에셋이 병목이 되는 이유(대역폭, 발열, 열 스로틀링)를 설명할 수 있다
- 플랫폼별 폴리곤 예산과 LOD Group을 설정해 거리에 따라 디테일을 자동으로 낮출 수 있다
- 텍스처 압축 포맷(ASTC, ETC2)과 Mip Map, Platform Override 설정을 목적에 맞게 적용할 수 있다

---

## 1. 왜 모바일은 PC/콘솔과 다르게 최적화해야 하는가

Day 51에서 Profiler로 병목을 찾는 법을 다뤘지만, 모바일 기기는 PC와 근본적으로 다른 제약을 가집니다. 데스크톱 GPU는 독립된 VRAM과 넉넉한 메모리 대역폭을 갖지만, 모바일 GPU는 대부분 **CPU와 메모리를 공유하는 통합 메모리(Unified Memory)** 구조이고, 배터리와 발열 한계 때문에 지속적으로 최고 성능을 낼 수 없습니다.

| 제약 요소 | PC/콘솔 | 모바일 |
|---|---|---|
| 메모리 대역폭 | GPU 전용 VRAM, 넉넉함 | CPU/GPU 공유, 제한적 |
| 발열 관리 | 팬/쿨러로 지속 고성능 | 스로틀링으로 성능이 시간에 따라 저하 |
| 텍스처 압축 | DXT/BC 계열 | ASTC/ETC2 계열 (칩셋마다 지원 다름) |
| 오버드로우 민감도 | 상대적으로 낮음 | 타일 기반 렌더러 특성상 매우 높음 |

특히 대부분의 모바일 GPU(Apple, Adreno, Mali)는 **TBDR(Tile-Based Deferred Rendering)** 방식을 씁니다. 화면을 작은 타일로 나눠 타일 단위로 렌더링하는데, 이 구조에서는 투명 오브젝트가 겹치는 **오버드로우(Overdraw)**가 성능에 특히 치명적입니다.

> 💡 **실무 팁**: "PC에서 60fps 잘 나오니 모바일도 괜찮겠지"라는 가정은 위험합니다. 반드시 실제 타깃 기기(특히 최저 사양 기기)에서 Day 51의 Development Build + Attach to Player로 직접 측정해야 합니다.

---

## 2. 폴리곤 예산과 LOD Group으로 거리별 디테일 관리

**폴리곤 예산(Polygon Budget)**은 씬에 동시에 존재할 수 있는 전체 삼각형 수의 상한선을 프로젝트 초기에 정해두는 것입니다. 모바일 게임은 보통 화면당 5만~15만 삼각형, 캐릭터 하나당 5천~2만 삼각형 정도를 기준점으로 삼습니다(장르와 타깃 기기에 따라 크게 달라짐).

LOD(Level of Detail)는 카메라와의 거리에 따라 자동으로 낮은 폴리곤 버전의 메시로 교체해 예산을 지키는 핵심 기법입니다.

```
1. 모델의 고/중/저 폴리곤 버전 3개를 Blender에서 미리 제작 (예: 10,000 / 3,000 / 800 삼각형)
2. Hierarchy에서 빈 GameObject 생성 후 LOD Group 컴포넌트 추가
3. LOD0(고), LOD1(중), LOD2(저) 슬롯에 각각 대응하는 메시 오브젝트 드래그
4. Scene 뷰의 LOD Group 슬라이더로 전환 거리(%) 조정
5. 최하단에 "Culled" 구간을 남겨 일정 거리 이상에서는 아예 렌더링하지 않도록 설정
```

| LOD 단계 | 화면 점유 비율 기준(예시) | 용도 |
|---|---|---|
| LOD0 | 50% 이상 | 근접 촬영, 컷신 |
| LOD1 | 10~50% | 일반 플레이 거리 |
| LOD2 | 1~10% | 원거리 배경 오브젝트 |
| Culled | 1% 미만 | 렌더링 생략 |

> 💡 **실무 팁**: LOD를 나누기 전에 원본 모델의 UV와 머티리얼 슬롯 구조를 LOD1/LOD2에서도 동일하게 유지하면, 머티리얼 교체 없이 메시만 바꿔도 시각적 이질감이 적습니다.

---

## 3. 텍스처 압축 포맷 선택과 Platform Override

Day 23~26에서 다룬 텍스처 임포트 설정은 데스크톱 기준이었다면, 모바일에서는 **플랫폼별로 다른 GPU 압축 포맷**을 명시적으로 지정해야 합니다. Unity의 Texture Import Settings에는 플랫폼마다 별도의 Override 탭이 있습니다.

```
텍스처 선택 → Inspector → Platform 탭에서 "Android" 또는 "iOS" 클릭
→ "Override for Android" 체크
→ Format 드롭다운에서 압축 포맷 선택
→ Max Size로 해상도 상한 지정 (예: 2048 → 1024)
```

| 포맷 | 플랫폼 | 특징 |
|---|---|---|
| ASTC | Android(최신), iOS | 블록 크기를 조절해 압축률/품질 트레이드오프 가능, 최신 표준 |
| ETC2 | Android(구형 기기 포함) | ASTC 미지원 구형 GPU 호환성 우선 |
| PVRTC | 구형 iOS | 최신 프로젝트에서는 거의 사용 안 함(레거시) |

- Android는 기기 파편화가 심해서, ASTC를 기본으로 쓰되 구형 기기 지원이 필요하면 ETC2를 폴백으로 함께 빌드하는 경우가 많습니다(Player Settings → Texture Compression Format).
- Mip Map은 기본적으로 켜두는 것이 좋습니다. 카메라에서 멀어진 오브젝트는 자동으로 저해상도 밉맵을 사용해 대역폭을 아끼기 때문입니다. 다만 UI 텍스처처럼 항상 같은 크기로 보이는 2D 요소는 Mip Map을 꺼서 불필요한 메모리 낭비를 막습니다.

> 💡 **실무 팁**: Max Size는 원본 텍스처 해상도와 무관하게 "이 텍스처가 화면에서 실제로 차지할 최대 픽셀 크기"를 기준으로 정해야 합니다. 4K 원본이라도 배경 소품에 쓰인다면 512~1024로 충분한 경우가 대부분입니다.

---

## 4. 셰이더 복잡도 낮추기 — 모바일 친화적 머티리얼

Day 43~44에서 다룬 Shader Graph나 커스텀 셰이더는 PC에서는 부드럽게 동작해도, 모바일 GPU의 프래그먼트 셰이더 연산 능력은 훨씬 제한적입니다.

- **URP의 Simple Lit / Mobile 계열 셰이더 우선 사용**: URP Lit(PBR 풀 스펙)보다 연산량이 적은 Simple Lit이나 Unlit 셰이더를 배경/소품처럼 시각적으로 덜 중요한 오브젝트에 적용
- **실시간 라이트 수 제한**: 모바일에서는 Per-Pixel 실시간 라이트를 1~2개로 제한하고, 나머지는 Day 38에서 다룬 라이트맵 베이킹으로 대체
- **투명(Transparent) 머티리얼 최소화**: 알파 블렌딩은 오버드로우를 직접적으로 늘리므로, 꼭 필요한 경우가 아니면 Opaque나 Alpha Cutout(Day 26의 PBR 워크플로우 참고)으로 대체
- **셰이더 변형(Variant) 관리**: Shader Graph에서 사용하지 않는 키워드/기능을 비활성화해 셰이더 컴파일 변형 수를 줄이면 빌드 크기와 로딩 시간도 함께 개선됨

```csharp
// 런타임에 오버드로우가 심한 파티클/이펙트 개수를 기기 성능에 따라 조절하는 예시
if (SystemInfo.systemMemorySize < 3000) // 3GB 미만 저사양 기기
{
    particleSystem.maxParticles = Mathf.Min(particleSystem.maxParticles, 20);
}
```

> 💡 **실무 팁**: Frame Debugger(`Window → Analysis → Frame Debugger`)로 한 프레임의 드로우 콜을 하나씩 재생해보면, 어떤 오브젝트가 겹쳐서 오버드로우를 유발하는지 시각적으로 바로 확인할 수 있습니다.

---

## 5. 메시 최적화와 정적/동적 배칭 재점검

Day 50에서 배운 배칭 개념을 모바일 관점에서 다시 짚으면, 모바일에서는 배칭 실패로 인한 드로우 콜 증가가 훨씬 치명적입니다.

- **버텍스 수 줄이기**: 스무딩 그룹이 과도하게 많거나 불필요한 UV 시임(Seam)이 많으면 버텍스가 중복 생성되어 실제 삼각형 수보다 버텍스 처리 부하가 커집니다. Blender에서 Merge by Distance로 불필요한 중복 버텍스를 정리합니다.
- **Static Batching 적극 활용**: 움직이지 않는 배경 오브젝트는 Static 플래그를 켜서 빌드 시점에 미리 하나의 메시로 합칩니다. 단, 메모리는 더 사용하므로 저용량 기기에서는 과도한 static batching이 오히려 메모리 압박이 될 수 있습니다.
- **Mesh Combine으로 드로우 콜 선제 감소**: 같은 머티리얼을 쓰는 여러 소품(예: 배경의 돌무더기, 나무 여러 그루)을 Blender나 Unity의 `Mesh.CombineMeshes` API로 하나의 메시로 합쳐 드로우 콜 자체를 줄입니다.

```csharp
// 여러 개의 소품 메시를 런타임에 하나로 합치는 예시
MeshFilter[] meshFilters = GetComponentsInChildren<MeshFilter>();
CombineInstance[] combine = new CombineInstance[meshFilters.Length];

for (int i = 0; i < meshFilters.Length; i++)
{
    combine[i].mesh = meshFilters[i].sharedMesh;
    combine[i].transform = meshFilters[i].transform.localToWorldMatrix;
}

Mesh combinedMesh = new Mesh();
combinedMesh.CombineMeshes(combine);
```

> 💡 **실무 팁**: Mesh Combine은 강력하지만, 합쳐진 오브젝트는 개별 컬링이 불가능해집니다. 화면 전체에 넓게 퍼진 오브젝트를 하나로 합치면 화면 밖에 있어도 전부 렌더링 대상이 될 수 있으니, 공간적으로 가까운 오브젝트끼리만 그룹화하는 것이 좋습니다.

---

## 📝 핵심 요약

1. 모바일 GPU는 TBDR 구조와 발열 스로틀링 특성상 오버드로우와 지속 성능 저하에 특히 취약하므로 PC 기준 최적화만으로는 부족하다
2. LOD Group으로 거리별 폴리곤 예산을 관리하고, 일정 거리 이상은 Culled 처리해 렌더링 자체를 생략한다
3. 텍스처는 플랫폼 Override로 ASTC/ETC2 같은 GPU 압축 포맷을 명시하고, Max Size와 Mip Map을 용도에 맞게 조정한다
4. Simple Lit/Unlit 셰이더와 라이트맵 활용으로 실시간 라이팅 연산을 줄이고, 투명 머티리얼과 오버드로우를 최소화한다
5. Static Batching과 Mesh Combine으로 드로우 콜을 줄이되, 컬링 손실과 메모리 트레이드오프를 함께 고려해야 한다

---

## 🔗 참고 자료

- [Unity Manual — Optimizing graphics performance](https://docs.unity3d.com/Manual/OptimizingGraphicsPerformance.html)
- [Unity Manual — Texture Compression](https://docs.unity3d.com/Manual/class-TextureImporterOverride.html)
- [Unity Manual — LOD (Level of Detail)](https://docs.unity3d.com/Manual/LevelOfDetail.html)

---

*⬅️ 이전: [Day 51 — Profiler로 성능 분석하기](../day-51/)  |  다음: [Day 53 — 텍스처 아틀라스와 메모리 최적화](../day-53/) ➡️*
