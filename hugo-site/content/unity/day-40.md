---
title: "Day 40 — Particle System으로 이펙트 만들기"
date: 2026-09-07
weight: 40
---

> **Phase 6: 환경과 월드 빌딩** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Unity Particle System(Shuriken)의 핵심 모듈 구조를 이해하고 Emission/Shape로 파티클 생성 방식을 제어할 수 있다
- Color/Size/Velocity over Lifetime 모듈로 시간에 따라 변화하는 이펙트를 만들 수 있다
- 스크립트로 파티클 시스템을 재생/정지/트리거하고, 성능을 고려한 이펙트 최적화 방법을 설명할 수 있다

---

## 1. Particle System 컴포넌트 개요

Unity의 기본 파티클 시스템은 코드네임 **Shuriken**이라 불리며, GameObject에 `Particle System` 컴포넌트를 추가하는 것만으로 수백~수천 개의 작은 스프라이트(또는 메시)를 동시에 생성·이동·소멸시킬 수 있습니다. 불, 연기, 마법 효과, 먼지, 스파크 같은 "규칙은 있지만 개별 오브젝트로 관리하기엔 비효율적인" 시각 효과에 사용합니다.

Particle System은 여러 **모듈(Module)**의 조합으로 동작합니다. 인스펙터에서 체크박스로 모듈을 켜고 끄며, 각 모듈은 독립적인 역할을 담당합니다.

| 모듈 | 역할 |
|---|---|
| Main | 파티클 수명, 시작 속도/크기/색상, 중력 배율 등 전역 기본값 |
| Emission | 파티클을 얼마나 자주, 몇 개씩 생성할지 |
| Shape | 파티클이 어떤 형태의 영역/표면에서 생성될지 |
| Velocity over Lifetime | 수명 동안 속도 변화 |
| Color over Lifetime | 수명 동안 색상/투명도 변화 |
| Size over Lifetime | 수명 동안 크기 변화 |
| Renderer | 파티클을 화면에 그리는 방식(빌보드, 머티리얼, 정렬) |

메인 모듈만 켜져 있어도 파티클이 생성되지만, 대부분의 "그럴듯한" 이펙트는 Emission + Shape + 서너 개의 Lifetime 모듈 조합으로 완성됩니다.

```
GameObject > Effects > Particle System
```

메뉴에서 바로 생성하면 기본 흰색 원형 파티클이 위로 퍼지는 프리뷰가 나타납니다. 씬 뷰 하단의 재생 컨트롤(Play/Pause/Stop, Playback Speed)로 실시간 미리보기가 가능합니다.

---

## 2. Emission과 Shape — 생성 방식 제어

**Emission 모듈**은 "얼마나 많은 파티클을, 얼마나 자주" 만들지를 결정합니다.

- `Rate over Time`: 초당 생성 개수 (지속적인 연기, 불꽃 등)
- `Rate over Distance`: 오브젝트가 이동한 거리당 생성 개수 (자동차 타이어 자국, 발자국 먼지)
- `Bursts`: 특정 시점에 한꺼번에 N개를 터뜨림 (폭발, 타격 이펙트)

```
Bursts
  Time: 0.0   Count: 20   Cycles: 1   Interval: 0.01   Probability: 1.0
```

폭발처럼 "한 번에 확 터지는" 이펙트는 `Rate over Time`을 0으로 두고 `Bursts`만 사용하는 것이 자연스럽습니다.

**Shape 모듈**은 파티클이 생성되는 공간적 영역을 정의합니다.

| Shape | 용도 예시 |
|---|---|
| Sphere / Hemisphere | 폭발, 마법진, 사방으로 퍼지는 효과 |
| Cone | 횃불, 분수, 스포트라이트형 분사 |
| Box | 비, 눈처럼 넓은 영역에서 균일하게 떨어지는 효과 |
| Circle | 바닥에 깔리는 원형 이펙트(장판형 스킬) |
| Mesh / Skinned Mesh Renderer | 캐릭터 소멸 효과처럼 특정 메시 표면에서 파티클 발생 |

`Mesh` Shape는 캐릭터가 재가 되어 사라지는 연출 등에 자주 쓰이며, 대상 메시의 버텍스/트라이앵글/에지 중 어디서 발생시킬지도 선택할 수 있습니다.

> 💡 **실무 팁**: Shape의 `Radius Thickness`를 0으로 두면 표면에서만, 1로 두면 내부 전체에서 파티클이 생성됩니다. 폭죽처럼 "테두리에서만 터지는" 느낌을 원하면 Thickness를 낮추세요.

