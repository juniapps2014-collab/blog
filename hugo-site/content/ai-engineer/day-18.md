---
title: "Day 18 — RAG 개념과 Chunking 전략"
date: 2026-07-21
weight: 18
---

> **Phase 7: RAG** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- RAG 파이프라인 전체 흐름(수집 → 청킹 → 임베딩 → 저장 → 검색 → 증강 → 생성)을 설명할 수 있다
- 청크 크기와 오버랩이 검색 품질에 미치는 영향을 이해한다
- 고정 크기/재귀적/시맨틱 청킹 전략의 장단점을 비교하고 상황에 맞게 선택할 수 있다

---

## 1. RAG란 무엇이고 왜 필요한가

**RAG(Retrieval-Augmented Generation)**는 LLM이 답변을 생성하기 전에 외부 지식 베이스에서 관련 정보를 검색(retrieve)해 프롬프트에 삽입(augment)하는 아키텍처입니다.

LLM은 학습 시점 이후의 정보를 모르고, 특정 회사의 내부 문서나 최신 데이터에 대한 지식도 없습니다. 파인튜닝으로 지식을 주입할 수도 있지만 비용이 크고, 지식이 자주 바뀌는 환경(사내 위키, 최신 뉴스, 개인화된 데이터)에서는 매번 재학습이 비현실적입니다. RAG는 모델 가중치를 건드리지 않고 **프롬프트에 실시간으로 관련 문서를 끼워 넣는 방식**으로 이 문제를 해결합니다.

**RAG 파이프라인 7단계:**

| 단계 | 설명 |
|---|---|
| 1. 수집 (Ingest) | PDF, 위키, DB 등에서 원본 문서를 수집 |
| 2. 청킹 (Chunk) | 문서를 검색 가능한 작은 단위로 분할 |
| 3. 임베딩 (Embed) | 각 청크를 벡터로 변환 |
| 4. 저장 (Store) | 벡터 DB에 벡터 + 메타데이터 저장 |
| 5. 검색 (Retrieve) | 사용자 질문을 임베딩해 유사한 청크를 검색 |
| 6. 증강 (Augment) | 검색된 청크를 프롬프트 컨텍스트에 삽입 |
| 7. 생성 (Generate) | LLM이 증강된 프롬프트로 최종 답변 생성 |

이 중 1~4단계는 오프라인(사전 준비) 작업이고, 5~7단계는 사용자 질문이 들어올 때마다 실시간으로 실행되는 온라인 작업입니다. 이번 Day에서는 2단계 청킹에 집중합니다 — 청킹은 RAG 품질을 좌우하는 가장 저평가된 단계입니다.

> 💡 **실무 팁**: RAG 디버깅 시 "생성이 이상하다"고 느껴지면 먼저 5단계(검색)까지만 실행해 어떤 청크가 검색됐는지 확인하세요. 실무에서 RAG 품질 문제의 절반 이상은 생성이 아니라 검색/청킹 단계에서 발생합니다.

---

## 2. 청크 크기가 왜 중요한가

청킹은 긴 문서를 임베딩 모델이 처리할 수 있는, 그리고 검색 시 의미 있는 단위로 반환될 수 있는 작은 조각으로 나누는 작업입니다. 청크 크기 선택은 두 가지 상충하는 힘 사이의 균형입니다.

**청크가 너무 작으면:**
- 문맥이 잘려 청크만 보고는 의미를 알 수 없음 (예: "이 정책은 2024년부터 적용된다"만 남고 "이 정책"이 뭔지는 다른 청크에 있음)
- 검색은 정확하지만 LLM에게 전달되는 정보가 파편적

**청크가 너무 크면:**
- 하나의 청크에 여러 주제가 섞여 임베딩 벡터가 "흐릿해짐"(dilution) — 특정 질문과의 유사도가 떨어짐
- 관련 없는 내용까지 프롬프트에 포함되어 컨텍스트 낭비 및 노이즈 증가
- 컨텍스트 윈도우와 비용 압박

**오버랩(overlap)**은 인접 청크 사이에 일부 텍스트를 중복시키는 기법입니다. 청크 경계에서 문장이나 문단이 잘려 의미가 끊기는 것을 완화합니다.

```python
# 예: 청크 크기 500 토큰, 오버랩 50 토큰
chunk_1 = tokens[0:500]
chunk_2 = tokens[450:950]   # 앞 청크의 마지막 50토큰과 겹침
chunk_3 = tokens[900:1400]
```

일반적인 시작점은 **청크 크기 300~800 토큰, 오버랩 10~20%** 이지만, 이는 문서 종류(법률 문서 vs 채팅 로그 vs 코드)와 임베딩 모델의 최대 입력 길이에 따라 실험적으로 조정해야 하는 하이퍼파라미터입니다.

> 💡 **실무 팁**: 청크 크기는 "느낌"이 아니라 실제 쿼리 셋으로 검색 정확도(recall@k)를 측정하며 튜닝해야 합니다. 하이퍼파라미터라는 사실을 잊지 마세요.

---

## 3. 청킹 전략 비교

### 3-1. 고정 크기 청킹 (Fixed-size Chunking)

가장 단순한 방법. 문자/토큰 수를 기준으로 기계적으로 자릅니다.

```python
def fixed_chunk(text: str, size: int = 500, overlap: int = 50) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start = end - overlap
    return chunks
```

- **장점**: 구현이 매우 간단하고 빠르며 문서 형식에 무관하게 작동
- **단점**: 문장이나 문단 중간을 무자비하게 자를 수 있어 의미 손실 위험이 큼

