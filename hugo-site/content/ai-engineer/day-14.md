---
title: "Day 14 — MCP 개념 — Server/Client, Tool, Resource, Prompt"
date: 2026-07-04
weight: 14
---

> **Phase 5: MCP** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- MCP(Model Context Protocol)가 표준화하려는 문제와 "USB-C for AI" 비유의 의미를 설명할 수 있다
- MCP Server가 노출하는 세 가지 프리미티브(Tool, Resource, Prompt)의 차이를 구분할 수 있다
- Python `mcp` SDK로 도구 하나를 노출하는 최소 MCP 서버를 작성할 수 있다

---

## 1. MCP가 해결하는 문제

LLM 에이전트가 외부 시스템(파일, DB, API, SaaS 툴)과 상호작용하려면 "이 도구가 뭘 하는지, 어떻게 호출하는지"를 모델에게 알려줘야 합니다. MCP 이전에는 이 연동을 각 애플리케이션(Claude Desktop, IDE 플러그인, 커스텀 에이전트)마다 **각자 다른 방식**으로 구현했습니다 — N개의 클라이언트가 M개의 도구와 연동하려면 N×M개의 통합 코드가 필요한 상황이었습니다.

**MCP(Model Context Protocol)**는 Anthropic이 공개한 개방형 표준으로, 이 연동 방식을 통일합니다. 흔히 "AI를 위한 USB-C"에 비유되는데, USB-C가 기기마다 다른 충전/데이터 케이블을 하나의 규격으로 통일했듯, MCP는 LLM 애플리케이션(클라이언트)과 외부 시스템(서버) 사이의 통신을 하나의 프로토콜로 통일합니다. 그 결과 도구 제작자는 MCP 서버를 한 번만 만들면 되고, Claude Desktop이든 Claude Code든 커스텀 LangGraph 에이전트든 MCP를 지원하는 모든 클라이언트에서 그대로 재사용할 수 있습니다.

```
[MCP Client]  <---- JSON-RPC 2.0 기반 프로토콜 ---->  [MCP Server]
(Claude Desktop,                                    (파일 시스템, GitHub,
 Claude Code,                                         Slack, 내부 DB,
 커스텀 에이전트 등)                                    커스텀 API 등)
```

> 💡 **실무 팁**: MCP는 "함수 호출 스펙"이 아니라 "연결 프로토콜"입니다. 이미 갖고 있는 내부 API를 MCP 서버로 한 번 감싸두면, 이후 어떤 LLM 클라이언트가 등장해도 재작업 없이 붙일 수 있다는 게 핵심 가치입니다.

---

## 2. MCP의 세 가지 프리미티브

MCP 서버는 클라이언트에게 세 가지 종류의 기능을 노출할 수 있습니다. 이 셋을 구분하는 것이 MCP를 이해하는 핵심입니다.

| 프리미티브 | 정의 | 제어 주체 | 예시 |
|---|---|---|---|
| **Tool** | 모델이 호출해 부수효과를 일으키거나 계산을 수행하는 함수 | 모델(Model-controlled) | `send_slack_message`, `run_sql_query` |
| **Resource** | 모델/클라이언트가 읽을 수 있는 데이터(파일, DB 레코드 등) | 애플리케이션(App-controlled) | `file:///logs/app.log`, `db://users/42` |
| **Prompt** | 재사용 가능한 프롬프트 템플릿(사용자가 직접 선택해 실행) | 사용자(User-controlled) | `/summarize-pr`, `/code-review-template` |

- **Tool**은 Function Calling(Day 16)과 개념적으로 동일합니다. 모델이 "이 도구를 호출하겠다"고 판단하면 클라이언트가 실행하고 결과를 다시 모델에 전달합니다.
- **Resource**는 REST의 GET과 비슷합니다. URI로 식별되며, 모델이 직접 실행하는 게 아니라 클라이언트가 컨텍스트에 첨부하는 방식으로 주로 쓰입니다.
- **Prompt**는 자주 쓰는 요청을 미리 정의해둔 슬래시 커맨드 같은 것으로, 최종 판단은 사용자가 내립니다.

> 💡 **실무 팁**: 새 MCP 서버를 설계할 때 "이 기능을 모델이 자율적으로 호출해도 안전한가?"를 먼저 물어보세요. 안전하면 Tool로, 단순 조회/참고 데이터면 Resource로, 사람이 명시적으로 트리거해야 하는 워크플로우면 Prompt로 분류하는 것이 자연스럽습니다.

---

## 3. MCP Client — 프로토콜의 반대편

