---
title: "Day 13 — 프로젝트 폴더 구조와 에셋 관리 베스트 프랙티스"
date: 2026-08-12
weight: 13
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 협업과 확장에 견고한 Unity 프로젝트 폴더 구조를 설계할 수 있다
- 에셋 네이밍 컨벤션을 정하고 일관되게 적용할 수 있다
- `.meta` 파일과 GUID의 역할을 이해하고 Git으로 안전하게 프로젝트를 관리할 수 있다

---

## 1. 왜 폴더 구조가 중요한가

Unity 프로젝트는 초반에는 `Assets` 폴더에 스크립트, 모델, 텍스처를 아무렇게나 넣어도 잘 돌아갑니다. 문제는 프로젝트가 커질 때 시작됩니다. 스크립트 하나를 찾는 데 몇 분씩 걸리고, 같은 이름의 머티리얼이 세 군데에 흩어져 있고, 협업자가 어디에 뭘 넣어야 할지 몰라 아무 폴더에나 던져 넣기 시작합니다.

폴더 구조는 단순한 정리 습관이 아니라 세 가지 실질적인 문제를 해결합니다.

- **탐색 비용**: 팀원 누구나 "이건 어디 있지?"를 규칙만 알면 바로 찾을 수 있어야 합니다
- **에셋 임포트 설정 충돌**: Unity는 폴더 단위로 임포트 프리셋을 적용하는 경우가 많아, 성격이 다른 에셋이 한 폴더에 섞이면 설정이 꼬입니다
- **버전 관리 충돌**: 여러 사람이 같은 폴더의 씬/프리팹을 동시에 건드리면 병합 충돌이 급증합니다. 기능 단위로 폴더를 나누면 충돌 범위가 줄어듭니다

---

## 2. 표준 폴더 구조 패턴

가장 널리 쓰이는 접근은 서드파티 에셋과 팀이 만든 에셋을 명확히 분리하는 것입니다. Unity는 폴더를 알파벳 순으로 정렬하므로, 팀 전용 폴더 앞에 언더스코어(`_`)를 붙이면 항상 최상단에 고정됩니다.

```
Assets/
├── _Project/              # 팀이 직접 만든 모든 에셋 (알파벳 정렬 최상단)
│   ├── Art/
│   │   ├── Models/
│   │   ├── Materials/
│   │   ├── Textures/
│   │   └── Animations/
│   ├── Audio/
│   │   ├── Music/
│   │   └── SFX/
│   ├── Prefabs/
│   │   ├── Characters/
│   │   ├── Environment/
│   │   └── UI/
│   ├── Scenes/
│   │   ├── Levels/
│   │   └── Testing/
│   ├── Scripts/
│   │   ├── Player/
│   │   ├── Enemy/
│   │   ├── UI/
│   │   └── Core/
│   └── Settings/          # URP 에셋, Input Actions 등 프로젝트 설정 자산
├── Plugins/               # 서드파티 SDK, 네이티브 플러그인
└── ThirdParty/            # 에셋 스토어 구매 에셋, 외부 패키지 소스
```

이 구조가 잘 작동하는 이유는 두 가지입니다. 첫째, `_Project` 하위는 **기능(feature) 기준**으로 나눠서 "플레이어 관련 스크립트+프리팹+애니메이션이 다 어디 있지?"라는 질문에 최소한의 클릭으로 답할 수 있습니다. 둘째, 서드파티 코드를 `Plugins`/`ThirdParty`에 격리하면 업데이트나 삭제 시 팀 코드에 영향을 주지 않습니다.

> 💡 **실무 팁**: 팀 규모가 작다면(1~3인) 폴더를 기능별(Feature-based, 예: `_Project/Player/`, `_Project/Enemy/` 안에 각각 스크립트·프리팹·아트를 함께 둠)로 재구성하는 것도 좋은 대안입니다. 파일 종류별(Type-based)보다 "한 기능을 삭제/이동할 때 폴더 하나만 옮기면 되는" 장점이 있습니다. 정답은 없으니 팀 컨벤션으로 문서화해 두는 것이 핵심입니다.

---

## 3. 네이밍 컨벤션

폴더 구조만큼 중요한 것이 파일 이름 규칙입니다. 이름만 보고 타입과 용도를 알 수 있어야 검색(Ctrl+Shift+F)과 자동완성이 제 역할을 합니다.

| 에셋 타입 | 접두사 예시 | 예 |
|---|---|---|
| Prefab | `PF_` | `PF_Player.prefab` |
| Material | `M_` | `M_Rock_Mossy.mat` |
| Texture | `T_` | `T_Rock_Albedo.png` |
| ScriptableObject | `SO_` | `SO_WeaponData_Sword.asset` |
| Animation Clip | `AC_` | `AC_Player_Run.anim` |
| Animator Controller | `AC_Ctrl_` (또는 `ANIM_`) | `ANIM_Player.controller` |
| Scene | `SCN_` (또는 접두사 없이 명확한 이름) | `SCN_Level01.unity` |
| C# 스크립트 | 접두사 없음, PascalCase | `PlayerController.cs` |

텍스처는 용도까지 접미사로 표기하면 나중에 셰이더에 연결할 때 헤맬 일이 없습니다.

```
T_Rock_Albedo.png     (Base Color / Albedo)
T_Rock_Normal.png     (Normal Map)
T_Rock_Metallic.png   (Metallic/Smoothness)
T_Rock_AO.png         (Ambient Occlusion)
```

