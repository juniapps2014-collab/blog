---
title: "Day 54 — VR/AR 프로젝트를 위한 3D 모델 고려사항"
date: 2026-09-22
weight: 54
---

> **Phase 8: 최적화와 실전 워크플로우** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- VR/AR이 일반 3D 프로젝트보다 훨씬 엄격한 성능 예산을 요구하는 이유를 설명할 수 있다
- 타깃 기기별 폴리곤/드로우콜/텍스처 예산을 고려해 3D 에셋을 설계할 수 있다
- 실제 크기(Real-world Scale)와 콜라이더 설계가 몰입감과 상호작용에 미치는 영향을 이해한다
- AR 프로젝트에서 Occlusion, Light Estimation 등 3D 모델에 추가로 요구되는 고려사항을 설명할 수 있다

---

## 1. VR/AR 3D 에셋이 일반 3D 프로젝트와 다른 이유

지금까지 다룬 최적화(Day 50~53의 배칭, 프로파일링, 모바일 최적화, 텍스처 아틀라스)는 모두 "일반 화면 출력"을 전제로 했습니다. VR/AR은 여기에 훨씬 가혹한 제약이 추가됩니다.

- **스테레오 렌더링(Stereo Rendering)**: 양쪽 눈에 각각 다른 시점을 렌더링해야 하므로, 이론적으로는 씬을 2번 그려야 합니다. Unity의 Single Pass Instanced 렌더링으로 드로우콜 자체는 줄일 수 있지만, GPU가 처리해야 하는 최종 픽셀/버텍스 연산량은 여전히 모노 렌더링보다 큽니다.
- **높은 프레임레이트 요구**: 일반 모바일 게임은 30~60fps면 충분하지만, VR은 어지러움(멀미)을 막기 위해 최소 72fps(Quest 2), 90~120fps(PCVR, Quest 3)를 유지해야 합니다. 프레임이 떨어지면 단순히 "버벅임"이 아니라 사용자가 실제로 메스꺼움을 느끼는 수준의 문제가 됩니다.
- **독립형(Standalone) 기기의 모바일급 하드웨어**: Quest 시리즈처럼 널리 쓰이는 독립형 VR 기기는 내부적으로 모바일 SoC를 사용합니다. Day 52에서 다룬 모바일 최적화 기법(폴리곤 감소, 텍스처 압축, 드로우콜 최소화)이 VR에서는 "선택"이 아니라 "필수"가 됩니다.
- **AR의 실세계 정합(Registration)**: AR은 3D 모델을 실제 공간의 스케일/조명/그림자와 자연스럽게 어우러지도록 배치해야 하므로, 모델링 단계에서부터 추가 고려사항이 생깁니다.

| 구분 | 일반 모바일/PC 게임 | VR | AR |
|---|---|---|---|
| 목표 프레임레이트 | 30~60fps | 72~120fps (기기별 고정) | 30~60fps (기기 카메라 처리 병행) |
| 렌더링 시점 수 | 1개 | 2개(스테레오) | 1개 + 실세계 합성 |
| 프레임 드랍 시 체감 | 화면이 끊김 | 멀미/어지러움 유발 | 트래킹 오차, 몰입감 저하 |
| 하드웨어 | 다양(고사양 포함) | 대부분 모바일급 SoC(Standalone) | 스마트폰/태블릿 SoC |

> 💡 **실무 팁**: VR 프로젝트를 시작할 때 가장 먼저 확인해야 할 것은 타깃 기기의 "고정 프레임레이트"입니다. 이 값은 옵션이 아니라 하드웨어/OS 레벨에서 강제되는 경우가 많아서, 이 프레임을 못 맞추면 프레임을 드랍하는 게 아니라 화면 전체가 버벅이는 형태로 나타납니다.

---

## 2. 기기별 폴리곤/드로우콜 예산 설계하기

VR/AR 3D 모델링은 "예쁘게 만들고 나중에 최적화"가 아니라, **예산을 먼저 정하고 그 안에서 모델링**하는 접근이 필요합니다. Day 27에서 다룬 LOD 개념과 Day 50의 드로우콜 개념을 VR/AR 기준으로 다시 적용해야 합니다.

