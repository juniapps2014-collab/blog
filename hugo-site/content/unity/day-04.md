---
title: "Day 04 — Prefab 개념과 활용"
date: 2026-08-03
weight: 4
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Prefab이 GameObject를 재사용 가능한 "템플릿"으로 만들어주는 원리와 필요성을 설명할 수 있다
- Prefab 인스턴스에서 Override를 적용하고, Apply/Revert로 원본과 동기화하는 워크플로우를 다룰 수 있다
- Nested Prefab, Prefab Variant, `Instantiate()` 스크립트 생성의 차이를 구분하고 상황에 맞게 사용할 수 있다

---

## 1. Prefab이란 무엇인가

Prefab은 GameObject(와 그 하위 계층 구조, Component, 설정값 전체)를 **재사용 가능한 에셋으로 저장한 템플릿**입니다. 확장자는 `.prefab`이며 Project 창에 파일로 존재합니다.

같은 종류의 적, 총알, 아이템 상자를 씬에 10개, 100개씩 배치해야 한다고 생각해보면 Prefab의 필요성이 명확해집니다. Prefab 없이 GameObject를 하나씩 복사(Ctrl+D)해서 배치하면, 나중에 "적의 체력을 100에서 150으로 바꿔야 한다"는 요청이 왔을 때 씬에 흩어진 인스턴스를 전부 하나씩 찾아 수정해야 합니다. Prefab을 쓰면 원본 Prefab 에셋 하나만 수정하면 그 Prefab으로부터 만들어진 모든 인스턴스에 변경 사항이 자동으로 반영됩니다.

| 방식 | 수정 시 동작 |
|---|---|
| 단순 복사(Duplicate) | 각 GameObject가 독립적 — 하나를 고쳐도 나머지는 그대로 |
| Prefab 인스턴스 | 원본 Prefab을 고치면 모든 인스턴스에 자동 반영 |

> 💡 **실무 팁**: "씬에 두 번 이상 등장할 가능성이 있는 오브젝트는 무조건 Prefab으로 만든다"를 기본 원칙으로 삼는 것이 좋습니다. 처음에는 한 번만 쓸 것 같던 오브젝트도 프로젝트가 커지면서 재사용되는 경우가 매우 흔합니다.

---

## 2. Prefab 만들기와 인스턴스의 관계

Prefab을 만드는 방법은 간단합니다. Hierarchy에 있는 GameObject를 Project 창으로 드래그하면 `.prefab` 에셋이 생성되고, 원래 Hierarchy에 있던 오브젝트는 자동으로 그 Prefab의 **인스턴스**로 바뀝니다.

Prefab 인스턴스가 만들어지면 Hierarchy에서 오브젝트 이름이 파란색으로 표시되고, 이름 옆에 파란 상자 아이콘이 붙습니다. 이 파란색 표시가 "이 오브젝트는 특정 Prefab 원본과 연결되어 있다"는 뜻입니다.

인스턴스에서 Transform 값이나 Component 속성을 바꾸면 그 값은 **Override(재정의)** 로 표시됩니다. Inspector에서 변경된 속성 이름이 굵은 글씨 + 파란 세로선으로 강조되는 것이 Override 표시입니다.

- **Overrides 드롭다운 → Apply All**: 인스턴스에서 바꾼 값을 원본 Prefab에 반영 (다른 모든 인스턴스도 함께 바뀜)
- **Overrides 드롭다운 → Revert All**: 인스턴스의 변경 사항을 취소하고 원본 Prefab 값으로 되돌림

```
Enemy_Prefab (원본, Project 창)
├── Enemy Instance #1 (Hierarchy) — Override 없음, 원본과 100% 동일
├── Enemy Instance #2 (Hierarchy) — Position만 Override
└── Enemy Instance #3 (Hierarchy) — Position + Color Override
```

> 💡 **실무 팁**: Position/Rotation/Scale처럼 인스턴스마다 당연히 달라야 하는 값은 Override로 남겨두고, "체력", "이동 속도"처럼 모든 인스턴스가 공유해야 하는 값을 실수로 Override해버린 경우에는 반드시 Revert하거나 원본에 Apply해서 일관성을 유지해야 합니다.

---

## 3. Prefab Mode — 원본을 직접 편집하기

Project 창의 Prefab 에셋을 더블클릭하면 **Prefab Mode**로 들어갑니다. 이 모드는 씬과 완전히 분리된 격리 편집 환경으로, 여기서 하는 모든 수정은 즉시 원본 Prefab에 저장됩니다(Ctrl/Cmd+S 또는 좌측 상단 뒤로가기 버튼을 누르면 자동 저장).

Prefab Mode로 들어가는 방법은 두 가지입니다.

- Project 창에서 더블클릭 → 씬 전체가 사라지고 해당 Prefab만 격리되어 표시됨
- Hierarchy의 인스턴스 오른쪽 화살표(▶) 클릭 → 씬 컨텍스트를 유지한 채 Prefab 내부로 진입(In-Context 모드)

> 💡 **실무 팁**: 실무에서는 In-Context 모드를 더 자주 씁니다. 예를 들어 지형 위에 놓인 나무 Prefab을 편집할 때, 격리 모드는 주변 지형이 안 보여 크기감을 파악하기 어렵지만 In-Context 모드는 씬 속 실제 위치에서 그대로 수정할 수 있습니다.

---

## 4. Nested Prefab과 Prefab Variant

