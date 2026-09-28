---
title: "Day 59 — 애니메이션과 라이팅으로 완성도 높이기"
date: 2026-09-27
weight: 59
---

> **Phase 9: 캡스톤 프로젝트** | 예상 학습 시간: 60분

---

## 🎯 학습 목표

- Day 58에서 구조적으로 완성한 씬에 캐릭터 애니메이션을 통합하고, State Machine과 Blend Tree가 자연스럽게 전환되는지 검증할 수 있다
- 라이트맵 베이킹, 스카이박스, Post-processing을 조합해 씬의 "분위기"를 의도한 대로 연출할 수 있다
- 애니메이션과 라이팅이 서로 어긋나는 흔한 문제(루트 모션 밀림, 베이크된 그림자와 실시간 그림자의 불일치)를 진단하고 고칠 수 있다

---

## 1. 오늘의 작업 흐름 - 애니메이션과 라이팅이 "완성도"를 결정하는 이유

Day 58까지는 씬이 구조적으로 맞는 상태(스케일, 콜라이더, 머티리얼 슬롯)를 만드는 데 집중했습니다. 하지만 같은 에셋이라도 애니메이션이 부자연스럽거나 조명이 밋밋하면 완성도가 떨어져 보입니다. 반대로 모델링 자체는 단순해도 애니메이션과 라이팅이 잘 맞아떨어지면 포트폴리오에서 훨씬 설득력 있는 결과물이 됩니다.

오늘의 작업 순서는 다음과 같습니다.

```
1. Unity: 캐릭터에 Humanoid Avatar + Animator Controller 연결 (Day 32, 34 복습)
2. Unity: Blend Tree로 이동 애니메이션(Idle-Walk-Run) 전환 다듬기 (Day 33 복습)
3. Unity: Lighting 창에서 씬 전체의 조명 레이어 설계 (Directional/Point/Area)
4. Unity: Lightmap 베이킹 실행 및 결과 검증 (Day 38 복습)
5. Unity: 스카이박스/Fog로 분위기 마감 (Day 39 복습)
6. Unity: Post-processing Volume으로 톤 다듬기 (Day 41 복습)
```

이 순서를 지키는 이유는 명확합니다. **애니메이션을 먼저 확정해야 캐릭터가 씬 안에서 어떻게 움직이는지 알 수 있고, 그 동선을 기준으로 조명을 배치해야** 그림자와 하이라이트가 실제로 보여줄 위치에 놓입니다. 순서를 바꿔 라이팅부터 완벽하게 잡으면, 나중에 캐릭터 동선이 바뀔 때 조명을 다시 손봐야 하는 경우가 많습니다.

> 💡 **실무 팁**: 실무에서도 "카메라/캐릭터 동선 확정 → 라이팅"의 순서를 지킵니다. 라이팅 아티스트가 조명을 잡기 전에 반드시 애니메이션 블로킹(대략적인 움직임)이 먼저 나와야 하는 이유가 여기에 있습니다.

---

## 2. 캐릭터 애니메이션 통합 체크리스트 (Day 29-34 복습)

씬에 배치한 캐릭터 모델이 실제로 움직이려면 아래 항목이 순서대로 맞아야 합니다.

```
[ ] Rig 탭에서 Animation Type = Humanoid로 설정, Avatar Definition 생성 확인 (녹색 체크)
[ ] Configure... 버튼으로 Avatar 골격 매핑 확인 - 빨간/노란 경고 본 없는지
[ ] Animator 컴포넌트에 Animator Controller 에셋 연결
[ ] Animator 창에서 Base Layer에 Idle/Walk/Run 등 필요한 State가 모두 존재하는지
[ ] 각 State의 Motion 필드에 올바른 클립(Clip)이 연결되어 있는지
[ ] Root Motion 사용 여부 결정 - 코드로 이동시킬지, 애니메이션 자체 이동을 쓸지
```

| 체크 항목 | 놓쳤을 때 생기는 증상 |
|---|---|
| Avatar 골격 매핑 | 캐릭터가 T-포즈로 고정되거나 팔다리가 꺾여 보임 |
| Motion 클립 연결 누락 | State는 있는데 애니메이션이 재생되지 않고 정지 상태로 보임 |
| Root Motion 설정 미결정 | 캐릭터가 제자리에서 걷는 것처럼 보이거나, 반대로 이중으로 이동해 미끄러짐 |

> 💡 **실무 팁**: Root Motion을 켤지 끌지는 프로젝트 초반에 한 번 정해두는 것이 좋습니다. 캡스톤처럼 이미 스크립트로 캐릭터를 이동시키는 구조라면 Root Motion은 끄고(Apply Root Motion 체크 해제), 코드의 `CharacterController.Move()`나 `Rigidbody` 이동만으로 위치를 제어하는 편이 디버깅이 쉽습니다.

---

## 3. Animator Controller와 Blend Tree 최종 점검

