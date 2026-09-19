---
title: "Day 51 — Profiler로 성능 분석하기"
date: 2026-09-19
weight: 51
---

> **Phase 8: 최적화와 실전 워크플로우** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Unity Profiler의 CPU/GPU/Memory/Rendering 모듈을 각각 언제, 왜 봐야 하는지 설명할 수 있다
- CPU 타임라인에서 병목이 메인 스레드인지 렌더 스레드인지 구분할 수 있다
- Deep Profile과 Development Build를 활용해 실제 타깃 기기에서 원격 프로파일링을 할 수 있다

---

## 1. Profiler를 왜 "감"이 아니라 데이터로 봐야 하는가

Day 50에서 Draw Call과 배칭을 다뤘지만, 실제로 내 씬의 병목이 Draw Call인지, 스크립트 로직인지, 물리 연산인지, 아니면 텍스처 메모리인지는 눈으로 봐서 알 수 없습니다. "느린 것 같다"는 감각으로 최적화를 시작하면 엉뚱한 부분(예: 폴리곤 수)을 줄이고도 프레임레이트가 그대로인 경우가 흔합니다.

Unity Profiler(`Window → Analysis → Profiler`)는 프레임 단위로 CPU, GPU, 메모리, 렌더링, 오디오, 물리 등 각 시스템이 실제로 얼마의 시간과 자원을 쓰는지 정량적으로 보여줍니다. 최적화의 첫 단계는 항상 "무엇이 병목인가"를 Profiler로 먼저 확인하는 것입니다.

| 증상 | 먼저 확인할 모듈 |
|---|---|
| 프레임레이트가 전반적으로 낮음 | CPU Usage 모듈에서 메인 스레드 시간 분포 |
| 특정 순간만 스터터(끊김) 발생 | CPU 모듈의 GC Alloc 스파이크, Physics 스파이크 |
| 모바일에서 발열/배터리 소모가 큼 | GPU Usage, Rendering 모듈 |
| 시간이 지날수록 느려짐 | Memory 모듈의 메모리 증가 추세(메모리 누수 의심) |

> 💡 **실무 팁**: Profiler를 열기 전에 먼저 Stats 창(Game 뷰 우측 상단 "Stats")으로 FPS, Draw Call, 배치 수 같은 요약 지표를 빠르게 훑는 습관을 들이면, Profiler에서 어느 모듈을 집중적으로 볼지 방향을 빨리 잡을 수 있습니다.

---

## 2. CPU Usage 모듈 — 메인 스레드 타임라인 읽기

CPU Usage 모듈은 프레임마다 각 스레드(메인 스레드, 렌더 스레드, 워커 스레드)가 무엇을 하는 데 시간을 썼는지 계층적 타임라인으로 보여줍니다.

```
Window → Analysis → Profiler → CPU Usage 클릭
→ 하단에 특정 프레임 클릭 → Timeline 뷰에서 각 스레드별 막대 확인
→ "Hierarchy" 뷰로 전환하면 함수 호출별 누적 시간을 표(정렬 가능)로 확인
```

타임라인에서 자주 마주치는 구간은 다음과 같습니다.

- **PlayerLoop**: `Update()`, `FixedUpdate()`, `LateUpdate()` 등 스크립트 콜백이 실행되는 구간
- **Rendering**: 메인 스레드가 렌더 커맨드를 준비해 렌더 스레드로 넘기는 구간 (실제 GPU 렌더링과는 별개)
- **Physics**: `FixedUpdate` 주기의 물리 시뮬레이션 스텝
- **GC.Collect / GC.Alloc**: 가비지 컬렉션 관련 스파이크 — 이 구간이 자주 튀면 런타임에 불필요한 할당(예: `Update()` 안에서 `new` 사용, `string` 연결)이 있다는 신호

```csharp
// Update()에서 매 프레임 할당이 일어나는 흔한 실수
void Update()
{
    string status = "HP: " + hp.ToString(); // 매 프레임 문자열 할당 → GC 압박
}

// 개선: StringBuilder 재사용 또는 값이 바뀔 때만 갱신
void Update()
{
    if (hp != lastHp)
    {
        statusBuilder.Clear().Append("HP: ").Append(hp);
        lastHp = hp;
    }
}
```

> 💡 **실무 팁**: Hierarchy 뷰에서 "Self" 시간과 "Total" 시간을 구분해서 봐야 합니다. Total은 자식 호출까지 합산된 값이라, 실제 병목 함수는 Self 시간이 큰 항목을 찾아야 정확합니다.

---

## 3. Deep Profile — 모든 함수 호출까지 추적하기

기본 Profiler는 일부 메서드에만 계측 코드가 있어, 커스텀 스크립트 내부의 세부 함수까지는 보이지 않을 때가 있습니다. Deep Profile을 켜면 스크립팅 런타임의 거의 모든 함수 호출을 계측해서 보여줍니다.

```
Profiler 창 상단 툴바 → "Deep Profile" 체크박스 활성화 → Play 버튼으로 재생
```

