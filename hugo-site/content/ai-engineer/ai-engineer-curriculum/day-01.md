# Day 01 — Python & Linux: AI 엔지니어의 개발 환경

> **Phase 1: 기초** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- AI 엔지니어링에서 Python이 사실상 표준 언어인 이유를 설명할 수 있다
- Linux 기본 명령어로 GPU 서버 환경을 다룰 수 있다
- 가상환경(venv)과 패키지 관리 흐름을 이해한다

---

## 1. 왜 Python인가?

대부분의 GPU 제공업체(Runpod, Lambda, AWS)와 딥러닝 프레임워크(PyTorch, Transformers, LangChain, LangGraph)는 Python 기반입니다.

**핵심 이유:**

- **생태계** — PyTorch, Hugging Face, LangChain 등 거의 모든 LLM 도구가 Python 우선 지원
- **빠른 프로토타이핑** — 문법이 단순해 아이디어를 즉시 코드로 옮기기 쉬움
- **C/CUDA 바인딩** — 내부 연산은 C++/CUDA로 최적화되어 있고, Python은 그 위의 인터페이스 역할

---

## 2. Linux — GPU 서버의 기본 운영체제

대부분의 GPU 클라우드(Runpod 등)는 Ubuntu 기반 Linux 컨테이너를 제공합니다.

**필수 명령어:**

| 명령어 | 용도 |
|---|---|
| `ls -la` | 파일/디렉토리 목록 (숨김 파일 포함) |
| `cd`, `pwd` | 디렉토리 이동/현재 위치 확인 |
| `cp`, `mv`, `rm` | 파일 복사/이동/삭제 |
| `chmod +x` | 실행 권한 부여 |
| `ps aux` | 실행 중인 프로세스 확인 |
| `kill -9 <pid>` | 프로세스 강제 종료 |
| `df -h` | 디스크 사용량 확인 |
| `top` / `htop` | 실시간 리소스 모니터링 |

> 💡 **실무 팁**: GPU 서버는 대부분 SSH로 접속하는 헤드리스(headless) 환경입니다. GUI 없이 터미널만으로 작업하는 것에 익숙해져야 합니다.

---

## 3. 가상환경과 패키지 관리

여러 프로젝트가 서로 다른 버전의 라이브러리(예: torch, transformers)를 요구하기 때문에 가상환경 분리가 필수입니다.

```bash
# venv로 가상환경 생성
python3 -m venv .venv
source .venv/bin/activate

# 패키지 설치
pip install torch transformers langgraph

# 현재 환경의 패키지 목록 저장
pip freeze > requirements.txt

# 다른 환경에서 동일하게 재현
pip install -r requirements.txt
```

> 최근에는 `uv`, `conda`, `poetry` 등 더 빠르고 정교한 도구도 널리 쓰입니다. 이 커리큘럼에서는 표준 도구인 venv/pip로 시작합니다.

---

## 4. 기본 프로젝트 구조 예시

```
my-agent-project/
├── .venv/                 # 가상환경 (git에 커밋하지 않음)
├── requirements.txt        # 의존성 목록
├── src/
│   ├── main.py
│   └── agents/
├── .env                    # API 키 등 환경변수 (git에 커밋하지 않음)
└── .gitignore
```

`.gitignore` 필수 항목:

```
.venv/
__pycache__/
*.pyc
.env
```

---

## 📝 핵심 요약

1. AI 엔지니어링 생태계는 Python 중심 — PyTorch, Hugging Face, LangGraph 모두 Python 우선
2. GPU 서버는 대부분 Linux 헤드리스 환경 — SSH/터미널 숙련이 필수
3. 가상환경(venv)으로 프로젝트별 의존성을 분리해야 버전 충돌을 방지
4. `.env`, `.venv/` 등 민감/재현 가능한 파일은 `.gitignore`에 반드시 포함

---

## 🔗 참고 자료

- [Python 공식 venv 문서](https://docs.python.org/3/library/venv.html)
- [Linux Command Line Basics](https://ubuntu.com/tutorials/command-line-for-beginners)

---

*⬅️ 이전: —  |  다음: [Day 02 — Docker](./day-02.md) ➡️*
