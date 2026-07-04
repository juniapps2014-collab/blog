---
title: "Day 20 — Hybrid Search & Reranker"
date: 2026-07-23
weight: 20
---

> **Phase 7: RAG** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 순수 벡터 검색이 정확한 키워드 매칭을 놓치는 이유를 설명할 수 있다
- BM25(희소 검색)와 벡터 검색(밀집 검색)을 결합하는 하이브리드 검색과 RRF를 이해한다
- 2단계 정밀 필터로서의 리랭커 도입 시점과 지연시간 트레이드오프를 판단할 수 있다

---

## 1. 벡터 검색의 맹점 — "정확히 그 단어"를 놓친다

Day 19에서 다룬 임베딩 기반 벡터 검색은 의미적 유사성을 잘 포착하지만, 역설적으로 **정확한 키워드 매칭에는 약합니다.**

예를 들어 사용자가 "에러 코드 E-4042"를 검색했다고 합시다. 임베딩 모델은 "E-4042"라는 특정 코드 문자열을 하나의 의미 단위로 정확히 구분하지 못하고, 대신 "에러", "코드"라는 일반적인 의미에 이끌려 전혀 다른 에러 코드를 언급한 문서를 더 유사하다고 판단할 수 있습니다. 제품명, 일련번호, 법 조항 번호, 사람 이름, 특정 기술 용어처럼 **정확한 문자열 일치가 중요한 쿼리**에서 벡터 검색만으로는 정밀도가 떨어집니다.

반대로 전통적인 키워드 검색(BM25 등)은 정확한 단어 매칭에는 강하지만 동의어나 문맥적 의미("자동차"와 "차량")를 이해하지 못합니다.

**이것이 하이브리드 검색이 필요한 이유입니다** — 두 방식은 서로의 약점을 정확히 보완합니다.

| 검색 방식 | 강점 | 약점 |
|---|---|---|
| 밀집 검색 (Dense / Vector) | 의미/문맥 이해, 동의어 처리 | 정확한 키워드/숫자/코드 매칭 약함 |
| 희소 검색 (Sparse / BM25) | 정확한 키워드 매칭, 희귀 용어 검색 | 동의어/의역 이해 못 함 |

> 💡 **실무 팁**: 사용자 쿼리에 고유명사, 코드, 버전 번호, ID가 자주 등장하는 도메인(기술 문서, 법률, 커머스 상품 검색)일수록 하이브리드 검색의 효과가 극적으로 커집니다.

---

## 2. BM25 — 희소 검색의 표준

**BM25(Best Matching 25)**는 TF-IDF를 발전시킨 통계 기반 키워드 검색 알고리즘입니다. 문서 내 쿼리 단어의 등장 빈도(Term Frequency)와 전체 코퍼스에서 그 단어가 얼마나 희귀한지(Inverse Document Frequency)를 결합해 점수를 매기며, 문서 길이에 대한 정규화도 포함합니다.

```python
from rank_bm25 import BM25Okapi

corpus = [
    "에러 코드 E-4042는 인증 토큰 만료를 의미합니다",
    "결제 실패 시 E-5001 코드가 반환됩니다",
    "사용자 인증은 OAuth2 흐름을 따릅니다",
]
tokenized_corpus = [doc.split() for doc in corpus]
bm25 = BM25Okapi(tokenized_corpus)

query = "E-4042".split()
scores = bm25.get_scores(query)   # 정확한 코드가 포함된 문서에 높은 점수
```

임베딩과 달리 BM25는 학습이 필요 없고, 계산이 가볍고, 결과 해석이 쉽습니다("이 단어가 몇 번 등장해서 점수가 높다"). 대부분의 벡터 DB(Qdrant, Weaviate)나 검색 엔진(Elasticsearch, OpenSearch)이 밀집 벡터 인덱스와 BM25 기반 희소 인덱스를 동시에 지원합니다.

---

## 3. 하이브리드 검색과 RRF(Reciprocal Rank Fusion)

하이브리드 검색은 같은 쿼리로 벡터 검색과 BM25 검색을 **각각 독립적으로 실행**한 뒤, 두 결과 리스트를 하나로 합칩니다. 문제는 두 검색의 점수 스케일이 다르다는 것입니다 — 코사인 유사도는 -1~1, BM25 점수는 0부터 이론상 무한대까지 나올 수 있습니다. 단순히 점수를 더하거나 평균 내는 것은 스케일이 안 맞아 왜곡됩니다.

**RRF(Reciprocal Rank Fusion)**는 점수 자체가 아니라 **순위(rank)**만 사용해 이 문제를 우회합니다.

```
RRF_score(d) = Σ  1 / (k + rank_i(d))
```

여기서 `rank_i(d)`는 검색 방식 i(벡터 또는 BM25)에서 문서 d가 몇 번째 순위인지이고, `k`는 보통 60으로 설정하는 상수(상위권 밖 문서의 영향을 완만하게 만드는 역할)입니다.

```python
def reciprocal_rank_fusion(rank_lists: list[list[str]], k: int = 60) -> dict[str, float]:
    scores: dict[str, float] = {}
    for ranked_docs in rank_lists:
        for rank, doc_id in enumerate(ranked_docs, start=1):
            scores[doc_id] = scores.get(doc_id, 0) + 1 / (k + rank)
    return dict(sorted(scores.items(), key=lambda x: x[1], reverse=True))

vector_results = ["doc_3", "doc_1", "doc_7"]   # 벡터 검색 상위 3개 (순위순)
bm25_results   = ["doc_1", "doc_9", "doc_3"]   # BM25 상위 3개 (순위순)

fused = reciprocal_rank_fusion([vector_results, bm25_results])
# doc_1이 두 방식 모두에서 상위권이므로 가장 높은 융합 점수를 받음
```