Day 32-33에서 만든 State Machine과 Blend Tree를 캡스톤 씬 기준으로 다시 점검합니다. 핵심은 "전환이 튀지 않는가"입니다.

```csharp
// 이동 속도를 Animator 파라미터로 넘겨 Blend Tree를 구동하는 전형적인 패턴
using UnityEngine;

public class CharacterAnimationDriver : MonoBehaviour
{
    [SerializeField] private Animator animator;
    [SerializeField] private CharacterController controller;
    [SerializeField] private float dampTime = 0.15f; // 전환을 부드럽게 하는 핵심 값

    private static readonly int SpeedHash = Animator.StringToHash("Speed");

    void Update()
    {
        // XZ 평면 속도만 사용 (수직 낙하 속도는 애니메이션과 무관)
        Vector3 flatVelocity = controller.velocity;
        flatVelocity.y = 0f;
        float normalizedSpeed = flatVelocity.magnitude / controller.velocity.magnitude > 0
            ? flatVelocity.magnitude
            : 0f;

        // SetFloat의 dampTime 인자가 Blend Tree 전환을 부드럽게 만드는 핵심
        animator.SetFloat(SpeedHash, normalizedSpeed, dampTime, Time.deltaTime);
    }
}
```

Blend Tree 전환에서 특히 자주 놓치는 부분은 `SetFloat`에 `dampTime`을 주지 않고 값을 바로 꽂아버리는 경우입니다. 이렇게 하면 속도가 0에서 5로 순간 이동하듯 바뀌면서 Idle에서 Run으로 애니메이션이 툭 끊겨 보입니다.

| 전환 파라미터 | 권장 값 | 효과 |
|---|---|---|
| Transition Duration | 0.1 ~ 0.25초 | State 간 전환 시 두 애니메이션을 자연스럽게 크로스페이드 |
| Has Exit Time | 이동 전환은 대부분 해제 | 입력에 즉각 반응해야 하는 전환(Idle↔Walk)은 Exit Time을 기다리면 반응이 느려짐 |
| SetFloat dampTime | 0.1 ~ 0.2초 | 파라미터 값 자체가 급격히 튀는 것을 완화 |

> 💡 **실무 팁**: 전환이 여전히 어색하다면 Animator 창을 열어둔 채 Play 모드에서 실시간으로 Blend Tree의 파란 점(현재 블렌드 위치)이 어떻게 움직이는지 관찰하세요. 점이 뚝뚝 끊기며 이동한다면 파라미터 갱신 로직을, 부드럽게 이동하는데도 애니메이션이 어색하다면 클립 자체의 루프 포인트를 의심해야 합니다.

---

## 4. 라이팅 설계 - 분위기를 만드는 3가지 레이어

캡스톤 씬의 조명은 아래 세 레이어로 나누어 설계하면 체계적으로 접근할 수 있습니다.

1. **Key Light (주광원)**: 씬 전체의 명암 방향을 결정하는 Directional Light 1개. 시간대(낮/노을/밤) 컨셉에 맞춰 색온도와 각도를 정합니다.
2. **Fill/Accent Light**: 주광원만으로는 그림자 영역이 완전히 검게 죽어버리므로, Point Light나 Area Light로 특정 오브젝트나 캐릭터 얼굴 주변을 살짝 밝혀줍니다.
3. **Ambient/Environment Light**: Lighting 창의 Environment Lighting(Skybox 기반) 또는 Baked Indirect로 전체적인 공간감을 채웁니다.

| Light 타입 | 용도 | Mode 권장 설정 |
|---|---|---|
| Directional Light (Key) | 태양광, 전체 명암 방향 | Mixed (실시간 그림자 + 베이크 GI) |
| Point/Spot Light (Accent) | 캐릭터·소품 강조, 실내 조명 | Baked (정적 오브젝트 위주라면) |
| Area Light | 창문에서 들어오는 부드러운 광량 | Baked (Area Light는 실시간 미지원) |

> 💡 **실무 팁**: Directional Light를 Mixed 모드로 두면 실시간 그림자는 유지하면서 간접광(Bounce Light)은 베이크된 결과를 사용해 성능과 품질의 균형을 잡을 수 있습니다. Day 50 이후 배울 최적화 관점에서도 이 조합이 가장 무난합니다.

---

## 5. 라이트맵 베이킹 워크플로우 (Day 38 복습)

Day 38에서 배운 라이트맵 베이킹을 캡스톤 씬 전체에 적용합니다. 베이킹 전 아래 순서를 지키세요.

```
[ ] 베이크할 정적 오브젝트에 Static 체크박스(또는 최소 Contribute GI) 활성화
[ ] Window > Rendering > Lighting 창에서 Lightmapping Settings 확인
[ ] Lightmap Resolution을 씬 규모에 맞게 조정 (기본 40 texels/unit → 소품이 많으면 낮춰서 베이크 시간 단축)
[ ] Lighting Mode = Baked Indirect 또는 Subtractive/Shadowmask 중 프로젝트에 맞는 모드 선택
[ ] Generate Lighting 버튼으로 베이크 실행, Progress 완료까지 대기
```

