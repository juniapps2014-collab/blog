---
title: "Day 15 — stdio vs Streamable HTTP — 전송 방식 이해와 실습"
date: 2026-07-18
weight: 15
---

> **Phase 5: MCP** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- MCP의 두 가지 표준 전송 방식(stdio, Streamable HTTP)의 동작 원리와 차이를 설명할 수 있다
- 각 전송 방식이 적합한 배포 시나리오(로컬 데스크톱 vs 네트워크 서비스)를 판단할 수 있다
- HTTP로 MCP 서버를 노출할 때 필요한 인증/보안 설정을 구성할 수 있다

---

## 1. 전송 방식이 왜 두 개로 나뉘는가?

MCP 프로토콜 자체(JSON-RPC 2.0 메시지 구조)는 전송 방식과 무관하게 동일합니다. 하지만 "이 메시지를 어떻게 실어 나를 것인가"는 완전히 다른 문제입니다. Day 14에서 만든 서버는 로컬에서 클라이언트가 직접 실행하는 프로세스였지만, 팀 전체가 공유하는 내부 도구 서버를 만든다면 네트워크 너머의 여러 클라이언트가 접속해야 합니다. 이 두 시나리오를 위해 MCP는 두 가지 표준 전송(transport)을 정의합니다.

| 항목 | stdio | Streamable HTTP |
|---|---|---|
| 통신 방식 | 표준입출력(stdin/stdout) 파이프 | HTTP POST + 서버센트이벤트(SSE) 스트림 |
| 프로세스 모델 | 클라이언트가 서버를 서브프로세스로 직접 실행 | 서버가 독립적으로 상시 구동, 클라이언트는 네트워크로 접속 |
| 클라이언트 수 | 1:1 (프로세스를 실행한 클라이언트 전용) | 1:N (여러 클라이언트가 동시 접속 가능) |
| 네트워크 노출 | 불가 (로컬 프로세스 통신) | 가능 (원격 접속) |
| 대표 사용처 | Claude Desktop, Claude Code, 로컬 개발 | 사내 공유 MCP 서버, SaaS형 MCP 서버 |
| 인증 필요성 | 불필요 (OS 프로세스 권한으로 충분) | 필수 (네트워크 노출이므로) |

---

## 2. stdio — 로컬 서브프로세스 방식

stdio 전송에서는 클라이언트(예: Claude Desktop)가 설정 파일에 적힌 커맨드로 서버 프로세스를 직접 실행(spawn)하고, 그 프로세스의 표준입력/출력 스트림으로 JSON-RPC 메시지를 주고받습니다.

```json
{
  "mcpServers": {
    "weather": {
      "command": "python",
      "args": ["/absolute/path/to/weather_server.py"],
      "env": {
        "WEATHER_API_KEY": "sk-..."
      }
    }
  }
}
```

서버 코드 쪽에서는 전송 방식만 `stdio`로 지정하면 됩니다.

```python
if __name__ == "__main__":
    mcp.run(transport="stdio")
```

**장점**: 별도 네트워크 설정, 인증, TLS가 전혀 필요 없습니다. 클라이언트와 서버가 같은 머신에서 프로세스로 직접 연결되므로 지연시간도 최소화됩니다. 로컬 파일 시스템 접근, 개인 개발 도구 연동에 가장 널리 쓰이는 이유입니다.

**한계**: 클라이언트가 서버 프로세스의 생명주기를 소유하므로, 클라이언트를 껐다 켤 때마다 서버도 재시작됩니다. 또한 구조적으로 다른 컴퓨터의 클라이언트가 접속할 수 없습니다.

> 💡 **실무 팁**: 로컬 개발/개인 생산성 도구(파일 검색, 로컬 DB 조회, 개인 스크립트 실행)라면 굳이 HTTP 서버를 띄울 필요 없이 stdio로 시작하세요. 별도 배포/인증 없이 즉시 동작합니다.

---

## 3. Streamable HTTP — 네트워크 공유형 서버

여러 사용자, 여러 클라이언트가 하나의 MCP 서버를 공유해야 한다면 (예: 팀 전체가 쓰는 내부 GitHub/Jira 연동 서버) 상시 구동되는 독립 프로세스로 서버를 배포하고 HTTP로 노출해야 합니다. **Streamable HTTP**는 이런 시나리오를 위한 전송 방식으로, 클라이언트가 HTTP POST로 요청을 보내고 서버는 단일 요청/응답 또는 SSE 스트림으로 응답합니다(과거의 별도 SSE 전송을 통합/대체한 최신 표준).

