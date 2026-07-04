---
title: "Day 02 — Docker: 앱을 컨테이너로 패키징하기"
date: 2026-07-05
weight: 2
---

> **Phase 1: 기초** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 이미지(image)와 컨테이너(container)의 차이를 설명할 수 있다
- Python/GPU 애플리케이션을 위한 Dockerfile을 직접 작성할 수 있다
- `docker build`/`run`/`exec`와 nvidia-container-toolkit으로 GPU 컨테이너를 실행할 수 있다

---

## 1. Docker가 필요한 이유

LLM 애플리케이션은 특정 버전의 Python, CUDA, PyTorch, 시스템 라이브러리(예: `libgomp`, `ffmpeg`)에 강하게 의존합니다. "내 컴퓨터에서는 되는데 서버에서는 안 되는" 문제는 대부분 이런 환경 불일치에서 발생합니다.

Docker는 애플리케이션과 그 실행 환경(OS 라이브러리, 런타임, 의존성)을 하나의 **이미지**로 묶어서, 어디서 실행하든 동일한 결과를 보장합니다.

| 개념 | 설명 |
|---|---|
| **이미지(Image)** | 앱 코드 + 의존성 + 실행 환경을 담은 읽기 전용 템플릿 (레이어의 스택) |
| **컨테이너(Container)** | 이미지를 실행한 인스턴스. 격리된 프로세스로 동작 |
| **Dockerfile** | 이미지를 어떻게 빌드할지 정의하는 스크립트 |
| **레지스트리(Registry)** | 이미지를 저장/배포하는 저장소 (Docker Hub, ECR, GHCR 등) |

가상머신(VM)과 달리 컨테이너는 호스트 OS의 커널을 공유하기 때문에 부팅이 필요 없고 훨씬 가볍습니다. VM이 "OS 전체를 복제"한다면, 컨테이너는 "프로세스를 격리"하는 방식입니다.

> 💡 **실무 팁**: "이미지는 클래스, 컨테이너는 인스턴스"라고 생각하면 이해가 쉽습니다. 같은 이미지로 컨테이너를 여러 개 띄울 수 있고, 각 컨테이너는 독립적인 파일시스템과 프로세스 공간을 가집니다.

---

## 2. Dockerfile 기본 — Python 애플리케이션

가장 기본적인 Python 기반 LLM 에이전트 서버의 Dockerfile 예시입니다.

```dockerfile
# 베이스 이미지: Python 3.11 slim (불필요한 패키지 제거된 경량 버전)
FROM python:3.11-slim

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 파일만 먼저 복사 (레이어 캐싱 최적화)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 나머지 소스 코드 복사
COPY . .

# 컨테이너가 사용할 포트 명시 (문서화 목적, 실제 포워딩은 -p 옵션)
EXPOSE 8000

# 컨테이너 시작 시 실행할 명령
CMD ["python", "src/main.py"]
```

**레이어 캐싱이 중요한 이유**: `requirements.txt`를 먼저 복사하고 설치한 뒤 소스 코드를 복사하면, 코드만 바뀌었을 때 `pip install` 레이어는 캐시를 재사용해 빌드 속도가 크게 빨라집니다. 반대로 `COPY . .`를 맨 위에 두면 코드 한 줄만 바꿔도 의존성 설치부터 다시 실행됩니다.

---

## 3. GPU를 사용하는 Dockerfile

LLM 추론/학습 컨테이너는 CUDA 런타임이 포함된 베이스 이미지가 필요합니다. NVIDIA가 공식 제공하는 CUDA 이미지를 사용하는 것이 일반적입니다.

```dockerfile
# NVIDIA 공식 CUDA + cuDNN 베이스 이미지
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

# Python 설치 (CUDA 이미지는 기본적으로 Python이 없음)
RUN apt-get update && apt-get install -y \
    python3.11 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .
CMD ["python3", "src/serve.py"]
```

GPU 컨테이너를 실행하려면 호스트에 **NVIDIA 드라이버**와 **nvidia-container-toolkit**이 설치되어 있어야 합니다. 이 툴킷이 컨테이너 내부에서 호스트의 GPU 디바이스에 접근할 수 있도록 다리를 놓아줍니다.

