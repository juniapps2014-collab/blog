---
title: "Day 16 — 자산 계층 구조와 명명 규칙: 설비 태그와 3D 노드 매핑"
date: 2026-11-27
weight: 16
---

> **Phase 3: 가상 모델 준비하기** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- 설비 태그 트리·3D 씬 그래프·데이터 포인트 네임스페이스가 서로 다른 세 개의 트리임을 구분하고, 각 트리의 주인과 변경 주기를 설명할 수 있다
- ISA-95 계층과 ISA-5.1·IEC 81346 같은 태그 체계를 참고해 프로젝트 고유의 태그 문법을 자리수·구분자 단위까지 확정할 수 있다
- 3D 노드와 설비 태그를 이름 규약 또는 사이드카 매니페스트로 연결하고, 고아 노드·미사용 태그를 자동 검출하는 검증 스크립트를 만들 수 있다

---

## 1. 트윈에는 트리가 세 개 있다

Day 15에서 좌표를 맞췄으니 이제 모델이 현실과 같은 자리에 있습니다. 그런데 트윈이 되려면 하나가 더 필요합니다. 씬에 있는 저 파란색 원통이 **어느 설비인지** 시스템이 알아야 합니다. 센서가 `P-101A/bearing/vib_rms = 4.2` 를 보내왔을 때, 어떤 GameObject의 머티리얼을 빨갛게 바꿔야 하는지 결정하는 건 결국 **이름**입니다.

여기서 초보자가 거의 항상 하는 가정이 있습니다. "3D 모델의 계층 구조를 설비 구조대로 만들면 되겠네." 틀린 건 아니지만, 그대로 밀고 나가면 반드시 막힙니다. 트윈에는 성격이 다른 트리가 **셋** 있고, 셋은 끝내 일치하지 않기 때문입니다.

| 트리 | 무엇을 표현하나 | 누가 주인인가 | 변경 주기 |
|---|---|---|---|
| **설비 태그 트리** | 공정·기능상의 소속 (1공장 → 압축동 → 펌프 P-101) | 공무팀 / 설계사 | 년 단위, 느림 |
| **3D 씬 그래프** | 렌더링·공간상의 소속 (건물 메시 → 배관 그룹 → 메시 노드) | 3D 담당 / CAD 변환기 | 자산 갱신마다 |
| **데이터 포인트 네임스페이스** | 신호의 주소 (MQTT 토픽, OPC UA NodeId, DB 태그명) | 제어팀 / SI 업체 | 설비 증설·교체마다 |

셋이 어긋나는 구체적인 이유가 있습니다.

- **펌프 P-101A와 P-101B는 기능상 같은 부모를 갖지만, 3D에서는 한 덩어리 메시로 들어옵니다.** CAD 변환기가 조립체를 머티리얼 단위로 병합해 버리는 게 흔합니다 (Day 13의 경량화 파이프라인이 일부러 그렇게 합니다 — 드로우콜을 줄여야 하니까요)
- **반대로 하나의 설비가 3D에서는 수십 개 노드로 쪼개집니다.** 배관 하나가 세그먼트 200개로 들어오는 식입니다
- **센서는 설비에 1:1로 붙지 않습니다.** 분전반 하나가 펌프 다섯 대의 전류를 함께 보고하고, 온도 트랜스미터 하나가 라인 전체를 대표합니다
- **3D에는 설비가 아닌 것도 많습니다.** 바닥, 조명 프로브, 카메라 리그, 안내 표지

그래서 설계 원칙은 이것 하나입니다.

> **세 트리를 억지로 일치시키지 말고, 안정적인 하나를 기준으로 삼아 나머지를 그 기준에 매핑한다.** 기준은 거의 항상 **설비 태그 트리**입니다. 가장 느리게 변하고, 현장 사람들이 실제로 입으로 말하는 이름이기 때문입니다.

