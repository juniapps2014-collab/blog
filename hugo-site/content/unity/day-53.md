---
title: "Day 53 — 텍스처 아틀라스와 메모리 최적화"
date: 2026-09-21
weight: 53
---

> **Phase 8: 최적화와 실전 워크플로우** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- 텍스처 아틀라스(Texture Atlas)가 드로우 콜과 메모리 사용량을 동시에 줄이는 원리를 설명할 수 있다
- Sprite Atlas와 수동 UV 아틀라싱을 상황에 맞게 적용할 수 있다
- Memory Profiler로 텍스처 메모리 사용량을 점검하고 불필요한 낭비를 찾아낼 수 있다

---

## 1. 텍스처 아틀라스란 무엇이고 왜 필요한가

Day 52에서 텍스처 압축 포맷(ASTC, ETC2)과 Max Size로 개별 텍스처의 용량을 줄이는 법을 다뤘습니다. 하지만 텍스처가 아무리 작아도 **개수가 많으면** 또 다른 문제가 생깁니다. 서로 다른 텍스처를 참조하는 오브젝트는 배칭(Batching)이 끊겨 드로우 콜이 늘어나고, 각 텍스처가 개별 파일로 로드되면서 메모리 단편화와 로딩 오버헤드도 함께 증가합니다.

**텍스처 아틀라스**는 여러 개의 작은 텍스처를 하나의 큰 텍스처 시트에 모아 담고, 각 오브젝트는 UV 좌표만 다르게 해서 이 하나의 시트를 참조하도록 만드는 기법입니다.

| 항목 | 아틀라스 미적용 | 아틀라스 적용 |
|---|---|---|
| 텍스처 파일 수 | 오브젝트마다 개별 | 하나의 시트로 통합 |
| 머티리얼/드로우 콜 | 텍스처마다 별도 머티리얼 → 배칭 실패 | 같은 머티리얼 공유 → 배칭 성공 |
| GPU 텍스처 스위칭 | 오브젝트마다 바인딩 변경 | 바인딩 1회로 다수 오브젝트 처리 |
| 메모리 정렬 | 작은 텍스처 다수 → 패딩 낭비 큼 | 큰 시트 하나 → 패딩 낭비 상대적으로 적음 |

> 💡 **실무 팁**: 아틀라스의 핵심 이득은 "용량 절감"보다 **"드로우 콜 감소"**에 있습니다. Day 50에서 다룬 배칭은 같은 머티리얼을 쓰는 오브젝트끼리만 가능한데, 아틀라스는 서로 다른 텍스처를 쓰던 오브젝트들을 "같은 머티리얼"로 묶어주는 전제 조건을 만들어 줍니다.

---

## 2. Sprite Atlas — 2D/UI 텍스처 자동 아틀라싱

Unity는 2D 스프라이트와 UI 이미지를 위한 자동화된 아틀라싱 도구인 **Sprite Atlas**를 기본 제공합니다.

```
1. Project 창에서 우클릭 → Create → 2D → Sprite Atlas
2. 생성된 Sprite Atlas 에셋의 Inspector에서 Objects for Packing 리스트에
   아틀라스로 묶을 스프라이트/폴더를 드래그
3. Packing Settings에서 Padding(스프라이트 간 여백), Allow Rotation,
   Tight Packing 등을 상황에 맞게 조정
4. Platform별 Max Texture Size와 압축 포맷을 하단에서 별도 설정
5. "Pack Preview" 버튼으로 실제 패킹 결과 미리보기
```

| 설정 항목 | 설명 |
|---|---|
| Padding | 스프라이트 간 여백(px). 너무 작으면 밉맵 생성 시 인접 스프라이트가 번져 보이는 블리딩(Bleeding) 발생 |
| Allow Rotation | 스프라이트를 회전시켜 빈 공간을 최소화(패킹 효율↑, 단 런타임 회전 보정 비용 약간 발생) |
| Tight Packing | 사각형이 아니라 실제 스프라이트 외곽선에 맞춰 촘촘히 배치 |
| Include in Build | 체크 해제 시 개발용 프리뷰만 되고 빌드에는 포함되지 않음 |

런타임에서 UI 요소가 동적으로 로드될 때는 `SpriteAtlasManager.atlasRequested` 콜백을 등록해 Addressables/Resources와 연동할 수 있습니다.

