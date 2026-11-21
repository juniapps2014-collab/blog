---
title: "Day 10 — 시계열 DB 입문: InfluxDB vs TimescaleDB, 스키마 설계"
date: 2026-11-21
weight: 10
---

> **Phase 2: 현실에서 데이터 가져오기** | 예상 학습 시간: 40분

---

## 🎯 학습 목표

- 일반 RDB 테이블에 센서 데이터를 그냥 쌓으면 왜 수개월 안에 무너지는지를 인덱스·파티션·압축 관점에서 설명할 수 있다
- InfluxDB의 태그/필드 모델과 TimescaleDB의 하이퍼테이블+컬럼스토어 모델을 비교하고, 내 트윈의 요구사항에 맞는 쪽을 근거를 들어 고를 수 있다
- 카디널리티 폭발을 피하는 스키마를 설계하고, 다운샘플링·보존 정책·연속 집계로 저장 비용과 조회 속도를 함께 잡을 수 있다

---

## 1. Day 08·09에서 받은 데이터는 지금 어디에 있나

지금까지 만든 파이프라인을 되짚어 보면 데이터의 종착지가 없습니다. Day 08의 Mosquitto는 메시지를 중계하고 버리고, Day 09의 OPC UA 서버는 **현재 값**만 들고 있습니다. OPC UA에 Historical Access(HA) 프로파일이 있긴 하지만 대부분의 PLC·게이트웨이는 구현하지 않고, 구현해도 보관 기간이 짧습니다.

디지털 트윈에서 과거 데이터가 없으면 할 수 없는 일이 명확합니다.

- **Day 28 리플레이** — 어제 14시 32분의 라인 상태를 되감으려면 그 시각의 모든 센서 값이 있어야 합니다
- **Day 29~31 이상 탐지·RUL 예측** — 학습 데이터가 곧 과거 시계열입니다. "정상이 어떤 모양인지"는 과거에서만 배울 수 있습니다
- **Day 27 What-if 비교** — 시뮬레이션 결과를 평가하려면 실측 베이스라인이 필요합니다

즉 시계열 DB는 트윈의 선택 사양이 아니라 **Phase 5~6 전체의 전제 조건**입니다. 오늘은 그 저장소를 고르고, 더 중요하게는 스키마를 잘못 짜면 어떻게 망하는지를 먼저 봅니다.

### 센서 데이터의 성질

시계열 워크로드는 일반적인 트랜잭션 워크로드와 성질이 정반대입니다.

| | 일반 OLTP (주문, 회원) | 센서 시계열 |
|---|---|---|
| 쓰기 패턴 | 임의 위치 INSERT/UPDATE | 거의 항상 **최신 시각에 append** |
| 수정·삭제 | 빈번 | 사실상 없음 (늦게 도착한 데이터 정도) |
| 조회 패턴 | 단건 PK 조회 | **시간 범위 + 집계** (최근 1시간 평균) |
| 데이터 수명 | 영구 | 원본은 며칠~몇 달, 집계본은 수년 |
| 값의 변화 | 제각각 | **이웃 값과 거의 같음** (온도는 천천히 변함) |

마지막 줄이 핵심입니다. 1초 간격 금형 온도가 `182.3, 182.3, 182.4, 182.4, 182.5...`로 흐르면, 각 값을 8바이트 double로 정직하게 저장하는 건 엄청난 낭비입니다. 시계열 DB는 바로 이 성질을 공격합니다.

---

## 2. 그냥 PostgreSQL 테이블에 쌓으면 무슨 일이 일어나는가

많은 팀이 이렇게 시작합니다.

```sql
CREATE TABLE sensor_data (
  id        BIGSERIAL PRIMARY KEY,
  device_id TEXT        NOT NULL,
  metric    TEXT        NOT NULL,
  ts        TIMESTAMPTZ NOT NULL,
  value     DOUBLE PRECISION
);
CREATE INDEX ON sensor_data (device_id, ts);
```

PoC 2주 동안은 완벽하게 동작합니다. 그리고 다음 순서로 무너집니다.

