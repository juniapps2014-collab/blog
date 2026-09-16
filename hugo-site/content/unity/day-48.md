---
title: "Day 48 — Timeline으로 컷신 제작하기"
date: 2026-09-16
weight: 48
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Timeline과 Playable Director의 관계를 이해하고 컷신용 Timeline 에셋을 직접 구성할 수 있다
- Animation Track, Audio Track, Activation Track, Control Track, Signal Track의 역할 차이를 설명하고 상황에 맞게 조합할 수 있다
- Signal Emitter/Receiver와 스크립트 API를 통해 Timeline과 게임플레이 코드를 연동할 수 있다

---

## 1. Timeline이란 무엇이고 언제 쓰는가

Unity Timeline은 여러 오브젝트의 애니메이션, 오디오, 카메라 전환, 이벤트 발생 시점을 **하나의 시간축 위에서 시각적으로 편집**할 수 있게 해주는 시퀀싱 도구입니다. 영상 편집 툴의 타임라인과 개념적으로 동일하며, 트랙(Track)과 클립(Clip)이라는 두 가지 기본 단위로 구성됩니다.

Animator Controller가 "상태 전이 기반의 반복 가능한 애니메이션"(걷기 ↔ 뛰기 등, Day 32~33 참고)에 적합하다면, Timeline은 **한 번 정해진 순서대로 흘러가는 연출**에 적합합니다. 대표적인 사용 사례:

- 컷신(Cutscene) — 대화 장면, 이벤트 연출
- 인트로/아웃트로 연출 — 게임 시작 로고, 스테이지 클리어 연출
- 여러 오브젝트가 동시에 움직여야 하는 합주형(orchestrated) 연출 — 문이 열리며 조명이 켜지고 사운드가 재생되는 등

```
Window > Sequencing > Timeline
```

메뉴에서 Timeline 창을 열고, 연출할 GameObject를 선택한 뒤 "Create" 버튼을 누르면 두 가지가 자동 생성됩니다.

1. **Timeline 에셋**(.playable) — 트랙과 클립 데이터를 담는 프로젝트 파일
2. **Playable Director 컴포넌트** — 씬에서 이 Timeline 에셋을 재생하는 실행기 역할

> 💡 **실무 팁**: Timeline 에셋은 프로젝트 에셋이므로 여러 씬에서 재사용할 수 있습니다. 단, 트랙에 바인딩된 오브젝트 참조는 씬마다 Playable Director의 인스펙터에서 따로 지정해야 합니다.

---

## 2. Playable Director — Timeline을 재생하는 엔진

Playable Director는 Timeline 에셋을 실제로 재생·제어하는 컴포넌트입니다. 인스펙터에서 확인할 수 있는 주요 설정은 다음과 같습니다.

| 설정 | 역할 |
|---|---|
| Playable | 재생할 Timeline 에셋 |
| Play On Awake | 씬 로드 시 자동 재생 여부 (컷신은 보통 꺼두고 스크립트로 트리거) |
| Wrap Mode | 재생이 끝났을 때 동작 — None(정지), Hold(마지막 프레임 유지), Loop(반복) |
| Update Method | DSP Clock, Game Time, Unscaled Game Time, Manual 중 선택 (일시정지 중 오디오만 별도로 흘러야 하는 경우 등에 사용) |

스크립트에서 재생을 제어할 때는 `PlayableDirector` API를 사용합니다.

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class CutsceneTrigger : MonoBehaviour
{
    [SerializeField] private PlayableDirector director;

    public void PlayCutscene()
    {
        director.time = 0;      // 처음부터 재생하도록 시간 초기화
        director.Play();
    }

    public void StopCutscene()
    {
        director.Stop();
    }

    private void OnDirectorPaused(PlayableDirector pd)
    {
        // director.Pause() 호출 시 콜백으로 등록 가능
    }
}
```

컷신 중 플레이어 입력을 막고 싶다면, `director.stopped` 이벤트를 구독해 컷신이 끝나는 시점에 입력을 다시 활성화하는 패턴이 일반적입니다.

```csharp
private void OnEnable() => director.stopped += OnCutsceneFinished;
private void OnDisable() => director.stopped -= OnCutsceneFinished;

