---
title: "Day 09 — 긴 문서 처리"
date: 2026-06-29
weight: 9
---


> **Phase 2: 프롬프트 엔지니어링** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- Claude의 200K 컨텍스트 윈도우를 효과적으로 활용하는 전략을 설명할 수 있다
- 긴 문서에서 요약, 추출, 분석을 위한 프롬프트 패턴을 작성할 수 있다
- 문서가 컨텍스트 한도를 초과할 경우 청킹(chunking) 전략을 설계할 수 있다

---

## 1. 왜 긴 문서 처리가 중요한가?

Claude의 200K 토큰 컨텍스트는 강력한 무기입니다. 일반적인 A4 문서 한 페이지가 약 400–500 토큰이므로, 이론상 약 400페이지 분량의 문서를 한 번에 처리할 수 있습니다.

하지만 **길다고 무조건 좋은 결과가 나오지 않습니다.** 긴 문서를 다룰 때는 두 가지 문제를 이해해야 합니다.

**Lost-in-the-Middle 현상**

연구에 따르면 LLM은 컨텍스트의 앞부분과 뒷부분에 더 집중하고, 중간 부분의 정보를 놓치는 경향이 있습니다.

```
[잘 기억] 앞부분 → ... [잘 놓침] 중간 ... → [잘 기억] 뒷부분
```

이를 완화하려면: 중요한 정보를 **앞이나 뒤**에 배치하고, 모델에게 "문서 전체를 꼼꼼히 읽어라"라고 명시적으로 지시하세요.

**토큰 비용 vs 성능 트레이드오프**

200K 토큰을 전부 사용하면 API 비용이 선형으로 증가합니다. 필요한 부분만 전달하는 것이 비용과 품질 모두에 유리할 수 있습니다.

---

## 2. 핵심 패턴: 요약, 추출, 분석

### 패턴 1 — 계층적 요약 (Hierarchical Summarization)

문서를 섹션별로 나눠 요약한 뒤, 그 요약본을 다시 요약합니다.

```python
import anthropic

client = anthropic.Anthropic()

def summarize_section(text: str, section_name: str) -> str:
    """섹션 하나를 요약합니다."""
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",  # 비용 절감: Haiku 사용
        max_tokens=300,
        messages=[{
            "role": "user",
            "content": f"""다음 문서 섹션을 3–5문장으로 요약하세요.
섹션 이름: {section_name}

<section>
{text}
</section>"""
        }]
    )
    return response.content[0].text

def final_summary(section_summaries: list[dict]) -> str:
    """섹션 요약들을 합쳐 최종 요약을 만듭니다."""
    combined = "\n\n".join(
        f"[{s['name']}]\n{s['summary']}" for s in section_summaries
    )
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=500,
        messages=[{
            "role": "user",
            "content": f"""다음은 긴 문서의 섹션별 요약입니다.
전체 핵심 내용을 300단어 이내로 요약하세요.

{combined}"""
        }]
    )
    return response.content[0].text

# 사용 예시
sections = [
    {"name": "서론", "text": "..."},
    {"name": "방법론", "text": "..."},
    {"name": "결과", "text": "..."},
]
summaries = [{"name": s["name"], "summary": summarize_section(s["text"], s["name"])} for s in sections]
print(final_summary(summaries))
```

### 패턴 2 — 구조적 정보 추출

문서에서 특정 정보만 뽑아낼 때는 출력 형식을 명확히 지정하세요.

```python
def extract_action_items(document: str) -> list[dict]:
    """문서에서 액션 아이템을 추출합니다."""
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1000,
        messages=[{
            "role": "user",
            "content": f"""다음 회의록에서 액션 아이템을 추출하세요.
JSON 배열 형식으로 반환하세요. 다른 텍스트 없이 JSON만 출력합니다.

형식:
[{{"owner": "담당자", "task": "할 일", "deadline": "기한 또는 null"}}]

<document>
{document}
</document>"""
        }]
    )
    import json
    return json.loads(response.content[0].text)
```

