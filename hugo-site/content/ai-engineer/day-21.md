---
title: "Day 21 — Qdrant / Chroma 실습"
date: 2026-07-04
weight: 21
---

> **Phase 8: 벡터 데이터베이스** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Chroma(인프로세스 프로토타이핑)와 Qdrant(Docker 기반 프로덕션형)의 차이와 각각의 적합한 사용 시점을 이해한다
- 두 벡터 DB 모두에서 컬렉션 생성, 벡터+메타데이터 upsert, 필터 조건이 포함된 쿼리를 직접 작성할 수 있다

---

## 1. Chroma vs Qdrant — 언제 무엇을 쓰는가

지금까지 RAG의 개념(청킹, 임베딩, 유사도, 하이브리드 검색)을 다뤘다면, 오늘은 이 모든 것을 실제로 담아내는 저장소인 **벡터 데이터베이스**를 직접 다뤄봅니다.

| 구분 | Chroma | Qdrant |
|---|---|---|
| 실행 방식 | 인프로세스(In-process) — 별도 서버 없이 Python 프로세스 안에서 실행 | 독립 서버(Docker/클라우드) — 클라이언트-서버 구조 |
| 설치 난이도 | `pip install chromadb`만으로 즉시 사용 | Docker 컨테이너 실행 또는 Qdrant Cloud 필요 |
| 적합한 상황 | 프로토타입, 로컬 실험, 노트북 기반 개발, 소규모 프로젝트 | 프로덕션 서비스, 다중 클라이언트 접근, 대규모 데이터, 고가용성 필요 |
| 영속성 | 로컬 디스크에 저장 가능(`PersistentClient`)하지만 동시 접근에 제약 | 서버가 동시성/트랜잭션을 전담 관리 |
| 필터링/인덱싱 | 기본적인 메타데이터 필터 지원 | Payload 인덱스, 복합 필터, 페이로드 기반 조건 등 훨씬 정교함 |
| 확장성 | 단일 프로세스 한계 | 샤딩, 복제(replication), 클러스터링 지원 |

**요약하면**: Chroma는 "일단 빠르게 RAG를 돌려보고 싶을 때", Qdrant는 "실제 서비스에 배포할 때"의 기본 선택지입니다. 실무에서는 초기 프로토타입을 Chroma로 만들고, 검증이 끝나면 Qdrant 같은 프로덕션형 DB로 마이그레이션하는 흐름이 흔합니다.

> 💡 **실무 팁**: Chroma도 `chromadb.HttpClient`로 서버 모드 실행이 가능하고, Qdrant도 `:memory:` 모드로 인프로세스 테스트가 가능합니다. 둘의 경계가 절대적인 것은 아니지만, "설계 의도"는 위 표와 같이 명확히 다릅니다.

---

## 2. Chroma 실습 — 로컬 프로토타이핑

설치부터 쿼리까지 별도 인프라 없이 몇 줄로 끝납니다.

```bash
pip install chromadb
```

```python
import chromadb

# 디스크에 영속 저장 (경로가 없으면 자동 생성)
client = chromadb.PersistentClient(path="./chroma_db")

# 컬렉션 생성 (이미 있으면 가져오기)
collection = client.get_or_create_collection(
    name="handbook_chunks",
    metadata={"hnsw:space": "cosine"},   # 거리 지표 지정
)

# 벡터 upsert — 직접 임베딩을 넣거나, documents만 넘기면 기본 임베딩 함수가 자동 적용
collection.upsert(
    ids=["chunk_1", "chunk_2", "chunk_3"],
    documents=[
        "휴가는 입사 1년 후부터 연 15일 발생합니다.",
        "출산 휴가는 법정 기준에 따라 90일 부여됩니다.",
        "환불 정책은 구매 후 7일 이내 신청 가능합니다.",
    ],
    metadatas=[
        {"section": "휴가", "updated_at": "2026-01-01"},
        {"section": "휴가", "updated_at": "2026-01-01"},
        {"section": "환불", "updated_at": "2026-03-15"},
    ],
)

# 필터 조건을 포함한 쿼리
results = collection.query(
    query_texts=["출산휴가는 며칠인가요?"],
    n_results=2,
    where={"section": "휴가"},   # 메타데이터 필터
)

for doc, meta, distance in zip(
    results["documents"][0], results["metadatas"][0], results["distances"][0]
):
    print(f"{distance:.4f} | {meta} | {doc}")
```

Chroma는 `documents`만 넘기면 기본 내장 임베딩 함수(`all-MiniLM-L6-v2`)로 자동 임베딩합니다. 직접 만든 임베딩(OpenAI 등)을 쓰고 싶다면 `embeddings` 파라미터에 벡터를 직접 전달하거나 `embedding_function`을 커스텀 지정하면 됩니다.

```python
from chromadb.utils import embedding_functions

openai_ef = embedding_functions.OpenAIEmbeddingFunction(
    api_key="sk-...",
    model_name="text-embedding-3-small",
)
collection = client.get_or_create_collection(
    name="handbook_chunks_openai",
    embedding_function=openai_ef,
)
```

---

## 3. Qdrant 실습 — Docker 기반 프로덕션형

Qdrant는 서버로 실행되므로 먼저 Docker로 띄웁니다.

```bash
docker run -p 6333:6333 -p 6334:6334 \
  -v $(pwd)/qdrant_storage:/qdrant/storage \
  qdrant/qdrant
```

