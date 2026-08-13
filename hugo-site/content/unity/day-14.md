---
title: "Day 14 — 2주차 정리: 간단한 인터랙티브 씬 완성"
date: 2026-08-13
weight: 14
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Rigidbody/Collider, UI(Canvas), 카메라, 오디오, 폴더 구조 관리(Day 08~13)를 하나의 인터랙티브 씬에 통합할 수 있다
- 물리 기반 이동과 트리거 충돌을 이용해 "아이템 수집 → UI 갱신 → 사운드 재생"으로 이어지는 이벤트 체인을 스크립팅할 수 있다
- Day 13에서 정한 폴더 구조와 네이밍 컨벤션을 실제 프로젝트에 적용하며 점검할 수 있다

---

## 1. 이번 주 배운 개념 정리와 오늘의 목표

2주차에서 다룬 내용을 표로 정리하면 다음과 같습니다.

| Day | 주제 | 오늘 실습에서의 역할 |
|---|---|---|
| 08 | Rigidbody와 물리 엔진 | 중력과 힘(Force)으로 플레이어 이동 처리 |
| 09 | Collider와 충돌 감지 | 아이템 획득, 벽 충돌을 트리거/충돌 이벤트로 감지 |
| 10 | Unity UI 시스템(Canvas) | 점수와 남은 아이템 개수를 화면에 표시 |
| 11 | 카메라 시스템 | 플레이어를 따라가는 3인칭 추적 카메라 구성 |
| 12 | 오디오 시스템 | 아이템 획득 시 효과음, 배경음악 재생 |
| 13 | 폴더 구조와 에셋 관리 | `Assets/` 하위를 역할별로 정리하고 네이밍 규칙 적용 |

오늘 만들 것은 **"굴러다니는 공을 조작해 아이템을 모두 모으면 클리어되는 미니 게임"** 입니다. 1주차 실습(Day 07)에서는 Transform으로 직접 이동시켰지만, 이번에는 Rigidbody 기반 물리 이동으로 교체하고 UI·오디오·카메라까지 하나의 씬에 엮습니다.

> 💡 **실무 팁**: 스프린트 리뷰 데모를 준비할 때도 "기능은 다 있는데 따로 논다"는 피드백을 가장 많이 받습니다. 오늘처럼 여러 시스템을 한 씬에서 맞물리게 하는 연습이 실무 감각을 기르는 데 직결됩니다.

---

## 2. Day 13 기준으로 폴더 구조 먼저 잡기

새 기능을 만들기 전에 Day 13에서 배운 규칙부터 적용합니다. 아이템, 사운드, 스크립트가 이번 실습에서 처음 추가되므로 아래처럼 폴더를 준비합니다.

```
Assets/
├── _Project/
│   ├── Scenes/
│   │   └── Week02_Review.unity
│   ├── Scripts/
│   │   ├── Player/
│   │   │   └── PlayerMotor.cs
│   │   ├── Gameplay/
│   │   │   ├── Collectible.cs
│   │   │   └── GameManager.cs
│   │   └── UI/
│   │       └── HudController.cs
│   ├── Prefabs/
│   │   └── Collectible_Coin.prefab
│   └── Audio/
│       ├── SFX_CoinPickup.wav
│       └── BGM_Loop01.mp3
```

Day 13에서 강조했던 "타입이 아닌 기능(feature)별로 묶기" 원칙에 따라 `Player`, `Gameplay`, `UI`처럼 역할 단위 하위 폴더를 만든 점에 주목하세요. 스크립트 이름도 `PascalCase`, 오디오 파일은 `SFX_`/`BGM_` 접두사로 구분해 Day 13의 네이밍 컨벤션을 그대로 따릅니다.

> 💡 **실무 팁**: 폴더 구조는 "나중에 정리하자"고 미루면 프로젝트가 커질수록 리팩터링 비용이 기하급수적으로 늘어납니다. 새 기능을 추가하는 시점에 바로 규칙을 적용하는 습관이 중요합니다.

