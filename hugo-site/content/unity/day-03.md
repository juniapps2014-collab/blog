---
title: "Day 03 — Scene 구성과 계층 구조(Hierarchy) 관리"
date: 2026-08-02
weight: 3
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Scene의 개념과 하나의 `.unity` 파일이 프로젝트에서 어떤 역할을 하는지 설명할 수 있다
- Hierarchy 창에서 GameObject를 체계적으로 그룹화하고 검색·정렬하는 실무 패턴을 적용할 수 있다
- 여러 Scene을 Build Settings에 등록하고 스크립트로 전환·중첩 로드하는 기본 흐름을 이해할 수 있다

---

## 1. Scene이란 무엇인가

Scene은 Unity 프로젝트를 구성하는 가장 큰 단위의 컨테이너입니다. 메인 메뉴, 하나의 스테이지, 로딩 화면처럼 "화면 전체가 바뀌는 단위"를 하나의 Scene 파일(`.unity`)로 저장한다고 생각하면 됩니다.

Scene 안에는 지금까지 다룬 모든 GameObject, 그 GameObject들의 Hierarchy 구조, 그리고 Lighting/Skybox 같은 씬 자체의 설정값이 함께 저장됩니다. Project 창에서 보이는 `.unity` 파일 하나가 곧 Scene 하나입니다.

| 예시 프로젝트 | Scene 구성 예시 |
|---|---|
| 플랫포머 게임 | MainMenu, Level01, Level02, GameOver |
| 모바일 퍼즐 게임 | Splash, Lobby, Puzzle_Easy, Puzzle_Hard |
| VR 데모 | Boot, MainScene (하나의 씬 안에서 룸만 전환) |

> 💡 **실무 팁**: 새 프로젝트를 만들면 기본으로 `SampleScene`이 생깁니다. 실무에서는 이 이름을 그대로 두지 말고 `MainMenu`, `Level01`처럼 역할이 드러나는 이름으로 바로 바꿔서 프로젝트 초기부터 혼란을 줄이는 것이 좋습니다.

---

## 2. Hierarchy 창 — Scene 안의 구조를 보는 창

Hierarchy 창은 현재 열려 있는 Scene에 속한 모든 GameObject를 트리 구조로 보여줍니다. Day 02에서 다룬 부모-자식 관계가 시각적으로 들여쓰기(indent)로 표현되는 곳이 바로 여기입니다.

Hierarchy에서 자주 쓰는 기능은 다음과 같습니다.

- **드래그 앤 드롭**: GameObject를 다른 GameObject 위로 끌어다 놓으면 부모-자식 관계가 만들어집니다
- **검색창(돋보기 아이콘)**: 이름으로 GameObject를 즉시 필터링, `t:Light`처럼 타입 접두사로 특정 Component를 가진 오브젝트만 검색 가능
- **더블클릭**: Scene 뷰 카메라가 해당 오브젝트로 즉시 포커스 이동
- **아이콘 색상**: 스크립트 오류가 있는 오브젝트는 이름 옆에 경고 아이콘이 표시됨

```
t:Camera        // Camera Component를 가진 오브젝트만 검색
t:Light         // Light Component를 가진 오브젝트만 검색
Enemy           // 이름에 "Enemy"가 포함된 오브젝트 검색
```

> 💡 **실무 팁**: Hierarchy 검색창의 타입 접두사(`t:`) 검색은 씬이 커질수록 진가를 발휘합니다. "이 씬에 Light가 몇 개 있는지, 어디 있는지"를 눈으로 스크롤하며 찾는 대신 `t:Light` 한 번이면 끝납니다.

---

## 3. 빈 GameObject로 씬을 폴더처럼 정리하기

씬에 오브젝트가 10개, 20개를 넘어가기 시작하면 평면적인 나열만으로는 관리가 어려워집니다. 실무에서 가장 널리 쓰는 패턴은 **빈 GameObject(Empty GameObject)를 폴더처럼 사용**해 논리적으로 묶는 것입니다.

```
Level01 (Scene)
├── --- ENVIRONMENT ---
│   ├── Ground
│   ├── Rocks
│   └── Trees
├── --- MANAGERS ---
│   ├── GameManager
│   ├── AudioManager
│   └── SpawnManager
├── --- UI ---
│   ├── Canvas_HUD
│   └── Canvas_Pause
└── --- PLAYER ---
    └── Player
```

빈 GameObject는 `GameObject > Create Empty` (단축키 Ctrl/Cmd+Shift+N)로 만들고, 이름 앞뒤에 `---` 같은 구분 기호를 붙이면 Hierarchy에서 시각적으로 섹션이 눈에 띕니다. 이 빈 오브젝트는 렌더링되는 요소가 없으므로 성능에 영향을 주지 않고, 순수하게 구조화 목적으로만 존재합니다.

| 그룹 이름 예시 | 담는 대상 |
|---|---|
| `--- ENVIRONMENT ---` | 지형, 배경 오브젝트, 정적 장식물 |
| `--- MANAGERS ---` | GameManager, AudioManager 등 싱글톤 성격의 시스템 오브젝트 |
| `--- UI ---` | Canvas, HUD 관련 오브젝트 |
| `--- PLAYER ---` | 플레이어 캐릭터와 관련 하위 오브젝트 |

