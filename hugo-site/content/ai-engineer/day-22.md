---
title: "Day 22 — Milvus / pgvector 비교와 선택 기준"
date: 2026-07-25
weight: 22
---

> **Phase 8: 벡터 데이터베이스** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- Milvus의 분산 아키텍처와 pgvector의 "Postgres 확장" 철학의 차이를 설명할 수 있다
- 프로젝트 규모, 운영 부담, 기존 스택을 기준으로 벡터 DB를 선택할 수 있다
- pgvector 기본 SQL(확장 설치, 컬럼 타입, 거리 연산자)을 직접 작성할 수 있다

---

## 1. 두 가지 철학: "전용 벡터 DB" vs "기존 DB의 확장"

Day 21에서 다룬 Qdrant, Chroma가 "처음부터 벡터 검색을 위해 설계된" 전용 DB라면, Milvus와 pgvector는 스펙트럼의 양 극단을 보여주는 좋은 대조군입니다.

- **Milvus** — 대규모 분산 처리를 염두에 두고 설계된 순수 벡터 DB. 수십억 벡터, 초당 수천 QPS를 목표로 하는 프로덕션 환경을 위한 아키텍처를 갖춤
- **pgvector** — PostgreSQL에 벡터 타입과 인덱스를 추가하는 "확장(extension)"일 뿐. 별도 인프라 없이 이미 쓰고 있는 Postgres에 `CREATE EXTENSION` 한 줄로 벡터 검색 기능을 얹음

이 둘은 경쟁 관계라기보다 "언제 전용 인프라가 필요한가"라는 질문에 대한 서로 다른 답입니다.

> 💡 **실무 팁**: 벡터 DB를 고를 때 가장 먼저 물어야 할 질문은 "우리가 지금 몇 개의 벡터를 다루고, 1년 뒤에는 몇 개일까?"입니다. 아키텍처 선택의 80%는 이 질문 하나로 결정됩니다.

---

## 2. Milvus 아키텍처 — 분산 대규모 검색

Milvus는 컴퓨팅과 스토리지를 분리한(compute-storage separation) 마이크로서비스 아키텍처를 갖고 있습니다.

**핵심 컴포넌트:**

| 컴포넌트 | 역할 |
|---|---|
| Proxy | 클라이언트 요청을 받아 라우팅 |
| Query Node | 실제 벡터 검색(ANN) 연산 수행 |
| Data Node | 삽입된 데이터를 세그먼트로 영속화 |
| Index Node | 백그라운드에서 인덱스 빌드 |
| etcd | 메타데이터 저장 |
| MinIO/S3 | 원본 벡터·인덱스 데이터의 오브젝트 스토리지 |
| Pulsar/Kafka | 노드 간 메시지 큐 |

이런 구조 덕분에 Query Node나 Data Node를 독립적으로 수평 확장할 수 있고, 샤딩과 복제를 통해 수십억 규모의 컬렉션도 처리할 수 있습니다. 반면 이 모든 컴포넌트를 운영해야 한다는 뜻이기도 합니다 — Kubernetes 클러스터, etcd 관리, 오브젝트 스토리지 설정 등 운영 복잡도가 상당합니다.

```bash
# Milvus Standalone(단일 노드, 개발용) 실행
docker run -d --name milvus-standalone \
  -p 19530:19530 -p 9091:9091 \
  milvusdb/milvus:v2.4.0 milvus run standalone
```

개발/PoC 단계에서는 "Standalone" 모드로 단일 컨테이너에서 돌릴 수 있지만, 이는 Milvus 본연의 분산 능력을 쓰지 않는 것이므로 프로덕션 스케일 검증에는 큰 의미가 없습니다. 진짜 강점은 "Milvus Cluster" 모드에서 나옵니다.

---

## 3. pgvector — 있는 인프라를 그대로 쓴다

pgvector는 PostgreSQL의 확장(extension)입니다. 새로운 DB를 배우거나 별도 클러스터를 운영할 필요 없이, 이미 쓰고 있는 Postgres 인스턴스에 벡터 컬럼 타입과 유사도 검색 연산자를 추가합니다.

```sql
-- 확장 설치 (한 번만)
CREATE EXTENSION IF NOT EXISTS vector;

-- 벡터 컬럼을 포함한 테이블 생성
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    metadata JSONB,
    embedding VECTOR(1536)  -- OpenAI text-embedding-3-small 차원
);

-- 근사 최근접 이웃(ANN) 인덱스 생성 (HNSW)
CREATE INDEX ON documents
USING hnsw (embedding vector_cosine_ops);

-- 코사인 거리 기준 상위 5개 유사 문서 검색
SELECT id, content, embedding <=> '[0.012, -0.034, ...]' AS distance
FROM documents
ORDER BY embedding <=> '[0.012, -0.034, ...]'
LIMIT 5;
```

