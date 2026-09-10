---
title: "Day 43 — Shader Graph 기초 개념"
date: 2026-09-10
weight: 43
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 셰이더가 무엇이고 Shader Graph가 코드 셰이더와 어떻게 다른지 설명할 수 있다
- Shader Graph 에디터의 기본 구조(노드, 마스터 스택, 프리뷰)를 이해하고 간단한 그래프를 만들 수 있다
- Property, Vertex/Fragment 스테이지, 주요 노드 카테고리를 활용해 기본적인 머티리얼 효과를 구현할 수 있다

---

## 1. 셰이더란 무엇인가

셰이더(Shader)는 GPU에서 실행되는 작은 프로그램으로, "화면에 픽셀 하나하나를 어떤 색으로 그릴지"를 계산합니다. 지금까지 다뤄온 Standard/URP Lit 머티리얼도 내부적으로는 셰이더가 계산을 수행한 결과입니다.

셰이더는 보통 두 단계로 나뉩니다.

| 스테이지 | 역할 | 처리 단위 |
|---|---|---|
| Vertex Shader | 정점의 위치, 노멀 등을 변형 | 메시의 정점(vertex) 하나당 1회 |
| Fragment(Pixel) Shader | 최종 픽셀 색상 계산 | 화면에 그려질 픽셀 하나당 1회 |

전통적으로 셰이더는 HLSL 같은 코드로 직접 작성했습니다. 코드 셰이더는 세밀한 제어가 가능하지만 문법이 낯설고 디버깅이 어렵습니다. Unity는 이를 시각적으로 대체할 수 있는 **Shader Graph**를 제공합니다.

> 💡 **실무 팁**: Shader Graph는 URP/HDRP 전용입니다. Built-in Render Pipeline에서는 동작하지 않으므로, Day 25에서 URP로 전환해둔 프로젝트가 전제 조건입니다.

---

## 2. Shader Graph vs 코드 셰이더

| 구분 | Shader Graph | 코드 셰이더(HLSL) |
|---|---|---|
| 작성 방식 | 노드를 연결하는 시각적 편집 | 텍스트 코드 작성 |
| 진입 장벽 | 낮음 — 프로그래밍 지식 없이도 가능 | 높음 — GPU 파이프라인/HLSL 문법 이해 필요 |
| 디버깅 | 노드별 프리뷰로 중간 결과 즉시 확인 | 별도 도구(RenderDoc 등) 필요 |
| 성능 | 내부적으로 HLSL로 컴파일되어 대체로 동등 | 직접 최적화 가능 |
| 세밀한 제어 | 제공하는 노드 범위 내로 제한 | 완전한 자유도 |
| 팀 협업 | 아티스트/디자이너도 직접 제작 가능 | 대부분 엔지니어 전담 |

실무에서는 아티스트가 Shader Graph로 비주얼 효과를 실험하고, 성능이 critical한 경우에만 엔지니어가 최종적으로 코드 셰이더로 포팅하는 방식이 흔합니다.

---

## 3. Shader Graph 에디터 시작하기

**생성 방법:**

```
Project 창 우클릭 → Create → Shader Graph → URP → Lit Shader Graph
(또는 Unlit Shader Graph)
```

- **Lit Shader Graph**: 라이팅 계산(빛, 그림자, PBR)을 자동으로 포함 — 대부분의 3D 오브젝트용 머티리얼에 사용
- **Unlit Shader Graph**: 라이팅 계산 없이 순수한 색상만 출력 — UI, 이펙트, 홀로그램처럼 빛의 영향을 받지 않는 표현에 사용

생성한 `.shadergraph` 파일을 더블클릭하면 전용 에디터가 열립니다. 화면 구성은 크게 네 부분입니다.

| 영역 | 역할 |
|---|---|
| Blackboard (좌측) | Property(외부에 노출할 변수) 목록 관리 |
| Graph Canvas (중앙) | 노드를 배치하고 연결하는 작업 공간 |
| Main Preview (우측 하단) | 현재 그래프 결과를 구체/평면 등에 미리보기 |
| Master Stack (우측) | 최종 출력 — Vertex 블록과 Fragment 블록으로 구성된 종착점 |

**Master Stack**이 핵심입니다. 모든 노드 연산은 결국 Master Stack의 입력 슬롯(Base Color, Normal, Metallic, Emission 등)에 연결되어야 화면에 반영됩니다.

---

## 4. Property와 노드 기본기

**Property**는 Blackboard에서 추가하는 외부 입력값으로, Inspector에서 조절하거나 스크립트(`Material.SetFloat` 등)로 런타임에 바꿀 수 있습니다.

주요 Property 타입:

| 타입 | 용도 |
|---|---|
| Float | 단일 숫자 (강도, 속도 등) |
| Color | 색상 (Base Color, Tint 등) |
| Texture2D | 텍스처 이미지 |
| Vector2/3/4 | 좌표, 방향, UV 오프셋 등 |
| Boolean | 켜기/끄기 스위치 (Keyword와 연동 가능) |

**자주 쓰는 노드 카테고리:**

