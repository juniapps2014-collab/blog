---
title: "Day 08 — MQTT 실습: Mosquitto로 센서 데이터 발행·구독하기"
date: 2026-11-19
weight: 8
---

> **Phase 2: 현실에서 데이터 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- Mosquitto 브로커를 설정 파일부터 직접 띄우고, 익명 접속을 막은 상태에서 계정·ACL로 발행/구독 권한을 분리할 수 있다
- Day 07에서 설계한 토픽 규약과 JSON 페이로드대로 가짜 센서 퍼블리셔를 Python으로 만들고, retained·LWT가 실제로 어떻게 동작하는지 눈으로 확인할 수 있다
- `$SYS` 토픽과 브로커 로그로 연결 수·메시지 처리량·끊김을 점검해, Day 10의 시계열 DB 수집기를 붙이기 전에 브로커가 건강한지 판단할 수 있다

---

## 1. 왜 공개 테스트 브로커로 시작하면 안 되는가

MQTT를 처음 만지면 `test.mosquitto.org`나 `broker.hivemq.com` 같은 공개 브로커로 `mosquitto_pub` 한 줄을 날려 보는 것으로 시작하기 쉽습니다. 동작 확인용으로는 나쁘지 않지만, 거기서 멈추면 **디지털 트윈에서 정작 중요한 것들을 하나도 못 배웁니다.**

공개 브로커에서는 인증이 없고, ACL이 없고, 토픽 네임스페이스가 전 세계와 공유되며(누군가 내 토픽에 쓰레기 값을 쏠 수 있고 실제로 그렇게 됩니다), persistence 설정을 만질 수 없고, `$SYS` 통계도 내 것이 아닙니다. 즉 Day 07에서 설계한 **토픽 규약·QoS·retain·LWT를 "운영 가능한 형태"로 묶는 연습**이 전혀 되지 않습니다.

그래서 오늘은 처음부터 로컬에 브로커를 세우고, 설정 파일을 한 줄씩 채워 가며 다음 상태까지 갑니다.

```
[fake-sensor.py] ──publish──▶ [Mosquitto 1883/TLS 8883]
     (edge 계정)                      │
                                      ├──▶ [subscriber: 트윈 역할]
                                      ├──▶ [$SYS 모니터링]
                                      └──▶ (Day 10) [Telegraf → InfluxDB]
```

마지막 줄이 중요합니다. 오늘 만드는 브로커는 버리는 실습용이 아니라 **Day 10(시계열 DB), Day 11(엣지 전처리), Day 19(Unity 구독)까지 계속 쓸 물건**입니다. 그래서 설정을 대충 하지 않습니다.

---

## 2. 브로커 세우기 — 설정 파일부터

### 설치

맥이면 `brew install mosquitto`, 데비안 계열이면 `apt install mosquitto mosquitto-clients`, 도커면 `eclipse-mosquitto` 이미지면 됩니다. 어느 쪽이든 **패키지가 깔아 주는 기본 설정으로 그냥 띄우지 말고**, 작업 디렉터리를 하나 만들어 내 설정 파일로 실행하는 편이 훨씬 배우는 게 많습니다.

```
dt-broker/
├── mosquitto.conf
├── passwd              # 해시된 계정 파일
├── acl                 # 토픽별 권한
└── data/               # persistence 파일이 쌓이는 곳
```

### mosquitto.conf

```conf
# ---- 리스너 ----
listener 1883 0.0.0.0
protocol mqtt

# ---- 인증 ----
allow_anonymous false
password_file /path/to/dt-broker/passwd
acl_file /path/to/dt-broker/acl

# ---- 영속성 ----
persistence true
persistence_location /path/to/dt-broker/data/
autosave_interval 60

# ---- 로그 ----
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
connection_messages true

# ---- 보호 장치 ----
max_queued_messages 1000
message_size_limit 262144
```

각 항목이 왜 거기 있는지가 핵심입니다.

