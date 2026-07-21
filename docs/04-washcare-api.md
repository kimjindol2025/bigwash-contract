# WashCare Phase 1 API 문서

작성일: 2026-07-16
갱신: 2026-07-21 — 인증(개발 공개 정책 명문화) + 에러 응답 계약 절 추가
(`docs/09-implementation-schedule.md` 1주차)
기준 파일: `src/washcare-api.fl`
OpenAPI 스펙: [`openapi-washcare.yaml`](openapi-washcare.yaml) (같은 폴더)

## 인증

### 현재 상태 — 개발 단계 전체 공개 정책 (의도된 결정)

- **내부 엔드포인트** 전체(`/care/customers`, `/care/sites`, `/care/equipment`,
  `/care/tickets/*`, `/care/consultations/*`, `/care/quotes/*`,
  `/care/customer-contacts`, `/care/customer-tasks/*`, `/care/customer-followups/*`,
  `/care/timeline`, `/care/contracts`, `/care/part-sales`, `/care/outreach/*`,
  `/care/sales`, `/care/sites/:id/link/*`, `/care/warranty-expiring` 등 — 전체
  라우트는 `openapi-washcare.yaml` 참조): 헤더 `x-api-key: <BIGWASH_INTERNAL_API_KEY>`를
  검사하지만, 환경변수 `BIGWASH_INTERNAL_API_KEY`가 비어있거나 미설정이면
  `internal-authorized?`(`src/washcare-api.fl`)가 **모든 요청을 무조건 통과시킨다**
  (fail-open).
- **이것은 버그가 아니라 2026-07-19에 내려진 명시적 개발 단계 결정이다** —
  로그인 시스템이 없는 현재 단계에서 매 요청마다 키를 요구하면 개발 속도가
  떨어진다는 판단. 인증 코드 자체는 이번 1주차에서 바꾸지 않는다
  (`docs/09-implementation-schedule.md` 1주차 범위 참조).
- **실데이터 금지·외부 노출 금지**: 이 공개 모드로 서버를 실행하는 동안은
  실제 고객 정보·연락처·계약금액 등 운영 데이터를 입력하지 않는다. 서버는
  `localhost` 또는 접근이 통제된 개발망(사내 VPN 등)에서만 실행하고,
  공인 IP·리버스 프록시를 통해 외부 인터넷에 노출하지 않는다. 개발 중
  실측·데모가 필요하면 가짜 고객명·가짜 연락처만 사용한다.
- **운영 배포 전 인증 필수 게이트**: 아래 조건을 모두 만족하기 전에는 이
  서버를 실제 고객 데이터와 함께 외부에 노출된 환경(예: `care.dclub.kr`
  운영 배포, README.md "배포" 절)에 올리지 않는다.
  1. `BIGWASH_INTERNAL_API_KEY`가 배포 환경에 실제로 설정되어 있음을 배포
     담당자가 확인
  2. 키 미설정 시 서버가 무인증으로 열리는 대신 **기동을 거부하거나 전체
     401을 반환**하도록 `internal-authorized?`/기동 스크립트를 fail-closed로
     전환(별도 스프린트 — 이번 1주차 범위 아님)
  3. 위 전환 후 "키 없이 기동 → 차단됨", "키 있을 때 기동 → 정상 200/401" 두
     경우를 실측 확인
  - 이 세 조건이 충족되기 전까지는 개발 공개 모드를 운영 배포에 그대로
    가져가지 않는다 — 즉 fail-open 상태로 실고객 데이터를 다루는 배포는
    금지한다.
  - **알려진 예외 (2026-07-20~, kim 확인)**: 위 게이트 완성 전에
    `care.dclub.kr`가 이미 공개 배포됐다(node25 pm2, `README.md` "배포" 절).
    `BIGWASH_INTERNAL_API_KEY`는 실제로 설정되어 있어 완전한 fail-open은
    아니고, 현재 올라간 데이터도 전부 테스트/마이그레이션 더미(실고객
    정보 없음, 2026-07-21 재확인)다. 코드 자체의 fail-closed 전환(조건 2)은
    아직 안 됐으므로 정책 문서 기준으로는 여전히 갭이지만, kim이 이 상태
    유지를 선택했다 — 실고객 데이터를 넣기 전에는 반드시 조건 2·3을
    마저 채울 것.
- **공개 엔드포인트** (`/care/status/:token`, `/care/site-status/:token`): 원래부터
  인증 없음. 토큰 자체가 접근 권한이며, 위 개발 공개 정책과 무관하게 항상
  같은 보안 모델(해시 저장, rate limit, `Cache-Control: no-store`)로 동작한다.

## 내부 엔드포인트

**이 표는 전체 내부 API 53개(정적 `/care/admin`, 공개 `/care/status/:token`·
`/care/site-status/:token` 제외)를 `src/washcare-api.fl`의 `server_get`/
`server_post`/`server_put` 등록과 1:1 대조해 채운 것이다. 각 요청/응답
스키마의 기계 판독용 정본은 `docs/openapi-washcare.yaml`이고, 아래 표와
이어지는 절은 설명용이다** — 두 문서가 어긋나면 openapi 쪽이 실제 코드와
더 자주 자동 대조되므로 openapi를 우선한다.

