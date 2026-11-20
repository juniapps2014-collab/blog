---
title: "Day 09 — OPC UA 서버·클라이언트 기초 실습"
date: 2026-11-20
weight: 9
---

> **Phase 2: 현실에서 데이터 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- `opcua-asyncio`로 OPC UA 서버를 직접 띄워 네임스페이스·ObjectType·변수 노드를 만들고, 주소 공간이 "자체 설명적"이라는 말이 코드 수준에서 무엇을 뜻하는지 설명할 수 있다
- 클라이언트에서 브라우징·읽기·Subscription(MonitoredItem)을 구현하고, 폴링과 구독의 차이·`publishing_interval`과 `sampling_interval`의 역할·deadband로 트래픽을 줄이는 법을 구분해 쓸 수 있다
- OPC UA 보안 엔드포인트와 인증서 신뢰 구조를 이해하고, Day 08에서 만든 MQTT 파이프라인으로 값을 넘기는 브리지를 설계할 수 있다

---

## 1. MQTT 브로커와 OPC UA 서버는 같은 자리에 있지 않다

Day 08에서 만든 Mosquitto는 **토픽 문자열을 중계하는 우체국**이었습니다. 브로커는 `factory/suwon/line1/press-01/temp.die`가 섭씨인지 화씨인지, 그 값이 무엇의 온도인지 전혀 모릅니다. 의미는 전부 사람이 토픽 이름과 JSON 키에 손으로 넣은 것이고, 그 규약이 깨지면 아무도 막아 주지 않습니다.

OPC UA 서버는 반대쪽 극단입니다. 서버는 **자기가 가진 데이터의 구조를 스스로 설명합니다.** 클라이언트는 사전 약속 없이 서버에 접속해서 "너 뭐 갖고 있니"를 물어볼 수 있고, 서버는 트리 구조로 답합니다. 각 노드에는 데이터 타입, 엔지니어링 단위, 값 범위, 읽기/쓰기 권한, 그리고 "이게 어떤 종류의 설비인지"를 가리키는 타입 참조가 붙어 있습니다.

| | MQTT | OPC UA |
|---|---|---|
| 데이터 식별 | 토픽 문자열 (약속) | NodeId (서버가 보장) |
| 구조 발견 | 불가능 — 문서를 봐야 함 | Browse 서비스로 런타임 탐색 |
| 타입 정보 | 없음 | DataType, ObjectType, 단위(EUInformation) |
| 통신 방향 | 발행/구독 (단방향 중계) | 세션 기반 요청/응답 + 구독 |
| 연결 모델 | 브로커 경유 (N:N) | 클라이언트–서버 직결 (1:1 세션) |

그래서 실무 구성은 보통 **둘 중 하나를 고르는 게 아니라 둘을 잇는 모양**이 됩니다.

```
[PLC/설비] ──OPC UA──▶ [엣지 게이트웨이] ──MQTT──▶ [클라우드/트윈]
            풍부한 의미              가볍고 방화벽 친화적
```

현장 쪽은 의미가 필요하므로 OPC UA, 상위 전송은 가볍고 NAT·방화벽을 잘 통과하는 MQTT. 오늘은 왼쪽 절반을 만들고, 마지막 섹션에서 화살표를 이어 붙입니다.

---

## 2. 주소 공간 — 오늘 반드시 이해해야 하는 개념

OPC UA에서 모든 것은 **노드(Node)** 입니다. 노드는 NodeId로 식별되고, 참조(Reference)로 서로 연결되어 그래프를 이룹니다.

NodeId는 이렇게 생겼습니다.

```
ns=2;i=1042        → 네임스페이스 2번, 숫자 식별자 1042
ns=2;s="PRESS01"."DieTemp"   → 문자열 식별자 (지멘스 PLC에서 흔한 형태)
ns=0;i=85          → Objects 폴더 (모든 서버에 동일하게 존재)
```