3D 노드 이름은 자산 갱신 때마다 바뀔 수 있다고 가정해야 합니다. 협력업체가 FBX를 다시 보내면서 `Pump_01`을 `pump01_v2`로 바꿔 놓는 일은 반드시 일어납니다. 그 이름 위에 시스템을 세우면 그때마다 트윈이 깨집니다.

---

## 2. 태그 체계 — 바퀴를 다시 만들지 않기

현장에는 이미 태그가 있습니다. P&ID 도면에, 설비 명판에, DCS 화면에 적혀 있는 그 이름입니다. **트윈의 태그는 그것을 그대로 가져오는 게 원칙**이고, 새로 만드는 건 현장에 아무 체계가 없을 때뿐입니다.

### 알아 둘 만한 체계들

| 체계 | 쓰이는 곳 | 형태 | 예시 |
|---|---|---|---|
| **ISA-5.1** | 플랜트 계측·제어 (P&ID) | 기능문자 + 루프번호 | `TT-1234` (온도 전송기), `PI-2101` (압력 지시계) |
| **IEC 81346** | 범용 (제조·건설·에너지) | 접두 기호로 측면 구분 | `=A1+B2-M3` (기능=, 위치+, 제품-) |
| **KKS / RDS-PP** | 발전 플랜트 | 계통·기기·부품 코드 | `10LAC20AP001` |
| **ISA-95 (IEC 62264)** | MES/ERP 연계 | 계층 모델 | Enterprise → Site → Area → Work Center → Work Unit |
| **Uniclass / OmniClass** | 건설·BIM | 분류 코드 | `Pr_65_52_03` |

실무에서 가장 많이 만나는 조합은 **ISA-5.1 태그를 ISA-95 계층에 담는 것**입니다. ISA-5.1은 "이게 무슨 기기인가"를, ISA-95는 "어디에 속하는가"를 답하기 때문에 역할이 겹치지 않습니다.

```
Enterprise  ACME
  Site        SEOUL1          서울 1공장
    Area        CMP           압축동
      WorkCenter  L1          1라인
        WorkUnit    P-101A    1단 급수펌프 A
        WorkUnit    P-101B    1단 급수펌프 B
        WorkUnit    TK-201    중간 탱크
```

ISA-5.1의 기능문자는 외워 두면 도면을 읽을 때 편합니다. 첫 글자가 **측정 대상**(T 온도, P 압력, F 유량, L 레벨, V 진동, J 전력), 둘째 글자 이후가 **기능**(T 전송, I 지시, C 제어, A 경보, S 스위치)입니다. 그래서 `FIC-301`은 "유량 지시 제어기 301번 루프"입니다. 트윈 화면에 태그만 띄워 놔도 현장 담당자는 그게 뭔지 압니다 — 이게 기존 체계를 쓰는 가장 큰 이익입니다.

### 현장에 체계가 없을 때

소규모 공장이나 신규 라인이면 태그가 엑셀에 제각각인 경우가 많습니다. 이때 직접 정하되, **과하게 설계하지 않는 게** 중요합니다. 코드 하나에 12개 필드를 욱여넣은 체계는 아무도 외우지 못하고, 결국 사람들이 별칭을 만들어 쓰면서 두 체계가 공존하게 됩니다.

쓸 만한 최소 문법:

```
<구역>-<기기종류><일련번호><중복기호>

  CMP-P101A    압축동 / 펌프 / 101 / A호기
  CMP-TK201    압축동 / 탱크 / 201
  ASM-RB003    조립동 / 로봇 / 003
```

정할 때 반드시 고정해야 하는 것들:

