---
title: "Day 22 — FBX/OBJ 포맷 이해와 Export 설정"
date: 2026-08-21
weight: 22
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- FBX와 OBJ 포맷이 각각 무엇을 저장하고 무엇을 저장하지 못하는지 설명할 수 있다
- Blender에서 Unity로 가져갈 모델을 Export할 때 축(Axis)과 단위(Scale) 문제가 왜 생기는지 이해하고 올바른 설정값을 고를 수 있다
- 실제로 소품 하나를 FBX로 Export해 Unity 프로젝트 폴더에 넣는 과정을 직접 수행할 수 있다

---

## 1. 왜 포맷 이해가 필요한가

3주차까지는 Blender 안에서 모델링·UV·머티리얼·렌더링을 모두 끝냈습니다. 이제부터는 그 결과물을 Unity로 옮기는 단계인데, 여기서 많은 입문자가 "분명 Blender에서는 멀쩡했는데 Unity에 넣으니 모델이 눕거나, 크기가 100배로 커지거나, 재질이 사라지는" 문제를 겪습니다.

이 문제 대부분은 모델링 실력과 무관하고, **Export 포맷과 설정을 제대로 이해하지 못해서** 생깁니다. 오늘은 코드를 쓰기 전에 반드시 알아야 하는 "파일 포맷과 좌표계"를 다룹니다.

---

## 2. FBX vs OBJ — 무엇이 다른가

| 항목 | FBX | OBJ |
|---|---|---|
| 개발사 | Autodesk | Wavefront (1990년대 표준) |
| 메시(Mesh) | 저장 가능 | 저장 가능 |
| UV 좌표 | 저장 가능 | 저장 가능 (`.obj` + `.mtl`) |
| 머티리얼 | 저장 가능 (색상, 일부 텍스처 경로) | `.mtl` 파일에 기본 속성만 저장 |
| 애니메이션 | 저장 가능 (키프레임, 스켈레톤) | **저장 불가** |
| 리깅/본(Bone) | 저장 가능 | **저장 불가** |
| 계층 구조(Hierarchy) | 저장 가능 (부모-자식 관계 유지) | 오브젝트 단위로만 분리, 계층 없음 |
| 파일 구조 | 바이너리 또는 ASCII 단일 파일 | 텍스트 파일 + 별도 `.mtl` |

정리하면, **정적인 소품(정지된 오브젝트) 하나만 옮긴다면 OBJ로도 충분**하지만, 앞으로 Day 29~35에서 다룰 캐릭터·리깅·애니메이션까지 고려하면 **FBX가 사실상 표준**입니다. 이 커리큘럼에서는 이후 계속 FBX를 기준으로 진행합니다.

> 💡 **실무 팁**: 실무에서 OBJ는 주로 "정적 배경 소품을 다른 툴(ZBrush, Substance Painter 등)과 주고받을 때"처럼 애니메이션이 필요 없는 교환 포맷으로 쓰입니다. 캐릭터나 움직이는 오브젝트는 처음부터 FBX로 작업하는 것이 정석입니다.

---

## 3. Blender와 Unity의 좌표계 차이

모델이 Unity에서 눕거나 뒤집혀 보이는 근본 원인은 두 프로그램이 **다른 좌표계(Axis Convention)**를 쓰기 때문입니다.

| 소프트웨어 | Up 축 | 전방(Forward) 축 | 핸디니스(Handedness) |
|---|---|---|---|
| Blender | Z-up | -Y | 오른손 좌표계 (Right-handed) |
| Unity | Y-up | Z | 왼손 좌표계 (Left-handed) |

Blender는 "위"가 Z축, Unity는 "위"가 Y축입니다. 즉 아무 설정 없이 그대로 내보내면 모델이 90도 넘어진 것처럼 보이는 게 정상입니다. 다행히 FBX Exporter는 이 변환을 자동으로 처리해주는 옵션을 제공합니다.

```
Blender FBX Export 창 → Transform 섹션
Forward: -Z Forward
Up: Y Up
```

이 두 값을 지정하면 Exporter가 내부적으로 좌표를 재계산해서, Unity에 임포트했을 때 Blender 뷰포트에서 보던 방향 그대로 나타납니다.

> 💡 **실무 팁**: Unity의 FBX Importer는 최신 버전에서 Blender 기본값(Z-up, -Y forward)도 어느 정도 자동 보정해주지만, 파이프라인 초반에는 "내가 직접 Forward/Up을 맞췄다"는 확신이 있는 편이 디버깅에 훨씬 유리합니다. 자동 보정에만 의존하면 나중에 문제가 생겼을 때 원인을 좁히기 어렵습니다.

---

## 4. 단위(Scale) 문제 — 100배로 커지는 이유

