---
title: "Day 50 — Draw Call과 배칭(Batching) 이해하기"
date: 2026-09-18
weight: 50
---

> **Phase 8: 최적화와 실전 워크플로우** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Draw Call이 무엇이고 왜 많아지면 성능이 떨어지는지 GPU 파이프라인 관점에서 설명할 수 있다
- Static Batching과 Dynamic Batching, SRP Batcher, GPU Instancing의 차이를 구분하고 각각이 적용되는 조건을 알 수 있다
- Frame Debugger로 실제 씬의 Draw Call과 배칭 여부를 직접 확인할 수 있다

---

## 1. Draw Call이란 무엇인가

Draw Call은 CPU가 GPU에게 "이 메시를 이 머티리얼로 그려줘"라고 내리는 명령 한 건을 말합니다. 씬에 오브젝트가 100개 있고 모두 다른 머티리얼을 쓴다면, 이론상 CPU는 100번의 Draw Call을 GPU에 전달해야 합니다.

문제는 Draw Call 자체가 GPU 렌더링 부하가 아니라 **CPU→GPU 통신 오버헤드**라는 점입니다. Draw Call 하나를 준비할 때마다 CPU는 상태 전환(머티리얼, 셰이더, 텍스처, 버퍼 바인딩 등)을 GPU 드라이버에 전달해야 하고, 이 과정이 누적되면 GPU가 놀고 있어도 CPU가 병목이 되는 "CPU-bound" 상황이 발생합니다. 특히 모바일처럼 드라이버 오버헤드가 큰 환경에서는 Draw Call 수가 프레임레이트에 직접적인 영향을 미칩니다.

| 상황 | 병목 지점 |
|---|---|
| Draw Call이 많고 폴리곤 수는 적음 | CPU (드라이버 오버헤드) |
| Draw Call은 적지만 셰이더 연산이 복잡함 | GPU (프래그먼트 셰이더) |
| 텍스처 해상도가 과도하게 큼 | GPU (메모리 대역폭) |

> 💡 **실무 팁**: "폴리곤 수를 줄이면 최적화된다"는 생각은 절반만 맞습니다. 모바일/저사양 환경에서는 폴리곤 수보다 Draw Call 수와 오버드로우(Overdraw)가 체감 성능에 더 큰 영향을 주는 경우가 많습니다.

---

## 2. Batching의 원리 — 여러 오브젝트를 하나의 Draw Call로

배칭(Batching)은 여러 오브젝트를 하나의 Draw Call로 묶어 CPU 오버헤드를 줄이는 기법입니다. Unity는 크게 네 가지 배칭 방식을 제공합니다.

### 2-1. Static Batching

- 절대 움직이지 않는 오브젝트(건물, 지형 소품 등)를 Inspector에서 `Static` 체크박스로 표시하면, Unity가 빌드 시점에 이들을 하나의 큰 메시로 미리 합칩니다.
- 같은 머티리얼을 공유해야 배칭 대상이 됩니다. 머티리얼이 다르면 여전히 별도 Draw Call로 처리됩니다.
- 장점: 런타임 CPU 비용이 거의 없음(빌드 타임에 미리 계산). 단점: 메모리 사용량 증가(정점 데이터가 중복 저장됨), 움직이면 안 됨.

```
Inspector → GameObject 선택 → 우측 상단 "Static" 체크박스 활성화
(또는 Static 드롭다운에서 "Batching Static"만 개별 선택 가능)
```

### 2-2. Dynamic Batching

- 움직이는 오브젝트 중 정점 수가 적은(약 300 vertex attribute 이하) 것들을 매 프레임 CPU가 실시간으로 병합합니다.
- 조건이 까다롭습니다: 같은 머티리얼, 동일한 셰이더 변형, 균일 스케일(non-uniform scale 불가) 등을 모두 만족해야 합니다.
- 최신 Unity 버전(URP 사용 시)에서는 SRP Batcher가 이 역할을 대체하는 경우가 많아, Dynamic Batching의 중요도는 예전보다 낮아졌습니다.

### 2-3. SRP Batcher (URP/HDRP 전용)

- Universal Render Pipeline에서 기본으로 제공하는 배칭 방식으로, 오브젝트를 하나로 합치는 대신 "머티리얼이 같은 오브젝트들의 GPU 상태 전환 비용"을 줄입니다.
- Draw Call 수 자체는 줄지 않을 수 있지만, 각 Draw Call 사이의 CPU 셋업 비용이 크게 감소합니다.
- 활성화 조건: 셰이더가 SRP Batcher를 지원해야 하며(Shader Graph로 만든 URP 셰이더는 기본 지원), `MaterialPropertyBlock`으로 개별 오브젝트 속성을 덮어쓰면 SRP Batcher가 깨질 수 있으니 주의가 필요합니다.