```csharp
using UnityEngine;
using UnityEngine.U2D;

public class AtlasBinder : MonoBehaviour
{
    void OnEnable()
    {
        SpriteAtlasManager.atlasRequested += RequestAtlas;
    }

    void RequestAtlas(string atlasName, System.Action<SpriteAtlas> callback)
    {
        // Addressables나 Resources.Load로 필요한 시점에 아틀라스를 로드
        SpriteAtlas atlas = Resources.Load<SpriteAtlas>("Atlases/" + atlasName);
        callback(atlas);
    }

    void OnDisable()
    {
        SpriteAtlasManager.atlasRequested -= RequestAtlas;
    }
}
```

> 💡 **실무 팁**: UI 요소가 많은 모바일 게임에서 Sprite Atlas를 적용하면 Canvas 하나 안의 배칭 효율이 극적으로 좋아집니다. 다만 아틀라스 하나의 크기가 너무 커지면(예: 4096×4096 이상) 오히려 필요 없는 스프라이트까지 항상 메모리에 상주하게 되므로, 화면/씬 단위로 아틀라스를 여러 개로 쪼개는 것이 좋습니다.

---

## 3. 3D 모델용 수동 UV 아틀라싱 — Blender 워크플로우

3D 모델의 머티리얼은 Sprite Atlas 대상이 아니므로, Day 18에서 다룬 UV 언랩 단계에서 아틀라스를 직접 구성해야 합니다. 여러 개의 작은 소품(돌, 나뭇가지, 팻말 등)을 하나의 텍스처 시트로 통합하는 것이 대표적인 활용 사례입니다.

```
1. Blender에서 아틀라스로 묶을 오브젝트들을 선택
2. Edit Mode 진입 후 각 오브젝트의 UV Island를 UV Editor에서 확인
3. UV Editor의 Select All → Pack Islands (단축키 없음, UV 메뉴에서 실행)
   → 여러 오브젝트의 UV를 0~1 UV 공간 안에 자동으로 재배치
4. 모든 오브젝트가 하나의 머티리얼/텍스처 슬롯만 참조하도록 정리
5. 텍스처 페인팅 또는 기존 텍스처들을 이미지 편집 툴에서
   하나의 시트로 합쳐 Substance Painter나 Blender 텍스처 페인트로 통합
```

| 방식 | 장점 | 단점 |
|---|---|---|
| Pack Islands 자동 배치 | 빠르고 UV 공간 활용률이 높음 | 텍스처 해상도가 오브젝트마다 불균등해질 수 있음 |
| 수동 UV 배치 | 중요한 오브젝트에 더 넓은 UV 공간(=고해상도) 할당 가능 | 시간이 오래 걸림 |

> 💡 **실무 팁**: 카메라에 자주, 크게 노출되는 오브젝트(주인공 캐릭터, 주요 소품)는 UV 공간을 더 넓게 배정해 상대적으로 고해상도를 갖도록 하고, 배경 소품은 좁은 UV 공간에 밀집시키는 "가중치 기반 UV 배치"가 실무에서 흔히 쓰입니다.

---

## 4. Memory Profiler로 텍스처 메모리 점검하기

아틀라싱을 적용했다면 실제로 메모리가 얼마나 줄었는지 측정해야 합니다. Day 51에서 다룬 Profiler의 CPU/GPU 성능 분석과 별개로, **Memory Profiler 패키지**(`Window → Package Manager`에서 설치)는 텍스처가 실제로 얼마나 메모리를 차지하는지 스냅샷으로 보여줍니다.

```
1. Package Manager에서 "Memory Profiler" 설치
2. Window → Analysis → Memory Profiler 열기
3. "Capture Player" 또는 "Capture Editor"로 현재 상태 스냅샷 촬영
4. Summary 탭에서 Texture2D 카테고리의 총 메모리 사용량 확인
5. Tree Map 뷰에서 어떤 개별 텍스처가 메모리를 많이 차지하는지 시각적으로 파악
6. 최적화 전/후 스냅샷 2개를 "Compare Snapshots"로 비교해 절감량 검증
```

