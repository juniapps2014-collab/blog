---
title: "Day 11 — 엣지 게이트웨이와 전처리: 필터링·다운샘플링·버퍼링"
date: 2026-11-22
weight: 11
---

> **Phase 2: 현실에서 데이터 가져오기** | 예상 학습 시간: 35분

---

## 🎯 학습 목표

- 엣지 게이트웨이가 트윈 파이프라인에서 맡는 네 가지 역할(프로토콜 변환·전처리·버퍼링·로컬 판단)을 구분하고, 어떤 처리를 엣지에 두고 어떤 처리를 클라우드에 둘지 기준을 세울 수 있다
- 데드밴드·예외 보고·스윙잉 도어·LTTB를 구분해 쓰고, 데이터를 줄이면서도 트윈이 필요한 정보를 잃지 않는 축소 전략을 설계할 수 있다
- 네트워크가 끊겼다 돌아올 때 데이터를 잃지 않는 store-and-forward 구조를 MQTT QoS·영속 큐·백프레셔 관점에서 구현 방향까지 설명할 수 있다

---

## 1. 왜 게이트웨이를 하나 더 두는가

Day 08~10을 거치며 파이프라인은 이렇게 생겼습니다. 센서 → (MQTT/OPC UA) → 브로커 → 시계열 DB. 그림으로는 깔끔한데, 실제 공장에 그대로 놓으면 세 군데에서 터집니다.

**① 현장 장비는 클라우드와 말을 못 합니다.** 15년 된 PLC는 Modbus TCP만 하고, TLS도 인증서도 모릅니다(Day 07). 이 장비가 직접 인터넷으로 나가는 건 기술적으로도 보안적으로도 불가능합니다.

**② 원본 데이터를 전부 올리면 비용이 감당되지 않습니다.** 진동 센서 하나가 10kHz로 샘플링하면 초당 1만 포인트, 설비 50대면 초당 50만 포인트입니다. 이걸 그대로 클라우드로 올리는 건 회선과 저장 비용 양쪽에서 무의미합니다.

**③ 네트워크는 반드시 끊깁니다.** 공장 WAN은 끊기고, VPN은 재협상하고, 클라우드 쪽 엔드포인트는 점검으로 내려갑니다. 끊긴 10분 동안의 데이터가 그냥 사라지면 Day 28의 리플레이에는 10분짜리 구멍이, Day 31의 RUL 학습 데이터에는 결측 구간이 남습니다.

엣지 게이트웨이는 현장 네트워크 안(보통 OT망과 IT망 사이 DMZ)에 놓이는 작은 컴퓨터입니다. 산업용 PC, 라즈베리파이급 보드, 혹은 PLC 옆의 IPC 한 대면 됩니다. 역할은 넷입니다.

| 역할 | 하는 일 | 이게 없으면 |
|---|---|---|
| 프로토콜 변환 | Modbus/OPC UA → MQTT, 레지스터 → 이름 있는 태그 | 레거시 장비가 트윈에 못 들어옴 |
| 전처리 | 필터링·데드밴드·다운샘플링·단위 변환 | 회선·저장 비용 폭발 |
| 버퍼링 | 단절 중 로컬 저장, 복구 시 재전송 | 데이터 구멍 |
| 로컬 판단 | 임계값 경보, 안전 인터록 | 왕복 지연(수백 ms~수 초)만큼 대응이 늦음 |

> 💡 **실무 팁**: 게이트웨이를 "데이터를 넘기는 중계기"로만 보면 설계가 빈약해집니다. 게이트웨이는 **현장의 진실을 트윈이 쓸 수 있는 형태로 번역하는 계층**입니다. 여기서 태그 이름, 단위, 품질 코드, 타임스탬프 규약이 결정되고, 그 결정이 Day 16의 자산 태그 체계와 Day 19의 Unity 구독 코드까지 그대로 따라갑니다.

### 무엇을 엣지에 두고 무엇을 올릴까

경계를 가르는 질문은 세 개입니다.

