---
title: "Day 10 — Unity UI 시스템(Canvas, UI 요소) 기초"
date: 2026-08-09
weight: 10
---

> **Phase 2: Unity 핵심 시스템** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Canvas의 세 가지 Render Mode(Screen Space - Overlay/Camera, World Space)의 차이와 적합한 사용 사례를 설명할 수 있다
- RectTransform의 Anchor와 Pivot 개념을 이해하고 다양한 해상도에 대응하는 UI를 구성할 수 있다
- Button, Text, Image, Slider 등 기본 UI 요소를 배치하고 스크립트에서 이벤트를 연결할 수 있다

---

## 1. Canvas — 모든 UI 요소의 뿌리

Unity의 UI 요소(Button, Text, Image 등)는 항상 **Canvas** 오브젝트의 자식으로 존재해야 렌더링됩니다. Hierarchy에서 `UI > Button` 등을 생성하면 Canvas가 없을 경우 Unity가 자동으로 하나를 만들어줍니다. Canvas는 3D 씬 위에 UI를 그리는 별도의 렌더링 레이어라고 이해하면 됩니다.

Canvas 컴포넌트의 `Render Mode`는 세 가지이며, 이 선택에 따라 UI가 화면에 그려지는 방식이 완전히 달라집니다.

| Render Mode | 동작 방식 | 주 사용처 |
|---|---|---|
| Screen Space - Overlay | 카메라와 무관하게 항상 화면 최상단에 그려짐 | 대부분의 HUD, 메뉴, 설정 창 |
| Screen Space - Camera | 지정한 카메라의 화면 공간에 그려지되, 카메라의 Far/Near 영향을 받음 | 카메라 이펙트(Post-processing)를 UI에도 적용하고 싶을 때 |
| World Space | 씬의 3D 오브젝트처럼 특정 위치에 배치됨 | 캐릭터 머리 위 체력바, VR UI, 게임 내 표지판 |

> 💡 **실무 팁**: 특별한 이유가 없다면 `Screen Space - Overlay`로 시작하세요. 가장 단순하고 성능 오버헤드도 적으며, 대부분의 2D UI 요구사항을 충족합니다. 3D 공간에 UI를 "붙여야" 할 때만 World Space를 고려하면 됩니다.

Canvas에는 반드시 **Canvas Scaler**와 **Graphic Raycaster** 컴포넌트가 함께 붙습니다. Graphic Raycaster는 마우스/터치 입력이 어떤 UI 요소에 닿았는지 판정하는 역할을 하며, 이 컴포넌트가 없으면 버튼 클릭 자체가 인식되지 않습니다.

---

## 2. Canvas Scaler — 해상도가 달라도 깨지지 않는 UI

모바일과 PC처럼 화면 해상도가 천차만별인 환경에서, UI 요소를 고정 픽셀 크기로만 배치하면 작은 화면에서는 넘치고 큰 화면에서는 작게 보이는 문제가 생깁니다. Canvas Scaler의 `UI Scale Mode`가 이 문제를 해결합니다.

| UI Scale Mode | 설명 | 사용 시점 |
|---|---|---|
| Constant Pixel Size | 항상 지정한 픽셀 크기 그대로 유지 | 해상도 편차가 거의 없는 환경(에디터 도구 등) |
| Scale With Screen Size | 기준 해상도(Reference Resolution) 대비 비율로 UI 전체를 확대/축소 | 모바일/멀티 해상도 대응 시 사실상 표준 |
| Constant Physical Size | 기기의 실제 인치/DPI 기준으로 물리적 크기 유지 | 기기마다 실제 크기가 같아야 하는 특수 UI |

`Scale With Screen Size`를 선택하면 `Reference Resolution`(예: 1920×1080)과 `Screen Match Mode`, `Match` 슬라이더를 설정합니다. `Match` 값을 0에 가깝게 두면 너비 기준으로, 1에 가깝게 두면 높이 기준으로 스케일이 계산됩니다.

```
Canvas Scaler 권장 설정 (모바일 세로 게임 예시)
- UI Scale Mode: Scale With Screen Size
- Reference Resolution: 1080 x 1920
- Screen Match Mode: Match Width Or Height
- Match: 0.5 (너비와 높이 절충)
```