| 설정 | 의미 | 빠뜨렸을 때 생기는 일 |
|---|---|---|
| `allow_anonymous false` | 계정 없는 접속 거부 | 네트워크에 닿는 누구나 아무 토픽에 발행 가능 |
| `persistence true` | retained 메시지·QoS 1/2 큐를 디스크에 보존 | 브로커 재시작 시 모든 retained 값 증발 → 트윈 화면이 빈 채로 뜸 |
| `autosave_interval 60` | 60초마다 디스크 flush | 비정상 종료 시 마지막 상태 손실 |
| `max_queued_messages` | 오프라인 세션당 큐 상한 | 죽은 클라이언트의 큐가 무한정 자라 메모리 고갈 |
| `message_size_limit` | 페이로드 상한 (여기선 256 KB) | 누군가 원파형 10 MB를 그대로 발행해 브로커 마비 |

`persistence`는 특히 디지털 트윈에서 중요합니다. Day 07에서 "retained 메시지로 대시보드 초기 공백을 없앤다"고 했는데, persistence를 끄면 **브로커를 재시작하는 순간 그 약속이 깨집니다.**

### 계정과 ACL

```bash
mosquitto_passwd -c /path/to/dt-broker/passwd edge01   # 엣지 게이트웨이용
mosquitto_passwd /path/to/dt-broker/passwd twin        # 트윈/대시보드용
mosquitto_passwd /path/to/dt-broker/passwd collector   # Day 10 수집기용
```

`-c`는 파일을 **새로 만들면서 기존 내용을 지웁니다.** 두 번째 계정부터는 절대 `-c`를 붙이지 마세요.

ACL 파일에서 역할을 나눕니다.

```conf
# acl — 엣지는 쓰기만, 트윈은 읽기만

user edge01
topic write factory/suwon/line1/#
topic read  factory/suwon/line1/+/cmd

user twin
topic read factory/#
topic read $SYS/broker/#

user collector
topic read factory/#
```

**`edge01`에 read 권한을 주지 않는 것**이 포인트입니다. 엣지 게이트웨이는 데이터를 올리는 쪽이지 남의 설비 데이터를 읽을 이유가 없습니다. 반대로 트윈은 읽기 전용이어야 합니다 — 시각화 클라이언트가 설비 명령 토픽에 쓸 수 있게 되는 순간, 브라우저 하나가 공장을 움직일 수 있는 구조가 됩니다. Day 37에서 다룰 OT/IT 경계의 가장 기초적인 형태입니다.

예외로 `edge01`에만 `cmd` 토픽 읽기를 열어 뒀습니다. 나중에 트윈에서 설비로 내려보내는 명령(Day 27의 what-if 실행 등)을 받을 통로입니다.

### 띄우고 확인

```bash
mosquitto -c /path/to/dt-broker/mosquitto.conf -v
```

`-v`는 verbose 로그입니다. 터미널을 하나 더 열어 구독해 봅니다.

```bash
mosquitto_sub -h localhost -p 1883 -u twin -P '비밀번호' -t 'factory/#' -v
```

`-v`를 붙이면 **토픽과 페이로드를 함께** 출력합니다. 안 붙이면 페이로드만 나와서 어느 센서 값인지 알 수 없으니, 사실상 항상 붙인다고 생각하면 됩니다.

인증이 제대로 걸렸는지 확인하려면 계정 없이 시도해 보세요.

```bash
mosquitto_sub -h localhost -t 'factory/#' -v
# → Connection error: Connection Refused: not authorised.
```

이 에러가 나와야 정상입니다. 안 나오면 `allow_anonymous`가 안 먹은 것이고, 설정 파일 경로를 잘못 줬을 가능성이 큽니다.

> 💡 **실무 팁**: Mosquitto는 설정 파일을 못 읽어도 **기본 설정으로 조용히 뜨는** 경우가 있습니다. "익명 접속이 왜 막히지 않지?"라고 헤매는 시간의 대부분이 이것 때문입니다. 띄울 때 로그 첫 줄의 `Config loaded from ...`을 반드시 눈으로 확인하세요.

---

## 3. 가짜 센서 퍼블리셔 만들기