```bash
# nvidia-container-toolkit 설치 (Ubuntu 기준)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

# Docker 데몬에 nvidia 런타임 등록
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

> 💡 **실무 팁**: 대부분의 GPU 클라우드(Runpod, Lambda, Vast.ai)는 nvidia-container-toolkit이 이미 설치된 베이스 이미지를 제공합니다. 직접 서버를 구축하는 게 아니라면 이 설치 과정은 생략 가능한 경우가 많습니다.

---

## 4. 빌드, 실행, 디버깅 명령어

```bash
# 이미지 빌드 (현재 디렉토리의 Dockerfile 사용, 태그 지정)
docker build -t my-agent:latest .

# 컨테이너 실행 (포트 포워딩 + GPU 전체 할당)
docker run -d --gpus all -p 8000:8000 --name agent-server my-agent:latest

# 특정 GPU만 할당 (0번, 1번 GPU만 사용)
docker run -d --gpus '"device=0,1"' my-agent:latest

# 실행 중인 컨테이너 목록
docker ps

# 컨테이너 내부 쉘 접속 (디버깅에 필수)
docker exec -it agent-server /bin/bash

# 로그 확인 (실시간 스트리밍)
docker logs -f agent-server

# 컨테이너 정지/삭제
docker stop agent-server
docker rm agent-server

# 사용하지 않는 이미지/컨테이너 일괄 정리
docker system prune -a
```

컨테이너 안에서 `nvidia-smi`가 정상적으로 GPU 정보를 출력하면 GPU passthrough가 올바르게 설정된 것입니다.

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

---

## 5. docker-compose와 .dockerignore

여러 컨테이너(예: LLM 서빙 컨테이너 + 벡터DB + Redis)를 함께 운영할 때는 `docker-compose.yml`로 관리하는 것이 훨씬 편합니다.

```yaml
services:
  agent:
    build: .
    ports:
      - "8000:8000"
    environment:
      - MODEL_NAME=llama3.1:8b
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    depends_on:
      - vectordb

  vectordb:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
    volumes:
      - qdrant_data:/qdrant/storage

volumes:
  qdrant_data:
```

```bash
# 전체 스택 실행 (백그라운드)
docker compose up -d

# 전체 스택 종료
docker compose down
```

빌드 컨텍스트에 불필요한 파일(가상환경, 캐시, `.git`)이 포함되면 빌드가 느려지고 이미지가 커집니다. `.dockerignore`로 제외합니다.

```
.venv/
__pycache__/
*.pyc
.git/
.env
*.log
node_modules/
```

> 💡 **실무 팁**: 이미지 크기는 곧 배포 속도와 직결됩니다. `python:3.11-slim`처럼 slim/alpine 베이스를 사용하고, 멀티 스테이지 빌드(multi-stage build)로 빌드 도구와 런타임을 분리하면 프로덕션 이미지 크기를 크게 줄일 수 있습니다.

---

## 📝 핵심 요약

1. 이미지는 템플릿, 컨테이너는 그 실행 인스턴스 — VM과 달리 커널을 공유해 훨씬 가볍다
2. Dockerfile은 의존성 설치를 코드 복사보다 먼저 배치해 레이어 캐싱을 최대화한다
3. GPU 컨테이너는 CUDA 베이스 이미지 + nvidia-container-toolkit + `--gpus all` 조합으로 동작한다
4. `docker exec`, `docker logs`는 컨테이너 디버깅의 기본 도구
5. 여러 서비스를 함께 운영할 때는 docker-compose로 오케스트레이션한다

---

## 🔗 참고 자료

- [Docker 공식 문서](https://docs.docker.com/)
- [NVIDIA Container Toolkit 설치 가이드](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Docker Compose 공식 문서](https://docs.docker.com/compose/)

---

*⬅️ 이전: [Day 01 — Python & Linux: AI 엔지니어의 개발 환경](../day-01/)  |  다음: [Day 03 — GPU & CUDA](../day-03/) ➡️*