---

## 3. Rigidbody 기반 PlayerMotor — Day 08 복습 + 확장

Day 08에서 배운 `Rigidbody.AddForce`를 이용해 1주차의 Transform 이동 코드를 교체합니다.

```csharp
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class PlayerMotor : MonoBehaviour
{
    [SerializeField] private float moveForce = 12f;
    [SerializeField] private float maxSpeed = 6f;

    private Rigidbody rb;
    private Vector2 moveInput;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
        rb.interpolation = RigidbodyInterpolation.Interpolate; // 카메라 추적 시 떨림 방지
    }

    private void Update()
    {
        moveInput = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
    }

    private void FixedUpdate()
    {
        Vector3 force = new Vector3(moveInput.x, 0f, moveInput.y) * moveForce;
        rb.AddForce(force, ForceMode.Force);

        // Day 08 복습: 물리 기반 이동은 속도를 직접 제한해줘야 무한 가속을 막을 수 있다
        Vector3 flatVelocity = new Vector3(rb.linearVelocity.x, 0f, rb.linearVelocity.z);
        if (flatVelocity.magnitude > maxSpeed)
        {
            Vector3 limited = flatVelocity.normalized * maxSpeed;
            rb.linearVelocity = new Vector3(limited.x, rb.linearVelocity.y, limited.z);
        }
    }
}
```

Rigidbody의 `Collision Detection`은 `Continuous`로 설정해 빠르게 굴러갈 때 벽을 통과하는 현상을 방지합니다. 이 설정은 Day 08에서 다룬 "터널링(Tunneling)" 문제와 직결됩니다.

---

## 4. Collectible — Day 09 트리거로 아이템 획득 이벤트 만들기

Day 09에서 배운 트리거 충돌을 이용해 아이템을 획득하면 사라지고 이벤트를 발생시키는 스크립트를 작성합니다.

```csharp
using UnityEngine;

[RequireComponent(typeof(Collider))]
public class Collectible : MonoBehaviour
{
    [SerializeField] private int scoreValue = 10;

    private void Reset()
    {
        GetComponent<Collider>().isTrigger = true; // Day 09: 물리적으로 막지 않고 겹침만 감지
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag("Player")) return;

        GameManager.Instance.OnCollectibleGathered(scoreValue);
        Destroy(gameObject);
    }
}
```

`GameManager`는 싱글턴 패턴으로 점수와 남은 아이템 개수를 관리하고, UI와 오디오를 동시에 갱신하는 중개자 역할을 합니다.

```csharp
using UnityEngine;

public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    [SerializeField] private HudController hud;
    [SerializeField] private AudioSource sfxSource;
    [SerializeField] private AudioClip pickupClip;

    private int score;
    private int remainingItems;

    private void Awake()
    {
        Instance = this;
        remainingItems = FindObjectsByType<Collectible>(FindObjectsSortMode.None).Length;
    }

    private void Start()
    {
        hud.UpdateScore(score);
        hud.UpdateRemaining(remainingItems);
    }

    public void OnCollectibleGathered(int value)
    {
        score += value;
        remainingItems--;

        hud.UpdateScore(score);
        hud.UpdateRemaining(remainingItems);

        // Day 12 복습: PlayOneShot으로 겹쳐 재생되는 짧은 효과음 처리
        sfxSource.PlayOneShot(pickupClip);

        if (remainingItems <= 0)
        {
            hud.ShowClearMessage();
        }
    }
}
```

---

## 5. HUD(Canvas)와 카메라 — Day 10~11 복습

Day 10에서 배운 Canvas 기반 UI로 점수/남은 개수를 표시하는 `HudController`를 만듭니다.

