---
title: "Day 58 — 모델링+임포트+머티리얼 통합 작업"
date: 2026-09-26
weight: 58
---

> **Phase 9: 캡스톤 프로젝트** | 예상 학습 시간: 60분

---

## 🎯 학습 목표

- Blender에서 만든 모델을 "임포트 준비 완료" 상태로 마무리하는 체크리스트를 스스로 적용할 수 있다
- Day 22-28에서 배운 FBX Export/Import 설정과 Day 24-26의 머티리얼 재구성 워크플로우를 하나의 파이프라인으로 실행할 수 있다
- 임포트 후 씬에 배치했을 때 발생하는 흔한 문제(스케일, 노멀, 머티리얼 슬롯 불일치)를 스스로 진단하고 고칠 수 있다

---

## 1. 오늘의 작업 흐름 - 왜 "통합"이 핵심인가

Day 57에서 컨셉과 기술 범위를 정했다면, Day 58의 목표는 새로운 지식이 아니라 **지금까지 따로따로 연습했던 기술을 한 번에 이어붙이는 것**입니다. Blender 모델링(Day 15-21), FBX 파이프라인(Day 22-24), 머티리얼/PBR(Day 25-26)을 개별 튜토리얼로 익혔더라도, 이 셋을 순서대로 이어서 한 번에 실행해보면 각 단계에서 놓쳤던 디테일이 드러납니다.

오늘 하루의 작업 순서는 다음과 같습니다.

```
1. Blender: 모델 마무리 (Apply Transform, Modifier 적용, UV 확인)
2. Blender: FBX Export (Day 22 설정 그대로 재적용)
3. Unity: Import Settings 점검 (Day 23 체크리스트)
4. Unity: Material 재구성 + PBR 텍스처 연결 (Day 24, 26)
5. Unity: 씬에 배치하고 스케일/충돌/라이팅 기준으로 검증
```

이 순서를 컨셉에 등장하는 오브젝트 개수만큼 반복하게 됩니다. 오브젝트가 3-5개라면 하나씩 완벽하게 끝내고 넘어가기보다, **전체를 한 바퀴 빠르게 돌려본 뒤 2차로 다듬는 방식**이 시간 관리에 유리합니다.

> 💡 **실무 팁**: 실무 파이프라인에서도 "에셋 하나를 끝까지 완성 → 다음 에셋" 방식보다 "전체를 러프하게 한 바퀴 → 우선순위대로 폴리싱"하는 방식이 마감 리스크를 줄입니다. 씬 전체의 밸런스를 먼저 눈으로 확인할 수 있기 때문입니다.

---

## 2. Blender 모델 마무리 체크리스트

Export 전 아래 항목을 순서대로 확인하세요. 이 단계를 건너뛰면 Unity에서 스케일이 틀어지거나 노멀이 뒤집히는 문제로 이어집니다.

```
[ ] 모든 오브젝트에 Ctrl+A → Apply → All Transforms 적용 (위치/회전/스케일 초기화 확인)
[ ] Modifier 스택 확인: Subdivision/Mirror 등은 Apply할지, Unity에서도 유지할지 결정
[ ] Edit Mode에서 N 패널 → Item 탭으로 Dimensions(실제 크기, 미터 단위) 확인
[ ] Mesh > Normals > Recalculate Outside (Shift+N)로 노멀 방향 재계산
[ ] UV Editor에서 UV 맵이 0-1 공간을 벗어나지 않는지 확인
[ ] 오브젝트 이름을 Unity에서 알아보기 쉽게 정리 (예: Cube.001 → Prop_Streetlamp)
```

| 체크 항목 | 놓쳤을 때 Unity에서 생기는 증상 |
|---|---|
| Apply All Transforms | 임포트 후 크기가 비정상적으로 크거나 작음, 회전이 어긋남 |
| Recalculate Normals | 특정 면이 투명하게(뒤집혀) 보이거나 라이팅이 이상하게 계산됨 |
| Dimensions 확인 | Unity 씬에서 다른 오브젝트 대비 스케일이 안 맞음 |
| 오브젝트 이름 정리 | Unity Hierarchy에서 어떤 메쉬가 뭔지 구분이 안 됨 |