| Method | Path | 설명 | 인증 |
|---|---|---|---|
| POST | `/care/customers` | 고객 생성 | O |
| POST | `/care/sites` | 사업장 생성 | O |
| GET | `/care/sites?customer_id=X` | 고객별 사업장 목록 | O |
| POST | `/care/equipment` | 장비 등록 | O |
| GET | `/care/equipment?customer_id=X` | 고객별 장비 목록 (site 조인) | O |
| POST | `/care/tickets` | A/S 접수 (공개 토큰 발급) | O |
| PUT | `/care/tickets/:id/status` | 티켓 상태 변경 | O |
| POST | `/care/tickets/:id/visits` | 방문·수리 이력 추가 | O |
| POST | `/care/tickets/:id/link/revoke` | 공개 링크 폐기 | O |
| POST | `/care/tickets/:id/link/reissue` | 공개 링크 재발급 | O |
| GET | `/care/tickets?status=X&today=1` | 상태별 티켓 목록 (Admin UI용, 2026-07-16 추가) | O |
| GET | `/care/tickets/:id` | 티켓 상세 + 방문이력 + 상태변경이력 (2026-07-16 추가) | O |
| GET | `/care/customers?q=X` | 이름·전화번호로 고객 검색, 최대 50건 (2026-07-16 추가) | O |
| GET | `/care/customers/:id` | 고객 상세 조회 (2026-07-19 추가) | O |
| GET | `/care/incoming-call?phone=X` | 전화 수신 자동조회 — 정확 일치(하이픈 무관), Tasker/MacroDroid 연동용 (2026-07-21 추가, `docs/11-mobile-caller-lookup.md`) | O |
| POST | `/care/call-events` | 자동 통화·문자 로거 webhook 수신(mobserve 등) — 고객 매칭 시 타임라인에 노출 (2026-07-21 추가, `docs/11-mobile-caller-lookup.md`) | O(쿼리 `?key=`, 헤더 아님) |
| POST | `/care/quotes` | 고객 견적 생성 (2026-07-19 추가) | O |
| GET | `/care/quotes?customer_id=X` | 고객별 견적 목록 (2026-07-19 추가) | O |
| PUT | `/care/quotes/:id/status` | 견적 상태 변경 (2026-07-19 추가) | O |
| POST | `/care/quotes/:id/convert` | 승인 견적을 계약으로 전환 (2026-07-19 추가) | O |
| GET | `/care/contracts?customer_id=X` | 고객별 계약 목록 (2026-07-20 추가) | O |
| GET | `/care/timeline?customer_id=X&type=Y` | 고객 통합 타임라인 — 상담·판매·견적·계약·출장·사후관리 UNION (2026-07-20 추가) | O |
| POST | `/care/consultations` | 상담 기록 생성 (2026-07-19 추가) | O |
| GET | `/care/consultations?customer_id=X` | 고객별 상담 기록 목록 (2026-07-19 추가) | O |
| PUT | `/care/consultations/:id/complete` | 상담 완료 처리 (2026-07-19 추가) | O |
| GET | `/care/consultations/due-today` | 오늘 다시 연락할 상담 목록 (2026-07-19 추가) | O |
| GET | `/care/consultations/recent?limit=N` | 최근 상담 목록 (기본 15건, 2026-07-19 추가) | O |
| GET | `/care/consultations/pending` | 다음 조치가 남은 상담 목록 (2026-07-19 추가) | O |
| POST | `/care/customer-contacts` | 고객 담당자 생성 (2026-07-19 추가) | O |
| GET | `/care/customer-contacts?customer_id=X` | 고객별 담당자 목록 (2026-07-19 추가) | O |
| POST | `/care/customer-tasks` | 고객 할 일 생성 (2026-07-19 추가) | O |
| GET | `/care/customer-tasks?customer_id=X` | 고객별 할 일 목록 (2026-07-19 추가) | O |
| PUT | `/care/customer-tasks/:id/complete` | 할 일 완료 처리 (2026-07-19 추가) | O |
| POST | `/care/customer-followups` | 사후관리 예정 생성 (2026-07-19 추가) | O |
| GET | `/care/customer-followups?customer_id=X` | 고객별 사후관리 목록 (2026-07-19 추가) | O |
| PUT | `/care/customer-followups/:id/complete` | 사후관리 완료 처리 (2026-07-19 추가) | O |
| GET | `/care/admin` | Admin UI 페이지 (HTML) — **이 경로 자체는 인증 없이 열람 가능**. 데이터 API 호출도 `BIGWASH_INTERNAL_API_KEY`가 서버에 설정된 경우에만 키 입력이 필요하고, 미설정(현재 개발 공개 정책, fail-open)이면 키 없이도 데이터가 그대로 조회됨 | X (셸만) / 데이터는 서버 키 설정 여부에 따름 |
| POST | `/care/part-sales` | 부품판매 등록 (2026-07-17 추가) | O |
| GET | `/care/part-sales?site_id=X` | 사업장별 부품판매 목록 (2026-07-17 추가) | O |
| POST | `/care/outreach` | 홍보/휴면기 접촉 예정 생성 (2026-07-17 추가) | O |
| POST | `/care/outreach/:id/response` | 접촉 응답·전환 결과 기록 (2026-07-17 추가) | O |
| GET | `/care/outreach/due` | 접촉 예정일이 지난(또는 오늘인) 대상 목록 (2026-07-17 추가) | O |
| POST | `/care/sales` | 판매 등록 — 고객/사업장/장비 생성 + 장비관리 링크 발급 + 첫 접촉 예약 (orchestrated, 2026-07-17 추가) | O |
| POST | `/care/sites/:id/link/revoke` | 사업장 장비관리 링크 폐기 (2026-07-17 추가) | O |
| POST | `/care/sites/:id/link/reissue` | 사업장 장비관리 링크 재발급 (2026-07-17 추가) | O |
| GET | `/care/warranty-expiring?days=N` | 보증 만료 임박 장비 목록, 기본 30일. ACTIVE 장비만 대상(2026-07-21 2주차 — RETIRED/REPAIR 제외) | O |
| GET | `/care/ops-summary?warranty_days=N` | 운영 대시보드 집계 — 지연·일정미정·오늘방문·보증임박 4개 섹션 (2026-07-21 2주차 추가) | O |
| GET | `/care/ops-weekly?as_of=YYYY-MM-DD` | 주간 운영 보고 — 미처리 A/S·다음 주 방문·보증 만료 기반 점검 대상 (2026-07-21 3주차 추가). `as_of` 생략 시 Seoul 오늘 | O |
| POST | `/care/care-plans` | 연간관리(CarePlan) 가입 생성 (2026-07-21 4주차 추가) | O |
| GET | `/care/care-plans` | CarePlan 목록 — `site_id`/`customer_id` 둘 다 선택. 하나를 주면 그 스코프(무제한), 둘 다 생략하면 고객·현장명 조인 최신 50건 전체 목록 (2026-07-21 4주차 추가, 5주차 무필터 확장) | O |
| GET | `/care/care-plans/:id` | CarePlan 상세 조회, `effective_status` 파생 포함 (2026-07-21 4주차 추가) | O |
| PUT | `/care/care-plans/:id` | 사용 방문 수(`used_visits`)·`next_inspection_at`·메모 수정 (2026-07-21 4주차 추가) | O |
| PUT | `/care/care-plans/:id/cancel` | CarePlan 취소 (2026-07-21 4주차 추가) | O |
| POST | `/care/care-plans/:id/renew` | CarePlan 갱신 — 기존 ACTIVE를 RENEWED로 전환 후 신규 행 생성 (2026-07-21 4주차 추가) | O |

위 53개(내부 API, `/care/admin` 제외) + 아래 "공개 엔드포인트" 절의
`/care/status/:token`, `/care/site-status/:token` 2개를 더하면
`openapi-washcare.yaml`의 전체 operation 55개와 정확히 일치한다
(`/care/admin`, 루트 `/`는 정적 페이지라 양쪽 문서 모두 API 스펙에서 제외).

### POST /care/customers

요청 본문: `{name, phone, email, memo, customer_type, address}` (`name` 필수)

- `customer_type`: `LEAD`|`CUSTOMER`|`SERVICE`|`VENDOR`, 생략 시 `LEAD`
- `address`: 선택. 신규 잠재고객 단계에서 사업장(`sites`)을 만들지 않고도 지역/주소를 먼저 남길 수 있다.

응답 200: `{ok: true, data: {id, name, phone, email, memo, customer_type, address, legacy_client_id, migration_status, created_at, updated_at}}`

응답 401: `{ok: false, error: "Unauthorized"}`

응답 400: `{ok: false, error: "..."}` (`customer_type`이 허용값이 아니면 400)

### POST /care/sites

요청: `{customer_id, name, address, contact_phone}`

응답 200: `{ok: true, data: {id, customer_id, name, address, contact_phone, status, created_at, updated_at}}`

### POST /care/equipment