**`ns=` 를 무시하면 반드시 사고가 납니다.** 네임스페이스 0은 OPC UA 표준이 정의한 노드(서버 상태, 기본 타입 등)이고, 1번 이후는 서버가 자기 것을 등록한 영역입니다. 그런데 **네임스페이스 인덱스는 서버 재시작이나 펌웨어 업데이트로 바뀔 수 있습니다.** 안정적인 것은 인덱스가 아니라 네임스페이스 URI(`http://mycompany.com/dt-demo/`)이므로, 클라이언트는 항상 URI로 인덱스를 조회한 뒤 써야 합니다. 설정 파일에 `ns=2;i=1042`를 하드코딩해 두고 어느 날 전체 태그가 깨지는 것이 OPC UA 입문자의 통과의례입니다.

노드에는 종류(NodeClass)가 있습니다. 실습에서 만질 것은 셋뿐입니다.

- **Object** — 폴더나 설비 같은 컨테이너. 값이 없습니다.
- **Variable** — 실제 값을 가진 노드. 센서 태그가 여기 해당합니다.
- **ObjectType / VariableType** — "프레스 기계는 이런 변수들을 갖는다"는 틀. 이게 OPC UA가 단순 태그 목록과 갈라지는 지점입니다.

그리고 Variable 노드의 값은 숫자 하나가 아니라 **DataValue 묶음**입니다.

```
Value        : 180.4
StatusCode   : Good / Bad_SensorFailure / Uncertain_LastUsableValue ...
SourceTimestamp : 2026-11-20T04:12:33.120Z   ← 현장에서 측정된 시각
ServerTimestamp : 2026-11-20T04:12:33.190Z   ← 서버가 처리한 시각
```

Day 06에서 "품질 플래그(`q`)를 페이로드에 넣어야 한다"고 했던 것, Day 07·08에서 JSON에 `ts`와 `q`를 손으로 넣었던 것이 **OPC UA에서는 프로토콜 차원에 이미 들어 있습니다.** 그리고 타임스탬프가 둘인 이유도 중요합니다 — 두 값의 차이가 벌어지면 네트워크나 서버가 밀리고 있다는 뜻이고, 트윈에서 "현실보다 몇 초 뒤처진 화면"을 보고 있다는 신호입니다.

---

## 3. 서버 만들기

Python에서는 `opcua-asyncio`(패키지명 `asyncua`)가 사실상 표준입니다.

```bash
pip install asyncua
```

### 뼈대

```python
# dt_server.py
import asyncio, math, random
from asyncua import Server, ua

URI = "http://daylogs.me/dt-demo/"

async def main():
    server = Server()
    await server.init()
    server.set_endpoint("opc.tcp://0.0.0.0:4840/dt/")
    server.set_server_name("DT Demo Server")

    idx = await server.register_namespace(URI)   # 보통 2가 된다 (의존하지 말 것)

    objects = server.nodes.objects

    # ── 설비 타입 정의: "프레스는 이런 변수를 갖는다"
    types = server.nodes.base_object_type
    press_type = await types.add_object_type(idx, "PressType")
    t_temp = await press_type.add_variable(idx, "DieTemp", 0.0)
    t_amps = await press_type.add_variable(idx, "Current", 0.0)
    t_state = await press_type.add_variable(idx, "State", "idle")
    for n in (t_temp, t_amps, t_state):
        await n.set_modelling_rule(True)   # 인스턴스에 반드시 생성

    # ── 인스턴스 생성
    line1 = await objects.add_folder(idx, "Line1")
    press = await line1.add_object(idx, "Press01", press_type)

    temp = await press.get_child(f"{idx}:DieTemp")
    amps = await press.get_child(f"{idx}:Current")
    state = await press.get_child(f"{idx}:State")

    # ── 엔지니어링 단위와 범위를 노드에 붙인다
    await temp.set_writable(False)
    await temp.add_property(idx, "EngineeringUnits",
                            ua.EUInformation(DisplayName=ua.LocalizedText("degC"),
                                             Description=ua.LocalizedText("degree Celsius")))
    await temp.add_property(idx, "EURange", ua.Range(Low=0.0, High=250.0))

    async with server:
        t = 0
        while True:
            v = 180 + 6 * math.sin(t / 40) + random.gauss(0, 0.4)
            await temp.write_value(v)
            await amps.write_value(12 + 0.05 * (v - 180) + random.gauss(0, 0.3))
            if t % 60 == 0:
                await state.write_value("running" if random.random() > 0.1 else "idle")
            t += 1
            await asyncio.sleep(1)

asyncio.run(main())
```

