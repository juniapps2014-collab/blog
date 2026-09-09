---
title: "Day 42 — 6주차 정리: 작은 환경 씬 완성"
date: 2026-09-09
weight: 42
---

> **Phase 6: 환경과 월드 빌딩** | 예상 학습 시간: 45분

---

## 🎯 학습 목표

- Terrain, 모듈형 에셋, 라이트맵, 스카이박스, 파티클, 포스트 프로세싱을 하나의 씬에 통합해 완성할 수 있다
- 작은 환경 씬을 만들 때 작업 순서(레이아웃 → 라이팅 → 디테일 → 후처리)를 스스로 설계할 수 있다
- 6주차에서 배운 각 시스템이 최종 비주얼에 기여하는 역할을 설명할 수 있다

---

## 1. 6주차 복습 — 무엇을 배웠나

Phase 6에서는 "빈 씬을 실제로 걸어 다닐 수 있는 작은 환경"으로 만드는 데 필요한 시스템들을 순서대로 다뤘습니다.

| Day | 주제 | 씬에서의 역할 |
|---|---|---|
| 36 | Terrain 시스템 | 지형의 큰 형태(언덕, 평지, 경사) |
| 37 | 모듈형 3D 에셋 레벨 디자인 | 건물, 통로 등 구조물 배치 |
| 38 | 라이트맵 베이킹 & GI | 정적 오브젝트의 사실적인 그림자/반사광 |
| 39 | 스카이박스 & 환경 분위기 | 하늘, 전역 조명 색감, 안개 |
| 40 | Particle System | 먼지, 안개 파티클, 물 튀김 등 동적 디테일 |
| 41 | Post-processing | 최종 색보정, Bloom, Vignette로 완성도 마무리 |

이 순서 자체가 실무에서 환경 씬을 만드는 표준 파이프라인과 거의 일치합니다: **큰 형태 → 구조물 → 정적 라이팅 → 분위기 → 동적 디테일 → 후처리**.

---

## 2. 실습 — 작은 환경 씬 만들기 (체크리스트)

오늘은 새 개념을 배우는 대신, 지금까지 배운 걸 하나의 씬에 통합하는 실습을 진행합니다. 아래 체크리스트를 순서대로 따라가며 작은 씬(예: "숲속 공터의 폐허" 또는 "사막의 오아시스")을 완성해 보세요.

**1단계 — 레이아웃 (Day 36-37)**

- [ ] Terrain 도구로 기본 지형 스컬핑 (언덕 1~2개, 평평한 중심 공간 확보)
- [ ] Terrain Layer로 최소 2종 텍스처 블렌딩 (예: 잔디 + 흙길)
- [ ] 모듈형 프리팹으로 랜드마크가 될 구조물 1~2개 배치 (폐허, 오두막 등)

**2단계 — 정적 라이팅 (Day 38)**

- [ ] 구조물과 지형을 `Static`으로 표시
- [ ] Directional Light를 원하는 시간대(새벽/노을 등) 각도로 조정
- [ ] Lightmapping 베이크 실행 후 그림자/AO 결과 확인

**3단계 — 분위기 (Day 39)**

- [ ] Skybox Material 교체 또는 Procedural Skybox 파라미터 조정
- [ ] Lighting 창에서 Environment Lighting(Ambient) 색상을 스카이박스와 어울리게 조정
- [ ] Fog를 켜서 원경에 자연스러운 depth감 추가

**4단계 — 동적 디테일 (Day 40)**

- [ ] 최소 1개의 Particle System 배치 (먼지 부유, 반딧불이, 폭포 물보라 등)
- [ ] Emission Rate와 Lifetime을 씬 규모에 맞게 조정 (과하면 프레임 드랍)

**5단계 — 후처리 마무리 (Day 41)**

- [ ] Global Volume(URP) 생성 후 Color Adjustments, Bloom, Vignette 추가
- [ ] Tonemapping(ACES 권장)으로 노출 정리
- [ ] 최종적으로 Game 뷰에서 카메라 앵글 1~2곳을 정해 스크린샷 캡처

```
씬 계층 구조 예시
Scene
├── Terrain
├── Directional Light (Static 라이팅 소스)
├── Structures (Static)
│   ├── Ruin_Wall_01
│   └── Ruin_Pillar_02
├── Effects
│   └── DustMotes (Particle System)
├── Global Volume (Post-processing)
└── Main Camera
```

> 💡 **실무 팁**: 처음부터 완벽하게 만들려 하지 말고, 5단계를 "러프하게 1바퀴" 먼저 완주한 뒤 다시 처음부터 디테일을 올리는 반복(iteration) 방식이 훨씬 빠릅니다. 특히 라이팅은 구조물 배치가 끝나기 전까지 미리 다듬어도 다시 베이크해야 하므로, 레이아웃을 먼저 고정하세요.

---

## 3. 흔한 실수와 점검 포인트

- **Static 표시 누락**: 라이트맵이 이상하게 나온다면 가장 먼저 오브젝트의 `Lightmap Static` 체크 여부를 확인하세요.
- **파티클 과다 배치**: 파티클 시스템을 여러 개 겹쳐 배치하면 모바일/저사양 기기에서 프레임이 급격히 떨어집니다. Day 52(모바일 최적화)에서 더 다룰 예정이니 지금은 개수를 최소화하세요.
- **후처리 과적용**: Bloom Intensity나 Vignette를 과하게 넣으면 오히려 디테일이 뭉개집니다. 적용 전/후를 토글하며 비교하는 습관을 들이세요.
- **안개(Fog) 색상 불일치**: Fog 색상이 스카이박스 색상과 다르면 원경과 하늘의 경계가 부자연스럽게 보입니다. Lighting 설정에서 Fog Color를 스카이박스 지평선 색과 맞추세요.

---

## 📝 핵심 요약

1. 환경 씬 제작은 "큰 형태 → 구조물 → 정적 라이팅 → 분위기 → 동적 디테일 → 후처리" 순서로 진행하는 것이 효율적이다
2. Terrain과 모듈형 에셋으로 레이아웃을 먼저 확정한 뒤에 라이트맵을 베이크해야 재작업을 줄일 수 있다
3. 스카이박스, Ambient Light, Fog는 서로 색상을 맞춰야 자연스러운 분위기가 만들어진다
4. 파티클과 후처리는 "적당히"가 핵심 — 과하면 성능과 비주얼 모두 손해를 본다
5. 완벽을 추구하기보다 전체 파이프라인을 러프하게 1바퀴 완주하고 디테일을 반복적으로 올리는 방식이 실무적이다

---

## 🔗 참고 자료

- [Unity Manual — Lighting](https://docs.unity3d.com/Manual/Lighting.html)
- [Unity Manual — Terrain Engine Guide](https://docs.unity3d.com/Manual/script-Terrain.html)
- [Unity Manual — Post-processing (URP)](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest/manual/EffectList.html)

---

*⬅️ 이전: [Day 41 — Post-processing으로 비주얼 완성도 높이기](../day-41/)  |  다음: [Day 43 — Shader Graph 기초 개념](../day-43/) ➡️*