요청: `{site_id, contract_id, category, model, serial_number, installed_at, warranty_ends_at}`

`serial_number`는 UNIQUE — 중복 시 400 에러(실측 확인, 2026-07-21). 다만
`error` 필드가 사람이 읽는 메시지가 아니라 내부 파일경로·줄번호·콜스택이
포함된 예외 객체 직렬화값이다 — 별도 에러 코드로 구분되지 않는 것과 메시지
새니타이즈 모두 개선 후보(아래 "알려진 개선 후보" 참조).

응답 200: `{ok: true, data: {...equipment row}}`

### POST /care/tickets

요청: `{site_id, equipment_id, symptom, priority, source, scheduled_at}`

- `priority`: `LOW`|`NORMAL`|`HIGH`|`URGENT`
- `source`: `PHONE`|`MESSAGE`|`WEB`|`INTERNAL`

응답 200: `{ok: true, data: {id, status: "RECEIVED", public_token}}`

**`public_token`은 이 응답에서 딱 한 번만 원문으로 내려온다** — DB에는 해시만 저장되므로
이후 다시 조회할 방법이 없다. 고객에게 즉시 전달해야 한다.

### PUT /care/tickets/:id/status

요청: `{status}` — `RECEIVED`|`SCHEDULED`|`IN_PROGRESS`|`COMPLETED`|`CANCELLED`

허용 전이만 가능(`RECEIVED→SCHEDULED/IN_PROGRESS/CANCELLED`,
`SCHEDULED→IN_PROGRESS/CANCELLED`, `IN_PROGRESS→COMPLETED/CANCELLED`).
그 외 조합은 400으로 응답한다(2026-07-19 `try/catch` 추가로 500에서 전환됨 —
아래 실측 참조).

- `COMPLETED`로 전이 시: `closed_at` 기록. 공개 링크는 **즉시 폐기되지 않고 7일간
  유지**된다 (`TICKET-COMPLETED-VISIBILITY-DAYS`, 2026-07-16 수정 — 이전에는 완료 즉시
  폐기되어 고객이 완료 상태를 확인할 방법이 없었던 버그를 고침).
- `CANCELLED`로 전이 시: 공개 링크 즉시 폐기.

응답 200: `{ok: true, data: {success: true, old_status, new_status}}`

**실측 확인(2026-07-21, 격리 테스트 DB에 서버 기동 후 curl로 재검증): 잘못된
전이·존재하지 않는 티켓 모두 이제 500이 아니라 400으로 응답한다.** 다만
`error` 필드는 사람이 읽는 메시지가 아니라 **캐치한 예외 객체 전체를 JSON
문자열로 직렬화한 값**이라, 내부 절대경로·줄번호·호출 스택이 여전히 그대로
노출된다(예: `error` 값 안에 `"stack":"Error: [update-ticket-status] [error]
Service ticket not found (at line 108, col 0)"`와
`"file":"/.../src/washcare-api.fl"`가 포함됨). Admin UI에서 이 에러를 그대로
사용자에게 보여주면 안 되고, 별도로 파싱해서 표시해야 한다. 메시지
새니타이즈는 개선 후보로 남겨둔다(아래 "알려진 개선 후보" 참조).

### POST /care/tickets/:id/visits

요청: `{technician, visited_at, diagnosis, action_taken, parts_used, labor_cost, parts_cost, next_inspection_at}`

응답 200: `{ok: true, data: {...visit row}}`

### POST /care/tickets/:id/link/revoke

요청 본문 없음. 응답 200: `{ok: true}`

### POST /care/tickets/:id/link/reissue

`COMPLETED`/`CANCELLED` 티켓은 재발급 불가(에러). 응답 200: `{ok: true, data: {ticket_id, public_token}}`
(이전 토큰은 즉시 무효화됨.)

### GET /care/tickets

쿼리: `status`(필수, RECEIVED 등), `today`(선택, `1`이면 오늘 생성된 것만).

응답 200: `{ok: true, data: [{id, site_id, equipment_id, symptom, priority, source, status, scheduled_at, created_at, site_name, contact_phone}, ...]}`

### GET /care/tickets/:id

응답 200: `{ok: true, data: {ticket: {...전체 필드, customer_id, customer_name, site_name, address, contact_phone 포함}, visits: [...], history: [...]}}`

응답 404: `{ok: false, error: "Not found"}` (실측 확인)

### GET /care/customers?q=X&filter=Y

`name`/`phone`/`address`/`memo`에 대해 `LIKE %q%` 부분일치, 최대 50건. `q` 없으면 빈 문자열로 전체(최대
50건) 반환. 전화번호 뒷 4자리 같은 부분 입력도 허용하고, 하이픈·공백을 제거한 뒤에도 비교하므로
`010-1234-5678`/`01012345678` 어느 쪽으로 검색해도 같은 고객이 걸린다(2026-07-20 추가, docs/05 33장).
`filter`는 `ALL`(기본)/`LEAD`/`CUSTOMER`/`SERVICE`/`VENDOR`.

응답 200: `{ok: true, data: [{id, name, phone, email, address, customer_type, migration_status, site_name, last_consulted_at, next_contact_at, region}, ...]}`

- `site_name`: 이 고객의 가장 먼저 등록된 현장(`sites`) 이름 — 현장이 없으면 `null`
- `region`: `address` 앞 두 토큰(예: "경기도 김포시")만 잘라낸 값 — 파싱 실패 시 `address` 원문
- `last_consulted_at`/`next_contact_at`: 최근 상담일 / 미완료 상담의 다음 연락 예정일(`consultations` 기준)

### GET /care/customers/:id

응답 200: `{ok: true, data: {id, name, phone, email, memo, customer_type, address, legacy_client_id, migration_status, created_at, updated_at}}`

응답 404: `{ok: false, error: "Customer not found"}`

### POST /care/quotes

요청: `{customer_id, title, amount, valid_until, memo}`

응답 200: `{ok: true, data: {...quotes row}}`

응답 400: `{ok: false, error: "..."}`

### GET /care/quotes?customer_id=X

고객별 견적 목록을 `created_at DESC, id DESC` 순으로 반환.

응답 200: `{ok: true, data: [{id, customer_id, quote_number, title, amount, valid_until, status, sent_at, contract_id, memo, created_at, updated_at}, ...]}`

### PUT /care/quotes/:id/status

요청: `{status}` — `DRAFT → SENT → REVIEWING → REVISION_REQUESTED → SENT` 흐름과 `ON_HOLD`/`REJECTED` 분기만 허용한다.

응답 200: `{ok: true, data: {...갱신된 quotes row}}`

응답 400: `{ok: false, error: "Quote not found" | "Invalid quote status transition" | ...}`

### POST /care/quotes/:id/convert

`APPROVED` 상태 견적만 계약으로 전환할 수 있다. 레거시 `contract.fl`을 로드하지 않고,
WashCare 쪽에서 `contracts`에 최소 INSERT를 수행한다.

응답 200: `{ok: true, data: {...CONVERTED 상태의 quotes row}}`

응답 400: `{ok: false, error: "Only APPROVED quotes can be converted to a contract" | ...}`

### POST /care/consultations

