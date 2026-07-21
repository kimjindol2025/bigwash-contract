# 11. 모바일 전화 수신 자동조회 (2026-07-21)

## 왜

§29(`docs/05` 핵심 자동화)가 "전화가 왔을 때 → 전화번호 검색 → 기존 고객
표시"라고만 적어두고, 번호가 시스템에 어떻게 자동으로 들어오는지는 정해두지
않았다. 이 문서는 그 갭을 채운다.

## 전제

- 상담·영업용 전화 = **개인 안드로이드 휴대폰**(PBX/인터넷전화 아님)
- iOS는 서드파티 앱의 통화기록·발신자 감지 접근을 막아두므로 이 방식은
  **안드로이드 전용**이다
- 서버가 인터넷 어디서나 닿아야 하므로 `https://care.dclub.kr` 배포가
  선행 조건이었다(`README.md` "배포" 절) — 완료됨

## 구조

```
전화가 옴
  → Tasker/MacroDroid가 "전화벨림" 이벤트 감지, 발신번호 확보
  → GET https://care.dclub.kr/care/incoming-call?phone=<발신번호>
  → {ok, found, data:{name, memo, last_consulted_at, next_contact_at, ...}}
  → 폰 화면에 팝업으로 띄움 (받기 전에 누구인지 이미 앎)
```

새 앱을 만들 필요 없음 — Tasker(유료, 검증됨) 또는 MacroDroid(무료) 설치만
하면 된다.

## API

`GET /care/incoming-call?phone=X` — `docs/04-washcare-api.md`, 정본은
`docs/openapi-washcare.yaml` 참조.

- 정확 일치만 한다(하이픈·공백 무관, `search-customers`의 부분일치 LIKE와
  다름) — 착신 팝업에 엉뚱한 고객이 뜨면 안 되기 때문
- 헤더 `x-api-key: <BIGWASH_INTERNAL_API_KEY>` 필요
- 응답 `found:false`면 `data:null` — 신규 발신자, 팝업 대신 "신규 고객"
  안내만 띄우면 됨

```bash
curl "https://care.dclub.kr/care/incoming-call?phone=01012345678" \
  -H "x-api-key: <키>"
# {"ok":true,"found":true,"data":{"id":7,"name":"박사장","phone":"010-...",
#  "customer_type":"CUSTOMER","memo":"...","site_name":"강남점",
#  "last_consulted_at":"2026-07-18 ...","last_content":"...",
#  "next_contact_at":"2026-07-25"}}
```

## Tasker 설정 (요약)

1. **Profile** 생성 → Event → Phone → Phone Ring
2. **Task** → Action → Net → HTTP Request
   - Method: GET
   - URL: `https://care.dclub.kr/care/incoming-call?phone=%CNUM`
     (`%CNUM`이 발신번호 변수)
   - Headers: `x-api-key:<키>`
3. 응답을 변수(`%incoming_call_result`)로 받아서 JSON 파싱
   (Tasker의 "Variable Set" + "JavaScriptlet" 또는 내장 JSON 파서 사용)
4. **Action** → Alert → Flash 또는 Popup으로 `name`/`memo`/`next_contact_at`
   표시 — 전화가 울리는 동안 잠깐 뜨는 정도로 충분

MacroDroid도 같은 3단계(트리거: Phone Ring → HTTP GET → Notification)로
동일하게 구성 가능.

## 통화·문자 자동 기록 — mobserve 연동 (2026-07-21 추가)

착신 팝업(위)과는 **별개 문제**다. 위 흐름은 "벨 울릴 때 누구인지 보여주기"고,
여기는 "통화·문자가 끝난 뒤 자동으로 고객 타임라인에 기록"이다. GitHub에서
정확히 이 역할을 하는 오픈소스를 찾아 그대로 붙였다 —
[`syncloudsoftech/mobserve`](https://github.com/syncloudsoftech/mobserve)
(Kotlin, MIT, 2026-06-05 활발히 유지보수 중). 새 앱을 만들거나 빌드할
필요 없이 [Releases](https://github.com/syncloudsoftech/mobserve/releases)
에서 APK 받아 설치 후 webhook URL만 설정하면 된다.

### 구조

```
통화/문자가 끝남 (mobserve가 CallLog/SMS content observer로 감지)
  → POST https://care.dclub.kr/care/call-events?key=<키>
    {"event":"call","direction":"incoming","participant":"+8210...",
     "duration":143,"date":1770000000000}
  → 발신번호가 기존 고객과 매칭되면 고객 타임라인(CALL/SMS)에 자동 노출
  → 모르는 번호도 원본은 버리지 않음(customer_id NULL로 저장, 타임라인엔 안 뜸)
```

### mobserve 앱 설정

1. APK 설치, 통화기록·SMS 권한 허용
2. Forwarding Rule 추가: event=call(또는 sms), direction=전체,
   webhook URL = `https://care.dclub.kr/care/call-events?key=<BIGWASH_INTERNAL_API_KEY>`
3. 이게 끝 — 코드 수정도, Tasker 설정도 필요 없음

### 왜 헤더가 아니라 쿼리파라미터 인증인가

mobserve 소스(`PostJsonWorker.kt`)를 직접 확인했다 — `Request.Builder()`에
헤더를 추가하는 코드가 없고 순수 JSON POST만 한다. 커스텀 헤더를 못 보내는
구조라서, 이 엔드포인트(`/care/call-events`)만 다른 내부 API와 다르게
`x-api-key` 헤더 대신 `?key=` 쿼리파라미터로 같은 값을 받는다
(`call-webhook-authorized?`, `src/washcare-api.fl`). 인증 정책(해시 비교,
fail-open 등)은 나머지 엔드포인트와 동일 — 04번 문서 "인증" 절 참조.

### 국제번호 정규화

mobserve는 발신번호를 `+821012345678` 같은 국제표기로 보낸다. DB엔
`010-1234-5678` 국내표기로 저장되어 있어 그대로 비교하면 매칭이 안 된다.
`normalize-phone`(`src/washcare.fl`)이 `+82` 접두사를 `0`으로 바꿔서
맞춘다 — `+821012345678` / `010-1234-5678` / `01012345678` 전부 같은
결과로 정규화됨을 직접 테스트로 확인(`tests/test_call_events.fl`).

## 지금 안 하는 것 (다음 단계로 미룸)

- **통화 녹음 연동**: 기종·OEM별 편차가 커서(삼성 기본녹음 vs 구글 순정 등)
  팝업 조회가 실제로 쓸모 있다고 확인된 다음에 붙인다
- **1차 개발범위(`docs/05` 30장) 밖의 정보**(미수금·연간관리 요약 등)를
  팝업에 넣는 것 — `docs/05` 33장 1차 컬럼 확정과 같은 원칙으로, 지금
  스키마에 없는 정보는 넣지 않는다
