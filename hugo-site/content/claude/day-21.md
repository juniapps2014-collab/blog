---
title: "Day 21 — RAG 패턴"
date: 2026-07-13
weight: 21
---


> **Phase 4: 고급/프로덕션** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- RAG(Retrieval-Augmented Generation)가 필요한 이유와 기본 파이프라인 구조를 설명할 수 있다
- Voyage AI 임베딩으로 문서를 벡터화하고 유사도 검색을 구현할 수 있다
- Contextual Retrieval 기법과 `search_result` 콘텐츠 블록을 활용해 검색 정확도와 답변의 출처 신뢰성을 동시에 높일 수 있다

---

## 1. RAG란 무엇이고 왜 필요한가

Claude는 학습 시점 이후의 정보나 사내 문서, 최신 고객 데이터처럼 학습 데이터에 없는 내용은 알지 못합니다. 매번 이런 정보를 프롬프트에 통째로 넣는 것은 컨텍스트 창 한계와 비용 때문에 현실적이지 않습니다. RAG는 질문이 들어올 때마다 관련 문서 조각만 검색해서 프롬프트에 끼워 넣는 방식으로 이 문제를 해결합니다.

기본 파이프라인은 세 단계입니다. 먼저 문서를 작은 조각(chunk)으로 나누고 임베딩 모델로 벡터화해 벡터 데이터베이스에 저장합니다. 사용자 질문이 들어오면 질문도 같은 임베딩 모델로 벡터화해 가장 유사한 청크를 찾습니다(검색). 마지막으로 검색된 청크를 Claude에 컨텍스트로 제공해 답변을 생성합니다(생성). 참고로 Anthropic은 자체 임베딩 모델을 제공하지 않으며, 공식 문서에서는 파트너사인 Voyage AI를 권장합니다.

| 단계 | 역할 | 대표 도구 |
|------|------|-----------|
| Indexing | 문서 청킹 + 임베딩 + 저장 | Voyage AI, 벡터 DB(Pinecone 등) |
| Retrieval | 질문 임베딩 + 유사도 검색 | 코사인 유사도, BM25 |
| Generation | 검색 결과를 컨텍스트로 답변 생성 | Claude Messages API |

---

## 2. Voyage AI 임베딩으로 검색 구현하기

Voyage AI는 `voyage-4`(범용), `voyage-code-3`(코드), `voyage-law-2`(법률) 등 도메인별 모델을 제공합니다. 문서와 질문을 임베딩할 때는 `input_type`을 각각 `"document"`와 `"query"`로 지정해야 검색 품질이 최적화됩니다.

```python
import voyageai
import numpy as np

vo = voyageai.Client()  # VOYAGE_API_KEY 환경변수 사용

documents = [
    "환불은 구매 후 14일 이내에만 가능합니다.",
    "배송은 평균 3~5영업일이 소요됩니다.",
    "회원 등급은 연간 구매액에 따라 4단계로 나뉩니다.",
]

# 문서 임베딩 (input_type="document")
doc_embds = vo.embed(documents, model="voyage-4", input_type="document").embeddings

query = "환불 정책이 어떻게 되나요?"
query_embd = vo.embed([query], model="voyage-4", input_type="query").embeddings[0]

# Voyage 임베딩은 정규화되어 있어 내적(dot product)이 코사인 유사도와 같다
similarities = np.dot(doc_embds, query_embd)
top_idx = np.argmax(similarities)
print(documents[top_idx])  # "환불은 구매 후 14일 이내에만 가능합니다."
```

실무에서는 이 검색 결과를 그대로 Claude에 넘기기보다, 상위 N개 청크를 리랭커(`rerank-2.5` 등)로 한 번 더 정렬해 가장 관련성 높은 결과만 컨텍스트에 포함시키는 것이 일반적입니다. 벡터 검색은 후보를 넓게 뽑고, 리랭커가 정밀하게 좁히는 2단계 구조입니다.

---

## 3. Contextual Retrieval과 Citations로 정확도·신뢰성 높이기