요청: `{customer_id, consulted_at, method, content, next_action, next_contact_at}`

- `method`: `PHONE`|`SMS`|`KAKAO`|`VISIT`|`OTHER`, 생략 시 `PHONE`
- `next_action`: `NONE`|`CALLBACK`|`QUOTE`|`SERVICE_TICKET`|`SALE`|`CONTRACT_REVIEW`, 생략 시 `NONE`
- `next_contact_at`: 선택. 다음에 다시 연락할 날짜

응답 200: `{ok: true, data: {...consultations row}}`

응답 400: `{ok: false, error: "..."}` (잘못된 `method`/`next_action` 등)

### GET /care/consultations?customer_id=X

고객별 상담 기록을 `consulted_at DESC` 순으로 반환.

응답 200: `{ok: true, data: [{...consultations row}, ...]}`

### PUT /care/consultations/:id/complete

상담 건별로 `completed_at`을 기록해 종료한다. 고객당 여러 follow-up이 동시에 열려 있을 수 있으므로, 최신 1건만 남기는 방식이 아니라 **각 상담 건을 개별 완료 처리**한다.

응답 200: `{ok: true, data: {...갱신된 consultations row}}`

### GET /care/consultations/due-today

`completed_at IS NULL`, `next_contact_at IS NOT NULL`, `date(next_contact_at) <= date('now')` 조건을 만족하는 상담 목록.

응답 200: `{ok: true, data: [{id, customer_id, next_contact_at, next_action, content, customer_name, phone}, ...]}`

### GET /care/consultations/recent?limit=N

최근 상담 목록. `limit` 기본값은 15.

응답 200: `{ok: true, data: [{id, customer_id, consulted_at, method, content, customer_name, phone}, ...]}`

### GET /care/consultations/pending

`completed_at IS NULL AND next_action <> 'NONE'` 조건의 상담 목록.

응답 200: `{ok: true, data: [{id, customer_id, next_action, next_contact_at, content, customer_name, phone}, ...]}`

### POST /care/part-sales

요청: `{site_id, equipment_id, ticket_id, part_name, quantity, unit_price, channel}`
(`equipment_id`/`ticket_id`는 nullable — A/S와 무관하게 부품만 팔 수 있음. `channel`은
`STORE`|`ONLINE`, 기본값 `STORE`)

`total_price`는 서버에서 `quantity * unit_price`로 계산(요청에 넣을 필요 없음).

응답 200: `{ok: true, data: {...part_sales row}}`

### GET /care/part-sales?site_id=X

응답 200: `{ok: true, data: [{...part_sales row}, ...]}` (최신순)

### POST /care/outreach

요청: `{site_id, equipment_id, touch_type, channel, next_touch_at}`

- `touch_type`: `CHECKIN`|`INSPECTION_REMINDER`|`REPLACEMENT_OFFER`|`PROMOTION`
- `channel`: `PHONE`|`KAKAO`|`SMS`|`EMAIL`

응답 200: `{ok: true, data: {...outreach_touches row}}`

### POST /care/outreach/:id/response

요청: `{response, converted_to, converted_ref_id, next_touch_at}`

- `response`: `NO_RESPONSE`|`POSITIVE`|`NEGATIVE`|`CONVERTED`
- `converted_to`(선택): `TICKET`|`PART_SALE`|`NEW_EQUIPMENT` — 이 접촉이 실제 A/S·부품판매·
  신규판매로 이어졌으면 어느 쪽인지, `converted_ref_id`로 해당 레코드 id 연결
- 전환됐으면 `next_touch_at`을 `null`로 둬서 이 라운드를 종결(재접촉 불필요)

응답 200: `{ok: true, data: {...갱신된 row}}`

### GET /care/outreach/due

`next_touch_at <= now`인 대상 중, 사업장·장비 조합별로 **가장 최근 접촉 1건만** 반환
(과거 이력이 아니라 "지금 연락해야 할 대상" 목록).

응답 200: `{ok: true, data: [{id, site_id, equipment_id, touch_type, channel, next_touch_at, site_name, contact_phone}, ...]}`

### POST /care/sales

9장 "신규 장비 판매" 흐름(기존 계약 연결 → 고객/사업장 생성 → 장비 등록 → 장비관리 링크 전달 →
첫 접촉 예약)을 하나의 호출로 묶은 orchestration 엔드포인트. 다섯 단계는 하나의 DB
트랜잭션으로 실행되며, 장비 등록 등 중간 단계가 실패하면 신규 고객·사업장·장비·접촉
예약을 모두 롤백한다.

요청: `{customer_id, customer_name, customer_phone, customer_email, site_name,
site_address, site_contact_phone, contract_id, equipment: [{category, model,
serial_number, installed_at, warranty_ends_at}, ...], first_outreach_days}`

- `customer_id`가 있으면 기존 고객을 재사용(이름 등 다른 필드는 무시), 없으면
  `customer_name` 등으로 신규 고객을 생성한다.
- `equipment`는 배열 — 한 번의 판매에 여러 장비를 함께 등록할 수 있다.
- `first_outreach_days`(기본 90) 뒤로 `CHECKIN` 유형의 첫 홍보 접촉이 자동 예약된다.

응답 200: `{ok: true, data: {customer_id, site_id, equipment: [...], site_public_token}}`

**`site_public_token`은 이 응답에서만 원문으로 내려온다** (티켓 토큰과 동일한 원칙 —
DB에는 해시만 저장). 고객에게 이 링크(`/care/site-status/:token`)를 전달한다.

### POST /care/sites/:id/link/revoke, POST /care/sites/:id/link/reissue

티켓 링크의 revoke/reissue와 동일한 패턴(해시 저장, 재발급 시 이전 토큰 즉시 무효화).

### GET /care/warranty-expiring?days=N

`days`(기본 30, 허용범위 0~3650) 이내에 `warranty_ends_at`이 도래하는 장비 목록. 이미 만료된 장비는 제외한다 — 재구매·교체판매 제안
대상 후보. **`equipment.status = 'ACTIVE'`만 포함한다** (2026-07-21 2주차 추가 —
`RETIRED`/`REPAIR` 장비는 재구매 제안 대상이 아니므로 제외). 목록은 최대 50건.
응답 200: `{ok: true, data: [{id, model, category, warranty_ends_at, status, site_id, site_name, contact_phone}, ...]}`

### GET /care/ops-summary?warranty_days=N

2주차 운영 대시보드 집계(`docs/09-implementation-schedule.md` 2주차). 미수금은
포함하지 않는다(`PaymentOrder` 정의 전 — `docs/09` 0장 원칙). 모든 "지금"은
Asia/Seoul로 보정한 값이다(`datetime('now', '+9 hours')`, SQLite 기본 `now()`는
UTC이므로 자정 근처 오차를 막기 위한 보정).

`warranty_days`: 기본 30, 허용범위 0~3650 (`/care/warranty-expiring`의 `days`와 동일 검증).

**확정 규칙(Codex, 2026-07-21):**