```
Project Settings → Graphics → Universal Render Pipeline Asset
→ SRP Batcher 옵션이 기본적으로 활성화되어 있는지 확인
```

### 2-4. GPU Instancing

- 완전히 동일한 메시+머티리얼을 가진 오브젝트를 대량으로(수풀, 돌, 군중 등) 그릴 때 사용합니다.
- 셰이더에 `#pragma multi_compile_instancing`을 추가하고 머티리얼 Inspector에서 "Enable GPU Instancing"을 체크하면, 각 인스턴스의 Transform 정보만 GPU에 배열로 전달해 단 한 번의 Draw Call로 수백~수천 개를 그립니다.

```csharp
Graphics.DrawMeshInstanced(mesh, 0, material, matrices, matrices.Length);
```

| 배칭 방식 | 적용 대상 | 오브젝트 이동 | 머티리얼 조건 |
|---|---|---|---|
| Static Batching | 정적 오브젝트 | 불가 | 동일 머티리얼 |
| Dynamic Batching | 저폴리곤 동적 오브젝트 | 가능 | 동일 머티리얼, 균일 스케일 |
| SRP Batcher | URP/HDRP 전반 | 가능 | SRP Batcher 호환 셰이더 |
| GPU Instancing | 동일 메시 대량 반복 | 가능 | 동일 메시+머티리얼 |

---

## 3. Frame Debugger로 실제 Draw Call 확인하기

이론만으로는 내 씬이 실제로 배칭되고 있는지 알 수 없습니다. Unity의 Frame Debugger를 사용하면 프레임 하나가 렌더링되는 과정을 Draw Call 단위로 하나씩 재생해볼 수 있습니다.

```
Window → Analysis → Frame Debugger → Enable 클릭
→ 좌측 목록에서 각 Draw Call을 순서대로 클릭하며 확인
→ "Batch Cause" 항목에서 배칭이 되었는지, 안 됐다면 왜 안 됐는지 사유 확인 가능
```

Frame Debugger 좌측 트리에서 각 항목을 클릭하면 우측에 그 시점까지 렌더링된 화면이 표시되고, 하단에 "Why this draw call can't be batched with the previous one" 같은 사유가 나타나는 경우도 있어 배칭 실패 원인을 직접 추적할 수 있습니다. 대표적인 배칭 실패 사유는 다음과 같습니다.

- 서로 다른 머티리얼 인스턴스 참조 (같은 셰이더라도 인스턴스가 다르면 실패)
- `MaterialPropertyBlock`으로 개별 속성을 덮어씀 (SRP Batcher 대상에서 제외됨)
- 정렬 순서상 사이에 다른 렌더 큐의 오브젝트가 끼어듦(불투명→투명 전환 등)
- 서로 다른 라이트맵 인덱스를 사용하는 정적 오브젝트

> 💡 **실무 팁**: Frame Debugger는 에디터 재생 모드에서만 정확히 동작합니다. 실제 타깃 기기(모바일 등)의 수치는 Unity Profiler의 "Rendering" 모듈이나 플랫폼 전용 프로파일러(Xcode Instruments, Android GPU Inspector)로 별도 확인해야 합니다.

---

## 📝 핵심 요약

1. Draw Call은 GPU 렌더링 자체보다 CPU→GPU 상태 전환 오버헤드에 가까우며, 많아지면 GPU가 놀아도 프레임이 떨어지는 CPU 병목이 발생한다
2. Static Batching은 빌드 타임에 정적 오브젝트를 병합하고, Dynamic Batching은 저폴리곤 동적 오브젝트를 런타임에 병합하지만 둘 다 동일 머티리얼 조건이 필요하다
3. URP를 사용한다면 SRP Batcher가 기본 최적화 수단이며, MaterialPropertyBlock 남용은 SRP Batcher를 깨뜨릴 수 있다
4. 동일한 메시를 대량 반복해서 그릴 때는 GPU Instancing이 가장 효율적이다
5. Frame Debugger로 실제 씬의 Draw Call과 배칭 실패 사유를 직접 확인하는 습관이 최적화의 출발점이다

---

## 🔗 참고 자료

- [Unity Manual — Draw Call Batching](https://docs.unity3d.com/Manual/DrawCallBatching.html)
- [Unity Manual — Frame Debugger](https://docs.unity3d.com/Manual/frame-debugger-window.html)
- [Unity Manual — GPU Instancing](https://docs.unity3d.com/Manual/GPUInstancing.html)

---

*⬅️ 이전: [Day 49 — 7주차 정리: 연출이 들어간 인터랙션 씬 제작](../day-49/)  |  다음: [Day 51 — Profiler로 성능 분석하기](../day-51/) ➡️*
