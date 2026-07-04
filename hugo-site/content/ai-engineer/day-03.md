---
title: "Day 03 — GPU & CUDA: LLM 추론/학습을 위한 하드웨어 이해"
date: 2026-07-06
weight: 3
---

> **Phase 1: 기초** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- GPU가 LLM 연산(행렬 곱셈)에 CPU보다 적합한 이유를 설명할 수 있다
- `nvidia-smi` 출력을 읽고 GPU 상태를 진단할 수 있다
- 모델 파라미터 수로부터 필요한 VRAM을 추정할 수 있다

---

## 1. CPU vs GPU — 왜 GPU인가

CPU는 소수의 강력한 코어(보통 8~64개)로 순차적/분기적 연산을 빠르게 처리하도록 설계되어 있습니다. 반면 GPU는 수천 개의 단순한 코어로 **동일한 연산을 대량의 데이터에 동시에** 적용하는 데 특화되어 있습니다.

LLM의 핵심 연산은 행렬 곱셈(matmul)입니다. Transformer의 attention과 feed-forward 레이어는 모두 대규모 행렬 곱셈으로 구성되며, 이는 각 출력 원소를 독립적으로 계산할 수 있는 "임베러싱리 패러렐(embarrassingly parallel)" 작업입니다.

| 구분 | CPU | GPU |
|---|---|---|
| 코어 수 | 수십 개 (강력함) | 수천 개 (단순함) |
| 설계 목적 | 범용 순차 처리, 분기 예측 | 대량 병렬 산술 연산 |
| 메모리 대역폭 | 낮음 (~50GB/s) | 매우 높음 (~1~3TB/s) |
| LLM 행렬곱 처리 | 느림 | 빠름 (수십~수백 배) |

> 💡 **실무 팁**: "GPU가 빠르다"는 것은 클럭 속도가 빨라서가 아니라, 동시에 처리하는 연산의 개수(병렬성)와 메모리 대역폭이 압도적으로 높기 때문입니다. LLM 추론 속도는 대부분 연산량(FLOPs)보다 **메모리 대역폭**에 의해 병목이 걸립니다 (memory-bound).

---

## 2. GPU 구성 요소 — CUDA 코어, VRAM, 대역폭

NVIDIA GPU는 다음 요소들의 조합으로 성능이 결정됩니다.

- **CUDA 코어**: 병렬 부동소수점 연산을 수행하는 기본 처리 단위. 코어 수가 많을수록 동시 처리량이 늘어남
- **Tensor 코어**: 행렬 곱셈(특히 FP16/BF16/INT8 혼합정밀도)에 특화된 전용 하드웨어. LLM 학습/추론 가속의 핵심
- **VRAM (GPU 메모리)**: 모델 가중치, 활성화값(activation), KV 캐시가 저장되는 공간. GDDR6X 또는 HBM 사용
- **메모리 대역폭**: VRAM과 연산 유닛 사이의 데이터 전송 속도. LLM 추론에서는 이 대역폭이 토큰 생성 속도의 상한을 결정

| GPU (예시) | VRAM | 메모리 대역폭 | 주요 용도 |
|---|---|---|---|
| RTX 4090 | 24GB GDDR6X | ~1TB/s | 개인/소규모 추론 |
| A100 (40GB) | 40GB HBM2e | ~1.6TB/s | 학습, 중대형 추론 |
| A100 (80GB) | 80GB HBM2e | ~2TB/s | 대형 모델 학습/추론 |
| H100 | 80GB HBM3 | ~3.35TB/s | 대규모 학습, 고성능 추론 |

---

## 3. `nvidia-smi` 읽는 법

GPU 상태를 확인하는 가장 기본적인 도구입니다.

```bash
nvidia-smi
```

```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.90.07     Driver Version: 550.90.07     CUDA Version: 12.4               |
|-------------------------------+----------------------+----------------------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC             |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M.             |
|===============================+======================+==================================|
|   0  NVIDIA A100-SXM4-80GB  On | 00000000:00:04.0 Off |                    0             |
| 35%   62C    P0   210W / 400W |  42311MiB / 81920MiB |     87%      Default             |
+-------------------------------+----------------------+----------------------------------+
```

주요 필드 해석:

| 필드 | 의미 | 확인 포인트 |
|---|---|---|
| `Driver Version` | 설치된 NVIDIA 드라이버 버전 | CUDA 툴킷 버전과 호환되어야 함 |
| `CUDA Version` | 드라이버가 지원하는 **최대** CUDA 버전 | 실제 설치된 CUDA 툴킷 버전과는 별개 |
| `Memory-Usage` | 현재 사용 중 VRAM / 전체 VRAM | OOM 여부 판단 |
| `GPU-Util` | GPU 연산 유닛 사용률(%) | 낮으면 데이터 전송/CPU 병목 의심 |
| `Temp` | GPU 온도 | 85°C 이상 지속 시 쓰로틀링 위험 |
| `Pwr:Usage/Cap` | 현재 전력 사용량 / 최대 전력 | 전력 제한(power limit) 확인 |

실시간 모니터링과 프로세스별 GPU 사용량 확인:

```bash
# 1초 간격으로 실시간 갱신
watch -n 1 nvidia-smi

# 어떤 프로세스가 GPU를 점유 중인지 확인
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
```

