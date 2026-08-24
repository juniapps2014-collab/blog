---
title: "Day 25 — URP(Universal Render Pipeline) 기초"
date: 2026-08-24
weight: 25
---

> **Phase 4: 3D 모델을 Unity로 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Built-in RP와 URP의 렌더링 구조 차이를 설명하고, 언제 URP를 선택해야 하는지 판단할 수 있다
- URP 프로젝트를 구성하는 핵심 애셋(URP Asset, Renderer Data)의 역할을 이해하고 품질 설정을 조정할 수 있다
- Lit/Simple Lit/Unlit 셰이더의 차이를 이해하고, Day 24에서 재구성한 머티리얼을 URP Lit로 올바르게 전환할 수 있다

---

## 1. Built-in RP에서 URP로 — 왜 파이프라인이 여러 개인가

Unity는 하나의 고정된 렌더링 방식을 쓰지 않습니다. Scriptable Render Pipeline(SRP)이라는 프레임워크 위에 목적이 다른 세 가지 파이프라인을 제공합니다.

| 파이프라인 | 특징 | 주 대상 |
|---|---|---|
| Built-in RP | Unity 초창기부터 존재한 고정 파이프라인, 커스터마이징 어려움 | 레거시 프로젝트 |
| URP (Universal RP) | 성능과 비주얼 품질의 균형, 모바일부터 콘솔까지 폭넓게 지원 | 대부분의 신규 프로젝트 |
| HDRP (High Definition RP) | 실사에 가까운 고품질 렌더링, 연산 비용이 큼 | PC/콘솔 고사양 타이틀 |

URP는 "적은 Draw Call, 적은 셰이더 변형(variant)"을 목표로 설계된 파이프라인입니다. Built-in RP는 렌더링 로직이 C++로 하드코딩되어 있어 수정이 거의 불가능했지만, URP는 렌더링 과정 자체가 `ScriptableRenderer`라는 C# 코드로 노출되어 있어 필요하면 렌더 패스를 직접 추가하거나 뺄 수 있습니다.

Day 22~24에서 다룬 Import/Material 워크플로우는 파이프라인과 무관하게 동일하지만, **머티리얼에 적용되는 셰이더**는 파이프라인마다 다릅니다. Built-in RP용 `Standard` 셰이더로 만든 머티리얼은 URP 프로젝트에서 마젠타(분홍색)로 깨져 보이는데, 이는 URP가 Built-in 셰이더를 렌더링할 방법을 모르기 때문입니다.

> 💡 **실무 팁**: 프로젝트 시작 시점에 파이프라인을 정하는 것이 중요합니다. Built-in으로 어느 정도 진행한 뒤 URP로 전환하는 것도 가능은 하지만(Edit → Render Pipeline → Universal Render Pipeline → Upgrade), 커스텀 셰이더나 서드파티 에셋이 많을수록 마이그레이션 비용이 커집니다.

---

## 2. URP를 구성하는 핵심 애셋

URP는 두 종류의 애셋 파일로 렌더링 동작을 제어합니다.

| 애셋 | 역할 |
|---|---|
| Universal Render Pipeline Asset | 그림자 거리, 안티앨리어싱, HDR, 그림자 캐스케이드 등 전역 품질 설정 |
| Universal Renderer Data | 실제 렌더링 순서(Renderer Feature), 렌더링 레이어, 후처리 연결 방식 |

프로젝트 생성 시 URP 템플릿을 선택하면 두 애셋이 자동 생성되고, `Edit → Project Settings → Graphics`의 `Scriptable Render Pipeline Settings` 슬롯에 등록됩니다. 이 슬롯이 비어 있으면 URP 셰이더가 있어도 Built-in RP로 렌더링을 시도해 다시 마젠타 문제가 발생합니다.

```
Project Settings → Graphics → Scriptable Render Pipeline Settings
→ URP Asset 드래그 앤 드롭

Project Settings → Quality → 각 품질 레벨(Low/Medium/High)마다
→ Render Pipeline Asset을 개별 지정 가능 (플랫폼별 품질 분기에 활용)
```

URP Asset의 주요 설정 항목:

| 설정 | 설명 |
|---|---|
| Rendering Path | Forward / Forward+ (Unity 6 기준, 다수 라이트를 더 효율적으로 처리) |
| HDR | High Dynamic Range 렌더링 활성화 여부 |
| Shadow Distance | 그림자가 렌더링되는 최대 거리, 값이 클수록 성능 비용 증가 |
| Shadow Cascades | 그림자 해상도를 거리별로 나누는 단계 수 |
| Anti Aliasing (MSAA) | 계단 현상 완화, 모바일에서는 2x~4x가 일반적 |

> 💡 **실무 팁**: 모바일과 PC를 동시에 타겟팅한다면 URP Asset을 플랫폼별로 복제해(`URP-Mobile`, `URP-PC`) Quality 설정에서 각각 연결하는 방식이 흔합니다. 그림자 거리, MSAA, Renderer Feature 개수를 플랫폼에 맞게 다르게 가져갈 수 있습니다.

---

## 3. Lit / Simple Lit / Unlit — URP 셰이더 선택하기

URP는 목적에 따라 세 가지 기본 셰이더를 제공합니다. Day 24에서 다룬 Blender → Unity 머티리얼 재구성 작업의 최종 목적지가 바로 이 셰이더들입니다.

