---
title: "Day 15 — Blender 설치와 인터페이스 익히기"
date: 2026-08-14
weight: 15
---

> **Phase 3: 3D 모델링 입문 - Blender** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Blender를 설치하고 프로젝트에 맞는 버전(LTS)을 선택할 수 있다
- Viewport, Outliner, Properties, Timeline 등 핵심 인터페이스 영역의 역할을 설명할 수 있다
- 마우스/키보드 단축키로 3D 뷰포트를 자유롭게 탐색하고 오브젝트를 기본 조작할 수 있다

---

## 1. Blender란 무엇이고 왜 Unity와 함께 배우는가

2주차까지는 Unity의 기본 도형(Cube, Sphere 등)만으로 씬을 구성했습니다. 3주차부터는 **Blender**로 직접 만든 3D 에셋을 Unity로 가져오는 파이프라인을 배웁니다.

Blender는 무료·오픈소스 3D 제작 툴로, 모델링·UV 언랩·텍스처링·리깅·애니메이션·렌더링까지 하나의 프로그램에서 처리할 수 있습니다. Unity가 "게임을 실행하고 로직을 처리하는 엔진"이라면, Blender는 "그 게임에 들어갈 3D 에셋을 만드는 제작 도구"라고 이해하면 됩니다.

| 구분 | Unity | Blender |
|---|---|---|
| 역할 | 게임 엔진 (실행, 물리, 렌더링, 로직) | 3D 콘텐츠 제작 툴 (모델링, 애니메이션) |
| 주요 산출물 | 실행 가능한 게임/앱 | FBX/OBJ 등으로 export하는 3D 에셋 |
| 라이선스 | 무료(개인/소규모)·유료(기업) | 완전 무료·오픈소스(GPL) |
| 이번 커리큘럼에서의 위치 | Day 01~14, Day 22 이후 재등장 | Day 15~21 집중 학습 |

> 💡 **실무 팁**: 인디 개발자나 소규모 스튜디오에서 "Unity + Blender" 조합이 특히 많이 쓰이는 이유는 둘 다 무료로 시작할 수 있고, FBX 포맷으로 매끄럽게 연동되기 때문입니다. Day 22~24에서 이 연동 과정을 자세히 다룹니다.

---

## 2. 설치와 초기 설정

### 2.1 다운로드

공식 사이트(blender.org)에서 설치 파일을 받습니다. 버전은 크게 두 갈래로 나뉩니다.

| 버전 유형 | 특징 | 추천 대상 |
|---|---|---|
| **LTS (Long Term Support)** | 장기간 버그 픽스만 제공, 안정성 우선 | 실무/학습용 — **이 커리큘럼은 LTS 기준** |
| 최신 정식 버전 | 신기능 포함, 상대적으로 불안정할 수 있음 | 최신 기능을 바로 써보고 싶은 경우 |

macOS는 Apple Silicon(M1 이상) 전용 빌드가 따로 있으니, Intel용을 잘못 받지 않도록 다운로드 페이지에서 칩셋을 확인합니다. Windows는 `.msi` 인스톨러 또는 Microsoft Store 버전 중 하나를 선택하면 됩니다.

### 2.2 첫 실행 시 체크할 설정

`Edit > Preferences` (macOS는 `Blender > Preferences`)에서 아래 항목을 먼저 확인해두면 이후 실습이 편해집니다.

- **Interface > Translation**: 학습 자료 대부분이 영문 메뉴 기준이므로 처음에는 영어 UI를 유지하는 것을 권장 (필요하면 언어만 한국어로 바꾸고 Tooltip은 영문 유지 가능)
- **Save & Load > Auto Save**: 기본적으로 켜져 있는지 확인 (기본값 2분 간격)
- **Input > Emulate Numpad**: 노트북처럼 Numpad가 없는 키보드를 쓴다면 체크 — 뷰 전환 단축키(Numpad 1/3/7)를 상단 숫자키로 대체 사용 가능
- **Input > Emulate 3 Button Mouse**: 마우스 휠 클릭이 불편한 트랙패드 환경이라면 체크