- **자리수를 고정합니다.** `P-1`과 `P-01`과 `P-001`이 섞이면 정렬이 깨지고 문자열 비교가 실패합니다. 세 자리면 세 자리로 끝까지
- **구분자는 한 종류만.** 하이픈이면 하이픈. `P_101`과 `P-101`이 공존하면 조인이 안 됩니다
- **대소문자를 고정합니다.** 전부 대문자가 무난합니다. MQTT 토픽은 대소문자를 구분하고, Windows 파일시스템은 구분하지 않아서, 섞이면 환경마다 다르게 동작합니다
- **의미 있는 번호를 쓰지 않습니다.** "100번대는 1층"처럼 번호에 뜻을 담으면 증축하는 순간 무너집니다. 소속은 계층으로 표현하고 번호는 번호로 둡니다
- **공백·한글·슬래시를 넣지 않습니다.** 태그는 MQTT 토픽, 파일명, URL, GameObject 이름, SQL 컬럼값으로 전부 쓰이게 됩니다. 어느 하나에서라도 이스케이프가 필요한 문자는 처음부터 배제합니다

> 💡 **실무 팁**: 태그 문자셋은 `[A-Z0-9-]`로 좁혀 두세요. 언더스코어까지는 괜찮지만 그 이상은 위험합니다. 특히 **한글 설비명을 태그로 쓰면** MQTT 브로커·InfluxDB 태그·Unity 오브젝트 이름까지는 대개 버텨 주다가, 파일명으로 저장하는 순간(스크린샷, CSV 익스포트, glTF 노드명) 인코딩이 환경마다 달라져 깨집니다. 한글 이름은 **표시용 `displayName` 속성으로 따로** 두고, 태그는 ASCII로 유지하는 게 정답입니다.

---

## 3. 3D 노드를 태그에 연결하는 두 가지 방법

이제 핵심입니다. 씬의 메시 노드와 설비 태그를 어떻게 잇느냐.

### 방법 A — 이름 규약 (Convention)

3D 노드 이름 자체에 태그를 넣는 방식입니다.

```
Plant_Root
└── CMP (압축동)
    └── L1
        ├── CMP-P101A              ← 설비 루트. 이름이 곧 태그
        │   ├── CMP-P101A@casing
        │   ├── CMP-P101A@motor
        │   └── CMP-P101A@shaft    ← 회전 애니메이션 대상
        └── CMP-TK201
            └── CMP-TK201@shell
```

- **장점**: 추가 파일이 없고, 씬 하이러키를 눈으로 보면 바로 이해됩니다. `GameObject.Find`나 경로 조회로 바로 찾을 수 있습니다
- **단점**: 3D 담당자가 이름을 바꾸면 끊어집니다. 한 메시가 여러 설비를 포함하거나 한 설비가 여러 메시로 쪼개진 경우를 표현하기 어렵습니다. CAD 변환기가 노드명을 `Part_0042`로 뭉개 버리면 수작업으로 전부 다시 붙여야 합니다

### 방법 B — 사이드카 매니페스트 (Mapping file)

3D는 3D대로 두고, 별도의 매핑 파일이 둘을 잇습니다.

```json
{
  "version": "1.3",
  "site": "SEOUL1",
  "assets": [
    {
      "tag": "CMP-P101A",
      "displayName": "1단 급수펌프 A",
      "class": "CentrifugalPump",
      "parent": "CMP-L1",
      "nodePaths": [
        "Plant_Root/Building_CMP/Equip_grp_12/Part_0042",
        "Plant_Root/Building_CMP/Equip_grp_12/Part_0043"
      ],
      "pivotNode": "Plant_Root/Building_CMP/Equip_grp_12/Part_0043",
      "signals": {
        "vib_rms": "acme/seoul1/cmp/l1/P101A/vib",
        "motor_current": "acme/seoul1/cmp/l1/MCC2/fdr07/i"
      }
    }
  ]
}
```

- **장점**: 3D와 태그가 독립적으로 변해도 매핑 파일만 고치면 됩니다. 1:N, N:1 관계를 그대로 표현할 수 있습니다. 신호 주소까지 한곳에 모여 있어 **이 파일 하나가 트윈의 계약서**가 됩니다
- **단점**: 파일이 늘고, 3D가 바뀌면 매핑도 같이 갱신해야 합니다. 검증 없이 두면 조용히 썩습니다

### 어느 쪽을 고를까

실무 권장은 **둘을 섞는 것**입니다.

> **설비 루트 노드까지는 이름 규약으로, 그 아래 부품 매핑과 신호 연결은 매니페스트로.**