- **지연에 민감한가?** 100ms 안에 반응해야 하는 인터록은 무조건 엣지. 대시보드 갱신은 1~2초 늦어도 됩니다.
- **데이터를 얼마나 줄이는가?** 10kHz 진동 원파형을 엣지에서 FFT로 처리해 RMS·피크·주요 주파수 성분 몇 개만 올리면 데이터가 1,000분의 1이 됩니다(Day 30).
- **모델이 자주 바뀌는가?** 자주 재학습하는 ML 모델을 수십 대 게이트웨이에 배포하는 건 운영 부담입니다. 안정화된 추론만 엣지로 내리세요.

---

## 2. 데이터를 줄이는 네 가지 방법 — 무엇을 버릴지 고르기

"다운샘플링"이라는 한 단어 안에 성질이 전혀 다른 기법들이 섞여 있습니다. 구분해서 써야 합니다.

### ① 데드밴드 / 예외 보고 (exception reporting)

가장 먼저 적용해야 할 기법이자, 가장 효과가 큽니다. **값이 의미 있게 변했을 때만 보낸다**는 발상입니다.

금형 온도가 `182.3 → 182.3 → 182.4 → 182.3`로 흐를 때, 0.5℃ 데드밴드를 걸면 네 번 중 한 번도 보내지 않습니다. 공정 온도처럼 느리게 변하는 신호는 이것만으로 전송량이 90% 이상 줄어드는 경우가 흔합니다.

OPC UA는 이걸 프로토콜 차원에서 지원합니다. Day 09에서 만든 구독에 `DataChangeFilter`를 붙이면 서버가 알아서 걸러서 보냅니다.

```python
# python-opcua / asyncua 계열 — 구독에 절대 데드밴드 걸기
from asyncua import ua

dcf = ua.DataChangeFilter(
    trigger=ua.DataChangeTrigger.StatusValue,     # 값 또는 품질이 바뀔 때만
    deadbandType=ua.DeadbandType.Absolute,        # Percent는 EURange 기준 비율
    deadbandValue=0.5,                            # ±0.5 단위 안의 변화는 무시
)
```

데드밴드에는 두 가지 함정이 있습니다.

- **절대 vs 비율**: 0~1000bar 압력계에 절대 데드밴드 1bar는 괜찮지만, 0~10bar 센서엔 너무 큽니다. 센서마다 레인지가 다르면 `Percent`(계측 범위 대비 비율)가 안전합니다.
- **하트비트 누락**: 값이 전혀 안 변하면 메시지도 영원히 안 옵니다. 그러면 트윈은 "센서가 안정적인 것"과 "센서가 죽은 것"을 구분할 수 없습니다. **반드시 최대 침묵 시간(예: 60초)을 두고 변화가 없어도 주기적으로 한 번은 보내세요.** 이게 전처리 설계에서 가장 자주 빠뜨리는 항목입니다.

```python
def should_publish(tag, value, now):
    last = state.get(tag)
    if last is None:
        return True
    if abs(value - last.value) >= tag.deadband:          # 유의미한 변화
        return True
    if now - last.sent_at >= tag.max_silence:            # 하트비트 (필수)
        return True
    return False
```

### ② 시간 기반 집계 (aggregation)

고정 윈도우로 묶어 통계값만 올리는 방식입니다. 1초 데이터를 1분 단위로 묶어 `avg / min / max / count`를 보냅니다.

여기서 **min·max를 반드시 포함**하는 게 핵심입니다. 평균만 올리면 1분 안에 있었던 순간 스파이크가 사라지고, Day 29의 이상 탐지가 볼 데이터가 없어집니다. 평균은 추세를, min/max는 사건을 담습니다.

Telegraf를 게이트웨이에 올리면 이 구조를 설정 파일만으로 만들 수 있습니다.