- **Input**: `Sample Texture 2D`, `Time`, `UV`, `Color` — 데이터를 그래프로 가져옴
- **Math**: `Add`, `Multiply`, `Lerp`, `Remap` — 값을 계산/조합
- **Procedural**: `Noise`, `Checkerboard`, `Gradient` — 코드 없이 절차적 패턴 생성
- **UV**: `Tiling And Offset`, `Rotate`, `Polar Coordinates` — 텍스처 좌표 변형
- **Utility**: `Blend`, `Custom Function` — 고급 조합 및 커스텀 HLSL 삽입

예를 들어 `Sample Texture 2D` 노드의 RGBA 출력을 Master Stack의 `Base Color`에 연결하면, 그 텍스처가 그대로 오브젝트에 입혀집니다. 여기에 `Tiling And Offset` 노드를 `Sample Texture 2D`의 UV 입력 앞에 끼우면 텍스처를 반복시키거나 이동시킬 수 있습니다.

> 💡 **실무 팁**: 그래프가 복잡해지면 관련 노드들을 선택한 뒤 우클릭 → `Group`으로 묶어 이름을 붙이세요. 나중에 본인이나 팀원이 그래프를 다시 열었을 때 이해하는 속도가 크게 달라집니다.

---

## 5. 실습 — 간단한 Dissolve 효과 만들기

이론만으로는 감이 잘 안 오므로, 오브젝트가 "사라지는" 디졸브 효과를 직접 만들어 봅니다.

**구성 노드 흐름:**

```
Noise (또는 Sample Texture 2D의 노이즈 텍스처)
   → Step 노드 (Threshold Property와 비교)
      → Alpha Clip Threshold (Master Stack, Alpha Clipping 활성화 필요)

동시에:
Step 결과의 경계 부분
   → Color Property(예: 주황색 발광)
      → Emission (Master Stack)
```

**단계별 진행:**

1. Blackboard에 `Float` Property `_Threshold` (0~1, 기본값 0.5) 추가
2. `Simple Noise` 노드를 배치해 절차적 패턴 생성
3. `Step` 노드에 Noise 출력과 `_Threshold`를 연결 — Threshold보다 작은 픽셀은 0(투명), 큰 픽셀은 1(불투명)이 됨
4. Master Stack에서 Graph Settings → `Alpha Clipping` 체크 활성화
5. `Step` 결과를 `Alpha Clip Threshold` 슬롯에 연결
6. `_Threshold` 값을 스크립트로 0→1까지 서서히 올리면 오브젝트가 노이즈 패턴을 따라 서서히 사라지는 디졸브 효과 완성

```csharp
// Threshold를 시간에 따라 0에서 1로 올리는 예시 스크립트
public class DissolveController : MonoBehaviour
{
    [SerializeField] private Renderer targetRenderer;
    [SerializeField] private float duration = 2f;

    private static readonly int Threshold = Shader.PropertyToID("_Threshold");

    public void PlayDissolve()
    {
        StartCoroutine(DissolveRoutine());
    }

    private System.Collections.IEnumerator DissolveRoutine()
    {
        var mat = targetRenderer.material; // 인스턴스화된 머티리얼
        float t = 0f;
        while (t < duration)
        {
            t += Time.deltaTime;
            mat.SetFloat(Threshold, t / duration);
            yield return null;
        }
    }
}
```

`Shader.PropertyToID`로 캐싱한 참조를 사용하면 문자열 비교 없이 빠르게 Property 값을 갱신할 수 있습니다. Property 이름은 Blackboard에서 지정한 **Reference** 값(보통 `_` 접두사가 붙은 이름)과 정확히 일치해야 합니다.

---

## 📝 핵심 요약

1. 셰이더는 GPU가 정점(Vertex)과 픽셀(Fragment) 단계로 화면을 그리는 프로그램이며, Shader Graph는 이를 노드 기반으로 시각화한 도구다
2. Shader Graph는 URP/HDRP 전용이며, Lit(라이팅 포함)과 Unlit(라이팅 없음) 두 종류로 시작할 수 있다
3. Blackboard의 Property는 Inspector와 스크립트(`Material.SetFloat` 등)에서 조절 가능한 외부 입력값이다
4. Master Stack이 그래프의 최종 출력 지점이며, Base Color/Normal/Emission/Alpha Clip Threshold 등 슬롯에 노드 결과를 연결해야 화면에 반영된다
5. Noise + Step 노드 조합만으로도 디졸브 같은 실용적인 효과를 코드 없이 구현할 수 있다

---

## 🔗 참고 자료

- [Unity Shader Graph 공식 매뉴얼](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest/manual/index.html)
- [Shader Graph Node Library](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest/manual/Node-Library.html)
- [Unity Manual — Material.SetFloat](https://docs.unity3d.com/ScriptReference/Material.SetFloat.html)

---

*⬅️ 이전: [Day 42 — 6주차 정리: 작은 환경 씬 완성](../day-42/)  |  다음: [Day 44 — 커스텀 셰이더로 머티리얼 표현력 높이기](../day-44/) ➡️*
