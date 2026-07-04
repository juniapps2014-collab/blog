---
title: "Day 10 — SSH / tmux / nvidia-smi: 원격 GPU 서버 운영"
date: 2026-07-13
weight: 10
---

> **Phase 3: Runpod & 인프라** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- SSH 키 설정과 포트 포워딩으로 원격 GPU 서버에 안전하게 접속할 수 있다
- tmux로 세션을 유지해 연결이 끊겨도 장시간 작업이 살아있게 만들 수 있다
- `nvidia-smi` 출력을 읽고 GPU 상태를 실시간으로 모니터링할 수 있다

---

## 1. SSH 키 설정 — Runpod 접속의 첫걸음

Runpod Pod(Day 09)는 기본적으로 SSH로 접속합니다. 비밀번호 대신 공개키 방식을 씁니다.

```bash
# 로컬 머신에서 SSH 키 쌍 생성 (이미 있다면 생략)
ssh-keygen -t ed25519 -C "your_email@example.com"

# 공개키 내용 확인 후 Runpod 계정 설정(Settings > SSH Public Keys)에 등록
cat ~/.ssh/id_ed25519.pub
```

Runpod 콘솔에 공개키를 등록해두면, 이후 생성하는 모든 Pod에 자동으로 반영되어 별도 설정 없이 접속할 수 있습니다.

```bash
# Runpod이 제공하는 접속 명령어 예시 (Pod 상세 화면에서 복사)
ssh root@<pod-ip> -p <ssh-port> -i ~/.ssh/id_ed25519
```

### 포트 포워딩 — Jupyter/API에 로컬처럼 접속하기

Pod 안에서 Jupyter나 vLLM API 서버(Day 07)를 띄웠을 때, `-L` 옵션으로 로컬 포트와 원격 포트를 연결하면 로컬 브라우저에서 `localhost`로 접속하듯 쓸 수 있습니다.

```bash
# 원격 8888(Jupyter)을 로컬 8888로, 원격 8000(vLLM)을 로컬 8000으로 포워딩
ssh root@<pod-ip> -p <ssh-port> -i ~/.ssh/id_ed25519 \
  -L 8888:localhost:8888 \
  -L 8000:localhost:8000
```

이제 로컬 브라우저에서 `http://localhost:8888`로 접속하면 Pod 안의 Jupyter에 연결됩니다.

> 💡 **실무 팁**: Runpod은 프록시 URL로도 포트를 노출할 수 있지만(Day 09), 인증 없이 인터넷에 열려버릴 수 있어 개발 중에는 SSH 포트 포워딩이 더 안전합니다.

---

## 2. tmux — 연결이 끊겨도 작업은 계속된다

SSH 연결은 노트북을 덮거나 네트워크가 끊기면 종료됩니다. 이때 SSH 세션 안에서 직접 실행 중이던 학습 스크립트나 vLLM 서버도 함께 죽습니다. **tmux**는 터미널 세션을 서버 쪽에 남겨두고, 재접속했을 때 그대로 이어볼 수 있게 해주는 터미널 멀티플렉서입니다.

| 명령어 | 설명 |
|---|---|
| `tmux new -s train` | `train`이라는 이름의 새 세션 생성 |
| `tmux ls` | 현재 존재하는 세션 목록 확인 |
| `tmux attach -t train` | `train` 세션에 다시 접속 |
| `Ctrl+b` `d` | 세션에서 분리(detach) — 세션은 백그라운드에서 계속 실행됨 |
| `Ctrl+b` `%` | 화면을 좌우로 분할(pane) |
| `Ctrl+b` `"` | 화면을 상하로 분할 |
| `Ctrl+b` `방향키` | 분할된 pane 간 이동 |
| `tmux kill-session -t train` | 세션 완전 종료 |

**전형적인 사용 흐름:**