- `overdue`(지연): `status IN ('RECEIVED','SCHEDULED')`이고 `scheduled_at`이
  있으며 `datetime(scheduled_at) < datetime('now','+9 hours')`(strict `<` —
  현재시각과 정확히 같으면 지연 아님). `IN_PROGRESS`는 포함하지 않는다.
- `unscheduled`(일정 미정): `status IN ('RECEIVED','SCHEDULED')`이고
  `scheduled_at`이 없음(NULL 또는 빈 문자열). **"담당자 미배정"이 아니다** —
  `service_tickets`에는 담당자 컬럼이 없고, `service_visits.technician`은
  방문이 실제로 발생한 뒤에만 존재하는 사후 이력이라 배정 여부를 나타낼 수
  없다. 신규 담당자 컬럼 도입 전까지 이 명칭·정의를 쓰지 않는다.
- `visits_today`(오늘 방문): `status NOT IN ('COMPLETED','CANCELLED')`이고
  `date(scheduled_at) = date('now','+9 hours')`(Seoul 오늘). **완료 이력인
  `service_visits`는 쓰지 않는다** — "오늘 나갈 일"이지 "오늘 끝난 일"이 아니다.
- `warranty_expiring`: 위 `GET /care/warranty-expiring`과 동일 로직 재사용
  (`list-warranty-expiring`/`count-warranty-expiring`, ACTIVE 필터 포함).

각 섹션은 `{count, items}`(전체 개수와 최대 50건 목록을 별도 쿼리로 계산 —
`count`는 50건 캡의 영향을 받지 않는다) 형태이고, `warranty_expiring`만
`days` 필드가 추가된다.

응답 200:
```json
{"ok": true, "data": {
  "as_of": "2026-07-21T01:00:00+09:00",
  "timezone": "Asia/Seoul",
  "overdue": {"count": 0, "items": [/* ticket row: id,site_id,symptom,priority,status,scheduled_at,site_name,contact_phone */]},
  "unscheduled": {"count": 0, "items": [/* 위와 동일한 ticket row 형태 */]},
  "visits_today": {"count": 0, "items": [/* 위와 동일한 ticket row 형태 */]},
  "warranty_expiring": {"count": 0, "days": 30, "items": [/* equipment row: id,model,category,warranty_ends_at,status,site_id,site_name,contact_phone */]}
}}
```

응답 400: `{ok: false, error: "warranty_days must be an integer between 0 and 3650"}`

### GET /care/ops-weekly?as_of=YYYY-MM-DD

3주차 주간 운영 보고(`docs/09-implementation-schedule.md` 3주차, `docs/01` §6
항목 8 / P0-2). 카카오·메일 발송은 범위 밖 — JSON·Admin 화면만. **미수금
키·섹션·추정값은 응답에 넣지 않는다**(PaymentOrder/입금원장 도입 후 버전된
API 변경으로 추가). 개발 단계 인증은 기존과 동일하게 fail-open
(`ApiKeyAuth | {}`).

`as_of` (선택): Asia/Seoul 달력 기준일, `YYYY-MM-DD`. 생략 시 서버 Seoul
"오늘". 잘못된 형식이면 400.

**확정 규칙(Codex, 2026-07-21):**

- `week`: 항상 `kind: "next"` — `as_of`가 속한 ISO 8601 주(월~일)의 **다음**
  주. `iso_year`, `iso_week`, `label`(`YYYY-Www`), `start_date`, `end_date`
  (둘 다 `YYYY-MM-DD`, Seoul 달력).
- `unprocessed`(미처리 A/S): `status NOT IN ('COMPLETED','CANCELLED')` —
  **IN_PROGRESS를 포함한 열린 티켓 전체**. **"담당자 미배정"이 아니다.**
- `visits_next_week`(다음 주 방문): `status NOT IN ('COMPLETED','CANCELLED')`
  이고 `date(scheduled_at)`이 `week.start_date`..`week.end_date` 구간.
  **`service_visits`(완료 이력)는 쓰지 않는다.**
- `inspection_due`(보증 만료 기반 점검 대상): `equipment.status = 'ACTIVE'`
  이고 `date(warranty_ends_at)`이 같은 다음 ISO 주 구간.

각 섹션은 `{count, items}`(`items` 최대 50, `count`는 캡과 무관한 전체 개수).

응답 200:
```json
{"ok": true, "data": {
  "as_of": "2026-01-01",
  "timezone": "Asia/Seoul",
  "week": {
    "kind": "next",
    "iso_year": 2026,
    "iso_week": 2,
    "label": "2026-W02",
    "start_date": "2026-01-05",
    "end_date": "2026-01-11"
  },
  "unprocessed": {"count": 0, "items": [/* OpsTicketRow */]},
  "visits_next_week": {"count": 0, "items": [/* OpsTicketRow */]},
  "inspection_due": {"count": 0, "items": [/* OpsEquipmentRow */]}
}}
```

응답 400: `{ok: false, error: "as_of must be a valid YYYY-MM-DD date"}`

## CarePlan (연간관리, 4~5주차)

`docs/09-implementation-schedule.md` 4~5주차, `docs/01` §8, `docs/05` §19,
`docs/07` §8. **백엔드(4주차)·Admin UI(5주차) 모두 완료됐다**(2026-07-21) —
아래 "Admin UI" 절의 `careplan` 메뉴가 실 데이터 목록/가입/취소/갱신 화면으로
동작하고, 고객 상세에 `연간관리` 탭과 상단 요약이 붙었으며, 새 A/S 접수
폼에는 현장의 CarePlan 이용 현황을 안내만 하는 배너가 붙는다. `site_id`에
걸리며(`docs/01` 원본 데이터모델과 동일 — equipment/part_sales/
outreach_touches와 같은 현장 단위 앵커), `payment_status`/PG 연동·할인율
계산·방문 자동차감·미수금 표시는 이번 범위에 없다(`PaymentOrder` 도입 전,
docs/02 Phase2 원칙 — Admin UI도 이 원칙을 그대로 따라 화면에 할인·과금·
자동차감 요소를 두지 않는다). **운영 배포·운영 DB 마이그레이션은 이번
갱신에 포함되지 않는다** — `db/contracts.sqlite`는 로컬 개발 DB에만
반영됐고 `scripts/migrate-phase1.sh` 등 운영 스크립트 실행은 하지 않았다.

### 공통 개념

- **plan_code 3종**(고정, 신규 코드 추가 없음):

  | plan_code | 기간 | 포함 방문(`included_visits` 기본값) | 가격 스냅샷(`price_snapshot` 기본값) |
  |---|---|---|---|
  | `TRIAL_90` | 90일 | 0 | 99,000원 |
  | `BASIC_360` | 365일 | 0 | 360,000원 |
  | `FIELD_790` | 365일 | 2 | 790,000원 |

  가입(`POST`)·갱신(`renew`) 시 `price_snapshot`/`included_visits`를 요청
  본문으로 override할 수 있다 — 둘 다 **0 이상의 정수**만 허용(소수·음수·
  숫자가 아닌 문자열은 400). override를 생략하면 위 표의 기본값을 쓴다.