### 여기서 벌어진 중요한 일

**ObjectType을 먼저 정의하고 인스턴스를 찍어 냈습니다.** 프레스가 10대로 늘어도 `add_object(idx, "Press02", press_type)` 한 줄이면 되고, 모든 인스턴스가 같은 변수 집합·같은 구조를 갖는 것이 **서버 차원에서 보장**됩니다. MQTT였다면 "Press02 토픽에 temp.die를 꼭 같은 이름으로 쓰자"는 사람끼리의 약속이었을 일입니다.

더 중요한 건 클라이언트 쪽입니다. 클라이언트가 어떤 노드를 만났을 때 "이건 PressType이다"를 알면, **그 설비에 어떤 3D 모델과 어떤 대시보드 레이아웃을 붙일지 자동으로 결정**할 수 있습니다. Day 16(자산 계층 구조와 명명 규칙), Day 17(DTDL·AAS)에서 이 아이디어를 정면으로 다룹니다. OPC UA의 ObjectType은 그 세계의 가장 현장에 가까운 형태입니다.

**`EngineeringUnits`와 `EURange`를 속성으로 붙였습니다.** 이제 클라이언트는 180.4라는 숫자와 함께 "섭씨이고, 0~250 범위이며, 쓰기 불가"라는 정보를 서버에서 직접 받습니다. 트윈 게이지의 최소/최대값을 코드에 하드코딩하지 않아도 된다는 뜻입니다.

> 💡 **실무 팁**: `set_modelling_rule(True)`를 빼먹으면 타입에 변수를 정의해도 **인스턴스에 아무것도 생기지 않습니다.** `get_child`가 `BadNoMatch`로 떨어지고, 원인을 찾느라 한참 헤매게 되는 대표적인 함정입니다.

---

## 4. 클라이언트 — 브라우징과 구독

### 브라우징: 모르는 서버 탐색하기

실제 현장에서는 남이 만든 서버에 붙어 "뭐가 있는지" 알아내는 것부터 시작합니다.

```python
# browse.py
import asyncio
from asyncua import Client

async def walk(node, depth=0):
    for child in await node.get_children():
        name = await child.read_browse_name()
        cls = await child.read_node_class()
        line = f"{'  ' * depth}{name.Name}  [{cls.name}]  {child.nodeid.to_string()}"
        try:
            if cls.name == "Variable":
                dv = await child.read_data_value()
                line += f"  = {dv.Value.Value} ({dv.StatusCode.name})"
        except Exception:
            pass
        print(line)
        if depth < 3:
            await walk(child, depth + 1)

async def main():
    async with Client("opc.tcp://localhost:4840/dt/") as client:
        idx = await client.get_namespace_index("http://daylogs.me/dt-demo/")
        print("namespace index =", idx)
        await walk(client.nodes.objects)

asyncio.run(main())
```

`get_namespace_index(URI)`가 2절에서 말한 핵심입니다. **인덱스를 묻지 말고 URI로 조회**하는 이 한 줄이 서버 재시작 후에도 코드가 살아남게 합니다.

> 💡 **실무 팁**: 탐색 단계에서는 코드보다 **UaExpert** 같은 GUI 클라이언트가 훨씬 빠릅니다. 주소 공간 트리를 눈으로 펼쳐 보고, 노드를 끌어다 값 변화를 바로 확인할 수 있습니다. 코드는 쓸 노드를 확정한 뒤에 쓰세요.

### 폴링이 아니라 구독

초보자가 가장 흔히 하는 실수는 `while True: await node.read_value()` 입니다. 동작은 하지만 틀렸습니다. 태그 500개를 1초마다 읽으면 초당 500번의 요청/응답이 오가고, **값이 하나도 안 변해도 같은 트래픽이 흐릅니다.** OPC UA는 이 문제를 Subscription으로 해결합니다.