> 💡 **실무 팁**: `Emulate Numpad`와 `Emulate 3 Button Mouse`는 트랙패드로 작업하는 macOS 사용자가 가장 먼저 켜야 하는 설정입니다. 이걸 안 켜두면 뷰 전환 단축키의 절반을 못 쓰는 것과 같습니다.

---

## 3. 인터페이스 핵심 구성 요소

Blender 화면은 기본적으로 여러 개의 **Editor**(영역)로 나뉘어 있고, 각 영역은 드래그로 크기 조절이나 분할이 가능합니다. 기본 레이아웃(`Layout` 탭)에서 자주 쓰는 영역은 다음과 같습니다.

| 영역 | 위치(기본값) | 역할 |
|---|---|---|
| **3D Viewport** | 화면 중앙 대부분 | 오브젝트를 배치·조작·조형하는 메인 작업 공간 |
| **Outliner** | 우측 상단 | 씬에 있는 모든 오브젝트를 계층 구조(트리)로 표시 — Unity의 Hierarchy와 동일한 개념 |
| **Properties** | 우측 하단 | 선택한 오브젝트/씬/렌더 설정 등 세부 속성 편집 — Unity의 Inspector와 유사 |
| **Timeline** | 화면 하단 | 애니메이션 프레임 재생/편집 (Day 31에서 본격 사용) |
| **Header/Toolbar** | 3D Viewport 상단·좌측 | 모드 전환(Object/Edit Mode), 변형 도구, 뷰 셰이딩 옵션 |

Unity와 비교하면 개념 매핑이 쉽게 이해됩니다.

| Unity | Blender | 공통 역할 |
|---|---|---|
| Hierarchy | Outliner | 씬의 오브젝트 목록/계층 |
| Inspector | Properties | 선택 대상의 속성 편집 |
| Scene View | 3D Viewport | 3D 공간에서 직접 배치/조작 |
| Game View | (Render 결과 미리보기) | 최종 결과물 확인 |

> 💡 **실무 팁**: Properties 패널 왼쪽의 세로 탭 아이콘들(렌더, 출력, 씬, 오브젝트, 모디파이어 등)은 처음엔 헷갈리지만, 아이콘에 마우스를 올리면 툴팁이 뜹니다. Day 17에서 다룰 Modifier 탭(렌치 모양 아이콘)만 먼저 위치를 기억해두세요.

---

## 4. 뷰포트 탐색과 카메라 조작

3D 뷰포트를 자유롭게 움직이지 못하면 모델링 자체가 불가능하므로, 가장 먼저 손에 익혀야 할 조작입니다.

### 4.1 마우스/트랙패드 기본 조작

| 동작 | 마우스(3버튼) | 트랙패드(macOS) |
|---|---|---|
| Orbit(회전) | 마우스 휠 버튼 드래그 | 두 손가락 드래그 |
| Pan(평행 이동) | Shift + 마우스 휠 버튼 드래그 | Shift + 두 손가락 드래그 |
| Zoom(확대/축소) | 마우스 휠 스크롤 | 핀치 줌 (또는 Ctrl + 두 손가락 드래그) |

### 4.2 뷰 전환 단축키 (Numpad)

| 단축키 | 동작 |
|---|---|
| Numpad 1 | 정면(Front) 뷰 |
| Numpad 3 | 측면(Right) 뷰 |
| Numpad 7 | 위(Top) 뷰 |
| Ctrl + Numpad 1/3/7 | 반대 방향(Back/Left/Bottom) 뷰 |
| Numpad 0 | 카메라 뷰 |
| Numpad . (period) | 선택한 오브젝트에 뷰 포커스(Frame Selected) |
| Numpad 5 | 원근(Perspective) ↔ 정사법(Orthographic) 전환 |

> 💡 **실무 팁**: `Numpad .`(선택 대상에 포커스)은 실무에서 가장 많이 쓰는 단축키 중 하나입니다. 오브젝트가 씬 밖 어딘가로 사라져서 안 보일 때, 이 단축키 한 번이면 바로 화면 중앙으로 돌아옵니다.

---

## 5. 오브젝트 기본 조작과 저장

### 5.1 Object Mode에서 이동·회전·스케일