- **기간 계산**: `ends_at`은 **시작일 포함** 계산이다 —
  `ends_at = starts_at + (기간일수 - 1)`. 예: `TRIAL_90`이 `2026-01-01`에
  시작하면 `ends_at`은 `2026-03-31`(90일째, 시작일 자신이 1일째).
- **`starts_at`/`next_inspection_at`**: 둘 다 `YYYY-MM-DD` 형식과 실제
  존재하는 날짜(윤년 아닌 해의 2월 29일 등은 SQLite `date()`가 다음 달로
  조용히 정규화하므로, 원문과 재비교하는 round-trip 검증으로 걸러낸다)를
  모두 만족해야 한다. `starts_at` 생략 시 서버의 Seoul "오늘"로 채워진다.
  `next_inspection_at`은 nullable — 아직 다음 점검일이 안 정해졌으면 생략.
- **저장 status vs `effective_status`**: DB에는 `ACTIVE`/`CANCELLED`/
  `RENEWED` 세 가지만 저장되고, 시간 경과로 자동 전이하지 않는다(이 저장소의
  다른 상태 머신과 동일 원칙 — `quotes.valid_until`이 지나도 자동으로
  `EXPIRED`가 안 되는 것과 같음). 모든 응답에는 파생 필드 `effective_status`가
  추가로 붙는데, **`status`가 `ACTIVE`이고 `ends_at`이 Seoul 기준 오늘보다
  과거면 `EXPIRED`**로 보여주고, 그 외에는 `status`를 그대로 반영한다
  (`CANCELLED`/`RENEWED`는 종료일과 무관하게 절대 `EXPIRED`로 바뀌지 않음).
- **하드 삭제 없음.** 같은 `site_id`에 대해 **취소되지 않은(`ACTIVE` 또는
  `RENEWED`) 기존 행과 날짜 구간이 겹치면**(양끝 포함) 신규 생성·갱신 모두
  트랜잭션 내에서 거부한다. `CANCELLED`인 행의 기간은 겹침 판정에서 제외된다
  — 취소된 기간은 다시 그 날짜로 새로 가입할 수 있다.
- **`used_visits`는 자동 차감이 없다.** `PUT`으로 항상 **절대값**을 보내며,
  같은 값으로 재시도해도 결과가 같다(멱등). 증가뿐 아니라 오입력을 바로잡는
  감소도 허용한다 — 다만 `0 <= used_visits <= included_visits` 범위를 벗어나면
  400.
- **`update`(`PUT`)·`cancel`·`renew`는 전부 대상 플랜이 `ACTIVE` 상태일 때만
  허용된다.** `CANCELLED`/`RENEWED` 플랜을 수정·재취소·재갱신하려 하면 400.
- `site_id`/`customer_id`/`:id` 경로·쿼리 값은 양의 정수만 허용(그 외 400).
- 미수금 키·PG 연동은 어디에도 없다.

### POST /care/care-plans

요청: `{site_id, plan_code, starts_at, price_snapshot, included_visits, next_inspection_at, memo}`

- `site_id`(필수, 양의 정수) — 존재하지 않으면 400 `"Site not found"`.
- `plan_code`(필수) — `TRIAL_90`|`BASIC_360`|`FIELD_790` 외 값은 400.
- `starts_at`(선택, 생략 시 Seoul 오늘), `price_snapshot`/`included_visits`
  (선택, 생략 시 plan_code 기본값), `next_inspection_at`(선택),
  `memo`(선택).

응답 200: `{ok: true, data: {...care_plans row, effective_status}}` — 생성
직후이므로 `status`는 항상 `ACTIVE`.

응답 400: 위 검증 실패 전부(`site` 없음, `plan_code` 오류, 날짜 형식·실존
오류, 가격/횟수 음수·소수, **겹치는 비취소 기간 존재**).

### GET /care/care-plans

`site_id`/`customer_id` 둘 다 **선택**(5주차 확장, 2026-07-21) — 셋 중
하나로 동작이 갈린다.

| 조건 | 동작 | 캡 |
|---|---|---|
| `site_id`만 있음 | 그 현장의 CarePlan만(`list-site-careplans`) | 없음(무제한, 기존 계약 유지) |
| `customer_id`만 있음 | 그 고객의 모든 현장을 조인한 CarePlan(`list-customer-careplans`) | 없음(무제한, 기존 계약 유지) |
| 둘 다 없음 | 전체 CarePlan(`list-all-careplans`) — Admin CarePlan 모듈 "전체 가입 현황" | **최신 50건**(`starts_at DESC, id DESC` 기준, 2~3주차 ops-summary/ops-weekly/search-customers와 동일한 캡 관례) |

세 경로 모두 `sites`/`customers`를 JOIN해 `customer_id`(현장의 소유
고객)·`customer_name`·`site_name`을 응답 각 행에 채운다(호출부가 필터
종류에 따라 응답 shape을 분기할 필요가 없도록 통일). 정렬은 세 경로 모두
`starts_at DESC, id DESC`.

`site_id`/`customer_id`에 정수가 아니거나 0 이하인 값을 주면(예:
`site_id=abc`, `site_id=-1`) 400 — 값을 아예 생략하는 것과는 다르다(생략은
무필터 전체 목록으로 처리됨).

응답 200: `{ok: true, data: [{...care_plans row, effective_status, customer_id?, customer_name?, site_name?}, ...]}`

응답 400: `{ok: false, error: "site_id must be an integer"}` 등 — `site_id`/
`customer_id`가 정수가 아니거나 0 이하일 때만(생략은 오류가 아님).

### GET /care/care-plans/:id

응답 200: `{ok: true, data: {...care_plans row, effective_status}}`

응답 404: `{ok: false, error: "Care plan not found"}`

### PUT /care/care-plans/:id

요청: `{used_visits, next_inspection_at, memo}` — 셋 다 선택, 생략한 필드는
기존 값을 유지한다(COALESCE). `used_visits`는 절대값(0..included_visits,
증가·감소 모두 허용, 재시도 멱등).

응답 200: `{ok: true, data: {...갱신된 row, effective_status}}`

응답 404: 존재하지 않는 `id`.
응답 400: 대상이 `ACTIVE`가 아니거나(`"Only ACTIVE care plans can be updated"`),
`used_visits`가 범위를 벗어나거나, `next_inspection_at`이 유효하지 않은 날짜.

### PUT /care/care-plans/:id/cancel

요청: `{memo}`(선택 — 취소 사유, 생략 시 기존 memo 유지).

응답 200: `{ok: true, data: {...status:"CANCELLED"인 row, effective_status:"CANCELLED"}}`

응답 404: 존재하지 않는 `id`.
응답 400: 대상이 `ACTIVE`가 아니면(`"Only ACTIVE care plans can be cancelled"`).

### POST /care/care-plans/:id/renew

기존 `ACTIVE` 플랜을 `RENEWED`로 바꾸고 새 `ACTIVE` 행을 하나의 트랜잭션으로
생성한다(`quotes`→`contracts` 전환과 동일한 오케스트레이션 패턴 — 실패 시
`ROLLBACK`). 새 행의 `renewed_from_id`가 원본을 가리킨다.

요청: `{plan_code, starts_at, price_snapshot, included_visits}` — 전부 선택.