```toml
# /etc/telegraf/telegraf.conf
[agent]
  interval          = "1s"
  metric_batch_size = 5000      # 배치로 묶어 전송 (Day 10 체크리스트 5번)
  metric_buffer_limit = 100000  # 메모리 버퍼 — 단절 시 여기에 쌓임
  flush_interval    = "10s"
  omit_hostname     = false

# 입력: 현장 Mosquitto 구독
[[inputs.mqtt_consumer]]
  servers       = ["tcp://127.0.0.1:1883"]
  topics        = ["factory/suwon/line1/+/telemetry"]
  qos           = 1
  data_format   = "json_v2"

# 전처리: 단위 변환 (화씨로 올라오는 레거시 태그 보정)
[[processors.starlark]]
  namepass = ["press_line"]
  source = '''
def apply(metric):
    f = metric.fields.get("die_temp_f")
    if f != None:
        metric.fields["die_temp"] = (f - 32.0) * 5.0 / 9.0
        metric.fields.pop("die_temp_f")
    return metric
'''

# 집계: 1분 윈도우로 통계 산출
[[aggregators.basicstats]]
  period     = "60s"
  drop_original = false          # 원본도 로컬 DB에는 남김
  stats      = ["min", "max", "mean", "stdev", "count"]

# 출력: 클라우드 시계열 DB
[[outputs.influxdb_v2]]
  urls   = ["https://influx.example.com"]
  token  = "${INFLUX_TOKEN}"
  organization = "factory"
  bucket = "telemetry"
```

`drop_original = false`가 의미 있는 선택입니다. **원본은 엣지의 로컬 저장소에, 집계본은 클라우드에** 두는 2계층 보존은 진동·전류처럼 고주파 데이터를 다룰 때 특히 유용합니다. 평소엔 집계본만 보다가 이상이 감지되면 그 구간의 원파형을 엣지에서 끌어오는 식입니다.

### ③ 압축 알고리즘 — 스윙잉 도어

공정 이력 관리 시스템(PI 같은 historian)이 수십 년 써 온 기법입니다. 데드밴드가 "직전 값과 비교"라면, 스윙잉 도어(swinging door)는 **"저장한 점들을 직선으로 이었을 때 원본에서 허용 오차 이상 벗어나는 순간에만 점을 찍는"** 방식입니다.

차이는 램프(ramp) 구간에서 드러납니다. 온도가 일정한 기울기로 상승 중이면 데드밴드는 계속 트리거되어 수십 점을 보내지만, 스윙잉 도어는 기울기가 바뀌는 지점 두 개만 보냅니다. 승온·승압처럼 완만히 변하는 공정값이 많은 설비에서 압축률이 크게 벌어집니다.

### ④ 시각화용 축소 — LTTB

위 셋이 "저장할 데이터를 줄이는" 기법이라면, LTTB(Largest-Triangle-Three-Buckets)는 **이미 저장된 데이터를 화면에 그릴 때** 쓰는 기법입니다. 10만 포인트를 1,000픽셀 폭 차트에 그릴 때 단순히 100개마다 하나씩 뽑으면(naive decimation) 스파이크가 통째로 사라져 "없던 일"이 됩니다. LTTB는 각 구간에서 인접 점들과 이루는 삼각형 넓이가 최대인 점을 골라 시각적 특징을 보존합니다.

Day 21의 Unity 런타임 대시보드에서 긴 구간 트렌드를 그릴 때 쓰게 될 겁니다. **저장 단계의 축소와 표시 단계의 축소를 섞지 마세요.** 저장은 되돌릴 수 없고, 표시는 언제든 다시 그릴 수 있습니다.

| 기법 | 적용 시점 | 되돌릴 수 있나 | 주 용도 |
|---|---|---|---|
| 데드밴드/예외 보고 | 전송 전 | ✗ | 느리게 변하는 공정값 |
| 시간 집계 | 전송 전 | ✗ (원본 병행 보관 시 ○) | 고주파 센서 요약 |
| 스윙잉 도어 | 저장 시 | ✗ | 램프가 많은 아날로그 값 |
| LTTB | 조회/표시 시 | ○ | 차트 렌더링 |

