---
title: "Day 38 — 라이트맵 베이킹과 글로벌 일루미네이션"
date: 2026-09-05
weight: 38
---

> **Phase 6: 환경과 월드 빌딩** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 실시간 조명과 베이크된 조명(Baked Lighting)의 차이와 각각의 장단점을 설명할 수 있다
- Lightmap, Light Probe, Reflection Probe의 역할을 구분하고 씬에 적용할 수 있다
- Progressive Lightmapper 설정값(해상도, 바운스 횟수 등)을 조정해 품질과 베이크 시간을 조절할 수 있다

---

## 1. 왜 조명을 미리 "구워야" 하는가

실시간으로 모든 조명을 계산하면 광원 하나당 매 프레임 그림자와 간접광(Global Illumination, GI)을 다시 계산해야 합니다. 광원이 여러 개, 오브젝트가 복잡할수록 이 연산은 기하급수적으로 무거워집니다.

**라이트맵 베이킹(Lightmap Baking)**은 정적인(움직이지 않는) 오브젝트에 대해 조명 계산을 미리 텍스처(라이트맵)에 구워 저장해 두는 기법입니다. 런타임에는 이 텍스처를 그냥 읽기만 하면 되므로 실시간 연산 비용이 거의 0에 가깝습니다.

| 구분 | Realtime Lighting | Baked Lighting |
|---|---|---|
| 계산 시점 | 매 프레임 | 에디터에서 사전 계산(베이크) |
| 런타임 비용 | 높음 (광원 수·복잡도에 비례) | 매우 낮음 (텍스처 샘플링만) |
| 동적 오브젝트 대응 | 자유로움 | 불가능 (정적 오브젝트 전용) |
| 그림자 품질 | 실시간 근사 | 고품질 간접광 포함 가능 |
| 파일 용량 | 없음 | 라이트맵 텍스처 용량 추가 |

실무에서는 대부분 **Mixed** 모드를 씁니다: 정적 배경은 베이크하고, 캐릭터나 움직이는 오브젝트는 Light Probe로 근사한 간접광을 실시간으로 받습니다.

---

## 2. Global Illumination(GI) 개념 이해하기

GI는 빛이 광원에서 나와 표면에 부딪힌 뒤 **반사되어 다른 표면에 다시 영향을 주는** 간접광(Indirect Light)까지 시뮬레이션하는 것을 말합니다. 직접광(Direct Light)만 계산하면 그림자 영역이 완전히 검게 나오지만, GI가 있으면 빨간 벽 옆 바닥이 은은하게 붉게 물드는 등 현실적인 빛 번짐이 생깁니다.

Unity의 GI 시스템은 크게 두 부분으로 구성됩니다.

- **Realtime GI**: 실시간으로 간접광을 근사 (Enlighten 기반, 최신 Unity에서는 사용 빈도가 줄어드는 추세)
- **Baked GI**: Progressive Lightmapper가 오프라인으로 광선을 추적(Path Tracing 유사 방식)해 정밀한 간접광을 계산 후 라이트맵에 저장

> 💡 **실무 팁**: 모바일이나 저사양 타겟 프로젝트는 Realtime GI를 끄고 Baked GI만 쓰는 것이 성능상 훨씬 유리합니다. Lighting 창에서 `Realtime Global Illumination` 체크를 해제하세요.

---

## 3. Progressive Lightmapper 설정하기

`Window > Rendering > Lighting` 창에서 베이크 관련 설정을 관리합니다.

| 항목 | 설명 |
|---|---|
| Lightmapper | CPU / GPU(Progressive GPU Lightmapper) 선택. GPU가 훨씬 빠름 |
| Direct/Indirect/Environment Samples | 광선 샘플 수. 높을수록 노이즈는 줄지만 베이크 시간 증가 |
| Bounces | 간접광이 몇 번 반사될지 (기본 2~4회면 대부분 충분) |
| Lightmap Resolution | 월드 유닛당 texel 수. 높을수록 디테일↑, 용량·시간↑ |
| Compress Lightmaps | 빌드 용량 절감 (품질 약간 손실) |

베이크 대상이 되려면 오브젝트의 **Static** 체크박스(또는 `Contribute GI`)가 켜져 있어야 합니다. Inspector 우측 상단의 Static 드롭다운에서 `Contribute GI`만 개별적으로 켤 수도 있습니다.

```
Window > Rendering > Lighting > Scene 탭
  - Lightmapper: Progressive GPU (권장)
  - Lightmap Resolution: 40 texels/unit (기본값, 씬 크기에 따라 조정)
  - Max Lightmap Size: 1024 또는 2048
  - Generate Lighting 버튼 클릭 → 베이크 시작
```