Unity에서 임포트한 모델이 갑자기 거대해지거나 미세하게 작아지는 문제는 대부분 **단위계 불일치**에서 옵니다.

- Blender의 기본 단위는 **미터(Meter)**이고, Scene 단위 설정(Scene Properties → Units)에 따라 실제 배율이 달라질 수 있습니다.
- Unity도 기본적으로 1 Unit = 1 Meter를 기준으로 물리 엔진(Rigidbody, Collider)이 동작합니다.
- 그런데 Blender FBX Exporter의 기본 `Scale` 값이나, 오브젝트에 적용되지 않은 Transform Scale이 섞이면 Export 시점에 배율이 왜곡됩니다.

**해결 순서:**

1. Blender에서 Export 전 `Object > Apply > All Transforms` (또는 최소 `Apply Scale`)로 오브젝트의 실제 크기를 1.0 기준으로 확정합니다.
2. Scene Properties → Units에서 Unit Scale이 1.0인지 확인합니다.
3. FBX Export 창의 `Apply Scalings` 옵션을 `FBX All`로 두고, `Scale` 값은 1.00을 유지합니다.

```
Object Mode → 오브젝트 선택 → Ctrl+A → All Transforms
Scene Properties → Units → Unit Scale: 1.0
FBX Export → Apply Scalings: FBX All, Scale: 1.00
```

> 💡 **실무 팁**: "일단 Export 해보고 Unity에서 Scale을 임의로 조정해서 맞추는" 방식은 당장은 편해 보이지만, 나중에 여러 모델을 한 씬에 모을 때 상대적 크기가 전부 어긋나는 원인이 됩니다. 반드시 Blender 쪽에서 실제 크기를 1.0으로 확정한 뒤 내보내는 습관을 들이는 것이 좋습니다.

---

## 5. 실습 — Day 21 소품을 FBX로 Export하기

1. Blender에서 Day 21에 완성한 머그컵(또는 나무 상자) 오브젝트를 선택합니다.
2. `Object > Apply > All Transforms`로 Location/Rotation/Scale을 확정합니다.
3. `File > Export > FBX (.fbx)`를 선택합니다.
4. Export 설정 패널에서 아래 값을 지정합니다.

| 옵션 | 값 |
|---|---|
| Path Mode | Copy (+ Embed Textures 체크) |
| Forward | -Z Forward |
| Up | Y Up |
| Apply Scalings | FBX All |
| Apply Unit | 체크 |
| Selected Objects | 체크 (선택한 오브젝트만 내보내기) |

5. 파일명을 `Mug.fbx`처럼 명확하게 지정하고, Unity 프로젝트의 `Assets/Models/` 폴더(없다면 새로 생성) 안에 직접 저장합니다.
6. Unity Editor로 돌아오면 Project 창에 파일이 자동으로 감지되어 임포트됩니다. Scene 뷰로 드래그해 방향과 크기가 Blender에서 보던 것과 일치하는지 확인합니다.

> 💡 **실무 팁**: FBX 파일을 Unity 프로젝트 폴더 바깥에 저장해뒀다가 나중에 복사해 넣는 것보다, 처음부터 `Assets/Models/` 안에 바로 Export하는 습관을 들이면 파일 경로가 꼬이는 일이 줄어듭니다.

---

## 📝 핵심 요약

1. OBJ는 정적 메시만 저장하고 애니메이션·리깅을 지원하지 않으므로, 캐릭터와 움직이는 오브젝트까지 고려하면 FBX가 표준 선택지다
2. Blender(Z-up, -Y forward)와 Unity(Y-up, Z forward)는 좌표계가 다르므로, FBX Export 시 Forward: -Z Forward / Up: Y Up으로 명시적으로 맞춰야 한다
3. 크기 왜곡 문제는 대부분 적용되지 않은 Transform Scale과 단위 설정 불일치에서 오므로, Export 전 `Apply All Transforms`로 크기를 1.0 기준으로 확정한다
4. FBX는 Unity 프로젝트의 `Assets/Models/` 폴더에 바로 내보내는 것이 경로 관리와 재임포트 측면에서 안전하다

---

## 🔗 참고 자료

- [Blender Manual — FBX 파일 형식](https://docs.blender.org/manual/en/latest/addons/import_export/scene_fbx.html)
- [Unity Manual — FBX 파일 가져오기](https://docs.unity3d.com/Manual/HOWTO-ImportObjectBlender.html)
- [Unity Manual — 3D 모델 파일 형식](https://docs.unity3d.com/Manual/3D-formats.html)

---

*⬅️ 이전: [Day 21 — 3주차 정리: 간단한 소품 모델링 완성](../day-21/)  |  다음: [Day 23 — Unity Import Settings 파헤치기 (Scale, Normals, Pivot)](../day-23/) ➡️*