---

## 3. 수명 동안의 변화 — Color/Size/Velocity over Lifetime

정적인 파티클은 밋밋합니다. 실제 이펙트의 완성도는 "시간에 따라 어떻게 변하는가"에서 나옵니다.

**Color over Lifetime**은 파티클이 태어나서 소멸할 때까지 색상과 알파(투명도)를 그라디언트로 제어합니다. 대부분의 이펙트는 끝에서 알파를 0으로 떨어뜨려 갑자기 사라지지 않고 자연스럽게 페이드아웃되도록 만듭니다.

```
Color over Lifetime
  Gradient: [불투명 주황] → [반투명 빨강] → [완전 투명]
```

**Size over Lifetime**은 커브(Curve)로 크기 변화를 제어합니다. 예를 들어 연기는 태어날 때 작다가 위로 올라가며 서서히 커지는 것이 자연스럽고, 스파크는 태어난 순간 가장 크고 점점 작아지는 편이 자연스럽습니다.

**Velocity over Lifetime**은 시간에 따른 속도 벡터 변화를 제어합니다. 중력만으로는 표현하기 어려운 "위로 솟구쳤다가 옆으로 퍼지는" 움직임이나 나선형 움직임(Orbital 옵션)을 만들 수 있습니다.

```csharp
// 런타임에 커브 기반 모듈 값을 스크립트로 조정하는 예시
using UnityEngine;

public class FireEffectController : MonoBehaviour
{
    [SerializeField] private ParticleSystem fireParticles;

    public void SetIntensity(float intensity)
    {
        var emission = fireParticles.emission;
        emission.rateOverTime = Mathf.Lerp(5f, 50f, intensity);

        var main = fireParticles.main;
        main.startSpeed = Mathf.Lerp(1f, 3f, intensity);
    }
}
```

모듈 값은 인스펙터에서 직접 조정하는 것이 기본이지만, 위처럼 `ParticleSystem.MainModule`, `ParticleSystem.EmissionModule` 같은 구조체를 통해 런타임에도 조정할 수 있습니다. 단, 이 구조체들은 값을 담는 프록시일 뿐이므로 반드시 `var emission = ps.emission;`처럼 지역 변수로 받아온 뒤 프로퍼티를 수정해야 실제로 반영됩니다.

> 💡 **실무 팁**: 각 Lifetime 모듈 우측의 드롭다운(빨간 삼각형 아이콘)에서 `Curve`, `Random Between Two Curves` 등을 선택할 수 있습니다. 두 커브 사이를 무작위로 섞으면 파티클 하나하나가 조금씩 다르게 움직여 훨씬 자연스러운 이펙트가 됩니다.

---

## 4. Renderer 모듈과 머티리얼

**Renderer 모듈**은 파티클을 실제로 화면에 그리는 방식을 결정합니다.

- `Render Mode: Billboard` — 항상 카메라를 향하는 평면 스프라이트 (연기, 불, 마법 효과 등 대부분의 2D 텍스처 이펙트)
- `Render Mode: Mesh` — 파티클 하나하나를 3D 메시로 렌더링 (파편, 나뭇잎, 화살 등 입체감이 필요한 경우)
- `Render Mode: Stretched Billboard` — 이동 방향으로 늘어나는 빌보드 (스파크, 트레일, 총알 궤적)

머티리얼은 보통 `Particles/Standard Unlit` 또는 URP의 `Particles Unlit` / `Particles Lit` 셰이더를 사용하며, 텍스처는 알파 채널이 있는 PNG나 가산 혼합(Additive Blending)용 흑백 텍스처를 씁니다.

| Blending Mode | 특징 |
|---|---|
| Alpha Blended | 배경 위에 자연스럽게 겹쳐짐 (연기, 안개) |
| Additive | 색을 더해서 밝게 빛나는 느낌 (불꽃, 마법, 빛 효과) |
| Multiply | 배경을 어둡게 (그림자, 오염 효과) |

`Sort Mode`(By Distance 등)는 반투명 파티클이 여러 개 겹칠 때 렌더링 순서를 결정하는데, 파티클 수가 많을수록 정렬 비용이 커지므로 꼭 필요한 경우에만 켭니다.

---

## 5. 스크립트로 제어하기 & Sub Emitters

