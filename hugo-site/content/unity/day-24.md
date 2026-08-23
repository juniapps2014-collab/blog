---
title: "Day 24 — Material 재구성 - Blender to Unity 워크플로우"
date: 2026-08-23
weight: 24
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Blender 머티리얼(Principled BSDF)이 FBX Export 과정에서 왜 그대로 넘어오지 않는지 설명할 수 있다
- Material Creation Mode와 Location 옵션을 이해하고, 텍스처 슬롯을 Unity Standard/URP Lit 셰이더에 올바르게 재연결할 수 있다
- 이름 기반 자동 매칭(Material Naming) 워크플로우를 활용해 여러 모델의 머티리얼 재구성 작업을 반복 가능하게 만들 수 있다

---

## 1. 왜 머티리얼은 "그대로" 넘어오지 않는가

Day 23에서 Import Settings의 `Materials` 탭을 잠깐 언급했습니다. Scale이나 Normals와 달리 머티리얼은 애초에 FBX 포맷 자체의 한계 때문에 완전히 보존되지 않습니다.

FBX는 지오메트리(정점, UV, 노멀)와 애니메이션은 비교적 충실히 저장하지만, 머티리얼 정보는 각 3D 툴마다 셰이더 모델이 다르기 때문에 "최소 공통분모"만 담습니다. Blender의 `Principled BSDF` 노드는 Base Color, Metallic, Roughness, Normal Map, Emission 등 수십 개의 입력을 가진 복잡한 셰이더 그래프인데, FBX는 이걸 각 텍스처 슬롯의 파일 경로 정도로만 근사해서 기록합니다. 노드 연결 구조, 커스텀 노드 그룹, 믹스 셰이더 같은 것은 FBX가 표현할 방법이 아예 없습니다.

결과적으로 Unity에 FBX를 임포트하면 "머티리얼은 생성되지만 텍스처가 비어 있거나, 색상만 대충 맞고 나머지 채널(Metallic, Normal, AO)은 빠진" 상태가 되는 경우가 흔합니다. 이건 Import Settings를 잘못 만져서 생기는 문제가 아니라 **FBX 포맷 자체의 구조적 한계**이므로, "재구성"이라는 별도 단계가 필요합니다.

---

## 2. Material Creation Mode 제대로 이해하기

Inspector → Model 탭 → Materials 섹션에는 세 가지 핵심 옵션이 있습니다.

| 옵션 | 값 | 설명 |
|---|---|---|
| Material Creation Mode | None | 머티리얼을 생성하지 않고 기본 회색 재질만 적용 |
| Material Creation Mode | Import via MaterialDescription | FBX에 기록된 머티리얼 설명을 읽어 Unity 머티리얼 애셋을 자동 생성 (기본값) |
| Material Location | Use Embedded Materials | 머티리얼을 FBX 파일 내부에 포함 (에셋 폴더가 지저분해지지 않지만 개별 수정이 번거로움) |
| Material Location | Use External Materials (Legacy) | `Materials` 하위 폴더에 별도 `.mat` 애셋으로 추출 (실무에서 권장) |

```
Inspector → Model 탭 → Materials 섹션
Material Creation Mode: Import via MaterialDescription
Material Location: Use External Materials (Legacy)
→ [Extract Materials...] 버튼 클릭 → Materials 폴더 지정
```

> 💡 **실무 팁**: `Use External Materials`로 추출해두면 같은 모델을 재임포트해도 이미 만든 머티리얼 설정(텍스처 연결, 셰이더 변경 등)이 유지됩니다. 반대로 Embedded 상태로 계속 작업하면 FBX를 다시 Export할 때마다 Unity 쪽 머티리얼 커스터마이징이 초기화될 위험이 있습니다.

---

## 3. 텍스처 슬롯을 Standard/URP Lit 셰이더에 재연결하기

머티리얼 애셋을 추출한 뒤에도 실제 텍스처(Base Color, Normal Map, Roughness 등)는 대부분 수동으로 다시 연결해야 합니다. Blender의 Principled BSDF 입력과 Unity 셰이더 슬롯의 대응 관계를 알아두면 이 작업이 기계적으로 끝납니다.

| Blender (Principled BSDF) | Unity Standard | Unity URP/Lit |
|---|---|---|
| Base Color | Albedo | Base Map |
| Metallic | Metallic | Metallic Map |
| Roughness (반전 필요) | Smoothness | Smoothness |
| Normal (Normal Map 노드 경유) | Normal Map | Normal Map |
| Emission | Emission | Emission Map |
| Alpha | Rendering Mode를 Transparent로 변경 후 Albedo 알파 채널 | Surface Type을 Transparent로 변경 |

