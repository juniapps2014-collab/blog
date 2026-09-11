---
title: "Day 44 — 커스텀 셰이더로 머티리얼 표현력 높이기"
date: 2026-09-11
weight: 44
---

> **Phase 7: 셰이더와 심화 렌더링** | 예상 학습 시간: 45분

---

## 🎯 학습 목표

- Shader Graph의 한계를 코드(HLSL)로 보완하는 Custom Function 노드의 구조와 사용법을 설명할 수 있다
- Subgraph로 셰이더 로직을 재사용 가능한 단위로 묶는 방법을 이해한다
- Fresnel/Rim Lighting, Vertex Displacement, Triplanar Mapping 등 실전에서 자주 쓰는 커스텀 효과를 직접 구현할 수 있다

---

## 1. 왜 Shader Graph만으로는 부족할 때가 있는가

Day 43에서 다룬 Shader Graph는 대부분의 머티리얼 표현을 노드만으로 처리할 수 있게 해줍니다. 하지만 다음과 같은 상황에서는 한계에 부딪힙니다.

- 반복문, 조건 분기 등 복잡한 로직을 노드로 표현하면 그래프가 지나치게 커지고 가독성이 떨어짐
- 특정 수학 공식(예: 커스텀 노이즈 함수, 물리 기반 근사식)을 정확히 그대로 옮기고 싶을 때
- 이미 검증된 HLSL 스니펫(다른 프로젝트, 논문, 커뮤니티 자료)을 그대로 재사용하고 싶을 때
- 성능이 critical해서 컴파일된 코드를 직접 미세 조정해야 할 때

이럴 때 Shader Graph를 완전히 버리고 코드 셰이더로 갈아탈 필요는 없습니다. Unity는 **Custom Function 노드**를 통해 그래프 안에 HLSL 코드 조각을 끼워 넣는 하이브리드 방식을 제공합니다.

> 💡 **실무 팁**: "그래프 vs 코드"는 양자택일이 아닙니다. 실무에서는 90%를 노드로 빠르게 만들고, 나머지 10%의 까다로운 부분만 Custom Function으로 채우는 하이브리드 워크플로우가 가장 흔합니다.

---

## 2. Custom Function 노드 기본기

Custom Function 노드는 두 가지 방식으로 코드를 넣을 수 있습니다.

| 방식 | 설명 | 언제 쓰나 |
|---|---|---|
| String (인라인) | 노드 내부에 짧은 HLSL 코드를 직접 입력 | 한두 줄짜리 간단한 계산 |
| File (외부 `.hlsl` 파일) | 별도 `.hlsl` 파일에 함수를 작성하고 경로 지정 | 재사용하거나 길이가 긴 로직 |

**File 방식 예시** — `CustomFresnel.hlsl`:

```hlsl
void CustomFresnel_float(float3 Normal, float3 ViewDir, float Power, out float Result)
{
    float3 n = normalize(Normal);
    float3 v = normalize(ViewDir);
    Result = pow(1.0 - saturate(dot(n, v)), Power);
}
```

규칙이 몇 가지 있습니다.

- 함수 이름 뒤에 `_float` 또는 `_half`를 붙여야 하며, Custom Function 노드의 이름과 정확히 일치해야 함
- 입력은 값으로, 출력은 반드시 `out` 키워드로 선언
- Custom Function 노드에서 이 파일을 지정하면, In/Out 슬롯이 함수 시그니처를 그대로 반영해 자동 생성됨

Shader Graph 에디터에서는 Custom Function 노드를 배치한 뒤 Node Settings에서 파일을 연결하고, Inspector에서 입출력 타입(Float/Vector3 등)과 이름을 함수 시그니처와 동일하게 맞춰줘야 정상 인식됩니다.

> 💡 **실무 팁**: `_float`는 정밀도가 높고, `_half`는 모바일에서 성능/대역폭 이점이 있습니다. 함수를 두 버전(`_float`, `_half`) 모두 작성해두면 Unity가 플랫폼에 맞는 정밀도를 자동 선택합니다.

---

## 3. Subgraph로 로직 재사용하기

여러 머티리얼에서 반복적으로 쓰는 노드 묶음(예: Fresnel 계산, UV 스크롤, 색상 그레이딩)은 매번 새로 만들 필요 없이 **Subgraph Asset**으로 분리할 수 있습니다.

**생성 방법:**

```
Project 창 우클릭 → Create → Shader Graph → Sub Graph
```

Subgraph는 일반 Shader Graph와 비슷하지만 Master Stack 대신 **Output 노드**를 사용해 결과값을 정의합니다. 완성된 Subgraph는 다른 Shader Graph에서 일반 노드처럼 검색해서 배치할 수 있습니다.

| 구분 | 일반 Shader Graph | Sub Graph |
|---|---|---|
| 최종 출력 | Master Stack (Base Color 등) | Output 노드 (임의의 값) |
| 사용처 | 머티리얼에 직접 적용 | 다른 그래프의 노드로 삽입 |
| 재사용성 | 낮음 (그래프 하나당 독립) | 높음 (여러 그래프에서 공유) |

**활용 예:** "Fresnel 강도 + 색상 틴트"를 계산하는 로직을 `RimGlow` Subgraph로 만들어두면, 캐릭터/무기/이펙트 머티리얼 각각에서 같은 Subgraph를 불러와 Power와 Color Property만 다르게 넣는 식으로 일관성 있게 재사용할 수 있습니다.

> 💡 **실무 팁**: Subgraph 안에 Custom Function 노드를 넣어 조합하면, "코드 로직 + 그래프 편의성"을 동시에 재사용 가능한 형태로 캡슐화할 수 있습니다.