Blender의 오브젝트 변형은 **단축키 한 글자 + Enter/좌클릭 확정** 흐름이 기본입니다. Unity 에디터에서 기즈모를 드래그하는 방식과 달리, 숫자를 직접 입력해 정밀하게 조작하는 경우가 훨씬 많습니다.

| 단축키 | 동작 | 축 제한 예시 |
|---|---|---|
| `G` | Grab(이동) | `G` → `X` → `2` → Enter = X축으로 2 단위 이동 |
| `R` | Rotate(회전) | `R` → `Z` → `45` → Enter = Z축 기준 45도 회전 |
| `S` | Scale(스케일) | `S` → `Shift+Z` → `1.5` → Enter = Z축만 제외하고 1.5배 |
| Esc / 우클릭 | 변형 취소 | 진행 중인 G/R/S 동작을 원위치로 되돌림 |

축 제한은 `X`, `Y`, `Z` 키로 해당 축만 적용하고, `Shift + 축` 키를 누르면 반대로 "그 축만 제외"하고 나머지 두 축에 적용됩니다.

### 5.2 Object Mode vs Edit Mode

지금 단계에서는 개념만 짚고 넘어갑니다 (본격적인 실습은 Day 16부터).

- **Object Mode**: 오브젝트 전체를 하나의 단위로 이동/회전/스케일 — Unity의 Transform 조작과 동일한 개념
- **Edit Mode**: 오브젝트를 이루는 **Vertex(정점)/Edge(모서리)/Face(면)** 단위로 형태 자체를 편집 — Unity에는 없는 개념으로, Day 16의 핵심 주제

`Tab` 키로 두 모드를 즉시 전환할 수 있습니다.

### 5.3 저장하기

`Ctrl + S`로 저장하며, Blender 파일 확장자는 `.blend`입니다. Unity 프로젝트처럼 `Assets` 폴더 규칙이 있는 것은 아니지만, 이후 Day 22 이후의 Import 파이프라인을 고려해 지금부터 프로젝트 폴더 구조를 잡아두는 것이 좋습니다.

```
BlenderProjects/
└── unity-3d-curriculum/
    ├── day15_interface_test.blend
    └── (앞으로 만들 .blend 파일들)
```

> 💡 **실무 팁**: Blender는 저장할 때마다 기존 파일을 `.blend1`, `.blend2`로 백업본을 남깁니다. 실수로 덮어썼을 때 이 백업 파일로 복구할 수 있으니 삭제하지 마세요.

---

## 📝 핵심 요약

1. Blender는 3D 에셋을 만드는 무료 오픈소스 툴로, 이 커리큘럼에서는 안정성 위주의 **LTS 버전**을 기준으로 학습한다
2. Outliner(Hierarchy), Properties(Inspector), 3D Viewport(Scene View)는 Unity 인터페이스와 대응 개념으로 이해하면 익히기 쉽다
3. 뷰포트 탐색(Orbit/Pan/Zoom)과 Numpad 뷰 전환 단축키는 모델링의 가장 기초적인 필수 조작이다
4. 오브젝트 변형은 `G`(이동)/`R`(회전)/`S`(스케일) 단축키 + 축 제한 키(`X`/`Y`/`Z`) + 숫자 입력 조합으로 정밀하게 처리한다
5. Object Mode는 오브젝트 단위 조작, Edit Mode는 Vertex/Edge/Face 단위 편집이며 `Tab`으로 전환한다 (Day 16에서 본격 실습)

---

## 🔗 참고 자료

- [Blender Manual — Introduction](https://docs.blender.org/manual/en/latest/getting_started/index.html)
- [Blender Manual — 3D Viewport Navigation](https://docs.blender.org/manual/en/latest/editors/3dview/navigate/introduction.html)
- [Blender Manual — Basic Controls (Move, Rotate, Scale)](https://docs.blender.org/manual/en/latest/scene_layout/object/editing/transform/introduction.html)

---

*⬅️ 이전: [Day 14 — 2주차 정리: 간단한 인터랙티브 씬 완성](../day-14/)  |  다음: [Day 16 — 기본 도형(Mesh) 모델링과 편집 모드](../day-16/) ➡️*
