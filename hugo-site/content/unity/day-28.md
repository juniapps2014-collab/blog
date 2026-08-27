---
title: "Day 28 — 4주차 정리: 모델 임포트 파이프라인 실습"
date: 2026-08-27
weight: 28
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Blender 모델을 Export부터 Unity 최종 배치까지 이어지는 전체 임포트 파이프라인을 순서대로 재현할 수 있다
- Day 22~27에서 배운 개별 설정(Export, Import Settings, Material, URP, PBR, LOD)이 파이프라인의 어느 단계에 해당하는지 설명할 수 있다
- 임포트 결과물에 흔히 발생하는 문제(스케일 불일치, 노멀 뒤집힘, 머티리얼 미스매치)를 체크리스트로 진단하고 수정할 수 있다

---

## 1. 4주차 전체 그림 — 왜 파이프라인으로 봐야 하는가

지난 한 주(Day 22~27) 동안 배운 내용은 각각 따로 떼어놓고 보면 개별 설정값처럼 보이지만, 실무에서는 **하나의 연속된 파이프라인**으로 이어집니다. 한 단계에서 실수하면 다음 단계에서 원인을 찾기 어려운 문제로 나타나는 경우가 많아서, 이번 정리 글은 개별 개념보다 "순서"와 "단계 간 연결"에 초점을 맞춥니다.

| Day | 주제 | 파이프라인 단계 |
|---|---|---|
| 22 | FBX/OBJ 포맷과 Export 설정 | ① Blender → 파일로 내보내기 |
| 23 | Unity Import Settings (Scale, Normals, Pivot) | ② Unity가 파일을 해석하는 방식 |
| 24 | Material 재구성 (Blender → Unity) | ③ 셰이딩 데이터 재연결 |
| 25 | URP 기초 | ④ 렌더 파이프라인에 맞는 셰이더 적용 |
| 26 | PBR 텍스처링 워크플로우 | ⑤ 사실적인 표면 표현 |
| 27 | 폴리곤 최적화와 LOD | ⑥ 성능을 고려한 최종 배치 |

이번 실습은 이 6단계를 실제로 하나씩 밟아 결과물을 완성하는 것이 목표입니다.

---

## 2. 실습 개요 — 무엇을 만드는가

간단한 소품(예: Day 21에서 만든 모델, 또는 새로 만든 저폴리곤 오브젝트 하나)을 대상으로 다음 결과물을 완성합니다.

- Unity 씬 안에 배치된, PBR 머티리얼이 정상 적용된 3D 오브젝트
- URP 셰이더로 렌더링되며 스케일/피벗/노멀이 모두 올바른 상태
- LOD Group이 설정되어 거리별로 폴리곤 수가 자동 전환되는 상태

특정 소품 하나를 정해 아래 절차를 그대로 따라가 보는 것이 이번 정리의 핵심입니다.

---

## 3. 단계별 실습 절차

### 3.1 Export (Day 22 복습)

```
Blender → File → Export → FBX (.fbx)
- Forward: -Z Forward, Up: Y Up (Unity 기준)
- Apply Transform 체크 (스케일/회전 값을 메쉬에 반영)
- Path Mode: Copy (+ Embed Textures 체크 시 텍스처까지 함께 포함)
```

> 💡 **실무 팁**: Export 시점에 Apply Transform을 빼먹으면, Unity에서 오브젝트의 Transform 값이 (1,1,1)이 아닌 이상한 스케일/회전으로 들어옵니다. Day 23의 Import Settings로 일부 보정은 가능하지만, 근본적으로는 Export 단계에서 깨끗하게 정리하는 것이 맞습니다.

### 3.2 Import Settings 점검 (Day 23 복습)

Unity 프로젝트에 FBX를 드래그한 뒤 Inspector의 Model 탭에서 다음을 확인합니다.

- **Scale Factor**: 기본값 1이 대부분 맞지만, Blender와 Unity의 단위 체계 차이로 100배 차이가 나는 경우가 있으므로 Scene 뷰에서 실제 크기를 눈으로 확인
- **Normals**: `Import` (원본 유지)가 기본. 셰이딩이 이상하면 `Calculate`로 전환해 재계산
- **Pivot**: 오브젝트를 클릭했을 때 기즈모가 원하는 위치(보통 바닥 중심)에 있는지 확인. 아니라면 Blender에서 Origin을 재설정 후 다시 Export

### 3.3 Material 재구성 (Day 24 복습)

```
Import 직후 Materials 탭 → Location: Use External Materials (Legacy) 또는 
"Extract Materials..." 버튼으로 머티리얼을 별도 에셋으로 분리
```

Blender의 Principled BSDF 노드 값(Base Color, Metallic, Roughness)이 Unity 머티리얼의 어떤 슬롯에 대응하는지 다시 매핑합니다. 자동 매핑이 완벽하지 않은 경우가 많아 눈으로 직접 비교/보정하는 과정이 필요합니다.

