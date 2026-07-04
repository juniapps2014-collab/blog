---
title: "Day 09 — Runpod 기초: Pod, Persistent Volume, Template"
date: 2026-07-12
weight: 9
---

> **Phase 3: Runpod & 인프라** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Runpod의 Pod와 Serverless의 차이를 이해하고 상황에 맞게 선택할 수 있다
- Persistent Volume과 Container Disk의 차이를 설명할 수 있다
- Template을 활용해 재현 가능한 GPU 작업 환경을 구축할 수 있다

---

## 1. Runpod이란

Runpod은 시간 단위로 GPU를 대여할 수 있는 클라우드 GPU 서비스입니다. AWS/GCP 대비 훨씬 저렴한 가격에 A100, H100, RTX 4090 등 다양한 GPU를 즉시 대여할 수 있어, 개인이나 소규모 팀이 vLLM 서빙(Day 07)이나 파인튜닝 실습을 할 때 널리 쓰입니다.

Runpod은 크게 두 가지 실행 방식을 제공합니다.

| 구분 | Pod | Serverless |
|---|---|---|
| 실행 방식 | 항상 켜져 있는 가상 서버 (SSH 접속 가능) | 요청이 올 때만 컨테이너가 뜨는 이벤트 기반 실행 |
| 과금 | 켜져 있는 시간만큼 (분/시간 단위) | 실제 처리 시간만큼 (초 단위, Cold Start 포함) |
| 적합한 용도 | 학습/실습, 장시간 실행되는 학습(training), 개발 중인 서빙 서버 | 트래픽이 간헐적인 프로덕션 API, 스케일-to-zero가 필요한 경우 |
| 콜드 스타트 | 없음 (계속 켜져 있으므로) | 있음 (컨테이너/모델 로딩 시간) |

이 커리큘럼처럼 실습 위주로 GPU를 붙였다 뗐다 하는 상황에서는 **Pod**가 기본 선택지입니다.

---

## 2. GPU 선택과 가격 구조

Runpod은 GPU 종류별로 "Secure Cloud"(안정적인 데이터센터, 가격 높음)와 "Community Cloud"(개인/소규모 제공자, 가격 낮지만 가용성 변동)로 나뉩니다.

| GPU | VRAM | 대략적 용도 |
|---|---|---|
| RTX 4090 | 24GB | 7B~13B 모델 추론, 개인 실습 |
| A100 (40GB/80GB) | 40~80GB | 13B~70B 모델 추론, 중형 파인튜닝 |
| H100 | 80GB | 대형 모델 학습, 고성능 추론 서빙 |

> 💡 **실무 팁**: 처음에는 Community Cloud의 저렴한 GPU(RTX 4090 등)로 실습하며 명령어와 워크플로우에 익숙해진 뒤, 실제로 큰 모델이 필요할 때만 Secure Cloud의 A100/H100으로 옮기는 것이 비용 효율적입니다.

---

## 3. Persistent Volume vs Container Disk

Runpod Pod를 생성할 때 반드시 이해해야 하는 개념이 두 종류의 디스크입니다.

- **Container Disk** — Pod(컨테이너)에 딸린 임시 저장 공간. **Pod를 종료(terminate)하면 데이터가 사라집니다.** OS, 설치한 패키지, 임시 파일이 여기 저장됩니다.
- **Persistent Volume (Network Volume)** — Pod를 종료해도 유지되는 별도의 네트워크 스토리지. 모델 가중치, 데이터셋, 체크포인트처럼 "다시 받으면 시간이 오래 걸리는" 파일을 여기에 저장해야 합니다.

```
/workspace          ← 보통 Persistent Volume이 마운트되는 경로
├── models/          # 다운로드한 모델 가중치 (재사용)
├── datasets/
└── checkpoints/

/                    ← Container Disk (Pod 종료 시 소멸)
├── (설치한 패키지, OS 파일 등)
```

> 💡 **실무 팁**: Pod를 "Stop"만 하면 Container Disk도 유지되지만, "Terminate"하면 완전히 사라집니다. 중요한 작업 결과는 반드시 `/workspace`(Persistent Volume) 아래에 저장하는 습관을 들여야 합니다. Stop 상태에서도 Volume 스토리지 요금은 계속 청구됩니다.