설비 루트는 개수가 수십~수백 개 수준이라 사람이 관리할 수 있고, 이름이 박혀 있으면 씬에서 눈으로 확인하기 좋습니다. 반면 부품 노드는 수천 개라 이름을 손으로 붙이는 건 불가능하고, 신호 주소는 어차피 3D 쪽 관심사가 아니니 파일로 빼는 게 맞습니다.

> 💡 **실무 팁**: 매니페스트는 **3D 담당자가 쓰는 파일이 아니라 빌드가 생성하는 파일**로 만드세요. Day 13의 변환 파이프라인에서 CAD 조립체 구조(STEP의 `NEXT_ASSEMBLY_USAGE_OCCURRENCE`, IFC의 `IfcRelAggregates`)를 읽어 매핑 초안을 자동 생성하고, 사람은 그 결과에 태그만 붙이는 구조가 훨씬 오래 갑니다. CAD에 이미 부품번호가 들어 있는 경우가 많아서, 자동 생성분이 70~80%는 맞습니다.

---

## 4. Unity 쪽 구현 — 레지스트리 하나로 좁히기

Day 15에서 좌표 변환을 `SiteOrigin` 한 곳으로 좁혔듯이, 태그 조회도 **단일 진입점**으로 좁힙니다. 씬 여기저기서 `GameObject.Find("CMP-P101A")`를 호출하는 코드가 생기면 그때부터 통제 불능입니다.

```csharp
using System.Collections.Generic;
using UnityEngine;

/// 태그 ↔ 씬 오브젝트 매핑의 단일 진입점.
/// 씬 시작 시 한 번 구축하고, 이후 조회는 전부 이곳을 거친다.
public class AssetRegistry : MonoBehaviour
{
    public static AssetRegistry Instance { get; private set; }

    readonly Dictionary<string, AssetNode> _byTag = new();

    void Awake()
    {
        Instance = this;
        foreach (var node in FindObjectsByType<AssetNode>(FindObjectsSortMode.None))
        {
            if (string.IsNullOrEmpty(node.tag_))
            {
                Debug.LogWarning($"[Registry] 태그 없는 AssetNode: {Path(node)}");
                continue;
            }
            if (_byTag.TryGetValue(node.tag_, out var dup))
            {
                // 중복 태그는 조용히 덮어쓰면 안 된다. 어느 쪽이 쓰일지 모른다.
                Debug.LogError($"[Registry] 태그 중복 {node.tag_}: {Path(dup)} / {Path(node)}");
                continue;
            }
            _byTag[node.tag_] = node;
        }
        Debug.Log($"[Registry] 자산 {_byTag.Count}건 등록");
    }

    public bool TryGet(string tag, out AssetNode node) => _byTag.TryGetValue(tag, out node);

    /// 태그가 없으면 조상 태그로 폴백한다.
    /// 분전반 신호처럼 하위 설비에 공통으로 걸리는 값을 처리하기 위함.
    public AssetNode Resolve(string tag)
    {
        while (!string.IsNullOrEmpty(tag))
        {
            if (_byTag.TryGetValue(tag, out var n)) return n;
            int i = tag.LastIndexOf('-');
            if (i <= 0) return null;
            tag = tag[..i];
        }
        return null;
    }

    static string Path(Component c)
    {
        var sb = new System.Text.StringBuilder(c.name);
        for (var t = c.transform.parent; t != null; t = t.parent)
            sb.Insert(0, t.name + "/");
        return sb.ToString();
    }
}
```

`AssetNode`는 설비 루트에 하나씩 붙는 가벼운 컴포넌트입니다.

