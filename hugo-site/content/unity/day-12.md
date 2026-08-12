---
title: "Day 12 — 오디오 시스템 다루기"
date: 2026-08-11
weight: 12
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- AudioSource, AudioListener, AudioClip의 역할과 관계를 설명할 수 있다
- 2D/3D 사운드 설정(Spatial Blend, Rolloff, Doppler)을 상황에 맞게 조정할 수 있다
- AudioMixer로 볼륨 그룹을 나누고 스크립트로 제어할 수 있다

---

## 1. Unity 오디오의 3대 요소: AudioListener, AudioSource, AudioClip

Unity 오디오 시스템은 세 가지 컴포넌트/에셋으로 구성됩니다.

| 요소 | 역할 |
|---|---|
| **AudioListener** | "귀" 역할. 씬에 하나만 있어야 하며, 보통 Main Camera에 기본으로 붙어 있음 |
| **AudioSource** | "스피커" 역할. 소리를 재생하는 GameObject에 붙이는 컴포넌트 |
| **AudioClip** | 실제 오디오 데이터(파일). AudioSource가 재생할 원본 소스 |

AudioListener는 씬에 정확히 하나만 있어야 합니다. 두 개 이상이면 콘솔에 경고가 뜨고 오디오가 제대로 재생되지 않습니다. 카메라를 여러 개 두고 전환하는 프로젝트라면, 사용하지 않는 카메라의 AudioListener 컴포넌트는 꺼두는 것이 안전합니다.

```csharp
using UnityEngine;

public class SimpleSoundPlayer : MonoBehaviour
{
    public AudioClip clickSound;
    private AudioSource audioSource;

    void Awake()
    {
        audioSource = GetComponent<AudioSource>();
    }

    public void PlayClick()
    {
        // PlayOneShot: 다른 소리와 겹쳐서 재생 가능 (짧은 효과음에 적합)
        audioSource.PlayOneShot(clickSound);
    }
}
```

> 💡 **실무 팁**: `audioSource.Play()`는 현재 재생 중인 클립을 중단하고 새로 재생하지만, `PlayOneShot()`은 기존 재생을 끊지 않고 겹쳐서 재생합니다. 발자국 소리, 타격음처럼 연속으로 겹쳐도 되는 효과음은 `PlayOneShot`을 쓰는 것이 자연스럽습니다.

---

## 2. AudioSource 주요 속성

Inspector에서 AudioSource를 열면 자주 만지는 속성들이 있습니다.

| 속성 | 설명 |
|---|---|
| `Play On Awake` | 씬 시작 시 자동 재생 여부. 배경음악(BGM)은 켜고, 효과음은 꺼서 스크립트로 제어하는 것이 일반적 |
| `Loop` | 반복 재생 여부. BGM, 앰비언스 사운드에 사용 |
| `Volume` | 0~1 사이 음량 |
| `Pitch` | 재생 속도/음높이 배율. 1이 기본, 낮추면 느리고 저음, 높이면 빠르고 고음 |
| `Spatial Blend` | 0(2D) ~ 1(3D) 사이 슬라이더. 아래에서 자세히 다룸 |
| `Priority` | 0~256, 값이 낮을수록 우선순위 높음. 동시 재생 소리가 많을 때 어떤 소리를 잘라낼지 결정 |

```csharp
// 코드로 볼륨/피치 제어
audioSource.volume = 0.7f;
audioSource.pitch = Random.Range(0.95f, 1.05f); // 매번 살짝 다른 피치로 단조로움 방지
```

> 💡 **실무 팁**: 같은 발소리 클립을 그대로 반복 재생하면 기계적으로 들립니다. `pitch`에 ±5% 정도 랜덤 편차를 주는 것만으로도 소리가 훨씬 자연스러워집니다.

---

## 3. 2D 사운드 vs 3D 사운드 — Spatial Blend

`Spatial Blend` 슬라이더가 Unity 오디오에서 가장 중요한 설정입니다.

- **0 (2D)**: 리스너와의 거리/방향에 관계없이 항상 동일한 볼륨으로 들림. UI 클릭음, BGM에 사용
- **1 (3D)**: 리스너와의 거리, 방향에 따라 볼륨과 좌우 패닝이 달라짐. 캐릭터 발소리, 총소리, 환경음 등 월드에 실제로 존재하는 소리에 사용

3D로 설정하면 아래 항목들이 함께 활성화됩니다.

| 속성 | 설명 |
|---|---|
| `Volume Rolloff` | 거리에 따라 볼륨이 줄어드는 곡선. `Logarithmic`(현실적, 기본값), `Linear`(단순 비례), `Custom`(직접 커브 그리기) |
| `Min Distance` | 이 거리 이내에서는 최대 볼륨 유지 |
| `Max Distance` | 이 거리를 넘으면 소리가 거의 들리지 않음(Rolloff 곡선에 따라) |
| `Doppler Level` | 도플러 효과 강도. 빠르게 지나가는 차량 소리 등에 사용, 기본은 1 |
| `Spread` | 3D 사운드를 얼마나 스테레오/모노처럼 퍼뜨릴지(0~360도) |