private void OnCutsceneFinished(PlayableDirector pd)
{
    PlayerInputManager.Instance.EnableInput();
}
```

---

## 3. 주요 트랙 종류

Timeline 창의 `+` 버튼(또는 트랙 영역 우클릭)으로 다양한 종류의 트랙을 추가할 수 있습니다. 컷신 제작에서 자주 쓰는 트랙은 다음과 같습니다.

| 트랙 | 역할 | 바인딩 대상 |
|---|---|---|
| Animation Track | 클립 구간 동안 재생할 애니메이션 지정, 또는 타임라인 자체에서 키프레임 직접 녹화 | Animator 또는 임의의 Transform |
| Audio Track | 특정 시점에 오디오 클립 재생 (대사, 효과음, BGM 전환) | Audio Source |
| Activation Track | 클립 구간 동안 GameObject를 활성화/비활성화 | 임의의 GameObject |
| Control Track | 파티클 시스템, 타임라인 중첩(nested Timeline), 프리팹 인스턴스 생성 등을 제어 | Prefab 또는 씬 오브젝트 |
| Signal Track | 특정 시점에 "신호"를 발생시켜 스크립트 이벤트를 트리거 | Signal Receiver |

**Animation Track 활용 팁:**

- 이미 만들어둔 Animation Clip을 트랙에 드래그해서 배치할 수도 있고, Timeline 편집 모드에서 직접 오브젝트를 움직여 키프레임을 녹화(Record 버튼)할 수도 있습니다.
- 여러 클립을 이어 붙일 때 클립 경계를 겹치면 자동으로 블렌드(Ease In/Out) 구간이 생겨 부드럽게 전환됩니다.

**Control Track 활용 팁:**

- Particle System을 Control Track에 연결하면 "Timeline이 재생될 때만 파티클이 재생되고, 멈추면 파티클도 멈추는" 동기화가 자동으로 이루어집니다.
- 다른 Timeline 에셋을 Control Track 안에 중첩시켜 "서브 컷신"을 조합하는 구조도 가능합니다.

> 💡 **실무 팁**: Activation Track으로 오브젝트를 켜고 끌 때, 해당 오브젝트의 초기 활성 상태(Timeline 재생 전 상태)는 Playable Director가 자동으로 기억했다가 재생 종료 후 복원해 줍니다. 컷신 중에만 등장하는 소품을 다룰 때 유용합니다.

---

## 4. Signal Track — 스크립트와 연동하기

Timeline 안에서 일어나는 일을 게임 로직과 연결하려면 **Signal**을 사용합니다. 예를 들어 "대사가 끝나는 시점에 퀘스트 플래그를 갱신"하거나 "카메라 컷 전환 시점에 화면 흔들림 효과를 트리거"하는 식입니다.

**설정 순서:**

1. Timeline에 **Signal Track**을 추가합니다.
2. 원하는 시점에 우클릭 → **Add Signal Emitter**로 신호를 배치합니다.
3. 새 **Signal Asset**을 생성하거나 기존 것을 지정합니다 (예: `OnDialogueEnd`).
4. 씬의 아무 GameObject에 **Signal Receiver** 컴포넌트를 추가하고, 해당 Signal Asset에 반응할 `UnityEvent`를 등록합니다.

```csharp
using UnityEngine;