| 기기(예시) | 씬 전체 권장 폴리곤(삼각형) | 드로우콜 예산(씬 전체) | 비고 |
|---|---|---|---|
| Quest 2 (Standalone) | 50,000 ~ 100,000 | 50~100 | 모바일 SoC, 발열/배터리 제약 |
| Quest 3 (Standalone) | 150,000 ~ 300,000 | 100~150 | Quest 2 대비 GPU 성능 향상 |
| PCVR (RTX급 GPU) | 500,000 이상 가능 | 200~300+ | 스테레오라도 데스크톱 GPU 여유 있음 |
| 모바일 AR (스마트폰) | 50,000 ~ 150,000 | 50~100 | 카메라 패스스루/트래킹 연산과 GPU 자원 공유 |

이 수치는 절대 기준이 아니라 "이 정도를 넘기면 프로파일링이 필수"라는 경고선으로 이해해야 합니다. Day 51에서 다룬 Profiler의 Rendering 항목으로 실제 기기에서 프레임 타임을 반드시 측정해야 합니다.

```csharp
// VR/AR에서는 오브젝트별 폴리곤 수를 코드로 미리 점검해두는 것이 유용합니다.
using UnityEngine;

public class PolyBudgetChecker : MonoBehaviour
{
    [SerializeField] private int maxTrianglesPerObject = 5000;

    void Start()
    {
        MeshFilter mf = GetComponent<MeshFilter>();
        if (mf != null && mf.sharedMesh != null)
        {
            int triCount = mf.sharedMesh.triangles.Length / 3;
            if (triCount > maxTrianglesPerObject)
            {
                Debug.LogWarning($"{name}: 삼각형 {triCount}개 — 예산({maxTrianglesPerObject}) 초과");
            }
        }
    }
}
```

> 💡 **실무 팁**: VR 컨트롤러로 직접 손에 쥐는 소품(무기, 도구 등)은 눈앞 가까이서 관찰되므로 배경 오브젝트보다 상대적으로 높은 폴리곤 예산을 배정하고, 반대로 먼 배경/장식용 오브젝트는 과감히 낮춰야 전체 예산을 지킬 수 있습니다.

---

## 3. 텍스처와 메모리 — VR/AR 전용 고려사항

Day 52~53에서 다룬 텍스처 압축(ASTC/ETC2)과 아틀라싱은 VR/AR에서 그대로 적용되지만, 몇 가지가 더 추가됩니다.

- **스테레오 렌더링으로 인한 텍스처 대역폭 2배 부담**: 양쪽 눈을 그리는 동안 같은 텍스처를 반복 샘플링하므로, 텍스처 해상도를 무작정 높이면 대역폭 병목이 배로 커집니다. VR용 텍스처는 동일한 시각 품질이라면 일반 모바일 게임보다 한 단계 낮은 해상도(예: 2048 대신 1024)로도 체감 차이가 크지 않은 경우가 많습니다.
- **밉맵(Mipmap) 필수 적용**: VR은 사용자가 머리를 움직이며 다양한 거리에서 오브젝트를 보게 되므로, 밉맵을 끄면 텍스처 앨리어싱(반짝임)이 특히 눈에 띕니다. Import Settings에서 Generate Mip Maps를 반드시 활성화합니다.
- **Fixed Foveated Rendering(FFR) 대응**: Quest 등 일부 기기는 화면 중심부만 고해상도로, 주변부는 저해상도로 렌더링하는 FFR을 지원합니다. FFR을 활용하면 같은 텍스처/폴리곤 예산으로도 체감 품질을 높일 수 있으므로, XR 플러그인 설정에서 Foveation Level을 확인해두는 것이 좋습니다.
- **라이트맵 크기 제한**: Day 38에서 다룬 라이트맵 베이킹은 VR Standalone 기기에서 메모리를 크게 잡아먹습니다. 라이트맵 해상도를 낮추고, Day 53의 Memory Profiler로 라이트맵이 차지하는 메모리를 별도로 점검해야 합니다.