> 💡 **실무 팁**: 네이밍 규칙은 프로젝트 시작 시 `README.md` 또는 Notion 문서 한 페이지로 정리해 팀에 공유하세요. 규칙이 없으면 시간이 지날수록 개인마다 다른 스타일이 뒤섞여 "레거시 정리"라는 이름의 대형 작업이 생깁니다.

---

## 4. `.meta` 파일과 GUID, 그리고 Git 관리

Unity는 `Assets` 안의 파일마다 동일한 이름의 `.meta` 파일을 자동 생성합니다. 이 파일에는 임포트 설정과 **GUID(전역 고유 식별자)**가 들어있는데, Unity 내부에서 에셋을 참조할 때 파일 경로가 아니라 이 GUID를 사용합니다. 즉 파일을 옮기거나 이름을 바꿔도 `.meta`가 함께 이동하면 참조가 깨지지 않습니다.

여기서 나오는 실무 규칙은 명확합니다.

- **`.meta` 파일은 반드시 Git에 커밋**해야 합니다 (`.gitignore`에 넣으면 절대 안 됩니다)
- 파일 이동/이름 변경은 **반드시 Unity 에디터 안에서** 수행해야 `.meta`가 함께 따라갑니다. OS 파일 탐색기나 터미널에서 직접 옮기면 GUID 연결이 끊어지고 씬의 참조가 모두 깨집니다
- 두 사람이 같은 폴더에서 각자 새 에셋을 만들면 GUID 충돌은 나지 않지만, `.meta`가 없는 상태로 커밋하면 상대방 쪽에서 새로 생성되어 diff가 지저분해질 수 있습니다 — 커밋 전 `Assets` 폴더에 추적되지 않는 `.meta`가 없는지 확인하는 습관이 필요합니다

Unity 프로젝트의 표준 `.gitignore`는 공식 저장소 형태로 제공됩니다.

```bash
# Unity가 공식 제공하는 .gitignore 템플릿을 그대로 사용하는 것을 권장
# https://github.com/github/gitignore/blob/main/Unity.gitignore

# 핵심적으로 무시해야 하는 폴더들
/[Ll]ibrary/
/[Tt]emp/
/[Oo]bj/
/[Bb]uild/
/[Bb]uilds/
/[Ll]ogs/
/[Mm]emoryCaptures/
```

`Library`, `Temp`, `Obj` 폴더는 로컬에서 재생성되는 캐시성 데이터이므로 절대 커밋하지 않습니다. 반면 `Assets`, `Packages`, `ProjectSettings`는 반드시 커밋 대상입니다.

> 💡 **실무 팁**: 대용량 바이너리(텍스처, 모델, 오디오)가 많아지면 Git 저장소 용량이 빠르게 커집니다. Git LFS(Large File Storage)를 초기부터 설정해 `*.png`, `*.fbx`, `*.wav` 같은 확장자를 LFS로 추적하면 나중에 마이그레이션하는 고통을 피할 수 있습니다.

---

## 5. 임포트 설정을 폴더 단위로 관리하기 — Preset

같은 폴더 안의 텍스처들은 보통 같은 임포트 설정(압축 방식, Max Size, sRGB 여부 등)을 공유해야 합니다. 매번 수동으로 설정하는 대신 **Preset** 기능을 쓰면 폴더 단위로 자동 적용할 수 있습니다.

1. 텍스처 하나를 원하는 설정으로 조정
2. Inspector 우측 상단의 Preset 아이콘 → `Save Current to...` 로 `.preset` 에셋 저장
3. 해당 Preset을 대상 폴더에 두고, 폴더에 `Default` 규칙으로 지정하면 이후 그 폴더에 임포트되는 모든 텍스처가 같은 설정을 자동으로 상속

```
Assets/_Project/Art/Textures/
├── T_Rock_Albedo.png
├── T_Rock_Normal.png
└── Preset/
    └── Texture_Default.preset   # 이 폴더의 기본 임포트 규칙
```

이렇게 해두면 새 팀원이 텍스처를 아무렇게나 드래그해도 압축 포맷이나 Max Size가 일관되게 적용되어, "왜 내 텍스처만 용량이 크지?" 같은 문제를 원천적으로 막을 수 있습니다.

---

## 📝 핵심 요약

1. 팀 에셋은 `_Project` 같은 접두사 폴더에 모아 서드파티 에셋과 명확히 분리하고, 기능 또는 타입 기준으로 하위 폴더를 구성한다
2. 에셋 타입별 접두사(`PF_`, `M_`, `T_`, `SO_` 등) 네이밍 규칙을 정하고 팀 문서로 공유한다
3. `.meta` 파일은 GUID로 에셋 참조를 유지하는 핵심 파일이므로 반드시 Git에 커밋하고, 파일 이동은 항상 Unity 에디터 안에서 수행한다
4. `Library`, `Temp`, `Obj` 등 캐시 폴더는 `.gitignore`로 제외하고, 대용량 바이너리는 Git LFS로 관리한다
5. Preset을 폴더 단위로 적용하면 임포트 설정 일관성을 자동으로 유지할 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Special Folder Names](https://docs.unity3d.com/Manual/SpecialFolders.html)
- [Unity Manual — Presets](https://docs.unity3d.com/Manual/Presets.html)
- [GitHub 공식 Unity .gitignore 템플릿](https://github.com/github/gitignore/blob/main/Unity.gitignore)

---

*⬅️ 이전: [Day 12 — 오디오 시스템 다루기](../day-12/)  |  다음: [Day 14 — 2주차 정리: 간단한 인터랙티브 씬 완성](../day-14/) ➡️*