이제 Day 07에서 정한 토픽 규약과 페이로드 형식대로 데이터를 쏘는 클라이언트를 만듭니다. 실제 PLC가 없어도 트윈 개발은 여기서부터 전부 진행할 수 있고, 실제로 현장 연결이 늦어지는 프로젝트에서 이 시뮬레이터가 몇 달간 유일한 데이터 소스가 되기도 합니다.

```python
# fake_sensor.py
import json, math, random, time
from datetime import datetime, timezone
import paho.mqtt.client as mqtt

BROKER, PORT = "localhost", 1883
BASE = "factory/suwon/line1/press-01"
STATUS = "factory/suwon/line1/_edge/edge-01/status"

client = mqtt.Client(client_id="edge-01", clean_session=False)
client.username_pw_set("edge01", "비밀번호")

# ── LWT: 내가 갑자기 죽으면 브로커가 대신 알려 준다
client.will_set(STATUS, json.dumps({"state": "offline"}), qos=1, retain=True)

client.connect(BROKER, PORT, keepalive=30)
client.loop_start()

# ── 접속 직후 online을 직접 발행
client.publish(STATUS, json.dumps({"state": "online"}), qos=1, retain=True)

def now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")

def payload(v, unit, quality="good"):
    return json.dumps({"ts": now(), "v": round(v, 2), "u": unit, "q": quality})

t = 0
try:
    while True:
        # 금형 온도: 180도 기준으로 완만히 흔들림
        temp = 180 + 6 * math.sin(t / 40) + random.gauss(0, 0.4)
        # 모터 전류: 온도 상승과 약하게 상관
        amps = 12 + 0.05 * (temp - 180) + random.gauss(0, 0.3)

        client.publish(f"{BASE}/temp.die", payload(temp, "degC"), qos=0)
        client.publish(f"{BASE}/current", payload(amps, "A"), qos=0)

        # 상태값은 변할 때만, retain으로
        if t % 60 == 0:
            state = "running" if random.random() > 0.1 else "idle"
            client.publish(f"{BASE}/state",
                           json.dumps({"ts": now(), "v": state}),
                           qos=1, retain=True)

        # 경보는 놓치면 안 되므로 QoS 1
        if temp > 188:
            client.publish(f"{BASE}/alarm/overtemp",
                           json.dumps({"ts": now(), "v": True, "limit": 188}),
                           qos=1)

        t += 1
        time.sleep(1)
except KeyboardInterrupt:
    client.publish(STATUS, json.dumps({"state": "offline"}), qos=1, retain=True)
    client.loop_stop()
    client.disconnect()
```

코드에서 Day 07의 설계 결정이 어떻게 코드로 내려왔는지 짚어 봅니다.

**QoS가 태그마다 다릅니다.** 고주기 센서값(`temp.die`, `current`)은 QoS 0 — 1초마다 새 값이 오니 하나 놓쳐도 트윈 화면은 멀쩡합니다. 반면 `alarm/overtemp`와 `state`는 QoS 1 — 놓치면 트윈이 영원히 잘못된 상태를 보여줍니다. "전부 QoS 1로 하면 안전하지 않나"는 생각이 들겠지만, 초당 수천 건이 들어오는 라인에서 전부 QoS 1이면 브로커가 ACK 왕복에 묶여 지연이 쌓입니다.

**retain이 상태값에만 붙어 있습니다.** `state`와 게이트웨이 `status`에는 retain=true, 센서값에는 없습니다. 1초짜리 값에 retain을 걸면 브로커가 토픽마다 마지막 값을 계속 덮어쓰며 디스크에 flush하는데, 태그가 수천 개면 그 자체로 부하입니다. 어차피 1초 뒤에 새 값이 오므로 retain의 이득도 거의 없습니다.

**`clean_session=False`와 `keepalive=30`.** clean session을 끄면 브로커가 이 `client_id`의 구독과 QoS 1 큐를 기억합니다. 게이트웨이가 30초 끊겼다 돌아와도 그 사이의 QoS 1 메시지를 받을 수 있습니다. keepalive 30초는 "30초 동안 아무 통신이 없으면 PINGREQ를 보낸다"는 뜻이고, 브로커는 **keepalive의 1.5배(45초)** 동안 소식이 없으면 죽은 것으로 보고 LWT를 발행합니다. 즉 **게이트웨이 사망 감지가 최대 45초 걸린다**는 뜻입니다. 더 빨리 감지하고 싶으면 keepalive를 줄여야 하고, 대신 PING 트래픽이 늘어납니다.

