---
title: "Day 49 — 7주차 정리: 연출이 들어간 인터랙션 씬 제작"
date: 2026-09-17
weight: 49
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 45분

---

## 🎯 학습 목표

- Shader Graph, 커스텀 셰이더, 상호작용 스크립트, Ragdoll, Cinemachine, Timeline을 하나의 씬에 통합해 완성할 수 있다
- "인터랙션(플레이어 입력) → 반응(애니메이션/물리) → 연출(카메라/시퀀스)"로 이어지는 작업 순서를 스스로 설계할 수 있다
- 7주차에서 배운 각 시스템이 하나의 인터랙션 씬 안에서 어떤 역할을 맡는지 설명할 수 있다

---

## 1. 7주차 복습 — 무엇을 배웠나

Phase 7에서는 "비주얼 표현력"과 "연출 도구"라는 두 축을 다뤘습니다. 전반부(43-44)는 셰이더로 머티리얼의 표현력을 높이는 법을, 후반부(45-48)는 오브젝트 반응과 카메라/시퀀스 연출을 다뤘습니다.

| Day | 주제 | 씬에서의 역할 |
|---|---|---|
| 43 | Shader Graph 기초 개념 | 노드 기반으로 커스텀 머티리얼 로직 구성 |
| 44 | 커스텀 셰이더로 표현력 높이기 | 발광, 디졸브, 홀로그램 등 특수 효과 머티리얼 |
| 45 | 애니메이션 이벤트와 스크립트 연동 | 상호작용 발생 시점을 정확히 감지해 로직 트리거 |
| 46 | Ragdoll Physics | 피격/사망 등 물리 기반 반응 연출 |
| 47 | Cinemachine 카메라 연출 고도화 | 상황에 따라 카메라 앵글/거동을 동적으로 전환 |
| 48 | Timeline으로 컷신 제작 | 여러 요소를 하나의 시간축 위에서 순서대로 연출 |

이 조합을 보면 7주차는 결국 "플레이어가 무언가를 트리거하면(45) → 오브젝트가 셰이더(43-44)와 물리(46)로 반응하고 → 카메라(47)와 Timeline(48)이 그 반응을 극적으로 보여준다"는 하나의 파이프라인으로 이어집니다.

---

## 2. 실습 — 연출이 들어간 인터랙션 씬 만들기 (체크리스트)

오늘은 새 개념 없이, 지금까지 배운 걸 하나의 "짧은 인터랙션 시퀀스"로 통합하는 실습을 진행합니다. 예시 시나리오: *"플레이어가 스위치를 누르면 발광 셰이더가 적용된 오브젝트가 반응하고, 근처의 적이 넘어지며(Ragdoll), 카메라가 컷신으로 전환되어 이 장면을 보여준다."*

**1단계 — 상호작용 트리거 (Day 45)**

- [ ] 스위치/버튼 오브젝트에 트리거 콜라이더와 상호작용 스크립트 부착
- [ ] Animation Event 또는 `OnTriggerEnter`로 "발동 시점"을 정확히 감지
- [ ] 발동 시 `UnityEvent` 또는 커스텀 이벤트로 후속 로직(셰이더 반응, Ragdoll, Timeline)을 느슨하게 연결

```csharp
using UnityEngine;
using UnityEngine.Events;

public class InteractionSwitch : MonoBehaviour
{
    [SerializeField] private UnityEvent onActivated;
    private bool activated;

    private void OnTriggerEnter(Collider other)
    {
        if (activated || !other.CompareTag("Player")) return;
        activated = true;
        onActivated.Invoke(); // 셰이더 반응, Ragdoll, Timeline 재생을 인스펙터에서 연결
    }
}
```

**2단계 — 셰이더 반응 (Day 43-44)**

- [ ] Shader Graph로 만든 발광(Emission) 머티리얼을 대상 오브젝트에 적용
- [ ] 발동 시 `MaterialPropertyBlock`으로 발광 강도를 0 → 목표값으로 코드에서 전환
- [ ] 매 프레임 `new Material()`을 생성하지 않도록 `MaterialPropertyBlock` 사용 습관화 (Day 44 참고)

**3단계 — 물리 반응 (Day 46)**

- [ ] 적 캐릭터에 미리 세팅해 둔 Ragdoll 구성 확인 (Rigidbody + Collider가 각 본에 부착)
- [ ] 발동 시 Animator를 끄고 Ragdoll Rigidbody를 활성화하는 전환 스크립트 호출
- [ ] 필요하다면 `AddForce`로 넘어지는 방향에 힘을 더해 연출을 강조

