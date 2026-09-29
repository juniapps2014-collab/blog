---
title: "Day 60 — 최종 폴리싱과 포트폴리오 정리"
date: 2026-09-28
weight: 60
---

> **Phase 9: 캡스톤 프로젝트** | 예상 학습 시간: 50분

---

## 🎯 학습 목표

- 캡스톤 씬에 남은 자잘한 버그와 어색한 부분을 체계적인 체크리스트로 찾아내고 마무리할 수 있다
- Player Settings와 빌드 설정 을 만들 수 있다
- 60일간의 결과물을 스크린샷·플레이 영상·README로 정리해 포트폴리오로 제시할 수 있다
---

## 1. 오릈의 자료 - "완쀱"물 "완쀱도"슴 다를려

Day 57관유팅수기획팅고 Day 58~59에서 모델링·임포트·애니메이션·라이팅까지 채운 캡스톤 씬이 이제 기능적으로 바생뗭 바시스닸면 텭젵이은과 룜보. 인햼 실조진만 싒다분여줄 수 있는 니리기입니다. 오늘은 "기능은 되지만 다듬어지지 않은가 상태"를 "제출 가능한 상태"로 끌어올리는 마지막 작업을 합니다.

```
1. Unity: 버그/오류 로그 최종 점검 (Console 창 Clear on Play 끄고 전체 플레이)
2. Unity: UI/사운드/카메라 등 "체감 완성도"에 영향을 주는 디테일 다듬기
3. Unity: Player Settings 및 빌드 설정 최종 점검
4. Unity: 실제 빌드(Standalone 또는 WebGL) 생성 및 실행 검증
5. 결과물: 스크린샷/영상 캡처
6. 결과물: README 및 프로젝트 소개 문서 작성
```

오늘 작업의 핵심은 "새로운 기능을 추가하지 않는 것"입니다. 캡스톤 마감일에 새 기능을 욕심내다가 오히려 안정성을 해치는 경우가 실무에서도 매우 흔합니다.

> 💡 **실무 프로젝트에서도 마일스톤 직전 며칠은 "Feature Freeze(기능 동결)" 기간으로 정해두고 버그 수정과 폴리싱만 진행합니다. 오늘 하루는 나만의 Feature Freeze 날이라고 생각하세요.

---

## 2. 최종 폴리싱 체크리스트

씬을 처음부터 끝까지 플레이하면서 아래 항목을 하나씩 확인합니다. 체크박스 형태로 정리해두면 빠뜨리는 항목 없이 점검할 수 있습니다.

```
[ ] Console 창에 빨간 Error가 하나도 없는가 (노란 Warning은 원인 파악 후 판단)
[ ] 씬 시작 시 카메라가 의도한 위치/각도에서 시작하는가
[ ] 캐릭터 이동, 점프, 상호작용 등 핵심 조작이 매 실행마다 일관되게 동작하는가
[ ] 오브젝트가 바닥을 뚫고 떨어지거나(콜라이더 누락), 허공에 떠 있지 않은가
[ ] 텍스처가 깨지거나(분홍색 Missing Material) 누락된 오브젝트가 없는가
[ ] 라이트맵이 밀리거나 깜빡이는(Light Bleeding) 부분이 없는가
[ ] 사운드가 있다면 배경음/효과음의 볼륨 밸런스가 적절한가
[ ] UI 텍스트에 오탈자나 플레이스홀더 텍스트("Lorem ipsum", "TODO")가 남아있지 않은가
```

| 흔한 문제 | 원인 | 해결 방법 |
|---|---|---|
| 분홍색 오브젝트 | 셰이더/머티리얼이 현재 렌더 파이프라인과 불일치 | Edit > Render Pipeline > Upgrade Materials 또는 머티리얼 재생성 |
| 캐릭터가 바닥을 뚫음 | Collider 누락 또는 Rigidbody의 Collision Detection이 Discrete | Continuous Dynamic으로 변경, 바닥 Collider 재확인 |
| 콘솔에 반복되는 NullReferenceException | Inspector에서 SerializeField 참조가 비어있음 | 스택 트레이스를 더블클릭해 해당 컴포넌트의 필드 재연결 |
| 라이트맵 얼룩/이음새 | Lightmap Resolution 부족 또는 UV2 겹침 | Lightmap Resolution 상향, Generate Lightmap UVs 재생성 후 재베이크 |

> 💡 **실무 팁**: Console 창 우측 상단의 "Clear on Play" 옵션을 켜두면 플레이할 때마다 이전 로그가 지워져서, 지금 실행에서 실제로 발생한 에러만 깔끔하게 볼 수 있습니다. 폴리싱 단계에서는 이 옵션을 반드시 켜두세요.