> 💡 **실무 팁**: 개발 중에는 `Auto Generate`를 꺼두고 필요할 때만 수동으로 `Generate Lighting`을 누르세요. 자동 베이크는 씬을 조금만 바꿔도 계속 재계산되어 에디터 작업 속도를 크게 떨어뜨립니다.

---

## 4. Light Probe와 Reflection Probe

라이트맵은 **정적** 오브젝트 표면에만 적용됩니다. 그렇다면 그 위를 걸어 다니는 캐릭터는 어떻게 주변 조명(간접광)의 영향을 받을까요? 이때 쓰는 것이 **Light Probe**입니다.

- **Light Probe**: 씬의 특정 지점들에서 주변 조명 정보(구면 조화 함수, Spherical Harmonics)를 샘플링해 저장. 동적 오브젝트가 이 사이를 이동하면 가장 가까운 프로브들을 보간해 간접광을 근사
- **Light Probe Group**: `GameObject > Light > Light Probe Group`으로 생성, 조명 변화가 큰 영역(그늘과 양지의 경계 등)에 밀도를 높여 배치

**Reflection Probe**는 광원이 아니라 주변 환경을 큐브맵으로 캡처해 금속/유리 등 반사 재질에 주변 환경이 비치도록 해줍니다.

- `GameObject > Light > Reflection Probe`로 생성
- Type을 `Baked`로 두면 정적 환경을 한 번만 캡처, `Realtime`으로 두면 매 프레임 갱신(비용 높음)

> 캐릭터가 라이트맵이 적용된 바닥 위에 서 있는데 그림자 안에서도 이상하게 밝다면, Light Probe가 배치되지 않았거나 밀도가 낮은 경우가 많습니다.

---

## 5. 베이크 결과 확인과 트러블슈팅

베이크가 끝나면 씬 뷰에서 바로 결과를 확인할 수 있고, `Window > Rendering > Lighting > Environment` 탭에서 라이트맵 텍스처 목록을 볼 수 있습니다.

자주 겪는 문제와 해결법을 정리하면 다음과 같습니다.

- **UV 겹침으로 인한 얼룩(Seams/Bleeding)**: 라이트맵은 별도의 UV 채널(UV2)을 사용합니다. Import Settings에서 `Generate Lightmap UVs`를 켜거나, Blender에서 직접 두 번째 UV를 언랩해 겹침을 없애야 합니다 (Day 18 참고)
- **베이크 시간이 너무 오래 걸림**: Lightmap Resolution을 낮추거나 Sample 수를 줄이고, Progressive GPU Lightmapper로 전환
- **그림자 경계가 지저분함**: `Filtering` 설정에서 디노이저(Denoising) 옵션을 켜거나 Sample 수를 늘림
- **간접광이 안 보임**: 오브젝트의 `Contribute GI`가 꺼져 있거나, Directional Light의 Mode가 `Realtime`으로만 설정된 경우

> 💡 **실무 팁**: 라이트맵 관련 문제의 8할은 UV2 세팅 문제입니다. 이상한 얼룩이나 아티팩트가 보이면 가장 먼저 Model Import Settings의 Lightmap UV 옵션부터 의심하세요.

---

## 📝 핵심 요약

1. 라이트맵 베이킹은 정적 오브젝트의 조명을 미리 계산해 텍스처로 저장, 런타임 비용을 크게 줄이는 기법이다
2. Global Illumination은 직접광뿐 아니라 반사되는 간접광까지 시뮬레이션해 현실적인 빛 번짐을 만든다
3. Progressive Lightmapper의 Sample 수, Bounces, Resolution 설정이 베이크 품질과 시간을 결정한다
4. Light Probe는 동적 오브젝트에 간접광을, Reflection Probe는 반사 재질에 주변 환경을 제공한다
5. 라이트맵 아티팩트 대부분은 UV2(Lightmap UV) 세팅 문제이므로 가장 먼저 점검해야 한다

---

## 🔗 참고 자료

- [Unity Manual - Lightmapping](https://docs.unity3d.com/Manual/Lightmapping.html)
- [Unity Manual - Light Probes](https://docs.unity3d.com/Manual/LightProbes.html)
- [Unity Manual - Reflection Probes](https://docs.unity3d.com/Manual/ReflectionProbes.html)

---

*⬅️ 이전: [Day 37 — 모듈형(Modular) 3D 에셋으로 레벨 디자인](../day-37/)  |  다음: [Day 39 — 스카이박스와 환경 분위기 연출](../day-39/) ➡️*