> 💡 **실무 팁**: `Match` 값 0.5는 만능이 아닙니다. 세로로 긴 UI(예: 채팅 리스트)가 많으면 1(높이 기준)에 가깝게, 가로로 넓은 HUD 요소가 많으면 0(너비 기준)에 가깝게 조정하는 것이 실제로 더 안정적입니다.

---

## 3. RectTransform — Anchor와 Pivot 제대로 이해하기

일반 GameObject는 `Transform`(Position, Rotation, Scale)을 쓰지만, UI 요소는 **RectTransform**을 씁니다. RectTransform이 어려운 이유는 위치뿐 아니라 "부모 크기가 변할 때 어떻게 따라갈 것인가"까지 정의하기 때문입니다.

- **Pivot**: 요소 자신의 회전/크기 조절 기준점 (0~1 범위, 0.5, 0.5가 중앙)
- **Anchor**: 부모 RectTransform 내에서 이 요소가 "고정되는 기준점" — 4개의 삼각형 아이콘으로 표시됨
- **Anchored Position**: Anchor 기준으로부터의 오프셋

Anchor의 4개 점이 한 곳에 모여 있으면(예: 중앙) 부모 크기가 변해도 요소는 항상 같은 상대 위치를 유지하며 크기는 고정됩니다. 반대로 Anchor의 4개 점을 각각 부모의 네 모서리로 벌려서 **Stretch** 상태로 만들면, 부모 크기 변화에 맞춰 요소 자체의 크기도 함께 늘어나거나 줄어듭니다.

| Anchor 설정 | 부모 크기 변경 시 동작 | 대표 사용처 |
|---|---|---|
| 한 점에 고정 (예: 좌상단) | 위치 고정, 크기 고정 | 좌상단 미니맵, 우상단 설정 버튼 |
| 좌우 Stretch, 상하 고정 | 가로로 늘어남 | 상단 헤더 바 |
| 4방향 모두 Stretch | 부모 전체를 채움 | 배경 패널, 전체화면 오버레이 |

```csharp
// 코드로 RectTransform 위치/크기 조작하기
RectTransform rt = GetComponent<RectTransform>();
rt.anchoredPosition = new Vector2(0f, -50f); // 앵커 기준 위로부터 50px 아래
rt.sizeDelta = new Vector2(200f, 60f);        // Stretch가 아닐 때의 가로/세로 크기
```

> 💡 **실무 팁**: UI가 "해상도를 바꾸면 이상한 곳에 붙어있다"는 문제의 90%는 Anchor를 부모의 특정 모서리/변에 맞추지 않고 기본값(중앙)인 채로 방치했기 때문입니다. UI를 배치하기 전에 항상 Anchor Preset(Alt+클릭 시 위치까지 같이 설정)부터 목적에 맞게 지정하는 습관을 들이세요.

---

## 4. 기본 UI 요소와 이벤트 연결

가장 자주 쓰는 UI 요소들과 각각의 핵심 속성입니다.

| 요소 | 핵심 컴포넌트 | 주요 용도 |
|---|---|---|
| Text / TextMeshPro - Text | 텍스트 렌더링 | 라벨, 점수 표시, 대화창 |
| Image | Sprite 렌더링, Fill Amount로 게이지 표현 가능 | 아이콘, 체력바 배경 |
| Button | Image + 클릭 이벤트 | 메뉴 선택, 액션 트리거 |
| Slider | 값 범위를 드래그로 조절 | 볼륨 조절, 진행률 표시 |
| Toggle | On/Off 상태 저장 | 설정 체크박스 |
| Scroll Rect | 콘텐츠가 넘칠 때 스크롤 처리 | 인벤토리, 리스트뷰 |

> 💡 **실무 팁**: 기본 `Text`보다는 **TextMeshPro(TMP)**를 쓰는 것이 사실상 표준입니다. 폰트 렌더링 품질(SDF 기반이라 확대해도 흐려지지 않음), 리치 텍스트 태그, 아웃라인/그림자 효과 등에서 기본 Text보다 훨씬 우수합니다. Unity 최신 버전은 UI 생성 메뉴에서 기본적으로 TMP를 권장합니다.