### 패턴 3 — 비교 분석

두 문서 또는 여러 버전을 비교할 때:

```python
def compare_documents(doc_a: str, doc_b: str, aspect: str) -> str:
    """두 문서를 특정 관점에서 비교합니다."""
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=800,
        messages=[{
            "role": "user",
            "content": f"""두 문서를 '{aspect}' 관점에서 비교 분석하세요.

<document_a>
{doc_a}
</document_a>

<document_b>
{doc_b}
</document_b>

비교 결과를 표 형식으로 제시하고, 핵심 차이점 3가지를 간단히 설명하세요."""
        }]
    )
    return response.content[0].text
```

---

## 3. 청킹(Chunking) 전략 — 컨텍스트 초과 시

문서가 200K 토큰을 초과하거나 비용 최적화가 필요할 때 사용합니다.

### 슬라이딩 윈도우 청킹

```python
def chunk_text(text: str, chunk_size: int = 4000, overlap: int = 200) -> list[str]:
    """텍스트를 overlap이 있는 청크로 분할합니다."""
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = start + chunk_size
        chunk = " ".join(words[start:end])
        chunks.append(chunk)
        start += chunk_size - overlap  # overlap만큼 뒤로 물러나 연속성 유지
    return chunks

def process_long_document(document: str, question: str) -> str:
    """긴 문서에서 질문에 답하기 위해 청킹을 사용합니다."""
    chunks = chunk_text(document)
    relevant_answers = []

    for i, chunk in enumerate(chunks):
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=200,
            messages=[{
                "role": "user",
                "content": f"""다음 텍스트 조각에서 이 질문과 관련된 정보가 있으면 추출하세요.
관련 정보가 없으면 "관련 없음"이라고만 답하세요.

질문: {question}

<text>
{chunk}
</text>"""
            }]
        )
        answer = response.content[0].text.strip()
        if answer != "관련 없음":
            relevant_answers.append(f"[청크 {i+1}]: {answer}")

    if not relevant_answers:
        return "문서에서 관련 정보를 찾지 못했습니다."

    # 수집된 정보를 최종 응답으로 통합
    final_response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=500,
        messages=[{
            "role": "user",
            "content": f"""다음 정보들을 바탕으로 질문에 답하세요.

질문: {question}

수집된 정보:
{chr(10).join(relevant_answers)}"""
        }]
    )
    return final_response.content[0].text
```

> 💡 **실무 팁**: overlap을 두면 청크 경계에서 문장이 잘려 맥락이 끊기는 문제를 방지할 수 있습니다. 일반적으로 청크 크기의 5–10%를 overlap으로 설정합니다.

---

## 📝 핵심 요약

1. Claude의 200K 컨텍스트는 강력하지만, **Lost-in-the-Middle** 현상에 주의 — 중요 정보는 앞이나 뒤에 배치
2. 대용량 처리 전략은 세 가지: **계층적 요약**, **구조적 추출**, **청킹**
3. 비용 최적화: 청크 처리의 1차 패스는 Haiku, 통합 단계는 Sonnet 조합이 효과적
4. 슬라이딩 윈도우 청킹에서 **overlap**을 적절히 설정해 경계 문맥 손실 방지
5. 출력 형식(JSON, 표 등)을 명시적으로 지정하면 추출 품질이 크게 향상됨

---

## 🔗 참고 자료

- [Anthropic 공식 문서 — 긴 컨텍스트 팁](https://docs.anthropic.com/en/docs/build-with-claude/context-windows)
- [Claude 모델 개요](https://docs.anthropic.com/en/docs/about-claude/models)
- [프롬프트 엔지니어링 가이드](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)

---

*⬅️ 이전: [Day 08 — XML 태그 활용](../day-08/)  |  다음: [Day 10 — 코드 생성 및 리뷰](../day-10/) ➡️*
