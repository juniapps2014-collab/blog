# Day 04 — 출력 형식 제어

> **Phase 1: 기초** | 예상 학습 시간: 30분

---

## 🎯 학습 목표

- 프롬프트만으로 JSON, 마크다운, 일반 텍스트 등 원하는 형식의 출력을 유도할 수 있다
- 구조화된 응답이 필요한 상황과 그렇지 않은 상황을 구분할 수 있다
- 형식 지시가 실패할 때 원인을 진단하고 수정할 수 있다

---

## 1. 왜 출력 형식이 중요한가?

LLM은 기본적으로 자연어를 생성합니다. 하지만 프로덕션 환경에서는 응답을 파싱해 다음 단계에 넘겨야 하는 경우가 많습니다. 형식이 일관되지 않으면 파싱 코드가 깨집니다.

```
사용자 → Claude → JSON 파싱 → DB 저장 → 다음 로직
                     ↑
              형식이 흔들리면 여기서 실패
```

Claude는 명시적 지시 없이도 맥락에서 형식을 추론합니다. 하지만 **프로덕션에서는 명시적으로 지정**하는 것이 원칙입니다.

---

## 2. 형식별 지시 패턴

### JSON 출력

```python
import anthropic
import json

client = anthropic.Anthropic(api_key="your-api-key")

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="""당신은 데이터 추출 어시스턴트입니다.
반드시 다음 JSON 스키마를 따르세요. 코드 블록 없이 순수 JSON만 반환하세요:
{
  "name": "string",
  "email": "string",
  "priority": "high" | "medium" | "low"
}""",
    messages=[{
        "role": "user",
        "content": "박준호 부장님 (junho.park@company.com)이 긴급 요청을 보냈습니다."
    }]
)

# 코드 블록 래퍼 제거 후 파싱
raw = response.content[0].text.strip()
if raw.startswith("```"):
    raw = raw.split("```")[1]
    if raw.startswith("json"):
        raw = raw[4:]

data = json.loads(raw)
print(data)
# {"name": "박준호", "email": "junho.park@company.com", "priority": "high"}
```

**팁**: `"코드 블록 없이 순수 JSON만"` 문구가 핵심입니다. 없으면 Claude가 ` ```json ` 래퍼를 붙이는 경우가 있습니다.

### 마크다운 출력

마크다운은 Claude의 기본 성향이지만, 용도에 따라 명시적으로 요청합니다.

```python
system = """기술 문서를 작성합니다.
다음 구조를 정확히 따르세요:
- H2(##)로 섹션 구분
- 코드는 반드시 언어 지정 코드 블록 사용
- 각 섹션은 최대 3문단
- 불릿 리스트 사용 금지, 산문으로 작성"""
```

### 일반 텍스트 (마크다운 제거)

챗봇이나 음성 인터페이스처럼 마크다운 렌더링이 없는 환경에서 필요합니다.

```python
system = """마크다운 서식을 사용하지 마세요.
별표(*), 샵(#), 백틱(`) 등 특수문자 없이 일반 텍스트로만 답변하세요."""
```

---

## 3. 구조화 출력 심화 — XML과 중첩 구조

JSON보다 Claude가 더 자연스럽게 다루는 형식이 XML입니다. 복잡한 중첩 구조나 긴 텍스트 포함 시 유리합니다.

```python
system = """분석 결과를 다음 XML 형식으로 반환하세요:

<analysis>
  <summary>전체 요약 (2문장)</summary>
  <sentiment>positive | neutral | negative</sentiment>
  <key_points>
    <point>핵심 포인트 1</point>
    <point>핵심 포인트 2</point>
  </key_points>
  <confidence>0.0~1.0 사이 숫자</confidence>
</analysis>"""
```

Python에서 파싱:

```python
import xml.etree.ElementTree as ET

raw = response.content[0].text
# <analysis> 태그 추출
start = raw.find("<analysis>")
end = raw.find("</analysis>") + len("</analysis>")
xml_str = raw[start:end]

root = ET.fromstring(xml_str)
summary = root.find("summary").text
sentiment = root.find("sentiment").text
confidence = float(root.find("confidence").text)

print(f"감정: {sentiment}, 신뢰도: {confidence:.0%}")
```

---

## 4. 형식 지시가 실패할 때

| 증상 | 원인 | 해결책 |
|------|------|--------|
| JSON 대신 설명 텍스트 반환 | 형식 지시가 user 메시지에만 있음 | system 프롬프트로 이동 |
| 코드 블록이 포함됨 | "순수 JSON만" 지시 누락 | 명시적으로 코드 블록 금지 |
| 필드가 누락되거나 추가됨 | 스키마 설명 불명확 | 예시 JSON을 system에 포함 |
| 가끔 형식이 깨짐 | temperature가 높음 | `temperature=0`으로 낮추기 |

```python
# 형식 일관성이 중요할 때는 temperature를 0으로
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=512,
    temperature=0,  # 결정론적 출력
    system="...",
    messages=[...]
)
```

---

## 📝 핵심 요약

1. 형식은 항상 system 프롬프트에 명시적으로 지정 — 추론에 의존하지 않는다
2. JSON 출력 시 "순수 JSON만, 코드 블록 없이" 문구 필수
3. Claude는 XML을 자연스럽게 생성 — 복잡한 중첩 구조엔 XML이 유리
4. 형식 일관성이 중요하면 `temperature=0` 설정
5. 파싱 코드에 방어 로직(코드 블록 제거 등) 항상 포함

---

## 🔗 참고 자료

- [출력 형식 제어 가이드](https://docs.anthropic.com/en/docs/build-with-claude/define-success#decide-on-evaluation-criteria)
- [Structured Output 패턴](https://docs.anthropic.com/en/docs/test-and-evaluate/strengthen-guardrails/increase-consistency)
- [XML 태그 활용법](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/use-xml-tags)

---

*⬅️ 이전: [Day 03 — 컨텍스트와 대화 흐름](./day-03.md)  |  다음: [Day 05 — Claude의 한계와 특성](./day-05.md) ➡️*
