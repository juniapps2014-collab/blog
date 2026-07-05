---
title: "AI 엔지니어"
description: "LLM Agent 엔지니어링 커리큘럼 — 기초부터 실전 배포까지"
---

> 파이썬 기초부터 Local LLM, LangGraph, MCP, RAG, FastAPI를 거쳐 실전 배포까지 순차적으로 학습합니다.
> 매일 하나의 강의노트가 추가되어 아래 목록에 이어서 쌓입니다.

---

## 📚 전체 목차

### Phase 1: 기초 (Day 01–05) — 개발 환경과 LLM 개념
| Day | 주제 |
|-----|------|
| 01 | Python & Linux — AI 엔지니어의 개발 환경 |
| 02 | Docker — 앱을 컨테이너로 패키징하기 |
| 03 | GPU & CUDA — LLM 추론/학습을 위한 하드웨어 이해 |
| 04 | Transformer 아키텍처 — 현대 LLM의 근간 |
| 05 | Token / Embedding / Context Window / KV Cache |

### Phase 2: 로컬 LLM (Day 06–08) — 내 컴퓨터에서 LLM 돌리기
| Day | 주제 |
|-----|------|
| 06 | Ollama — 가장 간단한 로컬 LLM 실행 |
| 07 | vLLM — 고성능 추론 서버 구축 |
| 08 | 양자화 & 추론 최적화 — GGUF/GPTQ/AWQ, Tensor Parallel, Flash Attention, Speculative Decoding |

### Phase 3: Runpod & 인프라 (Day 09–10) — 클라우드 GPU 다루기
| Day | 주제 |
|-----|------|
| 09 | Runpod 기초 — Pod, Persistent Volume, Template |
| 10 | SSH / tmux / nvidia-smi — 원격 GPU 서버 운영 |

### Phase 4: 에이전트 프레임워크 (Day 11–13) — LangGraph
| Day | 주제 |
|-----|------|
| 11 | LangGraph 개념 — State, Node, Edge |
| 12 | Conditional Edge & Checkpoint — 분기와 상태 저장 |
| 13 | Interrupt & Human-in-the-loop — 사람이 개입하는 워크플로우 |

### Phase 5: MCP (Day 14–15) — Model Context Protocol
| Day | 주제 |
|-----|------|
| 14 | MCP 개념 — Server/Client, Tool, Resource, Prompt |
| 15 | stdio vs Streamable HTTP — 전송 방식 이해와 실습 |

### Phase 6: 툴 콜링 & 구조화 출력 (Day 16–17)
| Day | 주제 |
|-----|------|
| 16 | Function Calling & JSON Schema |
| 17 | Structured Output & Pydantic 검증 |

### Phase 7: RAG (Day 18–20) — Retrieval-Augmented Generation
| Day | 주제 |
|-----|------|
| 18 | RAG 개념과 Chunking 전략 |
| 19 | Embedding Model & Similarity Search |
| 20 | Hybrid Search & Reranker |

### Phase 8: 벡터 데이터베이스 (Day 21–22)
| Day | 주제 |
|-----|------|
| 21 | Qdrant / Chroma 실습 |
| 22 | Milvus / pgvector 비교와 선택 기준 |

### Phase 9: 백엔드 API (Day 23–24) — FastAPI
| Day | 주제 |
|-----|------|
| 23 | FastAPI 기초 — REST API 설계 |
| 24 | WebSocket & Streaming Response, 인증(Authentication) |

### Phase 10: Multi-Agent (Day 25–26)
| Day | 주제 |
|-----|------|
| 25 | Planner / Researcher / Coder / Reviewer 역할 분리 |
| 26 | Supervisor 패턴 & Memory 설계 |

### Phase 11: 관찰성 (Day 27–28) — Observability
| Day | 주제 |
|-----|------|
| 27 | Langfuse — Logging & Tracing |
| 28 | Metrics & Evaluation — 에이전트 품질 측정 |

### Phase 12: 파인튜닝 (Day 29–30)
| Day | 주제 |
|-----|------|
| 29 | LoRA / QLoRA / PEFT — 효율적 파인튜닝 |
| 30 | SFT / DPO / RLHF — 정렬(Alignment) 기법 비교 |

### Final Project (Day 31)
| Day | 주제 |
|-----|------|
| 31 | 통합 프로젝트 — Runpod → vLLM → Local LLM → LangGraph → MCP → RAG → FastAPI → Web UI |

---

## 📌 진행 현황

- [x] Day 01 — Python & Linux
- [x] Day 02 — Docker
- [x] Day 03 — GPU & CUDA
- [x] Day 04 — Transformer 아키텍처
- [x] Day 05 — Token / Embedding / Context Window / KV Cache
- [x] Day 06 — Ollama
- [x] Day 07 — vLLM
- [x] Day 08 — 양자화 & 추론 최적화
- [x] Day 09 — Runpod 기초
- [x] Day 10 — SSH / tmux / nvidia-smi
- [x] Day 11 — LangGraph 개념
- [x] Day 12 — Conditional Edge & Checkpoint
- [x] Day 13 — Interrupt & Human-in-the-loop
- [x] Day 14 — MCP 개념
- [x] Day 15 — stdio vs Streamable HTTP
- [x] Day 16 — Function Calling & JSON Schema
- [x] Day 17 — Structured Output & Pydantic
- [x] Day 18 — RAG 개념과 Chunking
- [x] Day 19 — Embedding Model & Similarity Search
- [x] Day 20 — Hybrid Search & Reranker
- [x] Day 21 — Qdrant / Chroma 실습
- [x] Day 22 — Milvus / pgvector 비교
- [x] Day 23 — FastAPI 기초
- [x] Day 24 — WebSocket & Streaming & 인증
- [x] Day 25 — Multi-Agent 역할 분리
- [x] Day 26 — Supervisor 패턴 & Memory
- [x] Day 27 — Langfuse Logging & Tracing
- [x] Day 28 — Metrics & Evaluation
- [x] Day 29 — LoRA / QLoRA / PEFT
- [x] Day 30 — SFT / DPO / RLHF
- [x] Day 31 — 통합 프로젝트

---

## 📖 강의노트 목록