```python
# subscribe.py
import asyncio
from asyncua import Client, ua

class Handler:
    def datachange_notification(self, node, val, data):
        dv = data.monitored_item.Value
        print(f"{node.nodeid.to_string()}  {val}  "
              f"status={dv.StatusCode.name}  src={dv.SourceTimestamp}")

async def main():
    async with Client("opc.tcp://localhost:4840/dt/") as client:
        idx = await client.get_namespace_index("http://daylogs.me/dt-demo/")
        press = await client.nodes.objects.get_child(
            [f"{idx}:Line1", f"{idx}:Press01"])
        temp = await press.get_child(f"{idx}:DieTemp")
        amps = await press.get_child(f"{idx}:Current")

        sub = await client.create_subscription(500, Handler())   # publishing interval 500ms

        # 0.5도 미만의 변화는 알리지 말 것 (absolute deadband)
        filt = ua.DataChangeFilter(
            Trigger=ua.DataChangeTrigger.StatusValue,
            DeadbandType=ua.DeadbandType.Absolute,
            DeadbandValue=0.5)
        params = ua.MonitoringParameters(
            SamplingInterval=100, QueueSize=10, DiscardOldest=True,
            Filter=ua.ExtensionObject.from_object(filt)
                if hasattr(ua.ExtensionObject, "from_object") else filt)

        await sub.subscribe_data_change(temp, monitoring_parameters=params)
        await sub.subscribe_data_change(amps)

        await asyncio.sleep(3600)

asyncio.run(main())
```

여기 숫자 세 개의 역할이 각각 다릅니다. 이걸 섞어 쓰면 "데이터가 너무 자주 오거나 너무 느리게 오는" 문제가 생깁니다.

| 파라미터 | 누가 쓰는가 | 의미 |
|---|---|---|
| `SamplingInterval` (100ms) | 서버가 소스를 들여다보는 주기 | 짧을수록 변화를 놓치지 않지만 서버 부하가 늘어남 |
| `publishing_interval` (500ms) | 서버가 모아 둔 알림을 클라이언트에 보내는 주기 | 네트워크 패킷 수를 결정 |
| `QueueSize` (10) | 두 발행 사이에 쌓아 둘 샘플 개수 | 100ms 샘플링 × 500ms 발행 = 5개 → 10이면 여유 있음 |

즉 **서버는 100ms마다 보고, 500ms마다 모아서 한 번에 보냅니다.** 샘플링은 빠르게 하되 네트워크는 아끼는 구조이고, 이것이 폴링과의 결정적 차이입니다. 반대로 `QueueSize=1`로 두면 500ms 안에 생긴 5개 중 4개는 버려집니다 — 진동처럼 피크가 중요한 신호(Day 30)에서는 치명적입니다.

**Deadband**는 트래픽을 더 줄입니다. 금형 온도가 ±0.1도로 미세하게 떨리는 것까지 전부 올릴 이유는 없으니, 0.5도 이상 변했을 때만 알림을 받습니다. 태그가 수천 개인 현장에서 deadband 설정 하나가 전체 트래픽을 한 자릿수로 줄이는 일도 드물지 않습니다. 다만 **deadband를 크게 잡으면 그만큼 트윈이 둔감해집니다.** Day 11(엣지 전처리)에서 같은 고민을 다른 층위에서 다시 하게 됩니다.

> 💡 **실무 팁**: 구독을 걸어 놓고 **아무 알림도 안 오는** 경우, 값이 안 변하는 게 아니라 세션은 살아 있는데 구독이 죽은 상황일 수 있습니다. OPC UA는 알릴 데이터가 없어도 `publishing_interval` × `KeepAliveCount`마다 keep-alive 메시지를 보내므로, 그마저 끊겼는지 확인하면 둘을 구분할 수 있습니다.

---

## 5. 보안 — 기본값으로 두면 안 되는 것

OPC UA는 보안이 규격 안에 들어 있습니다. 서버는 여러 **엔드포인트**를 내걸고, 각각 보안 정책 조합을 갖습니다.

```
opc.tcp://host:4840/dt/  SecurityPolicy=None,                 MessageMode=None
opc.tcp://host:4840/dt/  SecurityPolicy=Basic256Sha256,       MessageMode=Sign
opc.tcp://host:4840/dt/  SecurityPolicy=Basic256Sha256,       MessageMode=SignAndEncrypt
```