---

## 4. Template — 환경을 재현 가능하게

매번 Pod를 새로 만들 때마다 CUDA, PyTorch, vLLM 등을 처음부터 설치하는 것은 비효율적입니다. Runpod의 **Template**은 "어떤 Docker 이미지로, 어떤 포트를 열고, 어떤 환경변수로 컨테이너를 띄울지"를 미리 정의해두는 설정입니다.

- Runpod이 제공하는 공식 Template (PyTorch, vLLM 등 사전 설치)을 그대로 쓰거나
- 자신만의 Docker 이미지를 만들어 Custom Template으로 등록하면, 다음에 Pod를 생성할 때 동일한 환경을 즉시 재현할 수 있습니다

```dockerfile
# Custom Template용 Dockerfile 예시
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

RUN pip install vllm

# 컨테이너 시작 시 실행할 스크립트
COPY start.sh /start.sh
CMD ["/start.sh"]
```

Template 설정 시 지정하는 주요 항목:

| 항목 | 설명 |
|---|---|
| Container Image | 사용할 Docker 이미지 |
| Container Disk / Volume Disk 크기 | 각각 몇 GB 할당할지 |
| Exposed Ports | 외부에 노출할 포트 (예: vLLM의 8000, Jupyter의 8888) |
| Environment Variables | API 키, 모델 이름 등 컨테이너 내부에서 쓸 값 |

---

## 5. 전형적인 워크플로우

1. **Template 선택** — 공식 PyTorch/vLLM Template 또는 커스텀 이미지 선택
2. **GPU와 디스크 크기 지정** — 예상 모델 크기에 맞춰 Persistent Volume 용량 결정 (70B 모델 GGUF 4bit면 대략 40GB 이상 권장)
3. **Pod 배포(Deploy)** — 몇 분 내로 컨테이너가 뜨고 SSH/HTTP 접속 정보가 발급됨
4. **포트 노출 확인** — Runpod은 Pod마다 프록시 URL(`https://<pod-id>-8000.proxy.runpod.net`)을 자동 발급해 외부에서 접속 가능
5. **작업 종료 시 Stop 또는 Terminate 결정** — 계속 쓸 예정이면 Stop(과금은 Volume만), 완전히 끝났으면 Terminate

```bash
# Pod 내부에서 vLLM 서버를 8000번 포트로 실행 (Day 07 참고)
vllm serve meta-llama/Llama-3.1-8B-Instruct --host 0.0.0.0 --port 8000

# Runpod이 자동 발급한 프록시 URL로 외부에서 접속
curl https://<pod-id>-8000.proxy.runpod.net/v1/models
```

> 💡 **실무 팁**: Runpod은 기본적으로 프록시를 통한 HTTPS 접속만 지원하고 임의 TCP 포트는 별도 설정이 필요합니다. SSH 접속은 다음 Day에서 다룰 TCP 포트 포워딩 방식을 사용합니다.

---

## 📝 핵심 요약

1. 상시 실행/개발 실습에는 Pod, 간헐적 트래픽의 프로덕션 API에는 Serverless가 적합
2. Container Disk는 Pod 종료 시 소멸, Persistent Volume은 유지되므로 모델/데이터는 반드시 Volume에 저장
3. Template으로 환경을 미리 정의해두면 Pod를 생성할 때마다 동일한 환경을 즉시 재현할 수 있다
4. Runpod은 Pod마다 프록시 URL을 자동 발급해 vLLM 같은 HTTP 서버를 외부에 노출할 수 있다

---

## 🔗 참고 자료

- [Runpod 공식 문서](https://docs.runpod.io/)
- [Runpod Pods 개요](https://docs.runpod.io/pods/overview)
- [Runpod Network Volumes](https://docs.runpod.io/pods/storage/create-network-volumes)

---

*⬅️ 이전: [Day 08 — 양자화 & 추론 최적화](../day-08/)  |  다음: [Day 10 — SSH / tmux / nvidia-smi](../day-10/) ➡️*
