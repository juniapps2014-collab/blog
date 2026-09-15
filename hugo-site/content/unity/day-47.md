---
title: "Day 47 — Cinemachine으로 카메라 연출 고도화"
date: 2026-09-15
weight: 47
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Cinemachine의 Virtual Camera와 Brain 구조를 이해하고 기본 씬에 적용할 수 있다
- Follow, Look At, Blend, Priority 개념을 활용해 여러 카메라 연출을 전환할 수 있다
- Noise, Impulse, State-Driven Camera로 게임 상황에 맞는 카메라 연출을 구성할 수 있다

---

## 1. Cinemachine이 필요한 이유

일반 `Camera` 컴포넌트에 직접 스크립트로 추적/흔들림/전환 로직을 짜면 코드가 금방 복잡해집니다. 카메라가 플레이어를 따라가다가, 컷씬에서 다른 각도로 전환하고, 총격을 받으면 흔들리고, 다시 원래대로 부드럽게 복귀하는 상황을 상상해보면 — if문과 Lerp 코드가 순식간에 얽힙니다.

**Cinemachine**은 이런 카메라 연출을 코드 없이(또는 최소한의 코드로) 조합 가능한 컴포넌트 단위로 만들어주는 Unity 공식 패키지입니다. 영화 촬영 용어(Virtual Camera, Dolly, Impulse 등)를 그대로 차용해 실제 카메라 감독처럼 씬을 연출할 수 있습니다.

```
Window > Package Manager > Cinemachine 설치
GameObject > Cinemachine > Virtual Camera
```

---

## 2. Virtual Camera와 Brain의 관계

Cinemachine의 핵심 구조는 두 계층으로 나뉩니다.

| 구성 요소 | 역할 |
|---|---|
| **CinemachineBrain** | 실제 `Camera` 오브젝트에 붙는 컴포넌트. 여러 Virtual Camera 중 어떤 것을 "실제로 렌더링할지" 결정하고 전환(Blend)을 관리 |
| **CinemachineVirtualCamera** | 실제 렌더링은 하지 않는 "가상 카메라". Follow/Look At 대상, Lens 설정, Noise 등을 독립적으로 가짐 |

씬에 Virtual Camera를 여러 개 배치해두고, **Priority** 값이 가장 높은 것이 자동으로 활성화됩니다. 예를 들어 평소엔 3인칭 추적 카메라(Priority 10)를 쓰다가, 특정 이벤트에서 클로즈업 카메라(Priority 20)를 활성화하면 Brain이 자동으로 두 카메라 사이를 부드럽게 Blend합니다.

```csharp
public class CameraSwitcher : MonoBehaviour
{
    public CinemachineVirtualCamera closeUpCam;

    public void TriggerCloseUp()
    {
        closeUpCam.Priority = 20; // 다른 카메라보다 높은 값으로 전환
    }
}
```

> 💡 **실무 팁**: 카메라를 직접 `enabled = false/true`로 끄고 켤 필요가 없습니다. Priority만 조절하면 Brain이 Blend까지 알아서 처리합니다.

---

## 3. Follow와 Look At — 추적과 조준의 분리

Virtual Camera에는 두 개의 독립적인 타겟 슬롯이 있습니다.

- **Follow**: 카메라의 "위치"가 따라갈 대상 (예: 플레이어)
- **Look At**: 카메라의 "시선 방향"이 향할 대상 (예: 적, 또는 플레이어 자신)

두 값이 같으면 단순 추적 카메라가 되고, 다르게 설정하면 "플레이어를 따라가면서 보스를 바라보는" 식의 연출이 가능합니다.

Body(Follow 알고리즘)와 Aim(Look At 알고리즘)은 각각 여러 방식 중 선택할 수 있습니다.

| Body 알고리즘 | 용도 |
|---|---|
| Transposer | 고정된 오프셋으로 대상을 따라감 (3인칭 게임 기본) |
| Framing Transposer | 화면 내 특정 위치에 대상을 유지하며 따라감 (2D/사이드뷰에 적합) |
| Orbital Transposer | 마우스 입력으로 대상 주위를 회전하며 따라감 |

| Aim 알고리즘 | 용도 |
|---|---|
| Composer | 대상을 화면 내 지정된 위치에 유지, 부드러운 추적 |
| POV | 마우스/스틱 입력으로 시점 회전 (FPS 시점) |
| Group Composer | 여러 대상을 동시에 프레임 안에 담기 |

```csharp
var vcam = GetComponent<CinemachineVirtualCamera>();
vcam.Follow = player.transform;
vcam.LookAt = boss.transform;
```

---