기본 청킹의 문제는 청크 하나만 떼어놓으면 맥락이 사라진다는 점입니다. 예를 들어 "이 정책은 지난달부터 적용된다"라는 청크는 무엇에 대한 정책인지 알 수 없습니다. Anthropic이 공개한 **Contextual Retrieval** 기법은 청크를 임베딩하기 전에 전체 문서를 기준으로 그 청크가 무엇에 관한 것인지 50~100 토큰짜리 설명을 Claude로 생성해 앞에 붙입니다. 이렇게 만든 "컨텍스트 강화 청크"를 임베딩과 BM25 색인 양쪽에 모두 사용합니다. Anthropic 자체 평가에서 이 방법은 검색 실패율을 35% 줄였고, 리랭킹까지 더하면 67%까지 줄었습니다. 문서 하나당 이런 설명을 미리 한 번만 생성하면 되므로, 프롬프트 캐싱을 활용하면 비용 부담도 크지 않습니다.

검색 정확도를 높였다면, 다음 문제는 "Claude가 어떤 근거로 이 답을 냈는가"입니다. 검색된 청크를 그냥 텍스트로 붙여넣으면 Claude가 실제로 어느 문장을 참고했는지 알기 어렵습니다. 이때는 `search_result` 콘텐츠 블록을 쓰면 Claude가 응답에 출처(URL/ID)와 인용 구간을 자동으로 붙여줍니다. 웹 검색 결과에 인용이 붙는 것과 동일한 방식이 RAG 파이프라인에도 그대로 적용되는 것입니다.

```python
from anthropic import Anthropic
from anthropic.types import MessageParam, TextBlockParam, SearchResultBlockParam

client = Anthropic()

# 벡터 검색으로 찾은 상위 청크를 search_result 블록으로 변환
search_results = [
    SearchResultBlockParam(
        type="search_result",
        source="internal://policy/refund-guide",
        title="환불 정책 가이드",
        content=[TextBlockParam(type="text", text="환불은 구매 후 14일 이내에만 가능합니다.")],
        citations={"enabled": True},
    ),
]

response = client.messages.create(
    model="claude-sonnet-5",
    max_tokens=1024,
    messages=[
        MessageParam(
            role="user",
            content=[*search_results, TextBlockParam(type="text", text="환불 정책이 어떻게 되나요?")],
        )
    ],
)
```

이렇게 하면 응답의 각 문장에 `search_result_location` 타입 인용이 달려 어떤 청크에서 어떤 문장을 근거로 답했는지 그대로 추적할 수 있습니다. `cited_text`는 출력 토큰으로 과금되지 않으므로 근거 인용을 붙여도 비용 부담이 크지 않습니다.

---

## 📝 핵심 요약

1. RAG는 질문마다 관련 문서 조각만 검색해 컨텍스트에 주입함으로써 컨텍스트 창 한계와 최신성 문제를 동시에 해결한다
2. Anthropic은 자체 임베딩 모델이 없고 Voyage AI를 권장하며, 문서는 `input_type="document"`, 질문은 `input_type="query"`로 임베딩해야 검색 품질이 최적화된다
3. Contextual Retrieval은 청크에 문서 전체 맥락을 요약해 붙인 뒤 임베딩·BM25 색인에 함께 사용하는 기법으로, 검색 실패율을 35~67% 줄인다
4. `search_result` 콘텐츠 블록을 쓰면 Claude가 근거 출처와 인용 구간을 응답에 자동으로 붙여주며, 인용 텍스트는 출력 토큰으로 과금되지 않는다
5. 실무 RAG는 벡터 검색으로 후보를 넓게 뽑고 리랭커로 정밀하게 좁히는 2단계 구조가 일반적이다

---

## 🔗 참고 자료

- [Embeddings](https://platform.claude.com/docs/en/build-with-claude/embeddings)
- [Contextual Retrieval in AI Systems](https://www.anthropic.com/engineering/contextual-retrieval)
- [Search results](https://platform.claude.com/docs/en/build-with-claude/search-results)
- [Citations](https://platform.claude.com/docs/en/build-with-claude/citations)

---

*⬅️ 이전: [Day 20 — Multi-agent 시스템 설계](../day-20/)  |  다음: [Day 22 — 프롬프트 인젝션 방어 및 보안](../day-22/) ➡️*
