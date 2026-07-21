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

## 지금 안 하는 것 (다음 단계로 미룸)

- **통화 녹음 연동**: 기종·OEM별 편차가 커서(삼성 기본녹음 vs 구글 순정 등)
  팝업 조회가 실제로 쓸모 있다고 확인된 다음에 붙인다
- **문자(SMS) 자동 기록**: 같은 Tasker 구조로 "문자 수신" 트리거만 추가하면
  되지만, 이번엔 전화만 먼저 확정
- **1차 개발범위(`docs/05` 30장) 밖의 정보**(미수금·연간관리 요약 등)를
  팝업에 넣는 것 — `docs/05` 33장 1차 컬럼 확정과 같은 원칙으로, 지금
  스키마에 없는 정보는 넣지 않는다