## 4. Blend — 카메라 전환을 영화처럼

두 Virtual Camera 사이를 전환할 때 즉시 컷(Cut)할지, 부드럽게 이동(Blend)할지는 **CinemachineBrain**의 Default Blend 설정에서 조정합니다.

- **Cut**: 즉시 전환 (컷씬의 각도 전환처럼)
- **Ease In/Out**: 부드럽게 가속/감속하며 전환
- **Custom Blend Asset**: 특정 카메라 쌍(A→B)마다 다른 전환 시간/커브를 지정

```
CinemachineBrain > Default Blend > Style: Ease In Out, Time: 1.5초
```

특정 카메라 조합에서만 다른 전환을 원한다면 Custom Blends 리스트에 "From: CamA, To: CamB, Blend: 2초 Ease In" 같은 규칙을 추가할 수 있습니다.

> 💡 **실무 팁**: 전투 중 카메라 전환은 0.2~0.5초의 짧은 Blend가 자연스럽고, 컷씬 사이 전환은 1~2초 정도의 느린 Blend가 영화적인 느낌을 줍니다.

---

## 5. Noise와 Impulse — 흔들림 연출

**Noise** 컴포넌트(Basic Multi Channel Perlin)를 Virtual Camera에 추가하면 카메라에 미세한 흔들림을 지속적으로 줄 수 있습니다. 걷기/뛰기 중 화면 흔들림, 또는 폭발 지속 효과 등에 사용합니다.

**Impulse**는 순간적인 충격 이벤트(폭발, 피격, 착지)에 반응하는 흔들림입니다. `CinemachineImpulseSource`를 이벤트가 발생하는 오브젝트에 붙이고, 씬의 Virtual Camera에는 `CinemachineImpulseListener`를 붙이면 거리 기반으로 감쇠되는 흔들림이 자동 적용됩니다.

```csharp
public class Explosion : MonoBehaviour
{
    private CinemachineImpulseSource impulseSource;

    void Awake() => impulseSource = GetComponent<CinemachineImpulseSource>();

    void OnExplode()
    {
        impulseSource.GenerateImpulse(); // 폭발 지점에서 충격 발생
    }
}
```

> 💡 **실무 팁**: Impulse는 발생 지점으로부터의 거리에 따라 카메라가 받는 흔들림 세기가 자동으로 줄어듭니다. 폭발 위치를 정확히 잡아두면 "가까울수록 세게 흔들리는" 연출이 별도 코드 없이 완성됩니다.

---

## 6. State-Driven Camera — 애니메이션 상태에 따른 카메라 전환

`CinemachineStateDrivenCamera`는 Animator의 State Machine과 연동해, 캐릭터 애니메이션 상태(Idle, Run, Attack 등)에 맞춰 자동으로 다른 Virtual Camera로 전환합니다. Day 32~33에서 다룬 Animator State Machine의 각 상태에 카메라를 매핑하는 방식입니다.

```
CinemachineStateDrivenCamera 설정
- Animated Target: 캐릭터의 Animator
- Instructions 리스트에 State ↔ Virtual Camera 매핑 추가
  (예: Attack 상태 → 클로즈업 카메라, Run 상태 → 넓은 추적 카메라)
```

이 방식은 보스전이나 필살기 연출처럼 "특정 애니메이션이 재생되는 동안만 카메라 앵글이 바뀌는" 상황에 특히 유용합니다.

---

## 📝 핵심 요약

1. Cinemachine은 Virtual Camera(설정)와 Brain(실제 렌더링/전환 관리)의 2계층 구조로 동작한다
2. Priority 값만 조정하면 Brain이 카메라 전환과 Blend를 자동으로 처리한다
3. Follow(위치 추적)와 Look At(시선 방향)을 분리해 다양한 카메라 알고리즘(Transposer, Composer 등)을 조합할 수 있다
4. Noise는 지속적 흔들림, Impulse는 이벤트 기반 순간 흔들림에 사용하며 거리에 따라 자동 감쇠된다
5. State-Driven Camera로 애니메이션 상태와 카메라 연출을 직접 연동할 수 있다

---

## 🔗 참고 자료

- [Cinemachine 공식 매뉴얼](https://docs.unity3d.com/Packages/com.unity.cinemachine@latest)
- [Cinemachine Impulse 문서](https://docs.unity3d.com/Packages/com.unity.cinemachine@2.9/manual/CinemachineImpulse.html)

---

*⬅️ 이전: [Day 46 — Ragdoll Physics와 물리 기반 애니메이션](../day-46/)  |  다음: [Day 48 — Timeline으로 컷신 제작하기](../day-48/) ➡️*