> 💡 **실무 팁**: "Apply Transform을 깜빡했다"는 3D 파이프라인에서 가장 흔한 실수입니다. Export 직전에 전체 선택(A) 후 Apply All Transforms를 습관적으로 한 번 더 실행하는 루틴을 만들어두세요.

---

## 3. FBX Export 설정 재점검 (Day 22 복습)

Day 22에서 배운 Export 설정을 그대로 다시 적용합니다. Blender의 File > Export > FBX 창에서 확인할 항목:

| 설정 | 권장 값 | 이유 |
|---|---|---|
| Forward / Up | -Z Forward, Y Up | Unity의 좌표계와 일치시켜 임포트 후 회전 문제 방지 |
| Apply Scalings | FBX All | Blender와 Unity의 단위 스케일 차이(1 Blender Unit = 1m) 보정 |
| Apply Unit | 체크 | 미터 단위 통일 |
| Path Mode | Copy (텍스처 임베드 시) | Export 시 텍스처를 FBX에 함께 포함해 파일 이동성 확보 |
| Selected Objects Only | 상황에 따라 체크 | 씬 전체가 아니라 필요한 오브젝트만 내보낼 때 |

```
# Blender FBX Export 단축 체크리스트
File > Export > FBX (.fbx)
  ㄴ Include: Selected Objects (필요 시)
  ㄴ Transform: Forward=-Z, Up=Y, Apply Scalings=FBX All, Apply Unit=✓
  ㄴ Geometry: Smoothing=Face, Apply Modifiers=✓ (Modifier를 Export에 굽고 싶을 때)
```

---

## 4. Unity Import Settings 점검 (Day 23 복습)

FBX를 Unity 프로젝트로 드래그한 뒤, Inspector에서 아래 항목을 순서대로 확인합니다.

- **Model 탭**: Scale Factor가 1인지, Mesh Compression이 필요 이상으로 걸려있지 않은지
- **Normals**: "Import" 또는 "Calculate"(Blender에서 이미 정리했다면 Import 권장)
- **Materials 탭**: Material Creation Mode를 "Import via MaterialDescription"이 아니라 상황에 따라 "None"으로 두고 Unity에서 직접 머티리얼을 재구성할지 결정 (Day 24 워크플로우와 연결되는 지점)

```csharp
// 임포트된 모델의 스케일/피벗을 코드로 검증하고 싶을 때 (Editor 스크립트)
using UnityEditor;
using UnityEngine;

public class ModelValidator
{
    [MenuItem("Tools/Validate Selected Model Scale")]
    static void ValidateScale()
    {
        foreach (var obj in Selection.gameObjects)
        {
            var scale = obj.transform.localScale;
            if (Mathf.Abs(scale.x - 1f) > 0.01f ||
                Mathf.Abs(scale.y - 1f) > 0.01f ||
                Mathf.Abs(scale.z - 1f) > 0.01f)
            {
                Debug.LogWarning($"{obj.name}: 스케일이 (1,1,1)이 아닙니다 → {scale}. " +
                    "Blender에서 Apply Transform을 다시 확인하세요.");
            }
        }
    }
}
```

> 💡 **실무 팁**: 오브젝트 개수가 많아지는 캡스톤 단계에서는 이런 간단한 검증 스크립트 하나가 "임포트 후 스케일이 이상한 오브젝트를 눈으로 하나씩 찾는" 시간을 크게 줄여줍니다.

---

## 5. 머티리얼 재구성과 PBR 텍스처 연결 (Day 24, 26 복습)

Import 후에는 Day 24에서 연습한 "Blender to Unity 머티리얼 재구성" 흐름을 그대로 적용합니다.