```csharp
using UnityEngine;

/// 설비 루트 오브젝트에 부착. 이 오브젝트 아래 전체가 한 설비다.
public class AssetNode : MonoBehaviour
{
    [Tooltip("설비 태그. 예: CMP-P101A")]
    public string tag_;                 // Unity의 내장 tag와 충돌을 피해 밑줄

    public string displayName;          // "1단 급수펌프 A" — 한글은 여기에만
    public string assetClass;           // "CentrifugalPump" — Day 17의 DTDL 모델 ID와 연결
    public Transform pivot;             // 회전·애니메이션 기준 (Day 20)
    public Renderer[] statusRenderers;  // 경보 시 색을 바꿀 대상 (Day 23)
}
```

이 구조의 이점은 **Day 19 이후가 전부 쉬워진다**는 데 있습니다. MQTT 메시지가 들어오면 토픽에서 태그를 뽑아 `Resolve`로 한 번 찾고, 그 `AssetNode`가 들고 있는 `statusRenderers`나 `pivot`에 값을 흘려보내면 끝입니다. 바인딩 코드가 설비 개수와 무관하게 한 벌로 유지됩니다.

```csharp
// Day 19에서 쓰게 될 형태 — 미리 그림만
void OnMqttMessage(string topic, float value)
{
    var tag = TopicMap.ToTag(topic);          // 토픽 → 태그 변환도 한 곳에서
    var node = AssetRegistry.Instance.Resolve(tag);
    if (node == null) { UnknownTag(tag); return; }
    // node.statusRenderers, node.pivot ... 에 값 적용
}
```

> 💡 **실무 팁**: `Resolve`가 못 찾은 태그는 **버리지 말고 모아서 보고하세요.** 실시간 데이터에 있는데 씬에 없는 태그는 둘 중 하나입니다 — 3D 모델링이 안 된 설비이거나, 태그 표기가 어긋난 것. 전자는 백로그, 후자는 지금 당장 고쳐야 할 버그인데, 로그를 안 남기면 둘 다 조용히 묻힙니다. 미지 태그를 집합에 모아 30초마다 한 번씩만 요약 출력하는 식이면 로그가 폭발하지도 않습니다.

---

## 5. 검증 — 썩기 전에 잡는다

매핑은 **반드시 썩습니다.** 설비가 교체되고, 3D가 갱신되고, 센서가 추가됩니다. 그러니 "잘 관리하자"는 다짐이 아니라 **CI에서 돌아가는 스크립트**가 필요합니다.

검사해야 할 것은 네 가지뿐입니다.

| 검사 | 증상 | 조치 |
|---|---|---|
| **태그 문법 위반** | `P_101`, `p-101`, `P-1` | 정규식으로 즉시 실패 |
| **고아 노드** | 씬에 있는데 매니페스트에 없는 설비 | 태그 부여 또는 비설비로 분류 |
| **유령 태그** | 매니페스트에 있는데 씬에 노드가 없음 | 3D 추가 백로그 |
| **미연결 신호** | 데이터는 들어오는데 받을 설비가 없음 | 태그 표기 교정 |

```python
#!/usr/bin/env python3
"""자산 매니페스트 린터. CI에서 실행하고, 위반이 있으면 종료코드 1."""
import json
import re
import sys
from collections import Counter

TAG_RE = re.compile(r"^[A-Z]{2,4}-[A-Z]{1,3}\d{3}[A-Z]?$")


def lint(manifest_path, scene_nodes_path, live_tags_path=None):
    manifest = json.load(open(manifest_path))
    scene_nodes = set(json.load(open(scene_nodes_path)))   # 씬 익스포트
    assets = manifest["assets"]
    errors, warnings = [], []

    # 1. 문법
    for a in assets:
        if not TAG_RE.match(a["tag"]):
            errors.append(f"태그 문법 위반: {a['tag']}")

    # 2. 중복
    for tag, n in Counter(a["tag"] for a in assets).items():
        if n > 1:
            errors.append(f"태그 중복 {n}회: {tag}")

    # 3. 부모 참조 무결성
    tags = {a["tag"] for a in assets}
    for a in assets:
        p = a.get("parent")
        if p and p not in tags and not p.endswith(("-L1", "-L2")):  # 계층 노드는 예외
            errors.append(f"{a['tag']}의 parent '{p}'가 매니페스트에 없음")

    # 4. 유령 태그 — 매니페스트에 있으나 씬에 노드 없음
    for a in assets:
        missing = [p for p in a["nodePaths"] if p not in scene_nodes]
        if missing:
            warnings.append(f"{a['tag']}: 씬에 없는 노드 {len(missing)}건 (예: {missing[0]})")

    # 5. 고아 노드 — 설비 루트 이름 규약을 따르는데 매니페스트에 없음
    mapped = {p for a in assets for p in a["nodePaths"]}
    for node in scene_nodes:
        leaf = node.rsplit("/", 1)[-1].split("@", 1)[0]
        if TAG_RE.match(leaf) and node not in mapped:
            warnings.append(f"고아 설비 노드: {node}")

    # 6. 미연결 신호 — 실제 수신 태그 중 매핑에 없는 것
    if live_tags_path:
        live = set(json.load(open(live_tags_path)))
        for t in sorted(live - tags):
            warnings.append(f"수신 중이나 매핑 없음: {t}")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"\n자산 {len(assets)}건 / 오류 {len(errors)} / 경고 {len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(lint(*sys.argv[1:]))
```