---

## 3. 끊겨도 잃지 않기 — store-and-forward

전처리보다 설계 난이도가 높고, 사고가 많은 쪽이 버퍼링입니다.

### 메모리 버퍼만으로는 부족하다

Telegraf의 `metric_buffer_limit`처럼 메모리 큐를 두면 짧은 단절은 넘깁니다. 하지만 게이트웨이가 재부팅되거나 정전이 나면 전부 사라지고, 단절이 몇 시간 가면 큐가 넘쳐 오래된 데이터부터 버려집니다. 진짜 필요한 건 **디스크에 쓰는 영속 큐**입니다.

구현 선택지는 셋입니다.

- **로컬 브로커의 영속화** — 현장에 Mosquitto를 하나 두고 `persistence true`로 디스크에 남긴 뒤, 브리지로 클라우드 브로커에 전달
- **로컬 시계열 DB** — SQLite나 InfluxDB를 엣지에 두고, 별도 전송 프로세스가 미전송 구간을 읽어 올림
- **전용 스트림 관리자** — AWS IoT Greengrass의 Stream Manager처럼 디스크 기반 스트림에 쓰고, 연결이 돌아오면 자동으로 밀어 올리는 컴포넌트

### Mosquitto 브리지 — 가장 손쉬운 출발점

Day 08에서 띄운 Mosquitto를 그대로 게이트웨이용으로 쓸 수 있습니다. 현장 브로커가 로컬에서 메시지를 받아 디스크에 쌓고, 클라우드 브로커와의 브리지가 복구되면 알아서 밀어 올립니다.

```conf
# /etc/mosquitto/conf.d/gateway.conf
persistence true
persistence_location /var/lib/mosquitto/
autosave_interval 30
max_queued_messages 100000          # 큐 상한 — 넘치면 버려진다

connection cloud-bridge
address broker.example.com:8883
bridge_protocol_version mqttv50

# 현장 → 클라우드 단방향. QoS 1로 전달
topic factory/suwon/# out 1

# 브리지 세션을 유지해야 끊긴 동안 쌓인 메시지가 살아남는다
cleansession false
remote_clientid gw-suwon-01
bridge_cafile /etc/mosquitto/certs/ca.crt
bridge_certfile /etc/mosquitto/certs/gw-suwon-01.crt
bridge_keyfile /etc/mosquitto/certs/gw-suwon-01.key
```

핵심은 두 줄입니다. `persistence true`가 있어야 재부팅을 견디고, `cleansession false`(MQTT 5에서는 긴 `Session Expiry Interval`)여야 브로커가 끊긴 동안의 큐를 유지합니다. 이 둘 중 하나라도 빠지면 "QoS 1을 썼는데 왜 데이터가 사라지죠?"라는 질문으로 돌아옵니다. **QoS는 연결이 살아 있을 때의 전달 보장이지, 세션이 없으면 보관 자체를 안 합니다.**

`max_queued_messages`도 반드시 의식적으로 정하세요. 기본값은 대개 작고, 넘치면 조용히 버립니다. "초당 발행량 × 견뎌야 할 단절 시간"으로 계산하고, 디스크 여유와 함께 검토해야 합니다.

### 복구 시 몰아치기 — 백프레셔를 설계하라

단절이 2시간이었다면 복구 순간 2시간치가 한꺼번에 날아갑니다. 여기서 두 번째 사고가 납니다.

- 클라우드 수집단이 순간 유입량을 못 버티고 쓰러집니다
- Day 10에서 본 연속 집계가 과거 버킷을 다시 계산하느라 부하가 치솟습니다
- Unity 클라이언트(Day 19)가 2시간치 메시지를 한 프레임에 받아 멈춥니다

그래서 전송 측에 **속도 제한**을 두는 게 정석입니다. "평소 처리량의 2~3배를 넘지 않게" 밀어 올리면 복구에 시간이 더 걸려도 전체 시스템은 안전합니다.