1. 임포트된 모델의 Material 슬롯 개수와 이름을 확인 (Blender에서 정한 이름이 그대로 넘어오는지)
2. URP/Lit 셰이더 기반의 새 Material 에셋을 슬롯 개수만큼 생성
3. Day 26에서 정리한 PBR 텍스처 세트(Base Color, Normal, Metallic/Smoothness, AO)를 각 슬롯에 연결
4. 모델의 Renderer 컴포넌트에서 새로 만든 Material을 순서대로 할당

| 텍스처 맵 | 연결할 Material 슬롯 | 색공간 설정 |
|---|---|---|
| Base Color / Albedo | Base Map | sRGB (Color) |
| Normal Map | Normal Map | Linear (Non-Color, Unity가 자동 감지) |
| Metallic / Smoothness | Metallic Map | Linear (Non-Color) |
| Ambient Occlusion | Occlusion Map | Linear (Non-Color) |

> 💡 **실무 팁**: Base Color만 sRGB이고 나머지 맵(Normal, Metallic, AO)은 모두 Non-Color(Linear)로 설정해야 합니다. Texture Import Settings에서 이 부분을 놓치면 머티리얼이 밋밋하거나 과도하게 밝아 보이는 원인이 됩니다.

---

## 6. 씬 배치와 통합 검증

모든 오브젝트를 순서대로 임포트하고 머티리얼까지 연결했다면, 씬에 배치하며 다음을 검증합니다.

- **스케일 일관성**: 여러 오브젝트를 나란히 놓았을 때 상대적 크기가 컨셉 의도와 맞는지 (사람 크기 기준 오브젝트 하나를 기준 자로 씬에 임시 배치해두면 편합니다)
- **콜라이더**: Day 09에서 배운 Collider가 필요한 오브젝트(바닥, 벽, 상호작용 가능한 소품)에 빠짐없이 붙었는지
- **머티리얼 슬롯 밀림**: 서브메쉬가 여러 개인 모델에서 머티리얼이 엉뚱한 슬롯에 걸린 경우가 없는지 (Scene 뷰에서 회전시켜 눈으로 확인)
- **라이팅 임시 확인**: 최종 라이팅은 Day 59 작업이지만, 기본 Directional Light 아래에서 머티리얼이 이상하게(과도하게 반사되거나 새까맣게) 보이지 않는지 미리 점검

> 💡 **실무 팁**: 오늘 단계에서 라이팅을 완벽하게 잡을 필요는 없습니다. "머티리얼이 물리적으로 말이 되는 값인지"만 확인하고, 분위기를 살리는 조명 연출은 Day 59로 넘기는 것이 스코프 관리에 맞습니다.

---

## 📝 핵심 요약

1. Day 58은 새 지식보다 Blender 모델링 → FBX Export → Unity Import → 머티리얼 재구성을 하나의 파이프라인으로 이어붙이는 통합 실습이다
2. Export 전 Apply All Transforms와 Recalculate Normals를 빠뜨리면 Unity에서 스케일/노멀 문제로 그대로 드러난다
3. FBX Export 설정(Forward/Up 축, Apply Scalings)과 Unity Import Settings(Normals, Materials 탭)는 Day 22-23에서 정한 기준을 그대로 재사용한다
4. PBR 텍스처는 Base Color만 sRGB, 나머지(Normal/Metallic/AO)는 Non-Color로 색공간을 맞춰야 머티리얼이 의도대로 보인다
5. 라이팅과 연출은 Day 59로 미루고, 오늘은 스케일·콜라이더·머티리얼 슬롯이 올바른지 "구조적으로 맞는 상태"까지만 완성하면 된다

---

## 🔗 참고 자료

- [Unity Manual — Importing Models](https://docs.unity3d.com/Manual/ImportingModelFiles.html)
- [Unity Manual — Material Import Settings](https://docs.unity3d.com/Manual/class-Material.html)
- [Blender Manual — FBX Export](https://docs.blender.org/manual/en/latest/addons/import_export/scene_fbx.html)

---

*⬅️ 이전: [Day 57 — 캡스톤 프로젝트 기획 - 나만의 미니 씬 컨셉 잡기](../day-57/)  |  다음: [Day 59 — 애니메이션과 라이팅으로 완성도 높이기](../day-59/) ➡️*