### 3.4 URP 셰이더 적용 (Day 25 복습)

프로젝트가 URP 기반이라면, 임포트된 머티리얼의 셰이더가 기본 Standard가 아니라 `Universal Render Pipeline/Lit`으로 지정되어 있는지 확인합니다. 아니라면:

```
Edit → Render Pipeline → Universal Render Pipeline → Upgrade Project Materials to UniversalRP Materials
```

또는 개별 머티리얼의 Shader 드롭다운에서 직접 변경합니다.

### 3.5 PBR 텍스처 연결 (Day 26 복습)

| 텍스처 맵 | Unity URP/Lit 슬롯 |
|---|---|
| Base Color / Albedo | Base Map |
| Normal | Normal Map |
| Metallic + Roughness (분리된 경우) | Metallic Map (Smoothness는 Roughness의 역수로 별도 처리 필요) |
| Ambient Occlusion | Occlusion Map |

> 💡 **실무 팁**: Blender는 Roughness, Unity Standard/URP Lit은 Smoothness(매끄러움) 값을 기본으로 사용합니다. `Smoothness = 1 - Roughness` 관계이므로, 텍스처를 그대로 꽂으면 반사 표현이 반대로 나타날 수 있습니다. Roughness 맵을 반전시키거나, 셰이더 그래프에서 `1 - x` 노드로 보정하세요.

### 3.6 LOD Group 설정 (Day 27 복습)

Decimate Modifier로 만든 LOD0/LOD1/LOD2 메쉬를 각각 Export → Import한 뒤, 부모 오브젝트에 `LOD Group` 컴포넌트를 추가하고 각 단계를 연결합니다. Scene 뷰의 LOD Group 바를 드래그해 전환 거리를 조정합니다.

---

## 4. 트러블슈팅 체크리스트

실습 중 흔히 마주치는 문제와 원인을 파이프라인 단계별로 정리합니다.

| 증상 | 가능한 원인 | 확인할 단계 |
|---|---|---|
| 오브젝트가 비정상적으로 크거나 작음 | Export 단위 설정 또는 Import Scale Factor 불일치 | 3.1, 3.2 |
| 표면이 검게 보이거나 안쪽이 보임 | 노멀 방향이 뒤집힘 | 3.2 (Normals: Calculate로 전환) |
| 회전축이 이상한 곳에 위치 | Blender에서 Origin(Pivot)이 잘못 설정됨 | 3.1 (Object → Set Origin) |
| 텍스처가 아예 안 보이거나 분홍색(Missing) | Path Mode가 Copy가 아니었거나 URP 셰이더 미적용 | 3.1, 3.4 |
| 금속 표면인데 반사가 안 됨 | Roughness/Smoothness 반전 문제 | 3.5 |
| 멀리서 봐도 LOD 전환이 안 됨 | Screen Relative Transition Height 값이 너무 작게 설정됨 | 3.6 |

---

## 5. 4주차를 마치며

Phase 4는 "3D 모델링(Blender)"과 "게임 엔진(Unity)"이라는 서로 다른 두 세계를 연결하는 구간이었습니다. 다음 Phase 5부터는 이 파이프라인 위에 캐릭터 리깅과 애니메이션을 얹어, 정적인 모델을 움직이는 캐릭터로 발전시킵니다. 지금까지의 임포트 파이프라인이 탄탄하지 않으면 애니메이션 단계에서 문제를 진단하기가 훨씬 어려워지므로, 이번 정리 실습에서 체크리스트를 통과한 결과물을 확보해두는 것이 좋습니다.

---

## 📝 핵심 요약

1. 임포트 파이프라인은 Export → Import Settings → Material → URP 셰이더 → PBR 텍스처 → LOD의 6단계로 이어지는 연속된 흐름이다
2. 각 단계의 문제는 다음 단계에서 다른 증상으로 나타나는 경우가 많으므로, 트러블슈팅 시 단계를 거슬러 올라가며 원인을 좁혀야 한다
3. Roughness/Smoothness처럼 Blender와 Unity가 반대 개념을 쓰는 값은 파이프라인에서 가장 흔한 실수 지점이다
4. 이번 실습에서 완성한 파이프라인은 Phase 5(캐릭터·애니메이션)부터 계속 재사용되므로 지금 탄탄히 검증해두는 것이 중요하다

---

## 🔗 참고 자료

- [Unity Manual — Importing Models](https://docs.unity3d.com/Manual/ImportingModelFiles.html)
- [Unity Manual — Materials, Shaders & Textures](https://docs.unity3d.com/Manual/Shaders.html)
- [Blender Manual — FBX Export](https://docs.blender.org/manual/en/latest/addons/import_export/scene_fbx.html)

---

*⬅️ 이전: [Day 27 — 폴리곤 수 최적화와 LOD 개념](../day-27/)  |  다음: [Day 29 — 캐릭터 모델링 기초와 토폴로지](../day-29/) ➡️*