- `6333`: REST API 포트
- `6334`: gRPC 포트 (대량 upsert 시 더 빠름)
- 볼륨 마운트로 컨테이너를 재시작해도 데이터가 유지됩니다

```bash
pip install qdrant-client
```

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue

client = QdrantClient(url="http://localhost:6333")

# 컬렉션 생성 — 벡터 차원과 거리 지표를 명시해야 함
client.create_collection(
    collection_name="handbook_chunks",
    vectors_config=VectorParams(size=1536, distance=Distance.COSINE),
)

# 벡터 + 메타데이터(payload) upsert
client.upsert(
    collection_name="handbook_chunks",
    points=[
        PointStruct(
            id=1,
            vector=[0.01, -0.02, ...],   # 1536차원 임베딩 벡터
            payload={"section": "휴가", "text": "휴가는 입사 1년 후부터 연 15일 발생합니다.", "updated_at": "2026-01-01"},
        ),
        PointStruct(
            id=2,
            vector=[0.03, 0.04, ...],
            payload={"section": "환불", "text": "환불은 구매 후 7일 이내 신청 가능합니다.", "updated_at": "2026-03-15"},
        ),
    ],
)

# 필터 조건이 포함된 쿼리
results = client.query_points(
    collection_name="handbook_chunks",
    query=[0.02, -0.01, ...],   # 질문 임베딩 벡터
    limit=5,
    query_filter=Filter(
        must=[FieldCondition(key="section", match=MatchValue(value="휴가"))]
    ),
)

for point in results.points:
    print(point.score, point.payload)
```

**Qdrant의 핵심 개념 3가지:**

- **Collection**: 벡터 + payload를 담는 컨테이너. 생성 시 벡터 차원과 거리 지표를 반드시 지정해야 함
- **Point**: `id` + `vector` + `payload`로 구성된 하나의 저장 단위 (Chroma의 document 한 건에 대응)
- **Payload Index**: 자주 필터링하는 필드(`section` 등)에 인덱스를 걸어두면 필터 조건이 포함된 쿼리 속도가 크게 향상됨

```python
# 자주 필터링하는 필드에 인덱스 생성 (대규모 컬렉션에서 필수)
client.create_payload_index(
    collection_name="handbook_chunks",
    field_name="section",
    field_schema="keyword",
)
```

> 💡 **실무 팁**: Qdrant에서 필터를 자주 사용하는데 payload 인덱스를 걸지 않으면, 필터 조건이 있는 쿼리마다 전체 스캔에 가까운 비용이 들 수 있습니다. 프로덕션 배포 전에 자주 쓰는 필터 필드에는 반드시 인덱스를 생성하세요.

---

## 4. 두 방식의 upsert/쿼리 API 비교

| 동작 | Chroma | Qdrant |
|---|---|---|
| 컬렉션 생성 | `get_or_create_collection(name=..., metadata={"hnsw:space": "cosine"})` | `create_collection(collection_name=..., vectors_config=VectorParams(...))` |
| 데이터 추가 | `collection.upsert(ids=, documents=, metadatas=)` | `client.upsert(collection_name=, points=[PointStruct(...)])` |
| 자동 임베딩 | 기본 내장 임베딩 함수 지원 | 없음 — 임베딩은 클라이언트가 직접 계산해서 전달해야 함 |
| 필터 쿼리 | `where={"key": "value"}` (간단한 딕셔너리 문법) | `Filter(must=[FieldCondition(...)])` (명시적 조건 객체) |
| 메타데이터 명칭 | `metadata` | `payload` |

Qdrant는 임베딩을 자동으로 계산해주지 않는다는 점이 중요한 차이입니다 — 이는 설계 철학의 차이로, Qdrant는 "벡터 저장/검색 엔진"에 집중하고 임베딩 생성은 애플리케이션 레이어(OpenAI API 호출 등)의 책임으로 명확히 분리합니다. 반면 Chroma는 빠른 프로토타이핑을 위해 임베딩까지 기본 제공합니다.

---

## 📝 핵심 요약

1. Chroma는 인프로세스 실행으로 설치 즉시 사용 가능한 프로토타이핑용 벡터 DB이고, Qdrant는 Docker/클라우드 기반의 프로덕션 지향 벡터 DB다
2. Chroma는 `documents`만 넘기면 기본 임베딩 함수가 자동 적용되지만, Qdrant는 임베딩 계산을 애플리케이션이 직접 책임진다
3. Qdrant는 컬렉션 생성 시 벡터 차원과 거리 지표를 명시적으로 지정해야 하며, `PointStruct`로 id/vector/payload를 구성한다
4. 필터가 포함된 쿼리를 자주 실행한다면 Qdrant의 payload 인덱스를 반드시 생성해야 필터 성능이 확보된다
5. 실무 흐름은 보통 Chroma로 빠르게 검증한 뒤 Qdrant 같은 프로덕션형 DB로 마이그레이션하는 경로를 따른다

---

## 🔗 참고 자료

- [Chroma 공식 문서](https://docs.trychroma.com/)
- [Qdrant 공식 문서](https://qdrant.tech/documentation/)
- [Qdrant Python Client 레퍼런스](https://python-client.qdrant.tech/)

---

*⬅️ 이전: [Day 20 — Hybrid Search & Reranker](../day-20/)  |  다음: [Day 22 — Milvus / pgvector 비교와 선택 기준](../day-22/) ➡️*