```python
import time

class RateLimitedForwarder:
    """미전송 버퍼를 배치로 밀어 올리되, 초당 전송량에 상한을 둔다."""

    def __init__(self, sink, max_points_per_sec=5000, batch=1000):
        self.sink, self.limit, self.batch = sink, max_points_per_sec, batch

    def drain(self, queue):
        while not queue.empty():
            started = time.monotonic()
            points = queue.peek(self.batch)          # 아직 지우지 않는다
            self.sink.write(points)                  # 실패하면 예외 → 큐 유지
            queue.commit(len(points))                # 성공 확인 후에만 삭제

            spent = time.monotonic() - started
            budget = len(points) / self.limit
            if spent < budget:
                time.sleep(budget - spent)           # 속도 제한
```

`peek → write → commit` 순서가 중요합니다. 큐에서 먼저 꺼내고 전송하면, 전송 중 프로세스가 죽을 때 그 배치가 증발합니다. **전송 성공을 확인한 뒤에 큐에서 지우는** 구조여야 at-least-once가 성립합니다.

중복 전송은 그 대가입니다. at-least-once는 같은 포인트가 두 번 갈 수 있다는 뜻이고, 시계열 DB에서는 보통 문제가 되지 않습니다. `(측정시각, device_id, metric)`이 같으면 덮어쓰기(upsert)가 되도록 스키마를 잡아 두면 중복이 자연히 멱등 처리됩니다. **엣지 버퍼링을 쓸 거라면 Day 10의 스키마 설계 단계에서 이 키를 미리 정해 두세요.**

### 타임스탬프 — 측정 시각은 엣지에서 찍는다

Day 10 체크리스트에서 "측정 시각과 수집 시각을 분리하라"고 한 이유가 여기서 분명해집니다.

```json
{
  "tag": "press-01.die_temp",
  "value": 182.4,
  "quality": 192,
  "ts_source":  "2026-11-22T06:14:02.350Z",   ← 센서/게이트웨이가 측정한 시각
  "ts_ingest":  "2026-11-22T08:41:17.002Z",   ← 클라우드가 받은 시각
  "gateway": "gw-suwon-01"
}
```

위 예시는 2시간 27분 늦게 도착한 버퍼 데이터입니다. 수집 시각으로 저장했다면 이 온도는 08시 41분의 상태로 기록되어, 리플레이에서도 이상 탐지에서도 전부 틀립니다.

그래서 **게이트웨이에서 반드시 타임스탬프를 찍고, 게이트웨이의 시계를 NTP로 동기화**해야 합니다. 동기화가 안 된 게이트웨이는 조용히 모든 데이터를 오염시킵니다. 여러 설비의 데이터를 한 화면에서 비교하는 트윈에서는 게이트웨이 간 몇 초의 시계 차이도 인과관계를 뒤집습니다.

> 💡 **실무 팁**: 운영에 들어가면 게이트웨이 자신의 상태도 텔레메트리로 올리세요. 버퍼 적재량, 마지막 전송 성공 시각, 시계 오프셋, 디스크 여유, 재연결 횟수 — 이 다섯 개면 "데이터가 안 보인다"는 신고가 들어왔을 때 센서 문제인지 게이트웨이 문제인지 회선 문제인지를 바로 가릅니다. Day 39의 운영 체크리스트에서 다시 다룹니다.

---

## 4. 게이트웨이 한 대 설계해 보기

지금까지 내용을 Day 05에서 정의한 범위(프레스 라인 1개, 설비 5대)에 맞춰 구체화하면 이런 모양이 됩니다.

```
[ OT 망 ]                     [ DMZ: 게이트웨이 ]              [ IT/클라우드 ]

PLC (Modbus TCP) ──┐
                   ├─→ 수집 어댑터 ─→ 정규화 ─→ 데드밴드 ─→ 로컬 Mosquitto
OPC UA 서버 ───────┘      (태그맵)    (단위/품질)  (+하트비트)   (persistence)
                                           │                        │
진동 센서 (10kHz) ─→ 로컬 FFT ─→ RMS/피크 ─┘                   브리지(QoS 1)
                        │                                           │
                   원파형은 로컬 7일 보관                            ▼
                                                            클라우드 브로커
                                                                    │
                                                            시계열 DB (Day 10)
```