- `plan_code` 생략 시 원본과 동일한 코드를 재사용.
- `starts_at` 생략 시 **원본의 `ends_at` 다음날**로 자동 계산된다 — 원본이
  아직 만료 전(조기 갱신)이어도 항상 원본 종료일 기준이라 "오늘" 기준으로
  계산할 때 생길 수 있는 조기 갱신 시 기간 겹침이 발생하지 않는다.
- `price_snapshot`/`included_visits` 생략 시 (재사용/변경된) `plan_code`의
  기본값을 쓴다 — 원본 값을 그대로 물려받지 않는다. 새 행의 `used_visits`는
  항상 0에서 다시 시작한다.

응답 200: `{ok: true, data: {...새로 생성된 ACTIVE row, effective_status:"ACTIVE"}}`

응답 404: 존재하지 않는 `id`.
응답 400: 대상이 `ACTIVE`가 아니거나(`"Only ACTIVE care plans can be renewed"`),
계산된 신규 기간이 다른 비취소 플랜과 겹치는 경우 등.

## Admin UI (MVP)

`GET /care/admin` — 단일 정적 HTML(`src/washcare-admin.html`, 인라인 JS, 프레임워크 없음).

- 메뉴: 홈(운영 대시보드) / 오늘 접수 / 진행중 / 완료 / 고객관리 / 홍보 대상 /
  보증 임박 / 연간관리 / + 고객 등록 / + 접수 생성 / + 부품판매 / + 판매 등록
- **홈(운영 대시보드, 2026-07-21 2주차 추가)**: `GET /care/ops-summary` 기반
  카드 4개(지연 A/S·일정 미정·오늘 방문·보증 임박) + 각 카드 클릭 시 해당
  상세 목록(티켓/장비 테이블)으로 스크롤.
- **통계·보고서(주간 운영 보고, 2026-07-21 3주차 추가)**: `GET /care/ops-weekly`
  기반. 주차 라벨·기간·`as_of` 헤더, 카드 3개(미처리 A/S·다음 주 방문·점검
  대상), 표 3개, LIMIT 50 안내, 빈 상태·오류 처리. 점검 대상 제목은
  **「보증 만료 기반 점검 대상」**. 미수금은 설명 문장만 두고 카드·키·가짜
  값을 두지 않는다. 「담당자 미배정」 라벨 금지. 기존 `escapeHtml` /
  `actionAttrs` / CSP 인라인 핸들러 패턴 유지(`loadOpsWeekly`).
- **연간관리(CarePlan, 2026-07-21 5주차 추가)**: `GET /care/care-plans`
  무필터 최신 50건 전체 목록 + `effective_status` 클라이언트 필터(전체/
  이용중/만료/취소/갱신됨) + 고객/현장/플랜/기간/가격/사용·잔여 방문/상태
  표시. `site_id` + plan_code 3종 + 시작일 + 선택 가격/포함횟수/점검일/
  memo 가입 폼(`POST /care/care-plans`). `ACTIVE` 행은 `used_visits`
  절대값 정정 입력, `confirm()` 확인을 거치는 취소(`PUT .../cancel`)·
  갱신(`POST .../renew`) 버튼을 제공하고, 가입/정정/취소/갱신은 공유
  busy 플래그로 중복 제출을 막는다. 고객 상세에는 `연간관리` 탭(현장
  select 기반 가입 폼 포함)과 상단 요약 칩("플랜명 / 잔여 N회"/"미가입")을 추가했고,
  새 A/S 접수 폼은 `site_id` 변경 시 해당 현장의 ACTIVE 플랜·종료일·잔여
  방문횟수를 `role="status"` 배너로 안내만 한다(요청 토큰으로 빠른 site_id
  변경 시 응답 레이스를 막음). **할인·과금·방문 자동차감·접수 차단은
  어디에도 없다** — 배너는 표시 전용이고 티켓 생성 로직은 CarePlan과
  무관하게 그대로 동작한다.
- 기능: 목록 조회, 상세 조회(방문·상태변경 이력 포함), 상태 변경(허용된 다음 상태만
  버튼으로 노출), 공개 링크 재발급 + 토큰 복사, 신규 접수 생성 + 발급된 토큰 복사,
  부품판매 등록, 홍보 대상 목록에서 긍정/부정/무응답 원클릭 기록(무응답=30일 후 재접촉,
  긍정=90일 후, 부정=재접촉 안 함), 판매 등록(고객·사업장·장비를 한 화면에서 등록하고
  장비관리 링크를 바로 복사), 보증 임박 목록에서 "교체제안 접촉 예약" 원클릭(3일 후),
  고객관리 홈에서 "오늘 다시 연락할 고객 / 최근 상담 고객 / 다음 조치 남은 고객" 3개
  리스트 조회, 고객 부분검색(이름/전화/주소/메모), 신규 고객 10초 등록, 고객 상세 내
  상담 기록 등록/완료 처리, 고객 상세 조회 시 요청 토큰 기반 identity guard로
  느린 응답이 다른 고객 화면을 덮어쓰지 않게 방지(`viewCustomer`)
- API 키는 페이지 상단 입력창에 입력 → `localStorage`에 저장 → 모든 호출에
  `x-api-key` 헤더로 사용. 페이지 자체(HTML/JS)는 인증 없이 열람 가능하다.
  데이터 호출은 `internal-authorized?`(`src/washcare-api.fl`)를 거치는데, 이
  함수는 **서버에 `BIGWASH_INTERNAL_API_KEY`가 설정된 경우에만** 키를 실제로
  검사한다 — 설정돼 있으면 올바른 키 없이는 데이터를 못 본다. 하지만 **현재
  개발 공개 정책대로 서버에 키를 아예 설정하지 않은 상태(fail-open)에서는
  브라우저에 키를 입력하지 않아도 데이터 API가 그대로 200을 반환한다**(위
  "인증" 절 참조) — "키를 모르면 아무 데이터도 못 본다"는 키가 설정된
  배포에만 해당하는 설명이다.
- 디자인은 최소한(design.md 팔레트 재사용)만 적용, 사용성 우선.

## 공개 엔드포인트

### GET /care/status/:token

인증 없음. 모든 응답에 `Cache-Control: no-store` 포함 (실측 확인, 2026-07-16).

| 상황 | 상태코드 | 응답 |
|---|---|---|
| 유효 토큰 | 200 | `{ok: true, data: {status, scheduled_at, site_name, contact_phone}}` |
| 존재하지 않거나 폐기된 토큰 | 404 | `{ok: false, error: "Not found"}` |
| 완료 후 7일 경과 | 404 | 위와 동일 (만료를 폐기와 구분하지 않음 — 의도적, "링크가 존재했다"는 사실 자체를 노출하지 않기 위함) |
| 분당 요청 제한 초과 (토큰 20회 또는 IP 60회) | 429 | `{ok: false, error: "Too many requests"}` |

응답에 `symptom`, `labor_cost` 등 내부 상세·원가 정보는 포함되지 않는다 (실측 확인).

### GET /care/site-status/:token