| 항목 | 일반 모바일 권장 | VR Standalone 권장 |
|---|---|---|
| 주요 텍스처 해상도 | 1024~2048 | 512~1024 |
| 밉맵 | 선택적 | 필수 |
| 라이트맵 해상도 | 중간~높음 | 낮음(동적 라이트 병행 고려) |
| 알파 블렌딩(투명) 오브젝트 수 | 제한적 허용 | 최소화(오버드로우가 스테레오로 배가) |

> 💡 **실무 팁**: 반투명(Alpha Blend) 머티리얼은 일반 프로젝트에서도 오버드로우 비용이 크지만, VR에서는 양쪽 눈 렌더링으로 그 비용이 그대로 두 배가 됩니다. 파티클, 이펙트, UI 배경 등에서 반투명 사용을 최소화하고 가능하면 Cutout(알파 테스트) 방식으로 대체하는 것이 좋습니다.

---

## 4. 실제 크기(Real-world Scale)와 상호작용 콜라이더 설계

VR/AR은 일반 화면 게임과 달리 **사용자가 실제 물리적 공간감으로 크기를 인식**합니다. 이 때문에 모델링/임포트 단계에서의 스케일 정확성이 몰입감에 직접적인 영향을 미칩니다.

- **1 유닛 = 1미터 원칙 엄수**: Day 23에서 다룬 Import Scale 설정이 VR/AR에서는 특히 중요합니다. 문 손잡이가 실제보다 크거나 작게 임포트되면, 사용자가 VR 컨트롤러로 손을 뻗었을 때 손과 오브젝트 크기가 어긋나는 위화감(Uncanny Scale)을 즉시 느낍니다.
- **손 상호작용을 고려한 콜라이더 단순화**: XR Interaction Toolkit 등으로 오브젝트를 잡을 때는 시각 메시(Visual Mesh)를 그대로 Mesh Collider로 쓰지 말고, Day 09에서 다룬 것처럼 Box/Capsule/Convex Mesh Collider로 단순화해야 합니다. 특히 Rigidbody가 붙는 그랩 오브젝트는 Convex 옵션이 꺼진 비-Convex Mesh Collider를 사용할 수 없습니다.

```csharp
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class VRGrabbable : MonoBehaviour
{
    void Awake()
    {
        MeshCollider mc = GetComponent<MeshCollider>();
        if (mc != null && !mc.convex)
        {
            // Rigidbody + Mesh Collider 조합은 반드시 Convex가 필요합니다.
            Debug.LogWarning($"{name}: Rigidbody와 함께 쓰는 MeshCollider는 Convex여야 합니다.");
        }
    }
}
```

- **AR에서의 실세계 스케일 매칭**: AR Foundation으로 배치되는 3D 모델은 실제 테이블, 바닥 등의 물리적 크기와 맞아야 하므로, 모델링 단계에서부터 실측 치수를 기준으로 작업하는 것이 필수입니다. 스케일이 어긋나면 아무리 텍스처와 라이팅이 훌륭해도 "합성된 느낌"이 강하게 남습니다.

| 상황 | 권장 콜라이더 |
|---|---|
| 정적 배경 오브젝트(벽, 바닥) | Mesh Collider(비-Convex 가능, Rigidbody 없음) |
| 손으로 잡는 소품(Rigidbody 있음) | Box/Capsule 또는 Convex Mesh Collider |
| 복잡한 형태의 그랩 오브젝트 | 여러 개의 단순 Primitive Collider를 조합(Compound Collider) |

> 💡 **실무 팁**: VR에서 "손에 쥐는 손맛"은 콜라이더의 정밀도보다 오히려 그립 애니메이션과 햅틱 피드백의 타이밍이 좌우하는 경우가 많습니다. 콜라이더는 상호작용이 자연스럽게 "걸리는" 수준으로 단순화하고, 나머지 디테일은 시각/햅틱 연출로 보완하는 편이 성능과 개발 효율 면에서 유리합니다.

---

## 5. AR 특화 고려사항 — Occlusion과 조명 정합

AR은 VR과 달리 실제 카메라 영상 위에 3D 모델을 합성하기 때문에, 3D 모델 자체의 품질과 별개로 "실세계와 얼마나 자연스럽게 섞이는가"가 중요합니다.