**① 행 수가 선형으로 쌓인다.** 설비 50대 × 센서 20개 × 1초 간격 = 초당 1,000행 = 하루 8,640만 행 = 한 달 25억 행. 1년이면 300억 행입니다.

**② 인덱스가 메모리를 벗어난다.** B-tree 인덱스는 키가 랜덤하지 않고 단조 증가하면 오른쪽 끝에만 삽입되어 그나마 낫지만, `(device_id, ts)` 복합 인덱스는 device_id별로 삽입 지점이 흩어집니다. 인덱스가 RAM보다 커지는 순간 매 INSERT마다 디스크 랜덤 I/O가 발생하고 쓰기 처리량이 절벽처럼 떨어집니다.

**③ 오래된 데이터를 지울 수 없다.** 90일 지난 데이터를 `DELETE FROM sensor_data WHERE ts < now() - interval '90 days'` 로 지우면 수억 행을 삭제 표시만 하고, 공간은 VACUUM 전까지 반환되지 않으며, 그 VACUUM이 몇 시간 동안 I/O를 잡아먹습니다.

**④ 행 오버헤드가 데이터보다 크다.** PostgreSQL의 행 헤더는 23바이트 + 정렬 패딩입니다. 실제 측정값 8바이트를 저장하려고 `id`(8) + `device_id` 문자열 + `metric` 문자열 + `ts`(8) + 헤더(~24)를 함께 씁니다. **값 1개당 70~100바이트.** 압축 없이는 하루 1,000행/초가 그대로 수 GB가 됩니다.

> 💡 **실무 팁**: 이 구조의 가장 교활한 점은 성능 저하가 서서히 온다는 것입니다. 개발 중엔 아무 문제 없고, 파일럿 라인 3개월 차에 "대시보드가 느려졌다"로 시작해서, 전사 확대 직전에 재설계를 해야 합니다. 트윈 프로젝트는 처음부터 시계열 저장소를 전제로 설계하세요.

시계열 DB는 이 네 가지를 각각 **시간 기반 파티셔닝 · 청크 단위 인덱스 · 파티션 DROP · 컬럼 지향 압축**으로 해결합니다.

---

## 3. TimescaleDB — PostgreSQL을 시계열용으로 확장하기

TimescaleDB는 PostgreSQL 확장(extension)입니다. 즉 SQL, JOIN, 외래키, 기존 드라이버, psql, pgAdmin이 전부 그대로 동작합니다.

### 하이퍼테이블

일반 테이블을 만든 뒤 하이퍼테이블로 전환하면, 내부적으로 시간 축을 따라 **청크(chunk)** 라는 자식 테이블로 쪼개집니다.

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE measurement (
  ts        TIMESTAMPTZ      NOT NULL,
  device_id TEXT             NOT NULL,
  metric    TEXT             NOT NULL,
  value     DOUBLE PRECISION NOT NULL,
  quality   SMALLINT         NOT NULL DEFAULT 192   -- OPC UA StatusCode (Day 09)
);

-- 7일 단위 청크로 분할
SELECT create_hypertable('measurement', by_range('ts', INTERVAL '7 days'));

CREATE INDEX ON measurement (device_id, metric, ts DESC);
```

눈여겨볼 점은 **대리키 `id`를 만들지 않았다**는 것입니다. 시계열 행에는 단건 조회할 일이 없으므로 BIGSERIAL은 공간과 시퀀스 경합만 더합니다.

청크 분할이 주는 이득:

- 최근 청크의 인덱스만 메모리에 있으면 되므로 쓰기 성능이 데이터 총량과 무관해집니다
- `WHERE ts > now() - interval '1 hour'` 쿼리는 플래너가 **청크 제외(chunk exclusion)** 로 나머지 청크를 아예 열지 않습니다
- 오래된 데이터 삭제가 `DROP TABLE` 수준으로 즉시 끝납니다

청크 간격은 **최근 청크 하나가 메모리의 25% 안에 들어가도록** 잡는 게 경험칙입니다. 데이터가 많으면 1일, 적으면 1개월도 괜찮습니다.

### 컬럼스토어 압축

일정 기간이 지난 청크를 행 저장에서 컬럼 저장으로 바꾸면, 같은 컬럼 값들이 모여 있으므로 델타 인코딩·Gorilla·사전 압축이 극적으로 먹힙니다.

```sql
ALTER TABLE measurement SET (
  timescaledb.enable_columnstore = true,
  timescaledb.segmentby = 'device_id, metric',   -- 이 키로 묶어서 압축
  timescaledb.orderby   = 'ts DESC'
);

