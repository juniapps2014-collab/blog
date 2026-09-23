---
title: "Day 55 — 에셋 파이프라인 자동화 (네이밍 규칙, 임포트 프리셋)"
date: 2026-09-23
weight: 55
---

> **Phase 8: 최적화와 실전 워크플로우** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- 일관된 네이밍 규칙이 왜 팀/개인 프로젝트 모두에서 유지보수 비용을 줄이는지 설명할 수 있다
- Unity Preset 시스템으로 모델/텍스처/오디오 임포트 설정을 자동화할 수 있다
- AssetPostprocessor 스크립트로 네이밍 규칙을 강제하고 임포트 설정을 코드로 자동 적용할 수 있다
- 폴더 구조와 임포트 자동화가 결합될 때 얻는 실무적 이점을 이해한다

---

## 1. 왜 "네이밍 규칙"이 최적화 주제로 다뤄지는가

Day 13에서 프로젝트 폴더 구조와 에셋 관리 베스트 프랙티스를 다뤘지만, 폴더 구조만으로는 부족합니다. 에셋 개수가 수백~수천 개로 늘어나면 이름만 보고 종류·용도·상태를 파악할 수 있어야 검색, 일괄 처리, 임포트 자동화가 모두 가능해집니다.

- **검색/필터링**: Unity의 Project 창 검색은 이름 기반이므로, 접두사(prefix)가 일관되면 `t:Texture2D Tex_Character_` 같은 검색으로 원하는 그룹만 즉시 찾을 수 있습니다.
- **자동화의 전제 조건**: 뒤에서 다룰 AssetPostprocessor로 "이름에 `_Normal`이 포함되면 Normal Map으로 임포트"같은 규칙을 걸려면, 애초에 이름이 규칙을 따라야 코드가 판단할 수 있습니다.
- **협업 시 충돌 감소**: 파일명이 예측 가능하면 여러 명이 동시에 작업해도 같은 규칙으로 새 에셋을 만들기 때문에 이름 충돌이나 중복 에셋이 줄어듭니다.

| 에셋 종류 | 권장 접두사 예시 | 예시 파일명 |
|---|---|---|
| 3D 모델(Mesh) | `SM_` (Static Mesh), `SK_` (Skeletal Mesh) | `SM_Barrel_01.fbx` |
| 텍스처 - 색상(Albedo) | `T_..._D` (Diffuse/Albedo) | `T_Barrel_D.png` |
| 텍스처 - 노멀맵 | `T_..._N` | `T_Barrel_N.png` |
| 텍스처 - 마스크(Metallic/AO/Smoothness) | `T_..._MASK` | `T_Barrel_MASK.png` |
| 머티리얼 | `M_` | `M_Barrel.mat` |
| 프리팹 | `P_` 또는 `PF_` | `PF_Barrel.prefab` |
| 애니메이션 클립 | `A_` 또는 `Anim_` | `Anim_Character_Walk.anim` |

> 💡 **실무 팁**: 접두사 체계는 팀마다 조금씩 다르지만, 중요한 건 "정답"이 아니라 "일관성"입니다. 프로젝트 시작 시 짧은 규칙 문서(예: `NAMING.md`)를 하나 만들어두고, 이후 모든 팀원/미래의 나 자신이 그 문서만 보면 규칙을 알 수 있게 하는 것이 핵심입니다.

---

## 2. Unity Preset 시스템으로 임포트 설정 표준화하기

Day 23에서 FBX Import Settings를, Day 52에서 텍스처 압축 설정을 개별적으로 다뤘습니다. 하지만 에셋이 많아지면 매번 수동으로 같은 설정(Scale Factor, Normals, 압축 포맷 등)을 반복 입력하는 것은 비효율적이고 실수도 잦습니다. Unity의 **Preset** 기능은 특정 Importer의 설정 값을 `.preset` 에셋으로 저장해 재사용할 수 있게 해줍니다.

**Preset 만드는 방법**:

1. 이미 원하는 대로 설정을 마친 모델/텍스처를 Project 창에서 선택합니다.
2. Inspector 우측 상단의 톱니바퀴(⚙) 아이콘을 클릭하고 **Create Preset**을 선택합니다.
3. 생성된 `.preset` 파일을 `Assets/Presets/` 폴더 등에 정리해둡니다.