---

## 4. 실전 커스텀 효과 1 — Fresnel/Rim Lighting

물체 가장자리(시선과 수직에 가까운 면)를 밝게 강조하는 Rim Lighting은 캐릭터 실루엣 강조, 홀로그램, 실드 이펙트 등에 자주 쓰입니다.

**노드 구성 흐름:**

```
Custom Function (CustomFresnel_float)
  입력: Normal (Normal Vector 노드), ViewDir (View Direction 노드), Power (Property)
  출력: Result
     → Multiply (Rim Color Property와 곱함)
        → Add (기존 Base Color 또는 Emission에 더함)
```

- `Normal Vector` 노드는 World Space를 기준으로 사용 (Object Space와 혼동하면 회전 시 효과가 어긋남)
- `Power` 값을 키울수록 가장자리 강조 영역이 좁고 강해짐 (보통 2~6 사이에서 조정)
- Emission 슬롯에 더하면 발광 효과, Base Color에 곱하면 은은한 셰이딩 강조 효과

```csharp
// Rim 강도를 게임 이벤트에 따라 동적으로 조절하는 예시
public class RimIntensityController : MonoBehaviour
{
    [SerializeField] private Renderer targetRenderer;
    private static readonly int RimPower = Shader.PropertyToID("_RimPower");

    public void SetRimPower(float power)
    {
        targetRenderer.material.SetFloat(RimPower, power);
    }
}
```

---

## 5. 실전 커스텀 효과 2 — Vertex Displacement & Triplanar Mapping

**Vertex Displacement(정점 변위)** 는 Vertex Shader 단계에서 정점 위치 자체를 이동시켜 물결, 바람에 흔들리는 나뭇잎, 심장 박동처럼 뛰는 표면 등을 구현합니다.

```hlsl
void WaveDisplace_float(float3 PositionOS, float Time, float Amplitude, float Frequency, out float3 Result)
{
    float wave = sin(PositionOS.x * Frequency + Time) * Amplitude;
    Result = PositionOS + float3(0, wave, 0);
}
```

이 함수의 출력을 Shader Graph의 Master Stack **Vertex** 블록의 **Position** 슬롯에 연결하면, 메시가 실제로 물리 연산 없이도 셰이더 단계에서만 출렁이는 것처럼 보입니다. CPU 부하 없이 GPU에서 병렬로 계산되므로 다수의 오브젝트에 적용해도 비용이 낮습니다.

**Triplanar Mapping**은 UV 언랩 없이도 텍스처를 입힐 수 있는 기법으로, 절차적으로 생성된 지형이나 UV가 왜곡되기 쉬운 복잡한 메시에 유용합니다. 원리는 오브젝트를 3개 축(X/Y/Z) 방향에서 각각 투영해 텍스처를 샘플링한 뒤, 표면 노멀의 방향에 따라 세 결과를 블렌딩하는 것입니다.

| 방식 | UV 필요 여부 | 적합한 대상 |
|---|---|---|
| 일반 UV 매핑 | 필요 (Blender에서 언랩 작업 필수) | 캐릭터, 소품처럼 UV 작업이 가능한 메시 |
| Triplanar Mapping | 불필요 | Terrain, 절차적 지형, 바위처럼 UV 왜곡이 심한 메시 |

Shader Graph에는 기본 제공되는 `Triplanar` 노드가 있어 직접 HLSL을 짤 필요 없이 텍스처와 Normal Map을 연결하기만 하면 됩니다. 다만 세부 블렌딩 곡선을 조정하고 싶다면 Custom Function으로 직접 구현할 수도 있습니다.

> 💡 **실무 팁**: Vertex Displacement를 적용한 메시는 Unity의 Frustum Culling/Bounding Box 계산이 원본 정점 위치 기준으로 이루어지므로, 변위 폭이 크면 화면 밖에서 잘못 컬링될 수 있습니다. Renderer의 Bounds를 여유 있게 키워주는 보정이 필요할 때가 있습니다.

---

## 📝 핵심 요약

1. Custom Function 노드는 Shader Graph 안에 HLSL 코드 조각(`_float`/`_half` 함수)을 끼워 넣어, 그래프만으로 표현하기 어려운 로직을 보완한다
2. Subgraph는 Master Stack 대신 Output 노드를 쓰는 독립 그래프로, 반복되는 셰이더 로직을 여러 머티리얼에서 재사용 가능하게 캡슐화한다
3. Fresnel/Rim Lighting은 Normal과 View Direction의 내적을 이용해 가장자리를 강조하는 대표적인 커스텀 효과다
4. Vertex Displacement는 GPU 단계에서 정점 위치를 이동시켜 물리 연산 없이 표면 움직임을 표현하며, Bounds 보정이 필요할 수 있다
5. Triplanar Mapping은 UV 언랩 없이 3축 투영과 노멀 기반 블렌딩으로 텍스처를 입히는 기법으로 절차적 지형에 특히 유용하다

---

## 🔗 참고 자료

- [Unity Shader Graph — Custom Function Node](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest/manual/Custom-Function-Node.html)
- [Unity Shader Graph — Sub-graph](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest/manual/Sub-graph.html)
- [Unity Shader Graph — Triplanar Node](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest/manual/Triplanar-Node.html)

---

*⬅️ 이전: [Day 43 — Shader Graph 기초 개념](../day-43/)  |  다음: [Day 45 — 오브젝트 상호작용 - 애니메이션 이벤트와 스크립트 연동](../day-45/) ➡️*