설계 결정 다섯 개를 명시적으로 적어 두면 나중에 다투지 않습니다.

1. **태그맵은 게이트웨이가 소유한다** — `40001 레지스터 → press-01.die_temp`, 단위 ℃, 레인지 0~400. 이 매핑 파일이 Day 16 자산 태그 체계의 출발점입니다.
2. **데드밴드와 하트비트를 태그마다 지정한다** — 온도 0.5℃/60초, 압력 0.2bar/30초, 가동 상태는 데드밴드 없음(상태 변화는 전부 보냄)/300초.
3. **고주파 신호는 엣지에서 특징만 추출한다** — 진동 원파형은 올리지 않고 RMS·피크·주요 대역 에너지만. 원파형은 로컬 7일.
4. **버퍼는 8시간치를 디스크에 담는다** — 초당 발행량 × 8시간 × 메시지 크기로 용량을 산정하고, 넘치면 **오래된 것부터 버리되 그 사실을 이벤트로 올린다**(조용히 버리지 않기).
5. **복구 전송은 평소의 3배로 제한한다** — 클라우드 수집단과 Unity 클라이언트를 보호.

이 다섯 줄이 Phase 2의 결과물입니다. Phase 3부터는 이 데이터를 받을 **가상 모델** 쪽으로 넘어가, CAD·BIM·3D 스캔에서 3D 자산을 확보하고 경량화하는 과정을 다룹니다. 그리고 Day 19에서 두 줄기가 Unity 안에서 만납니다.

---

## 📝 핵심 요약

1. 엣지 게이트웨이는 단순 중계기가 아니라 프로토콜 변환·전처리·버퍼링·로컬 판단을 맡는 계층이고, 여기서 정해진 태그 이름·단위·품질·시각 규약이 트윈 전체로 전파된다.
2. 데이터 축소는 데드밴드(전송 전), 시간 집계(전송 전), 스윙잉 도어(저장 시), LTTB(표시 시)로 성질이 전혀 다르다. 저장 단계의 축소는 되돌릴 수 없으므로 표시 단계 축소와 섞지 않는다.
3. 데드밴드를 걸 때는 **최대 침묵 시간(하트비트)** 을 반드시 함께 둔다. 없으면 "값이 안 변한 센서"와 "죽은 센서"를 구분할 수 없다.
4. MQTT QoS만으로는 단절을 못 견딘다. 브로커 `persistence` + 세션 유지(`cleansession false`) + 디스크 영속 큐가 갖춰져야 store-and-forward가 성립하고, 큐에서 지우는 건 전송 성공 확인 뒤여야 한다.
5. 복구 시 몰아치는 재전송은 수집단을 쓰러뜨린다. 속도 제한을 두고, 측정 시각(`ts_source`)과 수집 시각(`ts_ingest`)을 분리해 저장하며, 게이트웨이 시계는 NTP로 맞춘다.

---

## 🔗 참고 자료

- [Eclipse Mosquitto `mosquitto.conf` 매뉴얼 — persistence·bridge 설정](https://mosquitto.org/man/mosquitto-conf-5.html)
- [Telegraf Configuration — agent 버퍼·배치·aggregator 설정](https://docs.influxdata.com/telegraf/v1/configuration/)
- [Azure IoT Edge 오프라인 동작과 메시지 저장·전달](https://learn.microsoft.com/en-us/azure/iot-edge/offline-capabilities)

---

*⬅️ 이전: [Day 10 — 시계열 DB 입문: InfluxDB vs TimescaleDB, 스키마 설계](../day-10/)  |  다음: [Day 12 — 3D 자산 확보 경로 4가지: CAD / BIM / 스캔 / 수작업 모델링](../day-12/) ➡️*