**Preset을 프로젝트 기본값으로 강제 적용하기** — `Project Settings > Preset Manager`에서 특정 Preset을 특정 에셋 타입(예: 모든 `TextureImporter`)의 기본값으로 등록하면, 이후 새로 임포트되는 모든 텍스처가 자동으로 그 설정을 따릅니다. 필터(Filter)를 추가하면 폴더 경로나 파일명 패턴에 따라 다른 Preset을 적용할 수도 있습니다.

| 상황 | Preset Manager 필터 설정 예시 |
|---|---|
| `_N` 접미사 텍스처는 Normal Map으로 | Name filter: `*_N` |
| `Characters/` 폴더의 모델은 Humanoid로 | Path filter: `Assets/Models/Characters/*` |
| UI 스프라이트는 압축 없이 | Path filter: `Assets/UI/*` |

> 💡 **실무 팁**: Preset Manager의 필터는 위에서부터 순서대로 평가되므로, 더 구체적인 규칙(특정 폴더)을 일반 규칙(모든 텍스처)보다 위에 배치해야 의도한 대로 동작합니다.

---

## 3. AssetPostprocessor로 네이밍 규칙과 임포트를 코드로 강제하기

Preset Manager는 GUI 기반이라 팀 전체에 규칙을 "공유"하려면 프로젝트 설정 자체를 커밋해야 합니다. 더 세밀하고 코드로 명시적인 자동화가 필요할 때는 `AssetPostprocessor`를 사용합니다. 이 클래스를 상속한 스크립트를 `Editor` 폴더에 넣으면, 에셋이 임포트될 때마다 Unity가 자동으로 콜백을 호출합니다.

```csharp
using UnityEditor;
using UnityEngine;

// 반드시 Editor 폴더 안에 위치해야 합니다.
public class AssetNamingPostprocessor : AssetPostprocessor
{
    // 텍스처가 임포트되기 "직전"에 호출됨
    void OnPreprocessTexture()
    {
        TextureImporter importer = (TextureImporter)assetImporter;
        string fileName = System.IO.Path.GetFileNameWithoutExtension(assetPath);

        // 네이밍 규칙 검증: T_ 로 시작하지 않으면 경고
        if (!fileName.StartsWith("T_"))
        {
            Debug.LogWarning($"[Naming] '{fileName}' 은(는) 'T_' 접두사 규칙을 따르지 않습니다: {assetPath}");
        }

        // 접미사 기반으로 텍스처 타입 자동 설정
        if (fileName.EndsWith("_N"))
        {
            importer.textureType = TextureImporterType.NormalMap;
        }
        else if (fileName.EndsWith("_MASK"))
        {
            importer.sRGBTexture = false; // 마스크 텍스처는 색공간 보정 제외
        }
    }

    // 모델이 임포트되기 "직전"에 호출됨
    void OnPreprocessModel()
    {
        ModelImporter importer = (ModelImporter)assetImporter;
        string fileName = System.IO.Path.GetFileNameWithoutExtension(assetPath);

        if (!fileName.StartsWith("SM_") && !fileName.StartsWith("SK_"))
        {
            Debug.LogWarning($"[Naming] '{fileName}' 은(는) 'SM_'/'SK_' 접두사 규칙을 따르지 않습니다.");
        }

        // Day 23에서 다룬 스케일/노멀 설정을 코드로 강제
        importer.importNormals = ModelImporterNormals.Calculate;
        importer.meshCompression = ModelImporterMeshCompression.Medium;
    }
}
```

- `OnPreprocessTexture()`, `OnPreprocessModel()`, `OnPreprocessAudio()` 등은 모두 해당 타입의 에셋이 처음 임포트되거나 재임포트될 때 자동 호출됩니다.
- 이 시점에는 아직 최종 임포트가 끝나지 않았으므로, `assetImporter`를 통해 얻은 Importer 객체의 속성을 수정하면 그 값이 그대로 반영되어 임포트됩니다.
- 경고만 남기고 강제로 막지 않는 이유는, 팀 작업 중 예외적인 에셋(외부 구매 에셋 등)까지 규칙을 강제하면 오히려 방해가 되기 때문입니다. 상황에 따라 `Debug.LogError` + 임포트 취소 로직으로 강하게 막을 수도 있습니다.