인증 없음. 티켓 단위가 아니라 **사업장 단위로 지속되는 장비관리 링크** (판매 등록 시
발급). 보안 모델은 `/care/status/:token`과 동일(해시 저장, IP·토큰 rate limit,
`Cache-Control: no-store`, 404로 존재 여부 은닉) — 실측 확인.

응답 200: `{ok: true, data: {site_name, contact_phone, equipment: [{category, model,
installed_at, warranty_ends_at, status}, ...]}}`

계약금액, 고객 개인정보(이메일 등), A/S 이력 상세는 포함하지 않는다 — 사업장에 설치된
장비 현황만 보여준다.

## 에러 응답 계약 (2026-07-21 기준 수립, 실측 재검증)

이 절은 **신규·변경 엔드포인트가 지켜야 할 기준**을 정한다. 기준은 다음과 같다.

1. **응답 형식**: 성공·실패 모두 `{ok: boolean, error?: string, data?: ...}`
   형식을 유지한다. 이 저장소 전체에서 이미 일관되게 쓰이고 있다.
2. **상태 코드 판정 기준**:
   - 요청자가 고칠 수 있는 오류(필수 필드 누락, 허용되지 않은 enum 값,
     잘못된 상태 전이, 존재하지 않는 리소스 id, DB UNIQUE/NOT NULL 제약
     위반 등 — "도메인 검증 실패")는 **4xx**로 내려야 한다. 대표:
     `400`(값 오류), `401`(인증 실패), `404`(리소스 없음).
   - 서버 내부에서만 발생할 수 있는 오류(DB 연결 실패, 코드 결함 등 —
     요청자가 무엇을 바꿔도 재현되는 오류)만 **5xx**로 내려야 한다.
   - 도메인 검증과 서버 오류를 구분하려면 핸들러가 도메인 함수 호출을
     `try/catch`로 감싸고, 캐치한 예외를 `400`(또는 해당하는 4xx)으로
     내려야 한다.
3. **에러 응답 바디에 내부 파일 경로·줄번호·콜스택을 노출하지 않는다.**
   `catch`로 잡은 예외를 그대로 `(str e)`로 직렬화해 내려보내면 안 된다 —
   사람이 읽을 수 있는 메시지만 추출해서 내려야 한다.
4. **적용 범위(이번 1주차)**: 신규 엔드포인트에는 이 기준을 적용하고,
   기존 엔드포인트의 전수 리팩터는 범위 밖으로 남긴다(아래 "알려진 개선
   후보" 참조, 별도 스프린트).

## 알려진 개선 후보 (2026-07-21 실측 재검증 — 이전 버전 대비 상태 변경됨)

`docs/08-code-review-2026-07-19.md`가 다수 핸들러에 `try/catch`를 추가한
뒤(2026-07-19), 이 절의 기존 내용("도메인 에러가 전부 500으로 내려온다")은
**더 이상 정확하지 않다** — 아래는 격리 테스트 DB에 대해 실제로 서버를
띄우고 `curl`로 재확인한 결과다(`docs/09-implementation-schedule.md` 1주차).

- **상태 코드 자체는 대부분 이미 4xx로 고쳐졌다.** `POST /care/equipment`
  serial_number 중복, `PUT /care/tickets/:id/status` 잘못된 전이·존재하지
  않는 티켓 — 세 경우 모두 실측 결과 지금은 **500이 아니라 400**을
  반환한다(이전 버전 문서가 "500 실측"이라 적었던 것은 이제 stale).
- **다만 그 400 응답의 `error` 필드가 여전히 위 계약 3번을 위반한다.**
  `try/catch`가 캐치한 예외를 정리하지 않고 `(str e)`로 그대로 직렬화해
  내려보내기 때문에, `error` 값 자체가 `{"message":...,"stack":"Error: ...
  (at line 66, col 0)","raw":{"__flCallStack":[{"file":"/home/kim/kim/
  bigwash-contract/src/washcare-api.fl", ...}]}}` 형태의 **JSON으로 직렬화된
  전체 예외 객체**다 — 내부 절대경로·줄번호·호출 스택이 클라이언트에
  그대로 노출된다. 이 패턴(`(catch [e] (server_status 400 {:ok false
  :error (str e)}))`)은 `handle-create-customer`, `handle-create-site`,
  `handle-create-equipment`, `handle-create-ticket`,
  `handle-update-ticket-status`, `handle-add-visit`,
  `handle-create-consultation`, `handle-create-contact`,
  `handle-create-task`, `handle-create-followup`, `handle-create-part-sale`,
  `handle-list-customer-timeline`, `handle-create-quote`,
  `handle-update-quote-status`, `handle-convert-quote`,
  `handle-create-outreach`, `handle-outreach-response`,
  `handle-register-sale`, `handle-warranty-expiring`,
  `handle-revoke-link`, `handle-reissue-link`(`src/washcare-api.fl`)까지
  20개 이상 핸들러에 공통으로 쓰여서, **상태 코드는 400으로 고쳐졌지만
  내부 정보 노출 문제는 이전보다 오히려 더 넓게 퍼져 있다**(이전에는 일부
  500 응답에서만 발생했던 것이 지금은 이 패턴을 쓰는 모든 400 응답에서
  발생). 다음 정리 대상은 "상태 코드 재분류"가 아니라 "메시지 새니타이즈"다.
- **일부 핸들러는 여전히 `try` 없이 도메인 함수를 직접 호출한다** — 예:
  `handle-complete-consultation`, `handle-complete-task`,
  `handle-complete-followup`. 다만 실측 결과 이 셋은 대상 id가 없어도
  `UPDATE ... WHERE id=?`가 0행에 영향을 주고 이어지는 `SELECT`가 빈
  결과를 반환할 뿐이라 예외가 발생하지 않는다 — 즉 500이 아니라 **`200
  {"ok":true,"data":null}`로 조용히 "성공"처럼 응답한다**(존재하지 않는
  id를 완료 처리해도 에러가 안 남 — 이것도 4xx로 다뤄야 할 별도 갭이다).
  순수 조회(`GET`) 핸들러 다수도 `try` 없이 쓰이지만 도메인 함수가 조회만
  하므로 같은 이유로 예외를 던지지 않는다 — 이 그룹은 실질적인 500 위험이
  낮다.
- `GET /care/tickets/:id`, `GET /care/customers/:id`처럼 **명시적으로
  `nil?` 체크 후 `server_status 404`를 내리는 핸들러는 이미 계약을
  만족한다** — 깨끗한 `{"ok":false,"error":"Not found"}`만 내려가고 내부
  정보 노출이 없다(실측 확인).
- 이번 1주차 결론: **"4xx vs 5xx 판정" 문제는 대부분 해소됐고, 남은
  핵심 갭은 "4xx 에러 메시지의 내부 정보 노출"과 "일부 완료 처리
  핸들러가 존재하지 않는 id에도 200을 반환하는 것" 두 가지다.** 두 갭의
  전수 수정은 이번 주차 범위 밖이며, 별도 스프린트에서 `(str e)` 직렬화를
  사람이 읽는 메시지 추출로 교체하는 작업으로 처리한다.