**Nested Prefab**은 Prefab 안에 다른 Prefab을 자식으로 포함하는 구조입니다. 예를 들어 `Car_Prefab` 안에 `Wheel_Prefab` 4개를 자식으로 넣으면, 바퀴 디자인을 바꿀 때 `Wheel_Prefab`만 수정해도 모든 차량 Prefab에 반영됩니다.

**Prefab Variant**는 원본 Prefab을 기반으로 "일부만 다른" 파생 버전을 만드는 기능입니다. 원본 Prefab을 선택한 뒤 우클릭 → `Create > Prefab Variant`로 만들며, Variant는 원본과 부모-자식처럼 연결되어 있어 원본의 공통 변경 사항은 그대로 물려받으면서 Variant마다 다른 부분만 별도로 관리할 수 있습니다.

| 개념 | 관계 | 활용 예시 |
|---|---|---|
| Nested Prefab | Prefab 안에 Prefab을 자식으로 포함 | 자동차 Prefab 안에 바퀴 Prefab 4개 |
| Prefab Variant | 원본을 상속하고 일부만 재정의 | `Enemy_Base` → `Enemy_Fast`, `Enemy_Tank` |

```
Enemy_Base (원본 Prefab)
├── Enemy_Fast (Variant) — 이동 속도만 다르게 Override
├── Enemy_Tank (Variant) — 체력, Scale만 다르게 Override
└── Enemy_Boss (Variant) — 체력, 공격력, 모델 교체
```

> 💡 **실무 팁**: 몬스터 종류가 많은 게임에서는 공통 로직(AI, 애니메이션 상태 등)을 담은 Base Prefab 하나를 만들고 종류별 차이는 모두 Variant로 관리하면, 공통 버그를 고칠 때 Base 하나만 수정해도 모든 종류에 자동 반영되어 유지보수가 크게 쉬워집니다.

---

## 5. 스크립트로 Prefab 인스턴스화하기 — `Instantiate()`

에디터에서 미리 배치하는 것뿐 아니라, 게임 실행 중에 스크립트로 Prefab을 동적으로 생성하는 경우가 훨씬 많습니다(총알 발사, 적 스폰, 이펙트 생성 등). 이때는 `Object.Instantiate()`를 사용합니다.

```csharp
using UnityEngine;

public class EnemySpawner : MonoBehaviour
{
    [SerializeField] private GameObject enemyPrefab; // Inspector에서 Prefab 에셋을 드래그해 연결
    [SerializeField] private Transform spawnPoint;

    private void SpawnEnemy()
    {
        // 위치와 회전을 지정해 새 인스턴스 생성
        GameObject enemy = Instantiate(enemyPrefab, spawnPoint.position, spawnPoint.rotation);

        // 생성된 인스턴스의 Component에 바로 접근해 초기화도 가능
        if (enemy.TryGetComponent(out EnemyHealth health))
        {
            health.SetMaxHealth(100);
        }
    }

    private void DestroyEnemy(GameObject target)
    {
        Destroy(target); // 인스턴스 제거 (원본 Prefab 에셋은 영향받지 않음)
    }
}
```

`Instantiate()`의 첫 번째 인자로 넘기는 `enemyPrefab` 필드는 Inspector에서 **Project 창의 Prefab 에셋**을 직접 드래그해 연결해야 합니다. Hierarchy의 씬 인스턴스를 연결하면 씬이 바뀌거나 그 인스턴스가 파괴되었을 때 참조가 깨질 수 있습니다.

> 💡 **실무 팁**: 총알처럼 매 프레임 여러 번 생성/파괴되는 오브젝트를 `Instantiate`/`Destroy`로 반복하면 가비지 컬렉션 부담이 커집니다. 이런 경우를 위한 표준 최적화 패턴이 **Object Pooling**(오브젝트를 파괴하지 않고 비활성화해뒀다가 재사용)이며, 이후 심화 커리큘럼에서 다시 다룹니다.

---

## 📝 핵심 요약

1. Prefab은 GameObject를 재사용 가능한 템플릿 에셋으로 저장한 것으로, 원본을 수정하면 모든 인스턴스에 자동 반영된다
2. 인스턴스에서 값을 바꾸면 Override로 표시되며, Overrides 드롭다운의 Apply All/Revert All로 원본과 동기화할 수 있다
3. Prefab Mode(격리 모드·In-Context 모드)에서 Prefab 원본 자체를 직접 편집할 수 있다
4. Nested Prefab은 Prefab 안에 Prefab을 포함하는 구조이고, Prefab Variant는 원본을 상속해 일부만 재정의하는 파생 버전이다
5. 런타임에 동적으로 오브젝트를 만들 때는 `Instantiate(prefab, position, rotation)`을 사용하며, 반복 생성/파괴가 많은 경우 Object Pooling을 고려해야 한다

---

## 🔗 참고 자료

- [Prefabs (Unity Manual)](https://docs.unity3d.com/Manual/Prefabs.html)
- [Prefab Variant (Unity Manual)](https://docs.unity3d.com/Manual/PrefabVariants.html)
- [Object.Instantiate 스크립팅 API](https://docs.unity3d.com/ScriptReference/Object.Instantiate.html)

---

*⬅️ 이전: [Day 03 — Scene 구성과 계층 구조(Hierarchy) 관리](../day-03/)  |  다음: [Day 05 — 기본 C# 스크립팅 - MonoBehaviour 생명주기](../day-05/) ➡️*