```csharp
using TMPro;
using UnityEngine;

public class HudController : MonoBehaviour
{
    [SerializeField] private TMP_Text scoreText;
    [SerializeField] private TMP_Text remainingText;
    [SerializeField] private GameObject clearPanel;

    public void UpdateScore(int score) => scoreText.text = $"Score: {score}";
    public void UpdateRemaining(int remaining) => remainingText.text = $"Remaining: {remaining}";
    public void ShowClearMessage() => clearPanel.SetActive(true);
}
```

카메라는 Day 11에서 다룬 추적 카메라 개념을 단순화해, `LateUpdate`에서 플레이어 위치를 따라가도록 구성합니다.

```csharp
using UnityEngine;

public class FollowCamera : MonoBehaviour
{
    [SerializeField] private Transform target;
    [SerializeField] private Vector3 offset = new Vector3(0f, 6f, -6f);
    [SerializeField] private float smoothSpeed = 8f;

    private void LateUpdate()
    {
        Vector3 desiredPosition = target.position + offset;
        transform.position = Vector3.Lerp(transform.position, desiredPosition, smoothSpeed * Time.deltaTime);
        transform.LookAt(target);
    }
}
```

> 💡 **실무 팁**: 카메라 이동은 `Update()`가 아니라 `LateUpdate()`에서 처리해야 합니다. 플레이어의 `FixedUpdate()`/`Update()` 이동이 끝난 "다음" 시점에 카메라가 따라가야 떨림(jitter) 없이 부드럽게 추적됩니다.

---

## 6. 최종 점검 체크리스트

씬을 Play 모드로 실행하기 전에 아래 항목을 확인합니다.

1. Player의 Rigidbody `Collision Detection`이 `Continuous`로 설정되어 있는가
2. 모든 Collectible의 Collider `Is Trigger`가 체크되어 있는가
3. GameManager 인스펙터에 HudController, AudioSource, pickupClip이 모두 연결되어 있는가
4. 아이템 획득 시 점수/남은 개수 텍스트가 즉시 갱신되고 효과음이 재생되는가
5. 마지막 아이템을 먹었을 때 클리어 패널이 정상적으로 표시되는가
6. `Assets/_Project/` 하위 폴더 구조가 Day 13 규칙(기능별 폴더, PascalCase, 접두사)을 따르고 있는가

이 여섯 가지가 모두 통과하면 2주차 실습은 완료입니다. 지금까지는 기본 도형(Primitive)만으로 씬을 구성했지만, 3주차부터는 Blender로 직접 모델링한 에셋을 이 파이프라인에 올리기 시작합니다.

---

## 📝 핵심 요약

1. 2주차 실습은 Rigidbody 물리 이동, Collider 트리거, Canvas UI, 추적 카메라, 오디오를 하나의 씬에서 서로 신호를 주고받도록 연결하는 데 집중한다
2. GameManager 같은 중개자(싱글턴) 패턴을 쓰면 아이템 획득 이벤트 하나가 UI 갱신과 사운드 재생으로 자연스럽게 이어진다
3. 물리 기반 이동에서는 속도 제한과 `Continuous Collision Detection`으로 무한 가속·터널링 문제를 방지해야 한다
4. 카메라 추적 로직은 `LateUpdate()`에 두어야 플레이어 이동 이후 부드럽게 따라간다
5. Day 13에서 정한 폴더 구조와 네이밍 규칙은 기능을 추가하는 시점마다 바로 적용해야 나중에 리팩터링 비용이 늘지 않는다

---

## 🔗 참고 자료

- [Unity Manual — Rigidbody](https://docs.unity3d.com/Manual/class-Rigidbody.html)
- [Unity Manual — Canvas](https://docs.unity3d.com/Manual/UICanvas.html)
- [Unity Scripting API — AudioSource.PlayOneShot](https://docs.unity3d.com/ScriptReference/AudioSource.PlayOneShot.html)

---

*⬅️ 이전: [Day 13 — 프로젝트 폴더 구조와 에셋 관리 베스트 프랙티스](../day-13/)  |  다음: [Day 15 — Blender 설치와 인터페이스 익히기](../day-15/) ➡️*