-- 7일 지난 청크는 자동으로 컬럼스토어로 전환
CALL add_columnstore_policy('measurement', after => INTERVAL '7 days');

-- 90일 지난 청크는 통째로 DROP
SELECT add_retention_policy('measurement', INTERVAL '90 days');
```

`segmentby`를 거의 항상 WHERE에 들어가는 컬럼으로 잡는 게 핵심입니다. `device_id`로 세그먼트하면 특정 설비 조회 시 다른 설비의 압축 블록을 풀 필요가 없습니다.

### 연속 집계

대시보드가 "최근 24시간 1분 평균"을 물을 때마다 8만 행을 집계하는 건 낭비입니다. 연속 집계(continuous aggregate)는 결과를 증분으로 유지해 둡니다.

```sql
CREATE MATERIALIZED VIEW measurement_1m
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 minute', ts) AS bucket,
  device_id,
  metric,
  avg(value)   AS avg_value,
  min(value)   AS min_value,
  max(value)   AS max_value,
  count(*)     AS sample_count
FROM measurement
GROUP BY bucket, device_id, metric;

SELECT add_continuous_aggregate_policy('measurement_1m',
  start_offset => INTERVAL '3 hours',
  end_offset   => INTERVAL '1 minute',
  schedule_interval => INTERVAL '1 minute');
```

`end_offset`이 있는 이유는 **늦게 도착하는 데이터** 때문입니다. 엣지 게이트웨이가 네트워크 단절 후 버퍼를 몰아서 보내면(Day 11) 과거 구간이 갱신되는데, 너무 최신까지 집계하면 불완전한 버킷이 굳어집니다.

여기에 원본은 90일, 1분 집계는 2년, 1시간 집계는 영구 — 이렇게 **계단식 보존 정책**을 깔면 저장 비용이 안정됩니다.

---

## 4. InfluxDB — 시계열 전용 모델과 태그/필드

InfluxDB는 처음부터 시계열만을 위해 만들어진 DB입니다. 데이터 모델이 RDB와 다르므로 용어부터 맞춰야 합니다.

| InfluxDB 개념 | 대략의 대응 | 성질 |
|---|---|---|
| measurement | 테이블 | 논리적 묶음 |
| **tag** | 인덱싱된 컬럼 | **항상 문자열**, 자동 인덱싱, 카디널리티의 주범 |
| **field** | 인덱싱 안 된 컬럼 | 실제 측정값(float/int/bool/string), 인덱스 없음 |
| timestamp | ts | 나노초 정밀도 |
| point | 행 | measurement + tag set + field set + ts |

라인 프로토콜로 쓰면 이런 모양입니다. 쉼표·공백의 위치가 문법의 전부입니다.

```
press_line,site=suwon,line=1,device=press-01 die_temp=182.4,hyd_pressure=14.6,motor_current=31.2 1763683200000000000
└─measurement─┘└──────── tag set ───────────┘ └──────────── field set ──────────────────┘ └───── ts (ns) ─────┘
```

**태그와 필드를 가르는 기준은 명확합니다: WHERE나 GROUP BY에 쓰면 태그, 숫자로 계산하면 필드.**

- `device=press-01`, `line=1`, `site=suwon` → 태그 (필터 조건)
- `die_temp=182.4`, `motor_current=31.2` → 필드 (계산 대상)

흔한 실수가 **측정값을 태그로 넣는 것**입니다. `temp=182.4`를 태그로 쓰면 값이 바뀔 때마다 새 시리즈가 생기고, 몇 시간 만에 DB가 죽습니다.

### 카디널리티 폭발 — 시계열 DB의 1번 사고 원인

InfluxDB는 **고유한 (measurement + tag set) 조합 하나하나를 시리즈(series)** 로 보고, 시리즈 인덱스를 유지합니다. 시리즈 수 = 모든 태그 값의 **곱**입니다.

```
site(3) × line(10) × device(50) × metric(20) = 30,000 시리즈   → 건강함
여기에 batch_id(일 500개 누적) 추가       = 1,500만 시리즈/월  → 사망
```

태그에 절대 넣으면 안 되는 것들:

- **배치 ID, 주문 번호, 트레이스 ID, UUID** — 무한히 증가
- **타임스탬프 문자열** — 그 자체로 무한
- **측정값, 온도, 좌표** — 연속값
- **에러 메시지 전문** — 사실상 유일값

이런 값은 **필드로** 넣으세요. 필드는 인덱싱되지 않으므로 카디널리티에 기여하지 않습니다. 대신 그 값으로 빠른 필터링은 못 합니다 — 그게 맞는 트레이드오프입니다.

> 💡 **실무 팁**: TimescaleDB에는 이 함정이 없습니다. PostgreSQL은 컬럼 값이 몇 종류든 인덱스 크기만 커질 뿐 구조가 무너지지 않습니다. 설비 메타데이터가 자주 바뀌거나 고유 ID를 꼭 붙여야 하는 트윈이라면, 이 한 가지 이유만으로 Timescale이 안전한 선택이 될 수 있습니다.

### InfluxDB 3 — SQL과 Parquet

InfluxDB 3 계열은 스토리지가 Apache Arrow/Parquet 기반으로 바뀌었고, **SQL로 조회**할 수 있습니다(Flux 전용이던 2.x와 가장 크게 달라진 점).

```sql
SELECT
  date_bin(INTERVAL '1 minute', time) AS bucket,
  device,
  avg(die_temp) AS avg_temp,
  max(die_temp) AS max_temp