```python
# weather_http_server.py
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("weather-server")

@mcp.tool()
def get_weather(city: str) -> str:
    """지정한 도시의 현재 날씨를 조회합니다."""
    return "맑음, 27도"

if __name__ == "__main__":
    mcp.run(transport="streamable-http", host="0.0.0.0", port=8000)
```

클라이언트 측 설정도 명령 실행이 아니라 URL 접속 방식으로 바뀝니다.

```json
{
  "mcpServers": {
    "weather": {
      "url": "https://mcp.internal.example.com/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

**장점**: 서버를 한 번 배포하면 여러 클라이언트/여러 사용자가 동시에 접속할 수 있고, 컨테이너/쿠버네티스 등 기존 웹 서비스 인프라에 그대로 얹을 수 있습니다. 서버 프로세스가 클라이언트와 독립적으로 살아있으므로 상태(State)를 서버 쪽에서 오래 유지하기도 용이합니다.

**한계**: 네트워크에 노출되는 순간 인증, 인가, 레이트 리밋, TLS 등 일반적인 웹 서비스 보안 고려사항이 그대로 적용됩니다.

---

## 4. HTTP로 노출할 때의 보안 고려사항

MCP 서버가 stdio일 때는 "이 프로세스를 실행할 수 있는 사람 = 이 도구를 쓸 수 있는 사람"이라는 OS 레벨 권한 모델에 안전하게 기댈 수 있습니다. 하지만 HTTP로 전환하는 순간 이 가정이 깨지므로 다음을 반드시 고려해야 합니다.

- **인증(Authentication)**: `Authorization: Bearer <token>` 헤더 또는 OAuth 2.1 흐름으로 클라이언트를 식별. MCP 스펙은 OAuth 기반 인가를 권장합니다.
- **인가(Authorization)**: 인증된 클라이언트라도 모든 Tool/Resource에 접근 가능해선 안 됩니다. 사용자별로 호출 가능한 도구 범위를 제한하세요.
- **전송 암호화**: 반드시 HTTPS(TLS)를 사용합니다. 평문 HTTP로 토큰이나 도구 실행 결과를 주고받으면 안 됩니다.
- **입력 검증**: 네트워크로 도달하는 모든 Tool 호출 파라미터는 신뢰할 수 없는 입력으로 간주하고 서버 측에서 재검증합니다.
- **레이트 리밋/감사 로그**: 남용 방지와 사후 추적을 위해 호출 빈도 제한과 요청 로깅을 기본으로 구성합니다.

```python
from mcp.server.fastmcp import FastMCP
from starlette.middleware import Middleware
from starlette.middleware.authentication import AuthenticationMiddleware

mcp = FastMCP("weather-server")

# 실제 운영에서는 AuthenticationMiddleware 등으로
# 모든 요청에 Bearer 토큰 검증을 강제해야 한다
```

> 💡 **실무 팁**: "일단 사내망이니까 인증 없이 배포"는 흔한 실수입니다. 사내망도 내부자 위협이나 VPN 우회 접근에 노출될 수 있으므로, HTTP로 노출하는 MCP 서버는 예외 없이 토큰 기반 인증을 기본값으로 설계하세요.

---

## 📝 핵심 요약

1. stdio는 클라이언트가 서버를 서브프로세스로 직접 실행하는 1:1 로컬 통신 방식이며, 인증이 불필요하다
2. Streamable HTTP는 상시 구동되는 서버에 여러 클라이언트가 네트워크로 접속하는 1:N 방식이다
3. 로컬 개인 도구는 stdio로, 팀/조직이 공유하는 서비스형 도구는 Streamable HTTP로 배포하는 것이 기본 원칙이다
4. HTTP로 노출하는 순간 인증, 인가, TLS, 입력 검증, 레이트 리밋 등 일반 웹 서비스 보안 원칙이 그대로 요구된다
5. `mcp.run(transport=...)` 인자 하나로 stdio와 streamable-http 전환이 가능할 만큼 프로토콜 로직 자체는 전송 방식과 분리되어 있다

---

## 🔗 참고 자료

- [MCP Transports 공식 스펙](https://modelcontextprotocol.io/docs/concepts/transports)
- [MCP Authorization 스펙 (OAuth 2.1)](https://modelcontextprotocol.io/specification/draft/basic/authorization)
- [MCP Python SDK — Streamable HTTP 예제](https://github.com/modelcontextprotocol/python-sdk)

---

*⬅️ 이전: [Day 14 — MCP 개념 — Server/Client, Tool, Resource, Prompt](../day-14/)  |  다음: [Day 16 — Function Calling & JSON Schema](../day-16/) ➡️*
