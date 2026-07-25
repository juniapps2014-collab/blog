---
title: "Day 01 — Unity 설치 및 에디터 인터페이스 익히기"
date: 2026-07-25
weight: 1
---

> **Phase 1: Unity 기초 입문** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Unity Hub를 통해 원하는 버전의 Unity 에디터를 설치하고 새 프로젝트를 만들 수 있다
- Unity 에디터의 핵심 창(Scene, Game, Hierarchy, Inspector, Project, Console)의 역할을 설명할 수 있다
- 자주 쓰는 단축키와 레이아웃 커스터마이징으로 기본 작업 흐름을 만들 수 있다

---

## 1. Unity Hub와 에디터 설치

Unity는 에디터를 직접 다운로드하지 않고, **Unity Hub**라는 런처 프로그램을 통해 버전을 관리합니다. Unity 프로젝트마다 요구하는 에디터 버전이 다를 수 있기 때문에, Hub에서 여러 버전을 동시에 설치해두고 프로젝트별로 골라 쓰는 방식이 표준입니다.

설치 순서:

1. [unity.com/download](https://unity.com/download)에서 Unity Hub를 설치
2. Hub 실행 후 Unity 계정으로 로그인 (개인/학생용은 Personal 라이선스 무료)
3. 좌측 **Installs** 탭 → **Install Editor** → **LTS(Long Term Support)** 버전 선택 (신규 학습자는 최신 LTS 권장 — 안정성이 가장 높음)
4. 모듈 선택 화면에서 필요한 빌드 타겟 체크 (예: Windows/Mac용 개발이면 기본으로 충분, 모바일까지 고려하면 Android Build Support 등 추가)

> 💡 **실무 팁**: 여러 프로젝트를 오가며 작업할 계획이라면 처음부터 LTS 버전 하나로 통일하는 것이 좋습니다. 버전이 다르면 프로젝트를 열 때마다 "Upgrade" 경고가 뜨고, 팀 작업 시 충돌의 원인이 됩니다.

---

## 2. 새 프로젝트 생성과 템플릿 선택

Hub의 **Projects** 탭 → **New Project**에서 템플릿을 고를 수 있습니다.

| 템플릿 | 용도 |
|---|---|
| 3D (URP) | 이 커리큘럼에서 사용할 기본 템플릿. 범용 렌더 파이프라인(Universal Render Pipeline) 적용 |
| 3D (Built-in Render Pipeline) | 구버전 방식, 레거시 프로젝트 호환용 |
| 2D (URP) | 2D 게임 전용 |
| VR / Mobile | 특정 플랫폼 특화 템플릿 |

이 커리큘럼은 이후 URP 기반 머티리얼/셰이더를 다루므로 **3D (URP)** 템플릿으로 시작하는 것을 권장합니다. 프로젝트 이름은 영문/숫자/하이픈만 사용하는 것이 안전합니다 (경로에 한글이나 공백이 섞이면 일부 빌드 툴에서 오류가 날 수 있습니다).

---

## 3. 에디터 핵심 창 구성

Unity 에디터를 처음 열면 여러 개의 창(Window)이 보입니다. 각 창의 역할을 명확히 아는 것이 이후 모든 학습의 기반이 됩니다.

- **Scene 뷰**: 게임 월드를 3D 공간에서 직접 편집하는 창. 오브젝트를 배치, 이동, 회전, 크기 조절
- **Game 뷰**: 실제 플레이 시 카메라를 통해 보이는 최종 화면. Play 버튼을 누르면 여기서 미리보기 실행
- **Hierarchy 창**: 현재 Scene에 존재하는 모든 GameObject를 트리 구조로 나열. 부모-자식 관계 확인 가능
- **Inspector 창**: Hierarchy나 Project에서 선택한 오브젝트의 세부 속성(Component, Transform 값 등)을 표시하고 수정
- **Project 창**: 프로젝트에 포함된 모든 에셋(스크립트, 모델, 텍스처, Prefab 등) 파일 브라우저
- **Console 창**: `Debug.Log` 출력, 경고(warning), 에러(error) 메시지가 표시되는 곳. 스크립트 디버깅의 시작점

> 💡 **실무 팁**: Console 창은 항상 열어두는 습관을 들이세요. 빨간 에러 메시지를 무시하고 넘어가면 나중에 원인 파악이 훨씬 어려워집니다.

---

## 4. 자주 쓰는 단축키와 레이아웃

Scene 뷰에서 오브젝트를 다루는 기본 조작(Gizmo 도구):

```
Q — Hand(이동/뷰 패닝) 도구
W — Move(이동) 도구
E — Rotate(회전) 도구
R — Scale(크기) 도구
F — 선택한 오브젝트로 뷰 포커스 이동
Ctrl/Cmd + P — Play 모드 시작/정지
```

레이아웃은 우측 상단의 **Layout** 드롭다운에서 저장/전환할 수 있습니다. 처음에는 기본 제공되는 **Default** 레이아웃을 쓰다가, 스크립팅 작업이 많아지면 Project 창과 Console 창을 넓게 배치한 커스텀 레이아웃을 만들어두면 편리합니다.

> 💡 **실무 팁**: Play 모드에서 Scene을 수정하면 저장되지 않고 Play 모드 종료 시 원래대로 되돌아갑니다. 실수로 Play 모드에서 오브젝트를 옮기고 "왜 저장이 안 되지?"라고 당황하지 않도록, Game 뷰 테두리가 파란색(Play 중)인지 항상 확인하는 습관을 들이세요.

---

## 📝 핵심 요약

1. Unity Hub로 에디터 버전을 관리하며, 학습용으로는 최신 LTS 버전 하나로 통일하는 것이 안전하다
2. 새 프로젝트는 이후 URP 기반 학습을 이어갈 것이므로 3D (URP) 템플릿으로 시작한다
3. Scene/Game/Hierarchy/Inspector/Project/Console 6개 창의 역할을 구분해서 이해하는 것이 모든 작업의 출발점이다
4. Q/W/E/R 단축키로 Gizmo 도구를 빠르게 전환하고, Play 모드 중 수정 사항은 저장되지 않는다는 점을 기억한다

---

## 🔗 참고 자료

- [Unity Hub 매뉴얼](https://docs.unity3d.com/hub/manual/index.html)
- [Unity 에디터 인터페이스 개요 (Unity Manual)](https://docs.unity3d.com/Manual/UsingTheEditor.html)

---

*다음: [Day 02 — GameObject와 Transform 이해하기](../day-02/) ➡️*