FROM press_line
WHERE time >= now() - INTERVAL '1 hour'
  AND line = '1'
GROUP BY bucket, device
ORDER BY bucket DESC;
```

버전 선택 시 주의할 점은, 2.x 시절 자료의 Flux 쿼리·`bucket` 개념과 3.x의 SQL·`database` 개념이 섞여 돌아다닌다는 것입니다. 문서를 볼 때 **어느 메이저 버전인지 먼저 확인**하세요.

---

## 5. 그래서 무엇을 고를까 — 트윈 관점의 판단 기준

| 판단 축 | TimescaleDB | InfluxDB |
|---|---|---|
| 쿼리 언어 | 표준 SQL 전부 | SQL(3.x) / Flux·InfluxQL(2.x) |
| 설비 마스터와 JOIN | 같은 DB 안에서 자연스럽게 | 어려움 — 앱 레벨에서 조인 |
| 고카디널리티 | 견딤 | 설계로 피해야 함 |
| 쓰기 처리량 (단순 메트릭) | 높음 | 매우 높음 |
| 운영 난이도 | PostgreSQL 운영 지식 재사용 | 전용 지식 필요, 대신 단일 바이너리로 가벼움 |
| 생태계 | PostgreSQL 전체(PostGIS, 백업, 복제) | Telegraf 수집기, Grafana 1급 지원 |

**디지털 트윈 맥락에서는 Timescale 쪽으로 기우는 이유가 하나 더 있습니다.** 트윈은 센서 값만 다루지 않습니다. 설비 마스터(Day 16의 태그 체계), 자산 계층, 작업 지시, 알람 이력, 모델 메타데이터(Day 17)가 함께 있어야 하고, 이것들은 전부 관계형 데이터입니다. 시계열과 관계형을 한 DB에서 JOIN할 수 있다는 건 트윈 백엔드의 복잡도를 체감 수준으로 줄여 줍니다.

```sql
-- 설비 마스터와 조인해 "수원 공장 프레스 라인의 지난 1시간 최고 온도"
SELECT e.equipment_name, e.installed_at, max(m.value) AS peak_temp
FROM measurement_1m m
JOIN equipment e ON e.device_id = m.device_id
WHERE m.metric = 'die_temp'
  AND m.bucket > now() - INTERVAL '1 hour'
  AND e.site = 'suwon' AND e.asset_type = 'press'