**거리 연산자 종류:**

| 연산자 | 의미 |
|---|---|
| `<->` | L2(유클리드) 거리 |
| `<#>` | 음의 내적(negative inner product) |
| `<=>` | 코사인 거리 |

가장 큰 매력은 **트랜잭션과 JOIN이 그대로 된다는 점**입니다. 벡터 검색 결과를 `WHERE metadata->>'tenant_id' = '123'` 같은 일반 SQL 조건과 자유롭게 결합할 수 있고, 사용자 테이블·주문 테이블과 JOIN해서 필터링할 수 있습니다. 별도의 동기화 파이프라인(Postgres → 벡터 DB)이 필요 없다는 것 자체가 운영 리스크를 크게 줄여줍니다.

단점은 명확합니다: pgvector의 HNSW/IVFFlat 인덱스는 Postgres 프로세스 안에서 돌기 때문에, 컬렉션이 수천만~수억 벡터 규모로 커지면 인덱스 빌드 시간과 메모리 사용량이 급격히 부담스러워지고, 전용 벡터 DB만큼의 검색 지연시간 최적화는 어렵습니다.

> 💡 **실무 팁**: pgvector의 `HNSW`는 빌드는 느리지만 검색이 빠르고, `IVFFlat`은 빌드가 빠르지만 리콜(recall) 튜닝이 더 까다롭습니다. 데이터가 자주 갱신되는 서비스라면 HNSW의 증분 삽입 지원(`pgvector` 0.5+)을 확인하세요.

---

## 4. 선택 기준 매트릭스

| 기준 | Milvus | pgvector |
|---|---|---|
| 데이터 규모 | 수억~수십억 벡터 | 수십만~수천만 벡터 |
| 운영 부담 | 높음 (etcd, MinIO, Pulsar, K8s) | 낮음 (기존 Postgres에 확장만 추가) |
| 기존 스택 | 벡터 검색이 핵심 워크로드일 때 | 이미 Postgres를 RDB로 쓰고 있을 때 |
| 트랜잭션/JOIN | 지원 안 함 (전용 벡터 저장소) | 완전 지원 (일반 SQL과 결합) |
| QPS/지연시간 | 최적화 여지 큼 (샤딩, GPU 인덱스) | 인스턴스 스펙에 의존, 한계 있음 |
| 팀 러닝 커브 | 새로운 시스템 학습 필요 | 기존 SQL 지식 재사용 |
| 멀티테넌시 필터링 | 파티션/컬렉션 단위로 처리 | `WHERE` 절로 자연스럽게 처리 |

**실무 판단 흐름:**

1. 이미 Postgres를 메인 DB로 쓰고, 벡터 데이터가 수백만 건 이하 → **pgvector**로 시작 (인프라 추가 없음)
2. 벡터 검색이 제품의 핵심이고, 억 단위 확장이 예상됨 → **Milvus**(또는 Zilliz Cloud 매니지드) 도입
3. 애매하면 pgvector로 시작해서 병목이 실측될 때 마이그레이션 — 조기 최적화보다 검증된 필요에 따라 확장하는 편이 비용 효율적

> 💡 **실무 팁**: "나중에 Milvus로 옮기면 되지 않냐"는 생각으로 pgvector를 과소평가하지 마세요. 임베딩 차원과 메타데이터 스키마를 처음부터 잘 설계해두면 마이그레이션은 재색인(re-indexing) 스크립트 수준의 작업입니다.

---

## 📝 핵심 요약

1. Milvus는 컴퓨팅/스토리지 분리형 분산 아키텍처로 대규모 벡터 검색에 최적화되어 있지만 운영 복잡도가 높다
2. pgvector는 PostgreSQL 확장이라 별도 인프라 없이 기존 RDB 트랜잭션·JOIN과 함께 벡터 검색을 쓸 수 있다
3. `<->`, `<#>`, `<=>` 연산자로 L2/내적/코사인 거리 검색을 SQL 안에서 바로 수행할 수 있다
4. 선택 기준은 데이터 규모, 운영 부담 감수 여력, 기존 스택과의 통합 필요성 세 가지로 요약된다
5. 확신이 없다면 pgvector로 시작하고, 실측된 병목이 생겼을 때 전용 벡터 DB로 확장하는 전략이 합리적이다

---

## 🔗 참고 자료

- [Milvus 공식 문서](https://milvus.io/docs)
- [pgvector GitHub README](https://github.com/pgvector/pgvector)
- [Zilliz — Milvus vs pgvector 벤치마크](https://zilliz.com/blog)

---

*⬅️ 이전: [Day 21 — Qdrant / Chroma 실습](../day-21/)  |  다음: [Day 23 — FastAPI 기초 — REST API 설계](../day-23/) ➡️*