RRF의 장점은 각 검색 방식의 점수 분포나 스케일을 전혀 신경 쓰지 않아도 된다는 것입니다 — 오직 "몇 등이었는가"만 중요하기 때문에 서로 완전히 다른 성격의 검색 결과도 안정적으로 결합할 수 있습니다. Qdrant의 Query API, Weaviate의 `hybrid()` 검색이 내부적으로 RRF(또는 유사한 방식인 relative score fusion)를 지원합니다.

> 💡 **실무 팁**: 벡터 검색과 BM25 검색의 가중치를 조절하고 싶다면(예: 코드 검색 도메인에서는 BM25 비중을 높이고 싶은 경우) RRF에 가중치를 곱한 weighted RRF를 사용하거나, 벡터 DB가 제공하는 alpha 파라미터(밀집:희소 비율)를 조정하면 됩니다.

---

## 4. 리랭커 — 2단계 정밀 필터

하이브리드 검색까지 마쳐도 상위 k개(보통 20~50개) 후보는 여전히 "대략 관련 있어 보이는" 문서 집합일 뿐입니다. **리랭커(Reranker)**는 이 후보군을 대상으로 쿼리와 각 문서를 훨씬 정교하게 비교해 순위를 다시 매기는 2단계 모델입니다.

**왜 처음부터 리랭커로 전체를 검색하지 않는가?**

벡터/BM25 검색은 쿼리와 문서를 각각 독립적으로 벡터화한 뒤 비교하는 **바이-인코더(bi-encoder)** 방식이라 미리 계산해 인덱싱해두면 검색이 매우 빠릅니다. 반면 리랭커는 쿼리와 문서를 **함께** 하나의 모델에 입력해 두 텍스트 사이의 상호작용까지 직접 계산하는 **크로스-인코더(cross-encoder)** 방식입니다. 정확도는 훨씬 높지만, 문서 하나하나를 쿼리와 쌍으로 묶어 모델에 통과시켜야 하므로 전체 지식베이스에 적용하기엔 너무 느립니다.

그래서 실무 패턴은 **"빠르고 거친 1단계(하이브리드 검색으로 top-50 후보 추출) → 느리고 정밀한 2단계(리랭커로 top-50을 재정렬해 top-5만 최종 선택)"** 입니다.

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("BAAI/bge-reranker-v2-m3")

query = "환불 정책이 어떻게 되나요?"
candidates = [
    "배송은 결제 후 2~3일 소요됩니다.",
    "환불은 구매 후 7일 이내 신청 시 전액 처리됩니다.",
    "회원 가입은 이메일 인증이 필요합니다.",
]

pairs = [(query, doc) for doc in candidates]
scores = reranker.predict(pairs)   # 각 (쿼리, 문서) 쌍의 관련성 점수

reranked = sorted(zip(candidates, scores), key=lambda x: x[1], reverse=True)
top_docs = [doc for doc, score in reranked[:5]]
```

Cohere Rerank API처럼 관리형 서비스를 쓰거나, `bge-reranker`, `ms-marco-MiniLM` 같은 오픈소스 크로스-인코더를 로컬에서 실행할 수도 있습니다.

**리랭커 도입 시 지연시간 트레이드오프:**

| 구성 | 상대 지연시간 | 정확도 |
|---|---|---|
| 벡터 검색만 | 기준(가장 빠름) | 보통 |
| 하이브리드 검색(벡터+BM25) | 벡터 검색 대비 소폭 증가 | 보통~높음 |
| 하이브리드 + 리랭커 | 후보 수(k)에 비례해 유의미하게 증가 | 가장 높음 |

> 💡 **실무 팁**: 리랭커는 "공짜 정확도 향상"이 아닙니다. 후보 50개를 리랭킹하면 수백 ms의 추가 지연이 발생할 수 있습니다. 실시간 챗봇처럼 지연시간에 민감한 서비스라면 리랭킹 후보 수를 20개 이하로 줄이거나, 배치/비실시간 파이프라인(문서 요약, 오프라인 분석)에만 리랭커를 적용하는 것을 고려하세요. 검색 품질 저하가 사용자 경험에 미치는 영향이 지연시간 증가보다 클 때만 도입하는 것이 원칙입니다.

---

## 📝 핵심 요약

1. 벡터 검색은 의미 이해에는 강하지만 정확한 키워드/코드/ID 매칭에는 약하므로, 이런 도메인에서는 반드시 하이브리드 검색을 고려해야 한다
2. BM25는 학습이 필요 없는 통계 기반 희소 검색으로, 벡터 검색의 약점을 정확히 보완한다
3. RRF는 점수가 아닌 순위만으로 서로 다른 스케일의 검색 결과를 안정적으로 융합하는 방법이다
4. 리랭커는 크로스-인코더 방식으로 1단계 검색 결과(top-k 후보)를 정밀하게 재정렬하는 2단계 필터이며, 느리기 때문에 후보군에만 선택적으로 적용한다
5. 리랭커 도입 여부는 품질 향상 폭과 추가 지연시간을 실제로 측정해 서비스 요구사항에 맞춰 결정해야 한다

---

## 🔗 참고 자료

- [Qdrant — Hybrid Queries 공식 문서](https://qdrant.tech/documentation/concepts/hybrid-queries/)
- [Cohere Rerank API 공식 문서](https://docs.cohere.com/docs/rerank-2)
- [Elastic — Reciprocal Rank Fusion 설명](https://www.elastic.co/guide/en/elasticsearch/reference/current/rrf.html)

---

*⬅️ 이전: [Day 19 — Embedding Model & Similarity Search](../day-19/)  |  다음: [Day 21 — Qdrant / Chroma 실습](../day-21/) ➡️*