GROUP BY e.equipment_name, e.installed_at
ORDER BY peak_temp DESC;
```

반대로 **InfluxDB를 고를 만한 경우**도 분명합니다. 설비 수가 적고 메타데이터가 거의 고정이며, 초당 수십만 포인트를 단순 append만 하고, Telegraf로 수집해 Grafana로 보는 전형적인 모니터링 구성이라면 InfluxDB가 더 적은 손으로 더 빨리 돕니다.

### 스키마 설계 체크리스트

어느 쪽을 고르든 공통으로 적용되는 원칙입니다.

1. **좁은 테이블(long) vs 넓은 테이블(wide)** — `(ts, device, metric, value)`로 메트릭마다 한 행씩 쌓는 long 구조는 센서 추가가 자유롭지만 행 수가 N배입니다. 한 설비의 모든 센서를 한 행에 넣는 wide 구조는 압축률과 조회가 유리하지만 스키마 변경이 필요합니다. **설비 종류가 고정적이면 wide, 이기종 센서를 계속 붙일 거면 long.**
2. **품질 코드를 반드시 같이 저장** — Day 09의 OPC UA StatusCode나 MQTT 수신 여부를 함께 넣으세요. 값이 `0`인 것과 센서가 죽어서 `0`인 것은 전혀 다르고, 이 구분이 없으면 Day 29 이상 탐지 모델이 고장 데이터를 정상으로 학습합니다.
3. **시각은 UTC로, 수집 시각과 측정 시각을 분리** — 엣지에서 버퍼링된 데이터는 두 시각이 몇 시간씩 벌어집니다.
4. **원본 보존 기간을 먼저 정한다** — "일단 다 모아 두자"는 1년 뒤 비용 청구서로 돌아옵니다. 원본 30~90일 + 1분 집계 2년 + 1시간 집계 영구가 무난한 출발점입니다.
5. **쓰기는 반드시 배치로** — 포인트 하나당 HTTP 요청 1회는 어떤 시계열 DB도 버티지 못합니다. 5,000행 또는 1초 중 먼저 오는 쪽으로 묶어 보내세요. 이 버퍼링 로직이 Day 11의 주제입니다.

---

## 📝 핵심 요약

1. 센서 데이터를 일반 RDB 테이블에 쌓으면 인덱스가 메모리를 벗어나는 순간 쓰기가 무너지고, 오래된 데이터 삭제가 VACUUM 지옥이 된다. 시계열 DB는 시간 기반 파티셔닝·컬럼 압축·파티션 DROP으로 이 셋을 동시에 푼다.
2. TimescaleDB는 PostgreSQL 확장이라 표준 SQL과 JOIN이 그대로 살아 있고, 하이퍼테이블 + 컬럼스토어 + 연속 집계 + 보존 정책이 한 세트로 동작한다.
3. InfluxDB의 태그/필드 구분이 성패를 가른다. WHERE·GROUP BY에 쓰면 태그, 계산하면 필드. 배치 ID나 UUID를 태그에 넣는 순간 카디널리티가 폭발한다.
4. 트윈은 시계열만 저장하지 않는다. 설비 마스터·자산 계층·알람 이력과 JOIN해야 하므로 관계형 능력이 중요하고, 그래서 트윈 백엔드에서는 Timescale 쪽이 손이 덜 가는 경우가 많다.
5. 스키마에는 값과 함께 **품질 코드**를, 시각은 **측정 시각과 수집 시각을 분리해** 저장하고, 보존 계단(원본 → 1분 → 1시간)을 처음부터 설계한다.

---

## 🔗 참고 자료

- [InfluxDB schema design 가이드](https://docs.influxdata.com/influxdb/v2/write-data/best-practices/schema-design/)
- [TimescaleDB Hypertables 문서](https://docs.timescale.com/use-timescale/latest/hypertables/)
- [TimescaleDB Continuous Aggregates 문서](https://docs.timescale.com/use-timescale/latest/continuous-aggregates/)

---

*⬅️ 이전: [Day 09 — OPC UA 서버·클라이언트 기초 실습](../day-09/)  |  다음: [Day 11 — 엣지 게이트웨이와 전처리 — 필터링·다운샘플링·버퍼링](../day-11/) ➡️*