---

## 4. 눈으로 확인하는 retained와 LWT

개념으로만 들으면 와닿지 않으니 직접 확인합니다.

### retained 실험

퍼블리셔를 몇 분 돌린 뒤, **새 터미널**에서 상태 토픽만 구독합니다.

```bash
mosquitto_sub -h localhost -u twin -P '비밀번호' -t 'factory/suwon/line1/press-01/state' -v
```

구독하자마자 **즉시** 마지막 상태가 찍힙니다. 다음 상태 변화를 기다리지 않습니다. 반면 센서값 토픽을 구독하면 다음 1초 틱까지 아무것도 안 나옵니다.

```bash
mosquitto_sub -h localhost -u twin -P '비밀번호' -t 'factory/suwon/line1/press-01/temp.die' -v
# → 최대 1초 공백 후 첫 값
```

이 1초 공백이 트윈 대시보드에서는 "게이지가 잠깐 비어 있는" 모습으로 나타납니다. 1초면 괜찮지만, 10분 주기로 올라오는 태그라면 **화면을 열고 10분을 기다려야** 한다는 뜻이고, 그래서 저주기 태그에는 retain을 거는 게 맞습니다. retain 여부는 "상태 vs 측정값"이 아니라 **"다음 값이 올 때까지 기다릴 만한가"**로 판단하는 편이 정확합니다.

retained 메시지를 지우려면 **빈 페이로드를 retain으로 발행**합니다. 이건 자주 쓰게 됩니다 — 토픽 이름을 잘못 지어 발행한 retained 값이 영원히 남아 트윈에 유령 설비를 띄우는 사고가 흔합니다.

```bash
mosquitto_pub -h localhost -u edge01 -P '비밀번호' \
  -t 'factory/suwon/line1/press-01/오타토픽' -r -n
# -r: retain, -n: null(빈) 메시지 → 해당 토픽의 retained 값 삭제
```

### LWT 실험

상태 토픽을 구독해 둔 채로 퍼블리셔를 **`Ctrl+C`가 아니라 강제 종료**합니다.

```bash
kill -9 <fake_sensor.py의 PID>
```

`Ctrl+C`로 끝내면 코드가 직접 `offline`을 발행하고 깔끔하게 `disconnect()`하므로 LWT가 발동하지 않습니다. `kill -9`는 TCP 연결이 비정상적으로 끊기는 상황을 흉내 내고, 이때 브로커가 keepalive 타임아웃(약 45초) 뒤에 **대신** 발행합니다.

```
factory/suwon/line1/_edge/edge-01/status {"state": "offline"}
```

Day 06에서 이야기한 flatline 문제 — "값이 안 변하는 게 설비가 안정적인 건지, 게이트웨이가 죽은 건지" — 가 이 한 줄로 해결됩니다. 트윈은 이 토픽을 보고 해당 라인 전체를 회색 처리하면 됩니다.

> 💡 **실무 팁**: LWT에는 반드시 **retain=true**를 거세요. retain 없이 offline을 발행하면, 그 시점에 구독 중이던 클라이언트만 받습니다. 게이트웨이가 죽은 뒤에 대시보드를 새로 연 사람은 **아무 메시지도 못 받아서** 설비가 정상인 줄 압니다. 가장 알아야 할 사람이 모르게 되는 구조입니다.

---

## 5. 브로커가 건강한지 보는 법

Day 10에서 시계열 DB 수집기를 붙이기 전에, 브로커 자체를 들여다보는 법을 익혀 둡니다. Mosquitto는 자기 상태를 `$SYS` 토픽으로 발행합니다.

```bash
mosquitto_sub -h localhost -u twin -P '비밀번호' -t '$SYS/broker/#' -v
```

쏟아지는 값 중 실제로 보게 되는 것은 몇 개뿐입니다.