- **Occlusion(가려짐) 처리**: 실제 사물(사람의 손, 가구 등)이 AR 오브젝트 앞을 지나갈 때 자연스럽게 가려져야 합니다. AR Foundation의 `AROcclusionManager`를 사용하면 기기의 깊이 센서/ML 기반 깊이 추정값을 활용해 실세계 깊이와 3D 모델의 깊이를 비교, 자동으로 가려짐을 처리할 수 있습니다.
- **Light Estimation(조명 추정)**: 실제 환경의 밝기/색온도를 추정해 3D 모델의 라이팅에 실시간으로 반영해야 위화감이 줄어듭니다. `ARCameraManager.frameReceived` 이벤트로 밝기 정보를 받아 씬의 Directional Light 강도를 동적으로 조정하는 방식이 흔히 쓰입니다.
- **그림자 정합**: AR 모델이 바닥에 그림자를 드리우지 않으면 공중에 떠 있는 듯한 위화감이 생깁니다. Shadow-only 머티리얼(오브젝트 자체는 투명하고 그림자만 렌더링)을 바닥 평면에 적용하는 기법이 자주 사용됩니다.
- **Plane Detection과 모델 스케일 검증**: `ARPlaneManager`로 감지된 실제 평면 크기에 맞춰 모델이 배치되는지 런타임에 검증하는 것이 좋습니다.

```csharp
using UnityEngine;
using UnityEngine.XR.ARFoundation;

public class ARLightSync : MonoBehaviour
{
    [SerializeField] private ARCameraManager cameraManager;
    [SerializeField] private Light directionalLight;

    void OnEnable() => cameraManager.frameReceived += OnFrameReceived;
    void OnDisable() => cameraManager.frameReceived -= OnFrameReceived;

    void OnFrameReceived(ARCameraFrameEventArgs args)
    {
        if (args.lightEstimation.averageBrightness.HasValue)
        {
            directionalLight.intensity = args.lightEstimation.averageBrightness.Value;
        }
        if (args.lightEstimation.colorCorrection.HasValue)
        {
            directionalLight.color = args.lightEstimation.colorCorrection.Value;
        }
    }
}
```

> 💡 **실무 팁**: AR에서는 3D 모델의 폴리곤/텍스처 품질을 아무리 높여도, Occlusion과 그림자가 빠지면 "합성 스티커"처럼 보입니다. 리소스가 제한적이라면 고품질 모델링보다 Occlusion/그림자 정합에 우선 투자하는 것이 체감 품질 향상에 더 효과적입니다.

---

## 📝 핵심 요약

1. VR은 스테레오 렌더링과 고정 프레임레이트(72~120fps) 요구로 인해 일반 모바일 게임보다 훨씬 엄격한 폴리곤/드로우콜 예산이 필요하다
2. 기기별(Quest 2/3, PCVR, 모바일 AR) 폴리곤·드로우콜 예산을 먼저 정하고 그 안에서 모델링해야 하며, 손에 쥐는 오브젝트는 상대적으로 높은 예산을 배정한다
3. VR용 텍스처는 스테레오 대역폭 부담을 고려해 해상도를 낮추고 밉맵을 필수로 적용하며, 반투명 오브젝트는 최소화해야 한다
4. 1 유닛 = 1미터 원칙과 콜라이더 단순화(Convex Mesh Collider 등)는 VR의 몰입감과 상호작용 품질에 직접적인 영향을 준다
5. AR은 Occlusion, Light Estimation, 그림자 정합처럼 3D 모델 자체보다 "실세계와의 정합"이 체감 품질을 좌우하는 경우가 많다

---

## 🔗 참고 자료

- [Unity Manual — XR 성능 최적화](https://docs.unity3d.com/Manual/xr-best-practices.html)
- [Unity AR Foundation 문서 — Occlusion](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@latest/manual/features/occlusion.html)
- [Unity AR Foundation 문서 — Light Estimation](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@latest/manual/features/light-estimation.html)

---

*⬅️ 이전: [Day 53 — 텍스처 아틀라스와 메모리 최적화](../day-53/)  |  다음: [Day 55 — 에셋 파이프라인 자동화 (네이밍 규칙, 임포트 프리셋)](../day-55/) ➡️*