씬 노드 목록은 Unity 에디터 스크립트로 한 줄씩 뽑아 JSON으로 떨어뜨리면 됩니다. 중요한 건 **이게 자동으로 돌아간다는 사실**이지, 린터 자체가 정교한지가 아닙니다. 위의 여섯 검사만으로도 실무에서 나오는 매핑 사고의 대부분이 걸립니다.

오류와 경고를 나눈 이유도 분명합니다. **문법 위반·중복·참조 깨짐은 즉시 고쳐야 할 오류**지만, 고아 노드와 유령 태그는 **진행 중인 작업의 정상적인 모습**이기도 합니다. 3D가 먼저 들어오고 태그가 나중에 붙는 건 흔한 순서니까요. 전부 오류로 처리하면 사람들이 린터를 꺼 버립니다.

---

## 6. 명명 규칙을 자산 자체에 심어 두기

마지막으로, 규칙이 지켜지게 만드는 현실적인 장치 몇 가지입니다. 문서로만 적어 두면 지켜지지 않습니다.

**임포트 후처리로 자동 태깅.** Unity의 `AssetPostprocessor`로 FBX/glTF 임포트 직후 노드 이름을 검사해, 태그 패턴에 맞는 이름이면 `AssetNode`를 자동으로 붙입니다. 사람이 매번 컴포넌트를 추가하게 두면 빠집니다.

**에디터에서 즉시 피드백.** `AssetNode`의 인스펙터에 태그 정규식 검사를 넣어, 틀린 이름을 입력하면 그 자리에서 빨간 글씨가 뜨게 합니다. 린터가 CI에서 잡아 주는 것보다 30분 빠릅니다.

**태그는 프리팹 단위로 상속.** 같은 모델의 펌프가 여러 대면 프리팹 하나를 만들고 태그만 인스턴스별로 덮어씁니다. 설비 클래스(`assetClass`)는 프리팹에 고정, 태그는 인스턴스별 — 이 분리가 Day 17에서 DTDL 모델과 트윈 인스턴스를 나눌 때 그대로 대응됩니다.

**표시 이름과 태그를 끝까지 분리.** 화면에는 "1단 급수펌프 A"를 띄우되 내부 키는 `CMP-P101A`로 유지합니다. 다국어 지원이 필요해지거나 현장에서 설비 별칭이 바뀌어도 시스템은 흔들리지 않습니다.

> 💡 **실무 팁**: 태그 문법은 **버전을 붙이고 바꾸지 마세요.** 정말 바꿔야 하면 새 문법을 v2로 만들고, v1→v2 매핑 테이블을 영구 보관합니다. 과거 시계열 데이터는 v1 태그로 저장돼 있어서, 매핑 테이블이 없으면 Day 28의 리플레이에서 과거 데이터를 현재 씬에 올릴 방법이 사라집니다. 태그는 데이터베이스의 기본키와 같은 무게로 다뤄야 합니다.