### 3-2. 재귀적 청킹 (Recursive Character/Text Splitting)

문단 → 문장 → 단어 순으로 구분자 우선순위를 두고, 상위 구분자로 나눴을 때 청크가 여전히 크면 하위 구분자로 재귀적으로 더 쪼갭니다. LangChain의 `RecursiveCharacterTextSplitter`가 대표적 구현입니다.

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=50,
    separators=["\n\n", "\n", ". ", " ", ""],  # 우선순위 순
)
chunks = splitter.split_text(long_document)
```

- **장점**: 문단/문장 경계를 최대한 존중하면서도 크기 제약을 지킴. 실무 기본값으로 가장 널리 쓰임
- **단점**: 여전히 구조 기반이 아니라 구분자 기반이므로, 의미적으로 이질적인 내용이 한 청크에 섞일 수 있음

### 3-3. 시맨틱 청킹 (Semantic Chunking)

문장 단위로 임베딩을 구한 뒤, 인접 문장 간 임베딩 유사도가 급격히 떨어지는 지점(주제가 바뀌는 지점)을 경계로 나눕니다.

```python
# 개념적 흐름 (의사코드)
sentences = split_into_sentences(text)
embeddings = embed_model.encode(sentences)

boundaries = []
for i in range(1, len(sentences)):
    similarity = cosine_similarity(embeddings[i-1], embeddings[i])
    if similarity < threshold:   # 주제 전환 감지
        boundaries.append(i)
```

- **장점**: 의미적으로 응집된 청크를 만들어 검색 정확도가 가장 높은 경우가 많음
- **단점**: 청크마다 임베딩 계산이 추가로 필요해 전처리 비용/시간이 큼, threshold 튜닝이 까다로움

### 3-4. 구조 기반 청킹 (Structure-aware / Document-aware)

Markdown 헤더, HTML 태그, 코드 블록, PDF 섹션 등 문서 자체의 구조를 활용해 나누는 방식. 예를 들어 Markdown 문서라면 `#`, `##` 헤더를 기준으로 나누는 `MarkdownHeaderTextSplitter`가 있습니다. 코드 파일이라면 함수/클래스 단위로 나누는 것이 자연스럽습니다.

**전략 비교 요약:**

| 전략 | 구현 난이도 | 비용 | 품질 | 적합한 상황 |
|---|---|---|---|---|
| 고정 크기 | 매우 낮음 | 매우 낮음 | 낮음 | 프로토타입, 정형화되지 않은 로그 |
| 재귀적 | 낮음 | 낮음 | 중~높음 | 실무 기본값, 대부분의 텍스트 문서 |
| 시맨틱 | 높음 | 높음(임베딩 다회 호출) | 높음 | 고품질이 중요한 소규모 지식베이스 |
| 구조 기반 | 중간 | 낮음 | 높음 | Markdown/코드/명확한 섹션 구조가 있는 문서 |

> 💡 **실무 팁**: 처음부터 시맨틱 청킹으로 시작하지 마세요. `RecursiveCharacterTextSplitter` + 적절한 오버랩으로 베이스라인을 만들고, 검색 품질이 실제로 부족할 때만 더 비싼 전략으로 업그레이드하는 것이 비용 대비 효율적입니다.

---

## 4. 청크에 메타데이터 붙이기

청크 텍스트 자체만큼 중요한 것이 메타데이터입니다. 출처 문서명, 섹션 제목, 페이지 번호, 작성일 등을 청크에 함께 저장해 두면 검색 후 필터링(Day 20에서 다룰 하이브리드 검색과 결합), 출처 표시(citation), 최신 문서 우선순위 부여 등에 활용할 수 있습니다.

```python
chunk_record = {
    "text": chunk_text,
    "metadata": {
        "source": "employee_handbook.pdf",
        "section": "휴가 정책",
        "page": 12,
        "updated_at": "2026-06-01",
    },
}
```

---

## 📝 핵심 요약

1. RAG는 수집→청킹→임베딩→저장→검색→증강→생성의 7단계 파이프라인이며, 앞 4단계는 오프라인, 뒤 3단계는 실시간으로 동작한다
2. 청크 크기는 "문맥 손실"과 "의미 희석" 사이의 트레이드오프이며, 오버랩으로 경계 손실을 완화한다
3. 실무 기본값은 재귀적 청킹(`RecursiveCharacterTextSplitter`)이고, 시맨틱/구조 기반 청킹은 품질이 더 필요할 때 선택적으로 도입한다
4. RAG 디버깅 시 생성 결과보다 먼저 검색된 청크 자체를 확인하는 습관이 중요하다
5. 청크에는 텍스트뿐 아니라 출처/섹션/날짜 등 메타데이터를 함께 저장해야 필터링과 인용이 가능해진다

---

## 🔗 참고 자료

- [LangChain — Text Splitters 공식 문서](https://python.langchain.com/docs/concepts/text_splitters/)
- [Pinecone — Chunking Strategies for LLM Applications](https://www.pinecone.io/learn/chunking-strategies/)
- [LlamaIndex — Node Parsers / Text Splitters](https://docs.llamaindex.ai/en/stable/module_guides/loading/node_parsers/)

---

*⬅️ 이전: [Day 17 — Structured Output & Pydantic 검증](../day-17/)  |  다음: [Day 19 — Embedding Model & Similarity Search](../day-19/) ➡️*