```bash
# 1. SSH로 Pod 접속
ssh root@<pod-ip> -p <ssh-port>

# 2. tmux 세션 생성 후 장시간 작업 실행
tmux new -s vllm-server
vllm serve meta-llama/Llama-3.1-8B-Instruct --port 8000

# 3. Ctrl+b, d 로 분리하고 SSH 연결을 끊어도 서버는 계속 실행됨

# 4. 나중에 다시 접속해서 상태 확인
ssh root@<pod-ip> -p <ssh-port>
tmux attach -t vllm-server
```

> 💡 **실무 팁**: 파인튜닝처럼 몇 시간~며칠 걸리는 작업은 반드시 tmux(또는 `nohup`, `screen`) 안에서 실행하세요. SSH 연결이 끊기는 순간 포그라운드 프로세스는 즉시 종료됩니다.

---

## 3. nvidia-smi — GPU 상태 읽기

`nvidia-smi`(NVIDIA System Management Interface)는 GPU 사용률, 메모리, 온도, 실행 중인 프로세스를 보여주는 기본 명령어입니다.

```bash
nvidia-smi
```

출력 예시(요약):

```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 550.90       Driver Version: 550.90       CUDA Version: 12.4     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA A100-SXM4-80GB  On |   00000000:00:04.0 Off |                    0 |
| 30%   52C    P0    250W / 400W |  42311MiB / 81920MiB |     87%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                   |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|=============================================================================|
|    0   N/A  N/A     12345      C   python                            42300MiB |
+-----------------------------------------------------------------------------+
```

읽는 법:

| 항목 | 의미 | 확인할 것 |
|---|---|---|
| `Temp` | GPU 온도(°C) | 80°C 이상이면 쓰로틀링(성능 저하) 위험 |
| `Pwr:Usage/Cap` | 현재 전력 사용량 / 최대 허용 전력 | 최대치에 가까우면 연산이 활발히 진행 중 |
| `Memory-Usage` | 사용 중인 VRAM / 전체 VRAM | OOM 직전인지 판단 |
| `GPU-Util` | GPU 연산 유닛 사용률(%) | 낮은데 메모리만 높다면 데이터 로딩 등 병목 의심 |
| `Processes` 표 | 어떤 프로세스가 GPU 메모리를 얼마나 쓰는지 | 좀비 프로세스로 메모리가 안 풀렸는지 확인 |

```bash
# 1초 간격으로 실시간 모니터링 (학습/서빙 중 필수)
watch -n 1 nvidia-smi

# 메모리를 점유한 채 응답 없는 프로세스 강제 종료
kill -9 <PID>

# GPU별 사용률만 간단히 뽑아보기
nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv
```

> 💡 **실무 팁**: `GPU-Util`은 낮은데 `Memory-Usage`만 꽉 차 있다면, 연산 자체보다 데이터 로딩·전처리·디스크 IO가 병목일 가능성이 큽니다. vLLM 서빙 중이라면 이는 대개 정상(요청 대기 중)이지만, 학습 중이라면 DataLoader 설정을 점검해야 합니다.

---

## 📝 핵심 요약

1. SSH 공개키를 Runpod에 등록해두면 새 Pod 생성 시마다 자동으로 접속 환경이 구성된다
2. `-L` 옵션의 SSH 포트 포워딩으로 원격 Jupyter/API 서버에 로컬처럼 안전하게 접속할 수 있다
3. tmux는 SSH 연결이 끊겨도 세션을 서버에 남겨 장시간 작업(학습, 서빙)을 지속시킨다
4. `nvidia-smi`로 GPU 온도·메모리·사용률·프로세스를 확인하고, `watch -n 1`으로 실시간 모니터링한다

---

## 🔗 참고 자료

- [Runpod SSH 접속 가이드](https://docs.runpod.io/pods/configuration/use-ssh)
- [tmux 공식 GitHub Wiki](https://github.com/tmux/tmux/wiki)
- [NVIDIA nvidia-smi 공식 문서](https://developer.nvidia.com/system-management-interface)

---

*⬅️ 이전: [Day 09 — Runpod 기초](../day-09/)  |  다음: [Day 11 — LangGraph 개념](../day-11/) ➡️*