> 💡 **실무 팁**: 팀 프로젝트에서는 이 그룹 네이밍 규칙을 문서화해두는 것이 좋습니다. 사람마다 정리 방식이 다르면 Hierarchy가 금방 다시 뒤죽박죽이 됩니다.

---

## 4. 여러 Scene 다루기 — Build Settings와 전환

프로젝트가 커지면 Scene도 여러 개가 됩니다. `File > Build Settings` 창에서 `Add Open Scenes` 버튼으로 현재 열린 Scene을 등록하면, 이 목록에 있는 Scene들만 최종 빌드에 포함되고 각 Scene은 0번부터 시작하는 **Build Index**를 갖습니다.

스크립트에서 Scene을 전환하려면 `UnityEngine.SceneManagement` 네임스페이스의 `SceneManager`를 사용합니다.

```csharp
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneSwitcher : MonoBehaviour
{
    public void LoadLevel01()
    {
        // 이름으로 로드 - 기존 씬은 완전히 언로드되고 새 씬으로 교체됨
        SceneManager.LoadScene("Level01");
    }

    public void LoadNextLevelAdditive()
    {
        // Additive: 기존 씬을 유지한 채 새 씬을 "겹쳐서" 로드
        SceneManager.LoadScene("UI_Overlay", LoadSceneMode.Additive);
    }
}
```

`LoadSceneMode`에는 두 가지가 있습니다.

- **Single(기본값)**: 현재 씬을 완전히 언로드하고 새 씬으로 교체
- **Additive**: 현재 씬을 유지한 채 다른 씬을 추가로 로드 — 예를 들어 게임 플레이 씬은 그대로 두고 일시정지 메뉴 씬만 겹쳐서 띄우는 방식

> 💡 **실무 팁**: Additive 로딩은 "메인 월드 씬 + UI 전용 씬 + 오디오 매니저 전용 씬"처럼 역할별로 씬을 쪼개 팀원들이 서로 다른 씬 파일을 동시에 작업(협업 시 병합 충돌 감소)할 수 있게 해주는 실무 패턴으로도 자주 쓰입니다.

---

## 5. Hierarchy 정렬과 실행 중(Play Mode) 주의사항

Hierarchy는 기본적으로 GameObject가 생성된 순서, 혹은 수동으로 드래그해 배치한 순서대로 나열됩니다. 알파벳 자동 정렬 기능은 기본 제공되지 않으므로, 규모가 큰 씬에서는 앞서 다룬 그룹 오브젝트 패턴으로 정리하는 것이 사실상 유일한 실무적 해법입니다.

한 가지 반드시 기억해야 할 점은 **Play Mode에서 Hierarchy를 수정하면 그 변경 사항이 저장되지 않는다**는 것입니다. Play 버튼을 누르고 테스트하는 동안 오브젝트 위치를 옮기거나 새 오브젝트를 추가해도, Play를 멈추는 순간 Scene은 Play 시작 이전 상태로 되돌아갑니다.

> 💡 **실무 팁**: Play Mode 중에 값을 조정하다 "이 값 좋다!" 싶으면, Inspector에서 해당 Component를 우클릭 → `Copy Component`한 뒤 Play를 멈추고 `Paste Component Values`로 붙여넣으면 됩니다. 이 과정을 모르고 Play Mode에서 튜닝한 값을 그대로 날려버리는 것은 Unity 초보자들이 가장 많이 겪는 좌절 포인트 중 하나입니다.

---

## 📝 핵심 요약

1. Scene은 `.unity` 파일 하나에 대응하는 화면/레벨 단위의 컨테이너이며, 프로젝트 시작 시 기본 이름(SampleScene)을 바로 의미 있는 이름으로 바꾸는 것이 좋다
2. Hierarchy 검색창에서 `t:타입명` 문법으로 특정 Component를 가진 오브젝트만 빠르게 찾을 수 있다
3. 빈 GameObject를 폴더처럼 사용해 씬을 논리적 그룹으로 나누는 것이 씬 규모가 커졌을 때의 표준 정리 방식이다
4. Build Settings에 등록된 Scene은 Build Index를 가지며, `SceneManager.LoadScene()`으로 Single 또는 Additive 방식으로 전환·중첩할 수 있다
5. Play Mode 중 Hierarchy 변경 사항은 저장되지 않으므로, 마음에 든 값은 Copy/Paste Component Values로 미리 백업해야 한다

---

## 🔗 참고 자료

- [Scenes (Unity Manual)](https://docs.unity3d.com/Manual/CreatingScenes.html)
- [Hierarchy 창 (Unity Manual)](https://docs.unity3d.com/Manual/Hierarchy.html)
- [SceneManager 스크립팅 API](https://docs.unity3d.com/ScriptReference/SceneManagement.SceneManager.html)

---

*⬅️ 이전: [Day 02 — GameObject와 Transform 이해하기](../day-02/)  |  다음: [Day 04 — Prefab 개념과 활용](../day-04/) ➡️*