---

## 3. Player Settings와 빌드 설정 최종 점검

기능 점검이 끝났다면 실제로 "실행에서 파일"로 내보낼 준비를 합니다. `File > Build Settings`를 열기 전에 `Edit > Project Settings > Player`에서 아래 항목을 확인합니다.

| 설정 항목 | 확인할 내용 |
|---|---|
| Company Name / Product Name | 포트폴리오에 표시될 이름이므로 임시값("DefaultCompany" 등)이 남아있지 않은지 |
| Icon | 기본 Unity 아이콘이 아닌, 프로젝트를 대표하는 아이콘으로 교체했는지 |
| Default Screen Width/Height | 시연 환경(노트북 화면 등)에 맞는 해상도인지 |
| Resolution and Presentation > Fullscreen Mode | 포트폴리오 시연용이라면 Windowed로 두는 것이 여러 화면에서 안전 |
| Splash Screen | Unity Personal 버전은 스플래시 화면이 강제 노출됨을 인지하고 있는지 |

```
빌드 절차 (Standalone 기준)
1. File > Build Settings 오픈
2. Scenes In Build 목록에 캡스톤 씬이 포함되어 있는지 확인 (체크박스 On)
3. Platform을 PC, Mac, Linux Standalone으로 선택 (또는 WebGL)
4. Build 버튼 클릭 → 별도 폴더 지정 (예: Builds/Day60_Capstone/)
5. 빌드 완료 후 실행 파일을 더블클릭해 에디터가 아닌 "실제 빌드"에서 재생 테스트
```

에디터에서는 잘 되던 것이 빌드에서는 깨지는 경우가 은근히 많습니다. 대표적으로 리소스 경로 문제(`Resources` 폴더 밖의 에셋을 코드로 직접 로드하는 경우), 대소문자 구분(Windows는 관대하지만 빌드 플랫폼에 따라 엄격할 수 있음), 씬 인덱스 하드코딩(`SceneManager.LoadScene(1)`처럼 숫자로 참조했는데 Build Settings에 씬 순서가 다르게 등록된 경우) 등이 있습니다.

```csharp
// 씬 이름으로 로드하면 Build Settings의 씬 순서가 바뀌어도 안전합니다
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneLoader : MonoBehaviour
{
    [SerializeField] private string capstoneSceneName = "CapstoneScene";

    public void LoadCapstoneScene()
    {
        // 인덱스(0, 1, 2...) 대신 이름으로 참조 - Build Settings 순서 변경에 안전
        SceneManager.LoadScene(capstoneSceneName);
    }
}
```

> 💡 **실무 팁**: WebGL 빌드는 브라우저에서 바로 링크를 공유할 수 있어 포트폴리오용으로 특히 유용합니다. 단, 빌드 시간이 길고 일부 기능(파일 시스템 접근 등)에 제약이 있으니, 캡스톤 씬이 WebGL에서도 정상 동작하는지 반드시 별도로 테스트하세요.

---

## 4. 포트폴리오용 결과물 캡처 - 스크린샷과 플레이 영상

빌드가 정상 동작한다면, 이제 실제로 포트폴리에 올릴 시각 자료를 만듭니다. 글로만 설명하는 것보다 스크린샷 3~5장과 짧은 플레이 영상 1개가 훨씬 설득력이 있습니다.

| 자료 유형 | 권장 사양 | 촬영 팁 |
|---|---|---|
| 스크린샷 | 1920×1080 이상, PNG | Game 뷰 비율을 16:9로 맞추고, UI가 가려지지 않는 구도에서 촬영 |
| 플레이 영상 | 30~90초, 1080p, MP4 | 이동-상호작용-핵심 연출(라이팅/이펙트) 순으로 짧게 편집 |
| Before/After 비교 | 동일 구도에서 2장 | Day 1~2 결과물과 Day 60 결과물을 나란히 배치하면 성장 스토리가 됨 |

```
Unity 자체 기능으로 고화질 스크린샷 찍는 방법
1. Window > General > Game 창에서 해상도를 원하는 값(예: 1920x1080)으로 설정
2. Game 창 우측 상단 카메라 아이콘(또는 Ctrl+Shift+F12) 클릭 시 스크린샷 저장 가능한 에디터/패키지 활용
3. 또는 코드로: ScreenCapture.CaptureScreenshot("capture.png") 를 버튼 이벤트에 연결
```