- **None** — 평문. 오늘 실습용이고, 현장에 이대로 두면 누구나 값을 읽고 쓸 수 있습니다.
- **Sign** — 메시지 변조 방지. 내용은 평문으로 보입니다.
- **SignAndEncrypt** — 서명 + 암호화. 운영에서 기본값으로 삼아야 하는 것.

클라이언트에서 보안을 켜려면 인증서 쌍이 필요합니다.

```python
await client.set_security_string(
    "Basic256Sha256,SignAndEncrypt,client_cert.der,client_key.pem")
```

여기서 입문자가 거의 반드시 막히는 지점이 있습니다. **OPC UA의 인증서 신뢰는 상호(mutual) 방식입니다.** 클라이언트가 서버를 신뢰해야 할 뿐 아니라, 서버도 클라이언트 인증서를 **자기 신뢰 목록에 넣어 줘야** 합니다. 처음 접속하면 서버는 보통 연결을 거부하면서 그 인증서를 `rejected` 디렉터리에 저장해 두는데, 운영자가 그걸 `trusted`로 옮겨야 비로소 접속됩니다. "인증서를 제대로 만들었는데 `BadSecurityChecksFailed`가 난다"면 열에 아홉은 이 단계를 안 한 것입니다.

그리고 인증서(애플리케이션 신원)와 **사용자 인증은 별개 층**입니다. 익명·사용자명/비밀번호·X.509 사용자 인증서 중에서 서버가 허용하는 방식을 고릅니다. Day 08의 Mosquitto ACL처럼, "누가 읽을 수 있고 누가 쓸 수 있는가"는 그 위에서 서버가 노드별 권한(`UserAccessLevel`)으로 통제합니다.

트윈 관점에서 가장 중요한 원칙 하나만 기억하면 됩니다 — **트윈·대시보드 쪽 클라이언트는 쓰기 권한을 받지 않습니다.** 시각화가 설비에 값을 쓸 수 있는 구조는 그 자체가 사고 경로입니다. 관련된 OT/IT 분리 설계는 Day 37에서 본격적으로 다룹니다.

---

## 6. OPC UA를 MQTT로 흘려보내기

이제 Day 08의 브로커와 이어 붙입니다. 엣지 게이트웨이가 하는 일이 정확히 이것입니다.

```python
# bridge.py — OPC UA 구독 → MQTT 발행
import asyncio, json
from datetime import timezone
from asyncua import Client
import paho.mqtt.client as mqtt

BASE = "factory/suwon/line1/press-01"
MAP = {"DieTemp": ("temp.die", "degC"), "Current": ("current", "A")}

mq = mqtt.Client(client_id="edge-01-opcua")
mq.username_pw_set("edge01", "비밀번호")
mq.connect("localhost", 1883, keepalive=30)
mq.loop_start()

class Bridge:
    def __init__(self, names):
        self.names = names          # {nodeid 문자열: 브라우즈 이름} — 구독 걸 때 채워 둔다

    def datachange_notification(self, node, val, data):
        dv = data.monitored_item.Value
        name = self.names.get(node.nodeid.to_string(), "unknown")
        measure, unit = MAP.get(name, (name, ""))
        ts = (dv.SourceTimestamp or dv.ServerTimestamp)
        payload = {
            "ts": ts.replace(tzinfo=timezone.utc).isoformat(timespec="milliseconds")
                    .replace("+00:00", "Z"),
            "v": val,
            "u": unit,
            "q": "good" if dv.StatusCode.is_good() else "bad",
        }
        mq.publish(f"{BASE}/{measure}", json.dumps(payload), qos=0)
```

브리지 코드에서 눈여겨볼 점이 두 가지입니다.

**타임스탬프를 `SourceTimestamp`로 씁니다.** 게이트웨이가 메시지를 만든 시각(`time.now()`)을 쓰면 안 됩니다. 네트워크가 밀려 3초 뒤에 처리되면 그 3초가 그대로 데이터에 박히고, Day 28(리플레이)이나 Day 30(진동 신호 분석)에서 시간축이 어긋난 채로 분석하게 됩니다. **측정 시각은 측정한 쪽이 찍은 것을 끝까지 들고 가야 합니다.**