캐릭터처럼 움직이는 오브젝트는 라이트맵에 구워지지 않으므로, Light Probe Group을 배치해 캐릭터가 이동하는 동안에도 주변 간접광을 자연스럽게 받도록 해야 합니다.

```
Light Probe 배치 가이드
1. GameObject > Light > Light Probe Group 생성
2. 캐릭터의 예상 이동 경로를 따라 격자 형태로 Probe 배치
3. 조명이 급격히 바뀌는 경계(실내→실외, 그림자 진입부)에는 Probe 밀도를 높임
4. 베이크 후 Scene 뷰에서 Probe 사이를 걸어보며 캐릭터 셰이딩이 부드럽게 변하는지 확인
```

> 💡 **실무 팁**: 베이크가 끝났는데도 캐릭터가 유독 어둡거나 밝게 튄다면, Light Probe가 아예 없거나 캐릭터의 이동 경로에서 벗어난 위치에만 배치된 경우가 많습니다. Probe는 "캐릭터가 실제로 서 있을 법한 위치"를 기준으로 배치해야 합니다.

---

## 6. Post-processing과 Particle로 마무리 연출

라이팅까지 잡았다면 Day 41에서 익힌 Post-processing Volume으로 전체 톤을 다듬습니다.

| 효과 | 권장 시작값 | 목적 |
|---|---|---|
| Bloom | Intensity 0.3~0.8 | 밝은 광원 주변에 은은한 번짐 추가 |
| Color Adjustments | Post Exposure ±0.2, Contrast +5~10 | 씬 전체의 톤 통일 |
| Vignette | Intensity 0.15~0.25 | 화면 가장자리를 살짝 어둡게 해 시선을 중앙으로 유도 |
| Ambient Occlusion | Intensity 0.5~1.0 | 오브젝트가 맞닿는 부분의 그림자를 강조해 입체감 보강 |

```csharp
// 시간대(낮/노을)에 따라 Post-processing 프로파일을 전환하는 간단한 예시
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LightingMoodSwitcher : MonoBehaviour
{
    [SerializeField] private Volume postProcessVolume;
    [SerializeField] private VolumeProfile dayProfile;
    [SerializeField] private VolumeProfile duskProfile;

    public void SetDuskMood(bool isDusk)
    {
        postProcessVolume.profile = isDusk ? duskProfile : dayProfile;
    }
}
```

마지막으로 Day 40에서 다룬 Particle System을 활용해 씬에 생명감을 더합니다. 먼지 입자, 반딧불, 촛불 연기처럼 작은 움직임 하나가 정적인 씬을 훨씬 완성도 있게 만들어 줍니다. 단, 파티클은 과하면 오히려 산만해지므로 씬당 1~2개 포인트에만 배치하는 것을 권장합니다.

> 💡 **실무 팁**: Post-processing과 파티클은 "마지막 5%를 채우는" 작업입니다. 씬의 구조(모델링/임포트/애니메이션/기본 라이팅)가 먼저 탄탄해야 이 단계의 효과가 제대로 빛을 발합니다. 순서를 거꾸로 해서 이펙트부터 화려하게 넣으면, 정작 구조적 문제(스케일 불일치, 어색한 애니메이션 전환)를 가리기만 할 뿐 해결하지 못합니다.

---

## 📝 핵심 요약

1. 애니메이션을 먼저 확정하고 그 동선을 기준으로 라이팅을 설계해야 그림자와 하이라이트가 의도한 위치에 놓인다
2. Humanoid Avatar 매핑, Animator Controller 연결, Root Motion 사용 여부는 캐릭터가 움직이기 전에 반드시 점검해야 하는 3가지다
3. Blend Tree 전환은 `SetFloat`의 dampTime과 Transition Duration을 함께 조정해야 자연스러워진다
4. 조명은 Key(주광원)-Accent(보조광)-Ambient(환경광) 3레이어로 나누어 설계하면 체계적으로 분위기를 잡을 수 있다
5. 라이트맵 베이킹 후에는 반드시 Light Probe Group을 배치해 움직이는 캐릭터가 간접광을 자연스럽게 받도록 해야 한다
6. Post-processing과 파티클은 구조가 탄탄한 씬 위에 올리는 마무리 단계이며, 순서를 앞당기면 근본 문제를 가릴 뿐이다

---

## 🔗 참고 자료

- [Unity Manual — Lighting Overview](https://docs.unity3d.com/Manual/LightingOverview.html)
- [Unity Manual — Animator Controllers](https://docs.unity3d.com/Manual/class-AnimatorController.html)
- [Unity Manual — Light Probes](https://docs.unity3d.com/Manual/LightProbes.html)

---

*⬅️ 이전: [Day 58 — 모델링+임포트+머티리얼 통합 작업](../day-58/)  |  다음: [Day 60 — 최종 폴리싱과 포트폴리오 정리](../day-60/) ➡️*