public class QuestFlagUpdater : MonoBehaviour
{
    // Signal Receiver의 UnityEvent에서 이 메서드를 호출하도록 연결
    public void OnDialogueEndSignal()
    {
        QuestManager.Instance.SetFlag("Chapter1_IntroSeen", true);
    }
}
```

Signal Receiver의 인스펙터에서 `OnDialogueEnd` 신호와 `QuestFlagUpdater.OnDialogueEndSignal()` 메서드를 드래그로 연결하면, Timeline이 해당 프레임에 도달하는 순간 메서드가 호출됩니다.

> Signal은 "Timeline 재생 위치가 정확히 그 프레임을 지나갈 때"만 발동합니다. 스크럽(구간 이동)으로 건너뛰면 발동하지 않을 수 있으므로, 반드시 발동해야 하는 로직(예: 세이브)에는 별도의 안전장치를 두는 것이 좋습니다.

---

## 5. Cinemachine과 결합한 카메라 컷 연출

Day 47에서 다룬 Cinemachine Virtual Camera들은 Timeline의 **Cinemachine Track**과 결합할 때 진가를 발휘합니다. Cinemachine Track에 여러 Virtual Camera 클립을 순서대로 배치하면, 클립이 바뀌는 시점마다 자동으로 해당 카메라로 블렌드 전환됩니다.

**설정 순서:**

1. 씬에 **CinemachineBrain**이 메인 카메라에 붙어 있는지 확인합니다 (Day 47 참고).
2. Timeline에 **Cinemachine Track**을 추가하고, 여러 Virtual Camera를 트랙 위 클립으로 배치합니다.
3. 각 클립의 길이를 조절해 "이 시점엔 전신 샷, 다음 시점엔 클로즈업" 같은 컷 전환을 구성합니다.
4. 클립 경계의 블렌드 설정(Cut, Ease In/Out, Custom)으로 전환 방식을 지정합니다.

이 방식은 대화 장면에서 화자가 바뀔 때마다 카메라를 전환하는 전형적인 컷신 연출에 가장 널리 쓰입니다. Virtual Camera 자체의 Priority를 스크립트로 조작하는 방식(Day 47)과 달리, Timeline 위에서는 **컷 타이밍을 눈으로 보면서 편집**할 수 있다는 차이가 있습니다.

> 💡 **실무 팁**: 컷신 진행 중 플레이어의 실제 카메라 상태(Virtual Camera Priority 등)를 컷신이 끝난 뒤 그대로 복원하고 싶다면, 컷신 전용 Virtual Camera들의 Priority를 컷신 시작 시 임시로 올렸다가 `director.stopped` 콜백에서 원래 값으로 되돌리는 방식을 함께 사용합니다.

---

## 📝 핵심 요약

1. Timeline은 반복 상태 전이가 아닌 "한 번 정해진 순서로 흘러가는" 연출(컷신, 인트로 등)에 적합하며, Playable Director가 이를 재생·제어한다
2. Animation/Audio/Activation/Control/Signal 트랙을 조합해 애니메이션, 사운드, 오브젝트 활성화, 파티클, 이벤트 발생을 하나의 시간축에서 동기화할 수 있다
3. Signal Emitter/Receiver를 통해 Timeline의 특정 시점과 게임플레이 스크립트(퀘스트 갱신, 효과 트리거 등)를 연결할 수 있다
4. Cinemachine Track과 결합하면 여러 Virtual Camera 사이의 컷 전환을 Timeline 위에서 시각적으로 편집할 수 있다
5. `PlayableDirector.stopped` 이벤트로 컷신 종료 시점을 감지해 입력 활성화나 카메라 상태 복원 같은 후처리를 안전하게 처리할 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Timeline](https://docs.unity3d.com/Manual/TimelineOverview.html)
- [Unity Manual — Timeline Signals](https://docs.unity3d.com/Manual/TimelineWorkingWithSignals.html)
- [Unity Scripting API — PlayableDirector](https://docs.unity3d.com/ScriptReference/Playables.PlayableDirector.html)

---

*⬅️ 이전: [Day 47 — Cinemachine으로 카메라 연출 고도화](../day-47/)  |  다음: [Day 49 — 7주차 정리: 연출이 들어간 인터랙션 씬 제작](../day-49/) ➡️*