MCP Client는 MCP Server에 연결해 위 세 프리미티브를 발견(discover)하고 사용하는 주체입니다. 대표적으로 Claude Desktop, Claude Code, VS Code 확장, 그리고 직접 만드는 커스텀 에이전트가 클라이언트 역할을 합니다.

클라이언트-서버 연결의 기본 흐름은 다음과 같습니다.

1. **초기화(initialize)**: 클라이언트가 서버에 연결하며 지원 프로토콜 버전과 capability를 교환
2. **발견(discovery)**: 클라이언트가 `tools/list`, `resources/list`, `prompts/list`를 호출해 서버가 뭘 제공하는지 조회
3. **호출(invocation)**: 사용자 요청 처리 중 모델이 특정 Tool 호출을 결정하면 클라이언트가 `tools/call`을 서버에 전송
4. **결과 반영**: 서버의 응답을 클라이언트가 모델 컨텍스트에 다시 넣어줌

이 흐름은 전송 방식(stdio 또는 HTTP, Day 15에서 다룸)과 무관하게 동일한 JSON-RPC 메시지 구조를 따릅니다.

---

## 4. 최소 MCP 서버 만들기 (Python SDK)

Python `mcp` SDK의 `FastMCP`를 쓰면 데코레이터만으로 도구 하나를 노출하는 서버를 몇 줄로 작성할 수 있습니다.

```python
# weather_server.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("weather-server")

@mcp.tool()
def get_weather(city: str) -> str:
    """지정한 도시의 현재 날씨를 조회합니다.

    Args:
        city: 날씨를 조회할 도시 이름 (예: "Seoul", "Tokyo")
    """
    # 실제로는 외부 날씨 API 호출
    weather_db = {"Seoul": "맑음, 27도", "Tokyo": "흐림, 24도"}
    return weather_db.get(city, "해당 도시의 날씨 정보를 찾을 수 없습니다.")

@mcp.resource("config://server-info")
def get_server_info() -> str:
    """서버 메타데이터를 Resource로 노출"""
    return "weather-server v1.0 — 지원 도시: Seoul, Tokyo"

if __name__ == "__main__":
    mcp.run(transport="stdio")  # Day 15에서 다룰 전송 방식
```

함수의 **docstring**과 **타입 힌트**가 그대로 모델에게 전달되는 도구 설명(스키마)이 됩니다. `city: str`이라는 타입 힌트는 JSON Schema의 `"type": "string"`으로 자동 변환되고, docstring은 도구 설명(description)으로 사용됩니다 — Day 16에서 다룰 "설명이 정확해야 모델이 도구를 올바르게 호출한다"는 원칙이 MCP 서버 작성에도 그대로 적용됩니다.

Claude Desktop에서 이 서버를 사용하려면 설정 파일에 등록합니다.

```json
{
  "mcpServers": {
    "weather": {
      "command": "python",
      "args": ["/absolute/path/to/weather_server.py"]
    }
  }
}
```

> 💡 **실무 팁**: 도구 함수 이름과 docstring은 최대한 구체적으로 쓰세요. `get_data()`처럼 모호한 이름보다 `get_weather(city: str)`처럼 입력과 목적이 명확한 이름이 모델의 도구 선택 정확도를 크게 높입니다.

---

## 📝 핵심 요약

1. MCP는 LLM 애플리케이션과 외부 시스템 간 연동을 표준화한 개방형 프로토콜이며, "AI를 위한 USB-C"로 비유된다
2. MCP 서버는 Tool(모델이 호출), Resource(데이터 조회), Prompt(사용자가 트리거하는 템플릿) 세 가지를 노출할 수 있다
3. MCP 클라이언트(Claude Desktop, Claude Code 등)는 initialize → discovery → invocation 흐름으로 서버와 통신한다
4. Python `mcp` SDK의 `FastMCP`는 데코레이터 기반으로 함수의 타입 힌트/docstring을 자동으로 도구 스키마로 변환한다
5. 도구 이름과 설명의 명확성이 모델의 도구 선택 정확도에 직접 영향을 준다

---

## 🔗 참고 자료

- [Model Context Protocol 공식 문서](https://modelcontextprotocol.io/introduction)
- [MCP Python SDK (GitHub)](https://github.com/modelcontextprotocol/python-sdk)
- [Anthropic MCP 소개 발표](https://www.anthropic.com/news/model-context-protocol)

---

*⬅️ 이전: [Day 13 — Interrupt & Human-in-the-loop — 사람이 개입하는 워크플로우](../day-13/)  |  다음: [Day 15 — stdio vs Streamable HTTP — 전송 방식 이해와 실습](../day-15/) ➡️*