```csharp
using UnityEngine;

public class PortfolioScreenshot : MonoBehaviour
{
    // 에디터에서 F12 키를 누르면 PNG로 저장 - 포트폴리오용 캡처에 활용
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.F12))
        {
            string fileName = $"Capstone_{System.DateTime.Now:yyyyMMdd_HHmmss}.png";
            ScreenCapture.CaptureScreenshot(fileName);
            Debug.Log($"스크린샷 저장됨: {fileName}");
        }
    }
}
```

> 💡 **실무 팁**: 영상은 편집 과정에서 배경음악을 새로 입히기보다, 씬 안의 실제 오디오(발소리, 환경음)를 그대로 살리는 편이 "실제 동작하는 결과물"이라는 신뢰를 줍니다. 과도한 배경음악은 오히려 실제 게임플레이 사운드 품질을 가리는 역효과를 냅니다.

---

## 5. 프로젝트 README와 발표 자료 작성

시각 자료를 준비했다면 마지막으로 텍스트로 프로젝트를 설명하는 문서를 작성합니다. 포트폴리오를 보는 사람(채용 담당자, 협업 파트너)은 프로젝트를 직접 실행해보지 못하는 경우가 많으므로, README 하나만 읽어도 무엇을 만들었는지 파악할 수 있어야 합니다.

```
README 권장 구성
1. 프로젝트 제목과 한 줄 요약 (이 프로젝트가 "무엇"인지 3초 안에 전달)
2. 스크린샷 또는 GIF (가장 위쪽에 배치 - 텍스트보다 먼저 눈에 들어옴)
3. 사용 기술 스택 (Unity 버전, URP 여부, Blender, 주요 패키지)
4. 핵심 기능 목록 (애니메이션 전환, 라이팅 연출, 최적화 포인트 등)
5. 배운 점 / 어려웠던 점과 해결 과정 (기술적 의사결정을 보여주는 부분)
6. 실행 방법 (빌드 다운로드 링크 또는 WebGL 링크)
```

| 항목 | 나쁜 예 | 좋은 예 |
|---|---|---|
| 한 줄 요약 | "유니티로 만든 프로젝트입니다" | "60일간 Blender 모델링부터 Unity 라이팅까지 학습한 결과물로, 캐릭터 애니메이션과 환경 연출을 통합한 미니 인터랙티브 씬" |
| 배운 점 | "여러 가지를 배웠습니다" | "Blend Tree의 dampTime을 조정하지 않으면 애니메이션 전환이 부자연스럽다는 것을 발견했고, SetFloat에 전환 시간을 추가해 해결했습니다" |
| 기술 스택 | "Unity, C#" | "Unity 6 (URP), Blender 4.x, Cinemachine, Timeline, Shader Graph" |

> 💡 **실무 팁**: 채용 포트폴리오에서 가장 눈에 띄는 항목은 "무엇을 만들었는가"보다 "어떤 문제를 어떻게 해결했는가"입니다. 60일 동안 겪었던 구체적인 트러블슈팅 경험(예: Day 23의 스케일 문제, Day 59의 애니메이션-라이팅 어긋남)을 1~2가지 골라 README나 면접에서 이야기할 수 있도록 정리해두면 훨씬 강한 인상을 남깁니다.

---

## 📝 핵심 요약

1. 캡스톤 마무리 단계에서는 새 기능을 추가하기보다 기존 기능의 버그와 디테일을 다듬는 "Feature Freeze"에 집중해야 한다
2. Console 창의 에러/경고, 콜라이더 누락, 머티리얼 깨짐 등은 체크리스트로 순서대로 점검하면 빠짐없이 잡아낼 수 있다
3. 에디터에서 잘 되던 기능도 실제 빌드에서는 리소스 경로, 씬 인덱스 등의 문제로 깨질 수 있으므로 반드시 빌드본으로 재검증해야 한다
4. 포트폴리오는 스크린샷·짧은 플레이 영상 같은 시각 자료가 텍스트 설명보다 훨씬 설득력이 있다
5. README에는 결과물 자체보다 "어떤 문제를 어떻게 해결했는가"를 구체적으로 담는 것이 포트폴리오의 완성도를 높인다

---

## 🔗 참고 자료

- [Unity Manual — Publishing Builds](https://docs.unity3d.com/Manual/PublishingBuilds.html)
- [Unity Manual — Player Settings](https://docs.unity3d.com/Manual/class-PlayerSettings.html)
- [Unity Scripting API — ScreenCapture](https://docs.unity3d.com/ScriptReference/ScreenCapture.html)

---

*⬅️ 이전: [Day 59 — 애니메이션과 라이팅으로 완성도 높이기](../day-59/)  |  🎉 60일 Unity + 3D 모델링 커리큘럼 완주!*