> 💡 **실무 팁**: `OnPreprocess*` 계열 함수는 이미 임포트된 에셋에는 재적용되지 않습니다. 기존 에셋에 규칙을 소급 적용하려면 Project 창에서 해당 에셋들을 선택 후 마우스 우클릭 → **Reimport**를 실행해야 합니다.

---

## 4. 폴더 구조 + 자동화 파이프라인이 만드는 실무적 이점

Day 13의 폴더 구조, 오늘 다룬 네이밍 규칙과 임포트 자동화가 합쳐지면 "에셋이 들어오는 순간 정리되는" 파이프라인이 완성됩니다.

```
Assets/
  Art/
    Characters/
      SM_Hero.fbx
      T_Hero_D.png
      T_Hero_N.png
      M_Hero.mat
    Props/
      SM_Barrel_01.fbx
      T_Barrel_D.png
  Presets/
    Texture_Default.preset
    Texture_NormalMap.preset
    Model_StaticProp.preset
  Editor/
    AssetNamingPostprocessor.cs
```

| 구성 요소 | 역할 |
|---|---|
| 폴더 구조(Day 13) | 에셋을 "어디에" 둘지 정의 |
| 네이밍 규칙(오늘) | 에셋의 "이름"으로 종류/용도를 즉시 식별 |
| Preset(오늘) | GUI에서 설정한 임포트 값을 재사용 가능한 에셋으로 저장 |
| AssetPostprocessor(오늘) | 임포트 시점에 규칙을 코드로 강제/자동화 |

이 네 가지가 결합되면 새로운 팀원이 합류하거나, 외주로 제작된 에셋 뭉치를 프로젝트에 통합할 때도 "일단 정해진 폴더에 넣고 임포트만 하면" 압축 포맷, 스케일, Normal Map 여부 등이 자동으로 정리됩니다. Day 27의 폴리곤 최적화, Day 52~53의 텍스처/메모리 최적화도 결국 이 파이프라인 위에서 일관되게 적용될 때 효과가 배가됩니다.

> 💡 **실무 팁**: 자동화 스크립트를 처음 도입할 때는 기존 에셋 전체에 소급 적용하기보다, 새로 추가되는 에셋부터 규칙을 적용하고 점진적으로 기존 에셋을 정리하는 편이 프로젝트를 깨뜨릴 위험이 적습니다.

---

## 📝 핵심 요약

1. 일관된 네이밍 규칙은 검색, 협업, 자동화 스크립트 작성의 전제 조건이며 접두사/접미사 체계로 에셋 타입을 즉시 식별할 수 있게 한다
2. Unity Preset 시스템은 임포트 설정을 `.preset` 에셋으로 저장해 재사용하며, Preset Manager의 필터로 폴더/이름 기반 기본값을 자동 적용할 수 있다
3. `AssetPostprocessor`의 `OnPreprocessTexture()`, `OnPreprocessModel()` 등을 활용하면 임포트 직전에 네이밍 규칙 검증과 설정 자동화를 코드로 강제할 수 있다
4. `OnPreprocess*` 콜백은 최초 임포트 시점에만 적용되므로, 기존 에셋에 규칙을 소급 적용하려면 Reimport가 필요하다
5. 폴더 구조 + 네이밍 규칙 + Preset + AssetPostprocessor가 결합될 때 비로소 "에셋이 들어오는 순간 정리되는" 실전 파이프라인이 완성된다

---

## 🔗 참고 자료

- [Unity Manual — AssetPostprocessor](https://docs.unity3d.com/ScriptReference/AssetPostprocessor.html)
- [Unity Manual — Presets](https://docs.unity3d.com/Manual/Presets.html)
- [Unity Manual — Preset Manager](https://docs.unity3d.com/Manual/class-PresetManager.html)

---

*⬅️ 이전: [Day 54 — VR/AR 프로젝트를 위한 3D 모델 고려사항](../day-54/)  |  다음: [Day 56 — 8주차 정리: 최적화 체크리스트 적용](../day-56/) ➡️*