| 토픽 | 보는 이유 |
|---|---|
| `$SYS/broker/clients/connected` | 붙어 있어야 할 게이트웨이가 다 붙어 있나 |
| `$SYS/broker/clients/disconnected` | persistent 세션인데 끊긴 수 — 꾸준히 늘면 불안정 |
| `$SYS/broker/messages/received/1min` | 유입 처리량. 갑자기 0이면 현장이 죽은 것 |
| `$SYS/broker/publish/messages/dropped` | **0이 아니면 즉시 조사 대상** |
| `$SYS/broker/heap/current` | 메모리. 계속 우상향이면 큐가 쌓이는 중 |
| `$SYS/broker/load/connections/1min` | 재연결 폭풍 감지 |

`publish/messages/dropped`가 가장 중요합니다. **데이터가 조용히 사라지고 있다는 신호**이기 때문입니다. 보통 원인은 둘입니다 — 느린 구독자의 큐가 `max_queued_messages`를 넘었거나, 오프라인 세션의 큐가 꽉 찼거나. 트윈에서 "그래프에 구멍이 있는데 왜 그런지 모르겠다"는 문제의 상당수가 여기서 시작됩니다.

재연결 폭풍도 실제로 겪게 되는 문제입니다. 네트워크가 잠깐 끊겼을 때 수십 개 게이트웨이가 **동시에** 재접속을 시도하면 브로커가 인증·세션 복원을 한꺼번에 처리하다 밀리고, 그 때문에 또 타임아웃이 나서 다시 몰리는 악순환이 생깁니다. 클라이언트 쪽에서 **지수 백오프 + 지터**(예: 1s → 2s → 4s → … 상한 60s, 매번 ±20% 랜덤)를 넣는 것이 정석적인 해결책입니다. 라이브러리 기본값이 "1초마다 재시도"인 경우가 많으니 반드시 확인하세요.

### 로그에서 읽어야 할 패턴

`log_type information`을 켜 뒀으므로 연결 로그가 보입니다.

```
New client connected from 10.0.3.14:52230 as edge-01 (p2, c0, k30, u'edge01').
```

괄호 안을 읽을 줄 알면 유용합니다 — `p2`는 MQTT 프로토콜 버전, `c0`은 clean_session=false, `k30`은 keepalive 30초, `u'edge01'`은 인증된 사용자입니다. 의도한 설정대로 붙었는지 여기서 바로 확인됩니다.

반복적으로 나오면 문제인 로그도 있습니다.

```
Client edge-01 already connected, closing old connection.
```

같은 `client_id`를 두 프로세스가 쓰고 있다는 뜻입니다. MQTT는 client_id 중복을 허용하지 않아 **먼저 붙은 쪽을 끊어 버리고**, 그러면 그쪽이 재접속하면서 상대를 끊고, 무한 반복됩니다. 게이트웨이를 여러 대 배포할 때 설정 파일을 복사하다 흔히 생기는 사고입니다. client_id에 호스트명이나 일련번호를 넣는 규칙을 처음부터 정해 두세요.

---

## 6. 여기서 Day 10으로 넘어가기 전에

오늘 만든 브로커에는 아직 **데이터를 저장하는 곳이 없습니다.** 구독을 끊으면 그 사이 값은 사라집니다. MQTT는 전송 수단이지 저장소가 아니기 때문입니다. Day 10에서 시계열 DB를 붙이는데, 그 사이를 잇는 수집기 설정은 대략 이런 모습이 됩니다.

```toml
# telegraf.conf — Day 10에서 다룰 내용 미리보기
[[inputs.mqtt_consumer]]
  servers = ["tcp://localhost:1883"]
  topics  = ["factory/+/+/+/#"]
  username = "collector"
  password = "비밀번호"
  client_id = "telegraf-collector-01"

  data_format = "json_v2"
  [[inputs.mqtt_consumer.topic_parsing]]
    topic    = "factory/+/+/+/+"
    tags     = "_/site/line/asset/measure"
```

`topic_parsing`이 오늘 설계의 보상입니다. Day 07에서 `factory/{site}/{line}/{asset}/{measure}` 구조를 지켰기 때문에, 수집기가 **토픽 문자열을 그대로 쪼개 태그로 변환**할 수 있습니다. 토픽이 `sensor1`, `temp_press`, `line1_press01_temp`처럼 제각각이었다면 태그마다 파싱 규칙을 따로 써야 했을 겁니다.