버튼 클릭 이벤트는 에디터의 Inspector에서 `OnClick()` 리스트에 함수를 드래그로 등록할 수도 있고, 코드에서 직접 연결할 수도 있습니다. 실무에서는 재사용성과 디버깅 편의성 때문에 코드 연결을 더 선호하는 경우가 많습니다.

```csharp
using UnityEngine;
using UnityEngine.UI;

public class ShopUI : MonoBehaviour
{
    [SerializeField] private Button buyButton;
    [SerializeField] private Slider volumeSlider;

    private void OnEnable()
    {
        buyButton.onClick.AddListener(OnBuyClicked);
        volumeSlider.onValueChanged.AddListener(OnVolumeChanged);
    }

    private void OnDisable()
    {
        // 이벤트 리스너 해제를 잊으면 오브젝트가 파괴돼도 참조가 남아 메모리 누수로 이어질 수 있음
        buyButton.onClick.RemoveListener(OnBuyClicked);
        volumeSlider.onValueChanged.RemoveListener(OnVolumeChanged);
    }

    private void OnBuyClicked()
    {
        Debug.Log("구매 버튼 클릭됨");
    }

    private void OnVolumeChanged(float value)
    {
        AudioListener.volume = value;
    }
}
```

---

## 5. EventSystem — 입력을 UI로 전달하는 다리

씬에 UI가 하나라도 있으면 Unity가 **EventSystem** 오브젝트를 자동 생성합니다. EventSystem은 마우스/터치/키보드/게임패드 입력을 받아 어떤 UI 요소가 이 입력을 처리해야 하는지 판단하고 전달하는 중앙 관리자입니다.

EventSystem이 씬에 없거나 실수로 삭제되면 버튼 클릭, 슬라이더 드래그 등 모든 UI 상호작용이 멈춥니다. 씬을 여러 개 관리하다 보면 "UI가 갑자기 반응하지 않는다"는 문제의 원인이 EventSystem 중복 생성(씬 전환 시 2개 이상 존재)이나 삭제인 경우가 흔합니다.

```csharp
// 현재 선택된(포커스된) UI 요소 확인 - 게임패드 내비게이션 디버깅에 유용
using UnityEngine.EventSystems;

GameObject selected = EventSystem.current.currentSelectedGameObject;
Debug.Log(selected != null ? selected.name : "선택된 UI 없음");
```

> 💡 **실무 팁**: 게임패드나 키보드로 UI를 조작하는 콘솔/PC 게임을 만든다면, 시작 시 `EventSystem.current.SetSelectedGameObject(firstButton)`으로 첫 번째 버튼을 강제 선택해줘야 합니다. 마우스 입력이 없는 환경에서는 아무것도 선택되지 않은 상태로 남아 게임패드 방향키가 먹통이 되는 경우가 흔합니다.

---

## 📝 핵심 요약

1. 모든 UI 요소는 Canvas의 자식이어야 하며, Render Mode(Overlay/Camera/World Space)는 UI가 어떤 공간 기준으로 그려질지를 결정한다
2. Canvas Scaler의 `Scale With Screen Size` 모드는 여러 해상도에 대응하는 사실상의 표준 설정이다
3. RectTransform의 Anchor는 부모 크기 변화에 대한 반응 방식을, Pivot은 요소 자신의 기준점을 정의하며 둘을 혼동하면 해상도별 UI 붕괴로 이어진다
4. 기본 Text보다 TextMeshPro가 렌더링 품질과 기능 면에서 사실상 표준으로 쓰인다
5. EventSystem은 입력을 UI로 전달하는 필수 컴포넌트이며, 씬에서 누락되거나 중복되면 모든 UI 상호작용이 멈춘다

---

## 🔗 참고 자료

- [Unity Manual — Canvas](https://docs.unity3d.com/Manual/UICanvas.html)
- [Unity Manual — RectTransform](https://docs.unity3d.com/Manual/class-RectTransform.html)
- [Unity Manual — Canvas Scaler](https://docs.unity3d.com/Manual/script-CanvasScaler.html)

---

*⬅️ 이전: [Day 09 — Collider와 충돌 감지](../day-09/)  |  다음: [Day 11 — 카메라 시스템과 시네마틱 기초](../day-11/) ➡️*