**4단계 — 카메라 연출 (Day 47-48)**

- [ ] 이벤트 트리거 지점에 컷신용 Virtual Camera(또는 Cinemachine Track) 배치
- [ ] Timeline에 Signal Track을 추가해 "카메라 전환 → 셰이더 반응 → Ragdoll 발동" 순서를 시간축 위에 배치
- [ ] `PlayableDirector.stopped` 콜백으로 컷신 종료 후 플레이어 카메라/입력 복원

```
씬 계층 구조 예시
Scene
├── Player
├── InteractionSwitch (Day 45 스크립트 부착)
├── ReactiveObject (Shader Graph 발광 머티리얼)
├── Enemy (Ragdoll 구성 완료)
├── Cinemachine
│   ├── VCam_PlayerFollow (기본 카메라)
│   └── VCam_CutsceneCloseup (연출용 카메라)
└── CutsceneTimeline (Playable Director)
    ├── Signal Track (트리거 시점 표시)
    ├── Cinemachine Track (카메라 전환)
    └── Activation Track (ReactiveObject 강조)
```

> 💡 **실무 팁**: 여러 시스템을 한 번에 연결하려 하지 말고, 먼저 "트리거 → 셰이더 반응"만 완성해 테스트한 뒤, "→ Ragdoll", "→ 카메라 연출" 순으로 하나씩 붙여나가세요. 한 번에 다 연결하면 어느 단계에서 문제가 생겼는지 찾기 어렵습니다.

---

## 3. 흔한 실수와 점검 포인트

- **UnityEvent 남용**: 상호작용이 많아질수록 인스펙터에 연결된 `UnityEvent`가 늘어나 추적이 어려워집니다. 핵심 흐름은 코드에서 명시적으로 호출하고, `UnityEvent`는 부가 효과(사운드, 파티클) 정도로 제한하는 것이 유지보수에 유리합니다.
- **Ragdoll 전환 타이밍 오류**: Animator가 여전히 본을 제어하는 상태에서 Rigidbody를 켜면 두 시스템이 충돌해 캐릭터가 경련하듯 떨립니다. 반드시 Animator를 비활성화(또는 weight 0)한 뒤 물리를 활성화하세요.
- **컷신 중 카메라 충돌**: Cinemachine Virtual Camera의 Priority와 Timeline의 Cinemachine Track이 동시에 카메라를 제어하려 하면 예상치 못한 전환이 발생합니다. 컷신 재생 중에는 Timeline이 카메라를 전담하도록 다른 Virtual Camera의 Priority를 일시적으로 낮춰두세요.
- **발광 셰이더 성능**: Emission 강도를 매 프레임 Material 자체를 새로 만들어 갱신하면 GC 부담이 커집니다. `MaterialPropertyBlock`을 재사용하는 방식으로 갱신하세요.

---

## 📝 핵심 요약

1. 7주차는 "셰이더로 표현력 높이기(43-44) → 이벤트로 상호작용 감지(45) → 물리로 반응(46) → 카메라/Timeline으로 연출(47-48)"이라는 하나의 파이프라인으로 요약된다
2. 인터랙션 씬은 트리거 → 셰이더 반응 → Ragdoll → 카메라 연출 순으로 한 단계씩 붙여나가며 테스트하는 것이 디버깅에 유리하다
3. Ragdoll 전환은 Animator 비활성화와 Rigidbody 활성화 타이밍을 정확히 맞춰야 어색한 떨림을 피할 수 있다
4. 컷신 중에는 Timeline(Cinemachine Track)이 카메라를 전담하도록 다른 Virtual Camera의 Priority를 관리해야 한다
5. 여러 시스템을 연동할 때는 UnityEvent를 부가 효과 수준으로만 활용하고, 핵심 흐름은 코드로 명시적으로 관리하는 편이 유지보수에 유리하다

---

## 🔗 참고 자료

- [Unity Manual — Ragdoll Wizard](https://docs.unity3d.com/Manual/wizard-RagdollWizard.html)
- [Unity Manual — Shader Graph](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest/manual/index.html)
- [Unity Scripting API — MaterialPropertyBlock](https://docs.unity3d.com/ScriptReference/MaterialPropertyBlock.html)

---

*⬅️ 이전: [Day 48 — Timeline으로 컷신 제작하기](../day-48/)  |  다음: [Day 50 — Draw Call과 배칭(Batching) 이해하기](../day-50/) ➡️*