```csharp
AudioSource src = GetComponent<AudioSource>();
src.spatialBlend = 1f;              // 완전 3D
src.rolloffMode = AudioRolloffMode.Logarithmic;
src.minDistance = 2f;
src.maxDistance = 25f;
```

> 💡 **실무 팁**: `Min Distance`를 너무 작게 잡으면(예: 0.1) 캐릭터가 조금만 다가가도 소리가 갑자기 커져 부자연스럽습니다. 오브젝트 크기와 카메라 거리감을 고려해 최소 1~2 정도로 잡는 것이 무난합니다.

---

## 4. AudioMixer로 볼륨 그룹 관리하기

BGM, 효과음(SFX), 대사(Voice)를 각각 따로 조절하고 싶다면 `Window > Audio > Audio Mixer`에서 AudioMixer 에셋을 만들고 그룹을 나눕니다.

```
Master
 ├─ BGM
 ├─ SFX
 └─ Voice
```

각 AudioSource의 `Output` 필드에 해당 그룹을 연결하면, 그룹 단위로 볼륨을 조절할 수 있습니다. 옵션 메뉴의 볼륨 슬라이더는 보통 이 방식으로 구현합니다.

AudioMixer의 볼륨은 직접 `float`으로 노출되지 않고, **Exposed Parameter**(노출된 파라미터)로 등록한 뒤 스크립트에서 이름으로 접근합니다.

```csharp
using UnityEngine;
using UnityEngine.Audio;

public class VolumeController : MonoBehaviour
{
    public AudioMixer mixer;

    // 슬라이더 UI의 OnValueChanged에 연결
    public void SetBgmVolume(float sliderValue)
    {
        // 슬라이더는 보통 0~1 선형값, 오디오는 데시벨(dB, 로그 스케일)이므로 변환 필요
        float dB = sliderValue > 0.0001f
            ? Mathf.Log10(sliderValue) * 20f
            : -80f; // 0에 가까우면 사실상 무음 처리
        mixer.SetFloat("BGMVolume", dB);
    }
}
```

> ⚠️ AudioMixer의 파라미터는 **데시벨(dB)** 단위입니다. UI 슬라이더 값(0~1)을 그대로 넣으면 안 되고, 로그 변환을 거쳐야 사람 귀에 자연스러운 볼륨 곡선이 나옵니다. `Mathf.Log10(x) * 20`이 표준 변환 공식입니다.

파라미터를 노출하려면 Mixer 창에서 그룹의 Volume 슬라이더를 우클릭 → `Expose 'Volume (of BGM)' to script` → 상단의 `Exposed Parameters`에서 이름을 `BGMVolume` 등으로 변경합니다.

---

## 5. 3D 공간 사운드 실전 — Reverb Zone과 Audio Effects

환경에 따라 소리가 다르게 울리게 하려면 `Audio Reverb Zone` 컴포넌트를 빈 GameObject에 붙이고 구역(반경)을 설정합니다. 동굴, 실내 홀처럼 반향이 필요한 공간에 배치하면 리스너가 그 구역에 들어왔을 때 자동으로 리버브가 적용됩니다.

| 컴포넌트 | 용도 |
|---|---|
| `Audio Reverb Zone` | 특정 공간에 진입 시 리버브(잔향) 효과 적용 |
| `Audio Low Pass Filter` | 고음을 걸러내 먹먹한 소리로 (벽 너머 소리, 수중 효과 등) |
| `Audio Echo Filter` | 메아리 효과 |
| `Audio Chorus Filter` | 음을 여러 개 겹쳐 두껍게 만드는 효과 |

이 필터들은 AudioSource가 붙은 GameObject 자체에 추가로 붙여서 해당 소스에만 적용할 수도 있습니다.

---

## 📝 핵심 요약

1. AudioListener(귀)는 씬에 하나만, AudioSource(스피커)는 소리를 내는 오브젝트마다, AudioClip은 실제 음원 데이터
2. `PlayOneShot`은 겹쳐 재생 가능하고 `Play`는 기존 재생을 끊는다 — 효과음과 BGM에 각각 다르게 사용
3. `Spatial Blend`로 2D(UI/BGM)와 3D(월드 사운드)를 구분하고, Min/Max Distance와 Rolloff로 거리감을 조정
4. AudioMixer로 BGM/SFX/Voice를 그룹화하고, 볼륨 제어 시 데시벨 변환(`Log10(x) * 20`)이 필요하다
5. Reverb Zone과 각종 Audio Filter로 공간에 맞는 사운드 연출이 가능하다

---

## 🔗 참고 자료

- [Unity Manual - Audio Overview](https://docs.unity3d.com/Manual/Audio.html)
- [Unity Scripting API - AudioSource](https://docs.unity3d.com/ScriptReference/AudioSource.html)
- [Unity Manual - Audio Mixer](https://docs.unity3d.com/Manual/AudioMixer.html)

---

*⬅️ 이전: [Day 11 — 카메라 시스템과 시네마틱 기초](../day-11/)  |  다음: [Day 13 — 프로젝트 폴더 구조와 에셋 관리 베스트 프랙티스](../day-13/) ➡️*