- 장점: 어떤 커스텀 메서드가 정확히 몇 밀리초를 쓰는지까지 추적 가능
- 단점: 계측 오버헤드 자체가 매우 커서(실제 실행보다 몇 배 느려짐) **절대적인 시간 값을 신뢰하면 안 되고, 상대적인 비중(어떤 함수가 다른 함수보다 얼마나 더 무거운가)만 참고**해야 함
- 대형 프로젝트에서는 메모리 사용량이 급증해 에디터가 멈추거나 크래시할 수 있으므로, 문제가 의심되는 특정 씬/구간만 짧게 켜서 확인하는 것이 안전합니다

> 💡 **실무 팁**: Deep Profile은 "어디를 봐야 할지 감이 전혀 없을 때" 넓게 훑는 용도로 쓰고, 일단 의심 구간을 찾으면 끄고 일반 Profiler로 다시 정밀하게 확인하는 순서가 효율적입니다.

---

## 4. Development Build + 원격 프로파일링으로 실제 기기 측정하기

에디터에서 측정한 성능은 실제 빌드, 특히 모바일 기기의 성능과 크게 다를 수 있습니다. 에디터는 자체 오버헤드(에디터 UI, 추가 검증 로직)가 있어 항상 실제 빌드보다 느리게 나오고, 반대로 PC의 강력한 GPU/CPU 때문에 모바일에서 발생할 병목이 에디터에서는 드러나지 않기도 합니다.

**Development Build로 타깃 기기에서 직접 확인하는 절차:**

```
1. File → Build Settings → "Development Build" 체크
2. "Autoconnect Profiler" 체크 (선택) 또는 수동 연결
3. 타깃 기기(모바일 등)에 빌드 후 실행
4. 에디터의 Profiler 창 상단 "Attach to Player" 드롭다운에서 기기 선택
   → 같은 네트워크(Wi-Fi)에 연결되어 있으면 기기 목록에 자동으로 나타남
```

연결되면 에디터의 Profiler 창에 실제 기기의 CPU/GPU/메모리 데이터가 실시간으로 스트리밍됩니다. 이 방식으로 타깃 기기 고유의 병목(예: 저사양 GPU에서만 발생하는 프래그먼트 셰이더 병목)을 정확히 잡아낼 수 있습니다.

> 💡 **실무 팁**: 모바일에서는 Unity Profiler 외에도 플랫폼 전용 툴(iOS는 Xcode Instruments, Android는 Android GPU Inspector/Android Profiler)을 함께 쓰면 GPU 셰이더 단위, 배터리/발열 단위의 더 세밀한 데이터를 얻을 수 있습니다.

---

## 5. Memory Profiler로 누수와 과도한 사용량 추적하기

`Window → Analysis → Profiler`의 기본 Memory 모듈은 전체 메모리 사용량 추이만 보여주지만, 더 세밀한 분석에는 Package Manager로 설치하는 별도의 **Memory Profiler** 패키지를 사용합니다.

```
Window → Package Manager → "Memory Profiler" 검색 후 설치
Window → Analysis → Memory Profiler → "Capture" 버튼으로 특정 시점의 메모리 스냅샷 캡처
```

- 스냅샷 두 개(예: 씬 로드 전/후)를 비교(Diff)하면 어떤 오브젝트, 텍스처, 오디오 클립이 새로 늘었고 해제되지 않았는지 정확히 확인 가능
- "Unity Objects" 트리에서 타입별(Texture2D, AudioClip, Mesh 등) 메모리 점유율을 정렬해서 가장 큰 항목부터 최적화 우선순위를 정할 수 있음
- Scene 전환 후에도 메모리가 계속 늘어난다면, `Resources.UnloadUnusedAssets()`나 어드레서블(Addressables)의 명시적 해제 호출이 빠졌는지 확인해야 함

> 💡 **실무 팁**: 메모리 누수는 즉시 크래시로 이어지지 않아 놓치기 쉽습니다. 씬을 여러 번 반복 로드/언로드하면서 Memory Profiler로 스냅샷을 주기적으로 비교하는 테스트를 최적화 체크리스트에 포함시키는 것이 좋습니다.

---

## 📝 핵심 요약

1. 최적화는 감이 아니라 Profiler로 병목 지점(CPU/GPU/메모리 중 어디인지)을 먼저 확인하는 것에서 시작한다
2. CPU Usage 모듈의 Hierarchy 뷰에서는 Total이 아니라 Self 시간을 기준으로 실제 무거운 함수를 찾아야 한다
3. Deep Profile은 오버헤드가 커서 절대 시간이 아니라 함수 간 상대적 비중만 참고해야 한다
4. Development Build + Attach to Player로 반드시 실제 타깃 기기에서 성능을 재확인해야 하며, 에디터 수치만 믿으면 안 된다
5. Memory Profiler 패키지의 스냅샷 Diff 기능으로 메모리 누수와 과도한 자원 점유를 추적할 수 있다

---

## 🔗 참고 자료

- [Unity Manual — Profiler window](https://docs.unity3d.com/Manual/Profiler.html)
- [Unity Manual — CPU Usage Profiler module](https://docs.unity3d.com/Manual/ProfilerCPU.html)
- [Unity Manual — Memory Profiler package](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@latest)

---

*⬅️ 이전: [Day 50 — Draw Call과 배칭(Batching) 이해하기](../day-50/)  |  다음: [Day 52 — 모바일/저사양 기기를 위한 3D 에셋 최적화](../day-52/) ➡️*