| 셰이더 | 라이팅 모델 | 사용 사례 |
|---|---|---|
| Lit | PBR (Metallic/Specular Workflow) | 대부분의 3D 오브젝트, 사실적인 표면 표현이 필요할 때 |
| Simple Lit | Blinn-Phong (단순화된 라이팅) | 모바일 등 저사양 기기, PBR 연산 비용을 줄이고 싶을 때 |
| Unlit | 라이팅 계산 없음 | UI, 이펙트, 발광 오브젝트처럼 조명 영향을 받지 않아야 하는 표면 |

`Lit` 셰이더의 주요 슬롯은 Day 24에서 정리한 Blender ↔ Unity 대응표와 그대로 이어집니다.

```
Lit 셰이더 Surface Inputs
- Base Map (+ Color 틴트)
- Metallic Map / Smoothness (Metallic Alpha 또는 Albedo Alpha에서 소스 선택)
- Normal Map
- Emission Map
- Occlusion Map (AO)

Surface Options
- Surface Type: Opaque / Transparent
- Render Face: Front / Back / Both (양면 렌더링 필요 시 Both)
- Alpha Clipping: 마스크 텍스처로 잘라내기(나뭇잎, 울타리 등)에 사용
```

Built-in `Standard` 셰이더로 만들어진 머티리얼을 URP로 옮길 때는 셰이더 드롭다운에서 `Universal Render Pipeline/Lit`으로 직접 바꾸거나, `Edit → Rendering → Materials → Convert Selected Built-in Materials to URP` 메뉴로 일괄 변환할 수 있습니다. 단, 이 자동 변환은 텍스처 슬롯 매핑까지는 처리하지만 Roughness/Smoothness 반전 같은 값 보정은 해주지 않으므로 Day 24에서 다룬 수동 검증이 여전히 필요합니다.

> 💡 **실무 팁**: 모바일 프로젝트에서 프레임이 안 나올 때 가장 먼저 시도해볼 만한 것이 오브젝트 셰이더를 `Lit`에서 `Simple Lit`으로 바꾸는 것입니다. PBR 연산(다중 반사, 정밀 스페큘러 계산)을 생략하는 대신 시각적 손실은 비교적 적습니다.

---

## 4. Renderer Feature — 렌더링 파이프라인에 기능 끼워넣기

URP의 가장 큰 장점은 `Universal Renderer Data` 애셋에 `Renderer Feature`를 추가해 렌더링 파이프라인 중간에 커스텀 동작을 끼워 넣을 수 있다는 점입니다. Built-in RP에서는 이런 작업이 사실상 불가능했습니다.

```
Universal Renderer Data 애셋 선택
→ Inspector 하단 Add Renderer Feature 버튼
→ 목록에서 선택 (예: Render Objects, Decal, Screen Space Ambient Occlusion)
```

대표적인 Renderer Feature:

| Feature | 용도 |
|---|---|
| Render Objects | 특정 레이어의 오브젝트만 별도 패스로 다시 렌더링(아웃라인, X-ray 효과 등) |
| Screen Space Ambient Occlusion (SSAO) | 오브젝트 사이 접힌 부분에 자연스러운 음영 추가 |
| Decal | 노멀을 따라 투영되는 데칼(총알 자국, 얼룩 등) |
| Full Screen Pass | 화면 전체에 커스텀 셰이더 이펙트 적용(포스트 프로세싱 기초) |

Post-processing(Day 41에서 다룰 Bloom, Color Grading 등)도 이 Renderer Feature 시스템 위에서 동작합니다. `Global Volume` 오브젝트에 Volume Profile을 연결하고, Renderer Data에서 Post Processing이 활성화되어 있어야 효과가 적용됩니다.

> 💡 **실무 팁**: Renderer Feature를 많이 추가할수록 프레임당 렌더 패스 수가 늘어 성능에 영향을 줍니다. 특히 모바일 타겟에서는 SSAO 같은 화면 공간 이펙트는 비용이 크므로, 꼭 필요한 것만 남기고 Profiler(Day 51)로 실제 비용을 확인하는 습관이 중요합니다.

---

## 📝 핵심 요약

1. URP는 Built-in RP와 달리 렌더링 로직이 C#으로 노출된 Scriptable Render Pipeline으로, 성능과 커스터마이징 유연성의 균형을 맞춘 파이프라인이다
2. `Universal Render Pipeline Asset`(전역 품질 설정)과 `Universal Renderer Data`(렌더 패스 구성)가 URP 프로젝트의 핵심 애셋이며, Graphics/Quality 설정에 반드시 등록되어야 한다
3. Lit(PBR)/Simple Lit(Blinn-Phong)/Unlit 세 셰이더 중 대상 플랫폼과 시각적 요구 수준에 맞는 것을 선택하며, Built-in Standard 머티리얼은 자동 변환 후에도 Day 24식 수동 검증이 필요하다
4. Renderer Feature를 통해 아웃라인, SSAO, 데칼, 포스트 프로세싱 같은 기능을 파이프라인 중간에 끼워 넣을 수 있지만, 개수가 늘수록 성능 비용도 함께 늘어난다

---

## 🔗 참고 자료

- [Unity Manual — Universal Render Pipeline overview](https://docs.unity3d.com/Manual/urp/urp-introduction.html)
- [Unity Manual — Render Pipeline Converter](https://docs.unity3d.com/Manual/urp/features/rp-converter.html)
- [Unity Manual — Renderer Feature](https://docs.unity3d.com/Manual/urp/urp-renderer-feature.html)

---

*⬅️ 이전: [Day 24 — Material 재구성 - Blender to Unity 워크플로우](../day-24/)  |  다음: [Day 26 — PBR(Physically Based Rendering) 텍스처링 워크플로우](../day-26/) ➡️*