여기서 가장 자주 실수하는 부분이 **Roughness ↔ Smoothness 반전**입니다. Blender는 "거칠수록 값이 큼(Roughness)"인 반면 Unity Standard 셰이더는 "매끄러울수록 값이 큼(Smoothness)"을 쓰므로, Roughness 텍스처를 그대로 Smoothness 슬롯에 꽂으면 반사가 정반대로 나옵니다.

```
해결 방법 1: 텍스처를 Photoshop/GIMP 등에서 미리 반전(Invert)해서 저장
해결 방법 2: Unity에서 Metallic 셰이더의 "Smoothness Source"를
           "Metallic Alpha" 대신 "Albedo Alpha"로 바꾸고, Albedo 알파 채널에
           반전된 Roughness를 미리 합성해두기
해결 방법 3 (URP 권장): Shader Graph로 커스텀 셰이더를 만들어
           Roughness 텍스처를 (1 - Roughness) 노드로 반전 후 Smoothness에 연결
```

> 💡 **실무 팁**: URP를 쓸 계획이라면 Standard 셰이더로 먼저 맞추고 나중에 URP Lit로 옮기기보다, 처음부터 URP Lit 기준으로 텍스처를 연결하는 편이 낫습니다. 두 셰이더의 파라미터 이름과 범위가 미묘하게 달라서 나중에 다시 손봐야 하는 경우가 많습니다.

---

## 4. Material Naming — 이름 기반 자동 매칭으로 반복 작업 줄이기

모델이 수십 개, 수백 개가 되면 머티리얼을 하나하나 수동으로 연결하는 건 현실적이지 않습니다. Unity Import Settings의 `Location` 아래에 있는 `Material Search` 옵션은 파일 이름을 기준으로 기존 머티리얼을 자동 매칭해줍니다.

| Material Search 옵션 | 검색 범위 |
|---|---|
| Local Materials Folder | 현재 FBX와 같은 폴더 안에서만 검색 |
| Recursive-Up | 현재 폴더부터 상위 폴더로 올라가며 검색 |
| Everywhere | 프로젝트 전체에서 이름이 일치하는 머티리얼 검색 |

이 기능을 제대로 활용하려면 **Blender에서부터 머티리얼 이름을 규칙적으로 짓는 습관**이 선행되어야 합니다. 예를 들어 `M_Wood_Oak`, `M_Metal_Rusty`처럼 일관된 접두사(`M_`)와 명확한 이름을 쓰면, 여러 모델이 같은 나무 재질을 공유할 때 Unity가 자동으로 기존 `M_Wood_Oak.mat`을 재사용합니다. 반대로 Blender 기본값인 `Material.001`, `Material.002` 같은 이름을 방치하면 자동 매칭이 무의미해지고 매번 새 머티리얼이 중복 생성됩니다.

```
권장 네이밍 규칙 예시:
M_<카테고리>_<세부이름>
예: M_Wood_Oak, M_Metal_Rusty, M_Fabric_Denim
```

> 💡 **실무 팁**: 여러 모델이 같은 머티리얼을 공유하도록 이름을 통일해두면, 나중에 텍스처 하나만 교체해도 그 이름을 쓰는 모든 오브젝트에 한 번에 반영됩니다. 이건 단순 편의 기능이 아니라 드로우콜 배칭(Day 50에서 다룰 내용)에도 직결되는 최적화 습관입니다.

---

## 📝 핵심 요약

1. FBX는 셰이더 그래프를 표현하지 못하는 포맷이라, Blender의 Principled BSDF 머티리얼은 Unity로 넘어올 때 구조적으로 손실이 발생한다
2. `Material Location`을 `Use External Materials`로 설정해 별도 `.mat` 애셋으로 추출해야 재임포트 시 작업 내용이 보존된다
3. Roughness(Blender) ↔ Smoothness(Unity)는 값이 반전되어 있으므로 텍스처를 그대로 연결하면 반사가 뒤집힌다
4. URP를 쓸 계획이면 처음부터 URP Lit 셰이더 기준으로 텍스처를 연결하는 것이 이중 작업을 줄인다
5. Blender에서부터 `M_카테고리_이름` 같은 일관된 머티리얼 네이밍 규칙을 쓰면 Unity의 자동 매칭 기능을 제대로 활용할 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Materials, Shaders & Textures](https://docs.unity3d.com/Manual/Materials.html)
- [Unity Manual — Model Import Settings (Materials 탭)](https://docs.unity3d.com/Manual/FBXImporter-Materials.html)
- [Blender Manual — Principled BSDF](https://docs.blender.org/manual/en/latest/render/shader_nodes/shader/principled.html)

---

*⬅️ 이전: [Day 23 — Unity Import Settings 파헤치기 (Scale, Normals, Pivot)](../day-23/)  |  다음: [Day 25 — URP(Universal Render Pipeline) 기초](../day-25/) ➡️*