| 확인 포인트 | 의미 |
|---|---|
| Resident Memory | 실제 GPU/RAM에 상주 중인 텍스처 메모리 |
| Duplicate Textures | 같은 텍스처가 여러 벌 중복 로드된 경우 (아틀라싱 누락 신호) |
| Read/Write Enabled 텍스처 | CPU에서도 접근 가능하도록 원본을 이중 보관 → 메모리 2배 사용 |

> 💡 **실무 팁**: Texture Import Settings의 "Read/Write Enabled" 체크박스는 스크립트에서 `GetPixel()` 등으로 텍스처를 읽어야 할 때만 켜야 합니다. 불필요하게 켜두면 GPU용 사본과 CPU 접근용 사본을 동시에 메모리에 유지해 텍스처 메모리가 두 배로 늘어납니다.

---

## 5. 아틀라싱의 한계와 트레이드오프

아틀라스가 만능은 아닙니다. 다음과 같은 상황에서는 오히려 손해가 될 수 있습니다.

- **밉맵 블리딩(Mipmap Bleeding)**: 아틀라스 텍스처가 밉맵 레벨이 낮아질수록(멀리서 볼수록) 인접한 스프라이트의 색상이 섞여 들어가는 현상. Padding을 충분히 주거나 각 스프라이트 주변에 여백 픽셀을 채워 완화합니다.
- **부분 업데이트 비효율**: 아틀라스 안의 스프라이트 하나만 런타임에 동적으로 바꾸고 싶어도, 아틀라스 전체를 다시 빌드해야 하는 경우가 많아 자주 변하는 콘텐츠(예: 플레이어가 커스터마이징하는 아바타 파츠)에는 부적합할 수 있습니다.
- **타일링(Tiling) 텍스처와 상극**: 바닥, 벽처럼 UV를 0~1 범위 밖으로 반복(Repeat/Tile)해서 사용하는 텍스처는 아틀라스에 넣으면 인접 스프라이트를 침범하므로 아틀라싱 대상에서 제외해야 합니다.

| 아틀라싱에 적합 | 아틀라싱에 부적합 |
|---|---|
| UI 아이콘, 버튼 이미지 | 반복 타일링되는 바닥/벽 텍스처 |
| 배경 소품(돌, 식물, 잡동사니) | 스킨/파츠가 자주 교체되는 커스터마이징 텍스처 |
| 정적인 캐릭터 파츠 | 매우 큰 단일 히어로 애셋(그 자체로 이미 최적 크기) |

> 💡 **실무 팁**: "일단 다 합치고 보자"는 접근보다, Memory Profiler와 Frame Debugger(Day 52 참고)로 실제 드로우 콜/메모리 병목을 먼저 확인한 뒤 아틀라싱이 필요한 그룹만 선별하는 것이 효율적입니다.

---

## 📝 핵심 요약

1. 텍스처 아틀라스는 여러 텍스처를 하나의 시트로 합쳐 배칭을 가능하게 함으로써 드로우 콜을 줄이는 것이 핵심 이득이다
2. 2D/UI는 Sprite Atlas로 자동 패킹하고, 3D 모델은 Blender의 Pack Islands로 UV를 수동 아틀라싱한다
3. Memory Profiler의 Tree Map과 Compare Snapshots로 아틀라싱 전후 텍스처 메모리 절감을 정량적으로 검증해야 한다
4. Read/Write Enabled 옵션은 CPU 접근이 꼭 필요할 때만 켜야 하며, 그렇지 않으면 텍스처 메모리가 이중으로 낭비된다
5. 타일링 텍스처나 자주 교체되는 커스터마이징 파츠처럼 아틀라싱에 부적합한 케이스를 구분해 선별 적용해야 한다

---

## 🔗 참고 자료

- [Unity Manual — Sprite Atlas](https://docs.unity3d.com/Manual/class-SpriteAtlas.html)
- [Unity Manual — Memory Profiler](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@latest)
- [Blender Manual — UV Editing](https://docs.blender.org/manual/en/latest/modeling/meshes/uv/index.html)

---

*⬅️ 이전: [Day 52 — 모바일/저사양 기기를 위한 3D 에셋 최적화](../day-52/)  |  다음: [Day 54 — VR/AR 프로젝트를 위한 3D 모델 고려사항](../day-54/) ➡️*