```csharp
using UnityEngine;

public class HitEffectSpawner : MonoBehaviour
{
    [SerializeField] private ParticleSystem hitEffectPrefab;

    public void PlayHitEffect(Vector3 position, Vector3 normal)
    {
        ParticleSystem instance = Instantiate(
            hitEffectPrefab, position, Quaternion.LookRotation(normal));

        instance.Play();

        // Stop Action이 Destroy로 설정되어 있으면
        // 재생이 끝난 뒤 자동으로 GameObject가 파괴됩니다.
    }
}
```

타격 이펙트처럼 "한 번 재생하고 사라지는" 파티클은 Main 모듈의 `Stop Action`을 `Destroy`로 설정해두면 스크립트에서 별도로 `Destroy()`를 호출하지 않아도 자동 정리되어 메모리 누수를 방지할 수 있습니다.

**Sub Emitters** 모듈을 사용하면 하나의 파티클이 특정 이벤트(Birth, Death, Collision)를 만났을 때 또 다른 파티클 시스템을 추가로 발생시킬 수 있습니다. 예를 들어 폭죽이 터진 뒤(Death) 각 파편이 흩어지며 작은 불티를 추가로 뿌리는 2단 이펙트를 이 모듈로 구현합니다.

> 💡 **실무 팁**: `ParticleSystem.Emit(count)`을 사용하면 Emission 모듈의 자동 생성 규칙과 무관하게 코드에서 원하는 시점에 정확히 N개의 파티클을 즉시 발생시킬 수 있습니다. 콤보 타격처럼 프레임 단위로 정밀한 타이밍이 필요할 때 유용합니다.

---

## 6. 성능 최적화 체크리스트

파티클 이펙트는 화면을 화려하게 만들지만 잘못 쓰면 모바일에서 가장 먼저 프레임 드랍을 일으키는 원인이 됩니다.

- **Max Particles**를 항상 현실적인 값으로 제한한다 — 기본값(1000)을 그대로 두면 버그로 파티클이 무한 생성될 때 프레임이 급락한다
- **Overdraw**(반투명 파티클이 여러 겹 겹쳐 같은 픽셀을 여러 번 그리는 현상)를 주의한다 — 화면을 가득 채우는 큰 파티클을 여러 겹 겹치지 않도록 텍스처 자체의 밀도를 높이는 편이 낫다
- **Collision 모듈**은 물리 연산 비용이 크므로 꼭 필요한 이펙트에만 사용한다
- 모바일 타겟에서는 `Render Mode: Mesh` 파티클의 폴리곤 수와 개수를 함께 관리한다 (드로우 콜 증가)
- 화면 밖 이펙트는 `Particle System Culling`(Renderer 모듈의 Culling Mode) 설정으로 비활성 컬링을 활용한다

> 대규모 VFX가 필요한 프로젝트는 Shuriken 대신 **VFX Graph**(GPU 기반, URP/HDRP)를 검토할 만합니다. 다만 VFX Graph는 별도 패키지와 학습 곡선이 있어, 이번 커리큘럼에서는 기본기인 Shuriken 위주로 다룹니다.

---

## 📝 핵심 요약

1. Particle System은 Main/Emission/Shape/Renderer를 비롯한 여러 모듈의 조합으로 동작하며, 각 모듈이 "생성 규칙"과 "시각적 변화"를 나눠서 담당한다
2. Emission의 Rate over Time과 Bursts, Shape의 Sphere/Cone/Box 등을 조합해 이펙트의 기본 형태와 발생 패턴을 결정한다
3. Color/Size/Velocity over Lifetime 모듈로 시간에 따른 변화를 만드는 것이 밋밋한 파티클을 그럴듯한 이펙트로 바꾸는 핵심이다
4. 스크립트에서는 모듈 구조체를 지역 변수로 받아 값을 수정하며, Stop Action과 Sub Emitters로 자동 정리와 연쇄 이펙트를 구현한다
5. Max Particles 제한, Overdraw 관리, Collision 모듈 최소화는 파티클 이펙트 성능 최적화의 핵심 체크포인트다

---

## 🔗 참고 자료

- [Unity Manual — Particle Systems](https://docs.unity3d.com/Manual/PartSysReference.html)
- [Unity Scripting API — ParticleSystem](https://docs.unity3d.com/ScriptReference/ParticleSystem.html)
- [Unity Manual — VFX Graph 개요](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@latest)

---

*⬅️ 이전: [Day 39 — 스카이박스와 환경 분위기 연출](../day-39/)  |  다음: [Day 41 — Post-processing으로 비주얼 완성도 높이기](../day-41/) ➡️*