### 상용 플랫폼은 어떻게 하는가

참고로, 이 문제는 상용 플랫폼들도 똑같이 풀고 있습니다. 접근은 거의 같습니다.

- **Azure Digital Twins**: 트윈마다 고유한 `$dtId`를 두고, `relationship`으로 계층을 표현합니다. 3D는 별개이고 ID로 연결합니다
- **AWS IoT TwinMaker**: `entityId`를 가진 엔티티 계층과 3D 씬을 두고, 씬의 노드에 엔티티를 바인딩합니다. 사실상 앞에서 본 사이드카 매니페스트와 같은 구조입니다
- **OpenUSD**: 모든 prim이 `/World/Building/Pump_101` 같은 절대 경로를 갖고, 이 경로가 오버라이드·레퍼런싱의 키가 됩니다. 경로가 곧 ID라서 이름 규약 방식에 가깝습니다

공통점이 보입니다. **어느 쪽이든 "변하지 않는 ID"를 먼저 정하고 3D를 거기에 붙입니다.** 3D를 기준으로 삼는 설계는 어디에도 없습니다.

---

## 📝 핵심 요약

1. 트윈에는 **설비 태그 트리·3D 씬 그래프·데이터 포인트 네임스페이스** 세 개의 트리가 있고, 주인도 변경 주기도 다르다. 억지로 일치시키려 하지 말고, 가장 느리게 변하는 **설비 태그 트리를 기준**으로 나머지를 매핑한다.
2. 태그는 새로 만들지 말고 현장의 것을 가져온다. **ISA-5.1 기능문자 + ISA-95 계층** 조합이 가장 흔하다. 직접 정해야 하면 자리수·구분자·대소문자를 고정하고 문자셋을 `[A-Z0-9-]`로 좁히며, **번호에 의미를 담지 않는다.**
3. 매핑은 **설비 루트까지는 이름 규약, 그 아래 부품과 신호는 사이드카 매니페스트**로 섞는 게 실무 최적이다. 매니페스트는 손으로 쓰지 말고 CAD 조립체 구조에서 초안을 자동 생성한다.
4. Unity에서는 `AssetNode` + `AssetRegistry`로 **조회 진입점을 하나로 좁힌다.** 조상 태그 폴백을 넣어 분전반처럼 공유되는 신호를 처리하고, 못 찾은 태그는 버리지 말고 모아서 요약 보고한다.
5. 매핑은 반드시 썩으므로 **CI 린터로 문법·중복·참조 무결성·고아 노드·유령 태그·미연결 신호**를 검사한다. 문법 위반은 오류, 고아·유령은 경고로 나눠야 사람들이 린터를 끄지 않는다.
6. 규칙은 문서가 아니라 **임포트 후처리와 인스펙터 검증에 심어 둔다.** 표시 이름(한글)과 태그(ASCII)를 끝까지 분리하고, 태그 문법은 기본키와 같은 무게로 다뤄 바꾸지 않는다 — 과거 시계열이 그 태그로 저장돼 있다.

---

## 🔗 참고 자료

- [Azure Digital Twins — 트윈 그래프와 관계 모델링](https://learn.microsoft.com/en-us/azure/digital-twins/concepts-twins-graph)
- [AWS IoT TwinMaker — 엔티티·컴포넌트 계층 만들기](https://docs.aws.amazon.com/iot-twinmaker/latest/guide/twinmaker-gs-entity.html)
- [OpenUSD FAQ — prim 경로와 씬 그래프 구성](https://openusd.org/release/usdfaq.html)
- [Unity Manual — Hierarchy 창과 씬 계층 구조](https://docs.unity3d.com/Manual/Hierarchy.html)

---

*⬅️ 이전: [Day 15 — 좌표계·단위·원점 정렬: 현실과 가상을 맞추는 법](../day-15/)  |  다음: [Day 17 — 메타데이터 모델링: DTDL과 Asset Administration Shell](../day-17/) ➡️*