> 💡 **실무 팁**: `CUDA Version`에 표시되는 값은 "드라이버가 지원 가능한 최대 버전"이지 "설치된 CUDA 툴킷 버전"이 아닙니다. 실제 툴킷 버전은 `nvcc --version`으로 확인해야 합니다.

---

## 4. 드라이버 vs CUDA 툴킷 — 헷갈리는 버전 호환성

CUDA 관련 오류의 상당수는 이 둘을 혼동해서 발생합니다.

- **NVIDIA 드라이버**: OS와 GPU 하드웨어 사이의 저수준 인터페이스. `nvidia-smi`로 확인
- **CUDA 툴킷**: 컴파일러(`nvcc`), 라이브러리(cuBLAS, cuDNN) 등 개발 도구 모음. `nvcc --version`으로 확인
- **PyTorch의 CUDA 빌드**: PyTorch는 특정 CUDA 버전에 맞춰 컴파일되어 배포됨 (예: `torch==2.3.0+cu121`)

세 가지가 서로 호환되지 않으면 `CUDA error: no kernel image is available` 같은 오류가 발생합니다. 원칙은 **드라이버 버전 ≥ 툴킷이 요구하는 최소 버전**이며, PyTorch는 보통 자체적으로 필요한 CUDA 런타임 라이브러리를 함께 배포하므로 시스템 CUDA 툴킷을 별도로 설치하지 않아도 되는 경우가 많습니다.

```bash
# 드라이버가 지원하는 최대 CUDA 버전
nvidia-smi | grep "CUDA Version"

# 설치된 CUDA 툴킷(nvcc) 버전
nvcc --version

# PyTorch가 인식하는 CUDA 버전과 GPU 가용 여부
python3 -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.version.cuda)"
```

---

## 5. LLM용 GPU 선택 — VRAM 크기 어림잡기

모델을 로드하는 데 필요한 최소 VRAM은 **파라미터 수 × 파라미터당 바이트**로 추정할 수 있습니다.

| 정밀도 | 파라미터당 바이트 | 7B 모델 기준 VRAM(가중치만) |
|---|---|---|
| FP32 | 4 bytes | ~28GB |
| FP16 / BF16 | 2 bytes | ~14GB |
| INT8 | 1 byte | ~7GB |
| INT4 (양자화) | 0.5 byte | ~3.5GB |

```
필요 VRAM(가중치) ≈ 파라미터 수 × 바이트/파라미터
예: 70B 모델, FP16 → 70 × 10^9 × 2 bytes ≈ 140GB
```

여기에 **KV 캐시**(컨텍스트 길이·배치 크기에 비례해 증가, Day 05에서 상세히 다룸)와 활성화 메모리를 더해야 실제 추론에 필요한 VRAM이 나옵니다. 실무에서는 대략적으로 가중치 크기의 1.2~1.5배를 여유 있게 잡는 것이 안전합니다.

| 모델 규모 | FP16 추론 최소 VRAM | 권장 GPU |
|---|---|---|
| 7B | ~16GB | RTX 4090 (24GB), L4 |
| 13B | ~28GB | A100 40GB |
| 34B | ~70GB | A100 80GB |
| 70B | ~150GB | A100 80GB × 2, H100 × 2 |

단일 GPU에 모델이 들어가지 않으면 **멀티 GPU**로 분산해야 합니다. 대표적인 전략은 다음과 같습니다.

- **텐서 병렬화(Tensor Parallelism)**: 하나의 레이어 연산을 여러 GPU에 쪼개서 동시에 계산 (vLLM, DeepSpeed 등에서 지원)
- **파이프라인 병렬화(Pipeline Parallelism)**: 모델의 레이어를 GPU별로 나눠 순차적으로 통과시킴
- **데이터 병렬화(Data Parallelism)**: 동일한 모델을 GPU마다 복제하고, 배치를 나눠 처리 (주로 학습에서 처리량 향상 목적)

> 💡 **실무 팁**: 추론 서빙에서는 텐서 병렬화가 가장 흔히 쓰입니다. GPU 간 통신(NVLink 유무)이 텐서 병렬화 성능에 큰 영향을 주므로, 멀티 GPU 서버를 고를 때는 NVLink 지원 여부를 반드시 확인하세요.

---

## 📝 핵심 요약

1. GPU는 수천 개의 단순 코어와 높은 메모리 대역폭으로 행렬 곱셈 같은 병렬 연산에 최적화되어 있다
2. LLM 추론은 대체로 연산량이 아닌 메모리 대역폭에 의해 속도가 결정된다 (memory-bound)
3. `nvidia-smi`는 VRAM 사용량, GPU 사용률, 온도, 드라이버 버전을 확인하는 기본 도구다
4. 드라이버 버전, CUDA 툴킷 버전, PyTorch 빌드 버전은 각각 다른 개념이며 서로 호환되어야 한다
5. 필요 VRAM은 "파라미터 수 × 정밀도별 바이트"로 어림잡고, 여기에 KV 캐시 여유분을 더해야 한다

---

## 🔗 참고 자료

- [NVIDIA System Management Interface (nvidia-smi) 문서](https://developer.nvidia.com/system-management-interface)
- [CUDA Toolkit 문서](https://docs.nvidia.com/cuda/)
- [PyTorch CUDA Semantics](https://pytorch.org/docs/stable/notes/cuda.html)

---

*⬅️ 이전: [Day 02 — Docker: 앱을 컨테이너로 패키징하기](../day-02/)  |  다음: [Day 04 — Transformer 아키텍처](../day-04/) ➡️*