**StatusCode를 `q`로 변환합니다.** OPC UA가 프로토콜 차원에서 주던 품질 정보가 MQTT로 내려오면 사라지므로, JSON 필드로 손수 옮겨 담아야 합니다. 이 변환을 빠뜨리면 센서가 고장 나서 `Bad_SensorFailure`로 올라온 값이 **정상값인 척 트윈에 표시됩니다.** Day 06에서 품질 플래그를 강조한 이유가 여기서 구체화됩니다.

### 손실되는 것들

브리지를 지나는 순간 OPC UA가 갖고 있던 것 중 상당수가 사라집니다. ObjectType 구조, 엔지니어링 단위, EURange, 노드 간 참조 관계 — 전부 평평한 토픽 문자열로 납작해집니다. 이게 **MQTT가 가볍고 OPC UA가 무거운 이유**이자, 동시에 Day 17에서 메타데이터 모델(DTDL·AAS)이 따로 필요해지는 이유입니다. 전송 계층에서 잃은 의미를 모델 계층에서 되살리는 셈입니다.

그래서 요즘은 아예 **OPC UA PubSub over MQTT**라는 선택지도 있습니다. OPC UA의 데이터 모델을 유지한 채 MQTT를 전송 수단으로 쓰는 방식인데, 지원 장비가 아직 제한적이고 설정이 복잡해서 이 시리즈의 범위에서는 다루지 않습니다. 다만 "브리지에서 의미가 깎인다"는 문제를 규격 차원에서 풀려는 시도가 있다는 것은 알아 두면 좋습니다.

---

## 📝 핵심 요약

1. OPC UA 서버는 주소 공간으로 **자기 데이터 구조를 스스로 설명한다.** 클라이언트는 사전 문서 없이 Browse로 탐색하고, 값과 함께 DataType·단위·범위·StatusCode·SourceTimestamp를 받는다. MQTT에서 손으로 만들던 규약의 상당 부분이 프로토콜에 내장되어 있다.
2. NodeId의 네임스페이스 인덱스는 **바뀔 수 있다.** 항상 `get_namespace_index(URI)`로 조회해서 쓰고, `ns=2;i=1042`를 설정에 하드코딩하지 않는다.
3. ObjectType을 먼저 정의하고 인스턴스를 만들면 설비가 늘어도 구조가 서버 차원에서 보장되고, 클라이언트는 타입만 보고 3D 모델·대시보드 레이아웃을 결정할 수 있다 — Day 16·17의 자산 모델링으로 이어지는 토대다.
4. 폴링 대신 Subscription을 쓴다. `SamplingInterval`(서버가 보는 주기), `publishing_interval`(보내는 주기), `QueueSize`(그 사이 버퍼)는 역할이 다르며, deadband로 미세 변동을 걸러 트래픽을 크게 줄일 수 있다. 단 deadband가 크면 트윈이 둔감해진다.
5. 운영 엔드포인트는 `Basic256Sha256` + `SignAndEncrypt`가 기본이고, 인증서 신뢰는 **상호 방식**이라 서버의 trusted 목록에 클라이언트 인증서를 넣어 줘야 한다. 트윈 클라이언트에는 쓰기 권한을 주지 않는다.
6. OPC UA → MQTT 브리지에서는 **SourceTimestamp와 StatusCode를 반드시 페이로드로 옮겨 담아야 한다.** 게이트웨이 시각으로 덮어쓰면 시간축이 어긋나고, 품질 정보를 버리면 고장 센서 값이 정상값처럼 트윈에 표시된다.

---

## 🔗 참고 자료

- [OPC UA Part 3: Address Space Model (v1.05)](https://reference.opcfoundation.org/Core/Part3/v105/docs/)
- [OPC UA Part 4: Services — Subscription·MonitoredItem 규격](https://reference.opcfoundation.org/Core/Part4/v105/docs/)
- [OPC UA Part 2: Security Model (v1.05)](https://reference.opcfoundation.org/Core/Part2/v105/docs/)
- [opcua-asyncio (asyncua) 문서](https://opcua-asyncio.readthedocs.io/en/latest/)

---

*⬅️ 이전: [Day 08 — MQTT 실습: Mosquitto로 센서 데이터 발행·구독하기](../day-08/)  |  다음: [Day 10 — 시계열 DB 입문: InfluxDB vs TimescaleDB, 스키마 설계](../day-10/) ➡️*