### 남겨 둔 것들

오늘 의도적으로 미룬 항목을 적어 둡니다. 실습 브로커를 운영 브로커로 올릴 때 반드시 채워야 하는 것들입니다.

- **TLS (포트 8883)** — 지금은 평문 1883입니다. 비밀번호가 네트워크에 그대로 흐릅니다. 공장 내부망이라도 상위 구간으로 나갈 때는 필수이고, 실무에서는 비밀번호 대신 **클라이언트 인증서**를 쓰는 경우가 많습니다. Day 37에서 다룹니다.
- **브로커 이중화** — 단일 Mosquitto는 단일 장애점입니다. 상용에서는 클러스터를 지원하는 브로커(EMQX, HiveMQ 등)나 클라우드 관리형 서비스를 씁니다.
- **스키마 강제** — 지금은 누가 `{"temp": 25}` 같은 다른 형식을 발행해도 브로커가 막지 않습니다. MQTT에 스키마 개념이 없기 때문이고, 그래서 Day 17의 메타데이터 모델이 필요해집니다.
- **Sparkplug B** — MQTT 위에 데이터 모델과 상태 관리를 얹은 산업용 규약입니다. 토픽 구조·페이로드·birth/death 메시지를 표준화해 주므로, 오늘 손으로 만든 규약들을 대체할 수 있습니다. 규모가 커지면 검토해 볼 만합니다.

Day 09에서는 같은 데이터를 OPC UA로 받아 봅니다. 오늘 토픽 문자열에 손으로 붙인 의미를 서버가 **스스로 설명해 주는** 경험을 하면, Day 07 표의 "자체 설명성" 행이 왜 그렇게 중요했는지 체감하게 됩니다.

---

## 📝 핵심 요약

1. 공개 테스트 브로커는 동작 확인용일 뿐이다. `allow_anonymous false` + `password_file` + `acl_file`로 **엣지는 쓰기만, 트윈은 읽기만** 하도록 역할을 나눠야 Day 37의 OT/IT 경계가 성립한다.
2. `persistence true`를 빠뜨리면 브로커 재시작 때 retained 값이 전부 사라지고, 트윈 대시보드가 빈 화면으로 뜬다. `max_queued_messages`와 `message_size_limit`은 브로커를 지키는 최소한의 안전장치다.
3. QoS와 retain은 태그 단위로 다르게 건다. 고주기 센서값은 QoS 0 + retain 없음, 상태·경보는 QoS 1 + retain. retain 판단 기준은 "상태값인가"가 아니라 **"다음 값이 올 때까지 기다릴 만한가"**다.
4. LWT는 반드시 retain=true로 걸어야 한다. 그러지 않으면 게이트웨이가 죽은 뒤 대시보드를 연 사람은 장애를 전혀 모른다. 감지 지연은 keepalive의 약 1.5배다.
5. `$SYS/broker/publish/messages/dropped`가 0이 아니면 데이터가 조용히 사라지고 있다는 뜻이다. 재연결 폭풍은 클라이언트 쪽 지수 백오프 + 지터로 막고, client_id 중복은 호스트명 규칙으로 막는다.

---

## 🔗 참고 자료

- [mosquitto.conf(5) — Eclipse Mosquitto 설정 레퍼런스](https://mosquitto.org/man/mosquitto-conf-5.html)
- [mosquitto_pub(1) / mosquitto_sub(1) 매뉴얼](https://mosquitto.org/man/mosquitto_pub-1.html)
- [Eclipse Paho — MQTT 클라이언트 라이브러리](https://eclipse.dev/paho/index.php?page=clients/python/index.php)
- [MQTT Version 5.0 — OASIS Standard](https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html)

---

*⬅️ 이전: [Day 07 — 산업 프로토콜 지도: Modbus / OPC UA / MQTT](../day-07/)  |  다음: [Day 09 — OPC UA 서버·클라이언트 기초 실습](../day-09/) ➡️*
