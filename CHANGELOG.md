# Changelog

## 2026-07-19 — 고객관리 3차-B (견적 연결 + 계약 전환)

고객 상세에서 아직 비어 있던 견적 흐름을 붙였다. 이번 단계는 읽기 전용이 아니라
신규 도메인 추가다. 견적을 작성하고, 상태를 전이시키고, 승인된 견적을 바로 계약으로
전환할 수 있게 했다. 계약 생성은 레거시 `contract.fl`을 끌어오지 않고 WashCare 쪽
최소 `INSERT INTO contracts` 방식으로 처리해, 3차-A에서 이미 만든 고객별 계약 조회와
자동으로 이어지게 했다.

- 신규 `quotes` 테이블 + `idx_quotes_customer_id` 인덱스 추가
- 신규 도메인 함수: `generate-quote-number`, `valid-quote-transition?`,
  `create-quote`, `list-customer-quotes`, `update-quote-status`,
  `convert-quote-to-contract`
- 견적 상태 8종 도입: `DRAFT`, `SENT`, `REVIEWING`, `REVISION_REQUESTED`,
  `APPROVED`, `ON_HOLD`, `REJECTED`, `CONVERTED`
- 신규 API 4종: `POST /care/quotes`, `GET /care/quotes`,
  `PUT /care/quotes/:id/status`, `POST /care/quotes/:id/convert`
- Admin UI 고객 상세에 `견적` 탭 추가: 견적 목록, `+ 견적 작성`, 다음 상태만 노출하는
  버튼, `APPROVED` 상태에서만 가능한 `계약 전환` 버튼
- 계약 전환 완료 후에는 별도 연결 코드 없이 기존 `list-customer-contracts` 결과에
  새 계약이 자동으로 나타남
- `tests/test_customer_2nd_phase.fl`에 견적 생성, 잘못된 전이 거부,
  `DRAFT → SENT → REVIEWING → APPROVED`, 계약 전환 후 `contracts` 반영 및
  `list-customer-contracts` 노출 확인을 추가
- **검증 한계**: 이번 반영 뒤에는 테스트와 브라우저 E2E를 아직 재실행하지 않았다.

## 2026-07-19 — 고객관리 1차 (고객 등록·검색·상담 기록)

고객관리 전체 설계에서 실제 1차 범위를 세 가지로만 잘라 구현했다: 신규 고객을 빠르게
등록하고, 전화번호 부분 입력으로 기존 고객을 찾고, 상담 내용을 고객 기록에 남기고,
오늘 다시 연락할 고객을 자동으로 보이게 하는 단계다. 장비·출장·견적·판매·미수금·
사후관리 연결은 이번 범위에 넣지 않았다.

- `customers.customer_type`, `customers.address` 컬럼 추가 — 잠재고객 단계에서
  `sites`를 강제하지 않고도 최소 분류/주소를 저장
- 신규 `consultations` 테이블 + 인덱스 2종(`customer_id`, `next_contact_at`)
- `create-customer` 확장: `customer_type` 검증, 기본값 `LEAD`, 주소 저장
- `search-customers` 확장: 이름/전화뿐 아니라 주소·메모까지 부분검색
- 신규 도메인 함수: `get-customer`, `create-consultation`,
  `list-customer-consultations`, `complete-consultation`,
  `list-followups-today`, `list-recent-consultations`,
  `list-pending-next-actions`
- 신규 API 7종: `GET /care/customers/:id`, `POST /care/consultations`,
  `GET /care/consultations`, `PUT /care/consultations/:id/complete`,
  `GET /care/consultations/due-today`, `GET /care/consultations/recent`,
  `GET /care/consultations/pending`
- `POST /care/customers`에 400 에러 매핑 추가 — 새 고객 구분 검증 실패를 500이 아니라
  400으로 응답
- Admin UI 고객관리 화면 추가: 고객관리 홈, 부분검색, `+ 고객 등록`, 고객 상세,
  상담 등록/완료, 오늘 다시 연락할 고객/최근 상담/다음 조치 남은 고객 3개 리스트
- 신규 테스트 `tests/test_customer_consultation.fl` 작성, 기존
  `test_washcare.fl`/`test_part_sales_outreach.fl`의 `create-customer` 호출부를
  새 시그니처에 맞게 수정
- **검증 한계**: 이 워크스페이스에는 `/root/apps/bigwash-contract` 경로가 없어,
  기존 절대경로 `load`/`import`를 전제로 한 전체 회귀 테스트와 실서버 E2E는 아직
  실행하지 못했다. 기능 코드는 반영했지만, 로컬 검증을 위해서는 절대경로 전략을
  별도로 정리해야 한다.

## 2026-07-17 — 판매 관리 흐름 보강 (활동 40%, 마지막 축)

부품판매·홍보에 이어 마지막으로 남았던 "판매" 축을 관리 흐름으로 보강. 지금까지는
계약(Contract) 생성만 있었고 고객/사업장/장비 등록이 각각 별도 API 호출로 흩어져
있었으며, "고객에게 장비관리 링크 전달"(9장)도 구현이 없었다.

- `POST /care/sales` — 견적·계약 → 고객/사업장 생성(기존 고객 재사용 가능) → 장비
  등록(여러 대 한 번에) → 사업장 단위 장비관리 링크 발급 → 첫 홍보 접촉 자동 예약을
  단일 호출로 orchestrate
- `sites.public_token_hash` 추가 — 티켓 링크와 별개로, **사업장 단위로 지속되는**
  장비관리 링크. 같은 보안 모델(해시 저장, rate limit, no-store, 폐기/재발급) 재사용
- `GET /care/site-status/:token` (공개, 인증 없음) — 사업장명·연락처·등록 장비 목록
  (모델·보증만료일) 조회, 계약금액·이메일 등은 노출하지 않음
- `GET /care/warranty-expiring?days=N` — 보증 만료 임박 장비 목록, 재구매·교체판매
  제안 대상 후보. Admin UI "보증 임박" 화면에서 "교체제안 접촉 예약" 원클릭 가능
- Admin UI에 "판매 등록"(신규/기존 고객 선택, 사업장·장비 한 화면 등록, 발급된
  장비관리 링크 복사) / "보증 임박" 메뉴 추가
- 신규 테스트 `tests/test_sales_flow.fl` — 신규/기존 고객 판매등록, 첫 접촉 자동예약,
  장비관리 링크 조회·폐기·재발급, 보증 만료 임박 필터링(기간 경계값 포함) 검증. 3회
  연속 실행 안정성 확인
- 실서버로 전체 흐름(판매등록/링크조회/폐기/재발급/보증목록/401) 실측 확인
- **디버깅 중 발견**: `sites` 테이블에 컬럼을 추가하는 트랜잭션이 이후 단계(인덱스
  생성)에서 실패하며 통째로 롤백된 뒤, 수동 개입 과정에서 스키마가 일시적으로
  불일치 상태(`public_token_hash` 컬럼과 그걸 참조하는 인덱스가 따로 존재)에 빠진 것을
  발견·복구. 최종적으로는 `phase1-create-schema`의 트랜잭션 처리 자체는 올바르게
  동작함(부분 실패 시 전체 롤백) — 개발 중 로컬 DB를 반복 실행하며 생긴 일회성 상태
  불일치였고, 재현되는 코드 버그는 아니었음.

전체 테스트(`test_contract.fl`, `test_phase1_migration.fl`×3, `test_washcare.fl`,
`test_part_sales_outreach.fl`, `test_sales_flow.fl`×3) 통과 확인 후 커밋.

## 2026-07-17 — 부품판매·휴면기 관리(홍보) 추가

실제 사업 구조 확인(매출 장비70%/부품30%, 활동 판매40%/홍보20%/서비스15%/출장25%,
장비당 A/S 주기 ~3년) 후 제품 문서(`docs/01`)를 재정리하고, 지금까지 완전히 빠져있던
두 축을 구현.

- `part_sales` 테이블 + `create-part-sale`/`list-site-part-sales` — A/S와 무관하게도
  등록 가능한 독립 매출 이벤트로 설계 (equipment_id/ticket_id nullable)
- `outreach_touches` 테이블 + `create-outreach-touch`/`record-outreach-response`/
  `list-due-outreach` — 판매 후 휴면기 동안의 접촉을 추적하고, A/S·부품판매·신규판매
  중 어디로 전환됐는지(`converted_to`/`converted_ref_id`) 기록
- API 5종 추가: `POST /care/part-sales`, `GET /care/part-sales`, `POST /care/outreach`,
  `POST /care/outreach/:id/response`, `GET /care/outreach/due`
- Admin UI에 "홍보 대상"(due 목록 + 원클릭 긍정/부정/무응답 기록) / "+ 부품판매" 메뉴 추가
- 신규 테스트 `tests/test_part_sales_outreach.fl` — 부품판매 총액 계산, A/S 무관 판매,
  홍보 due 목록 노출, 무응답 시 재접촉일 갱신, 전환 기록 연결까지 검증. 3회 연속 실행
  안정성 확인
- 실서버로 전체 흐름(부품판매 생성/조회, 홍보 생성/due조회/응답기록, API키 미인증 401)
  실측 확인

전체 테스트(`test_contract.fl`, `test_phase1_migration.fl`×3, `test_washcare.fl`,
`test_part_sales_outreach.fl`) 통과 확인 후 커밋.

## 2026-07-16 — WASHCARE-RUN-006: E2E 검증 및 Admin UI (MVP)

**목표**: WashCare Phase 1을 "테스트 통과" 수준이 아니라 실제 고객 접수부터 완료까지
끝까지 동작하는 수준으로 검증.

### 발견 및 수정

- **[버그] 완료 티켓의 공개 상태 링크가 완료 즉시 폐기되어, 고객이 "완료" 상태를 확인할
  방법이 없었다.** E2E로 접수→진행→완료까지 실제 API 흐름을 끝까지 돌려봐야만 잡히는
  버그(개별 단위 테스트는 통과하고 있었음). `TICKET-COMPLETED-VISIBILITY-DAYS`(7일)를
  추가해 완료 후에도 일정 기간 조회 가능하게 수정. `docs/02-integration-architecture.md`
  스펙 문구도 함께 갱신.
- **[테스트 격리] `test_phase1_migration.fl`, `test_washcare.fl`가 재실행 시 실패하거나
  공유 DB의 이전 데이터에 의존해 결과가 흔들리는 문제 발견 및 수정.** 배열 위치 대신
  고유 식별자(number, legacy_client_id)로 조회하도록 변경, 픽스처 정리 코드 추가,
  `INSERT OR IGNORE`로 재실행 안전성 확보. 3회 연속 실행으로 안정성 확인.

### 추가

- Admin UI (MVP): `GET /care/admin`, 오늘접수/진행중/완료/고객검색 메뉴, 접수생성·상태변경·
  상세조회·토큰복사 기능. 이를 위해 신규 백엔드 엔드포인트 3종 추가:
  `GET /care/tickets`(목록), `GET /care/tickets/:id`(상세), `GET /care/customers`(검색).
- API 문서 `docs/04-washcare-api.md` + OpenAPI 스펙 `docs/openapi-washcare.yaml` 작성.

### 실측 검증 결과 (2026-07-16)

- `test_contract.fl`, `test_phase1_migration.fl`(3회 연속), `test_washcare.fl` 전부 PASS
- E2E: 고객등록 → 사업장·장비등록 → A/S접수(토큰발급) → 공개조회(RECEIVED) →
  상태변경(SCHEDULED→IN_PROGRESS) → 방문이력추가 → 완료처리 → **완료 직후 공개조회
  200/COMPLETED 확인(버그 수정 후)** — 끝까지 성공
- 공개 상태 페이지: 200(정상)/404(없는 토큰)/429(rate limit) 전부 확인, 모든 응답에
  `Cache-Control: no-store` 확인
- `BIGWASH_INTERNAL_API_KEY` 미설정 시 전체 내부 엔드포인트 401 fail-closed 확인

### 알려진 미해결 항목 (docs/04-washcare-api.md 참조)

- 도메인 에러(중복 serial_number, 잘못된 상태전이 등)가 400이 아닌 500으로 응답되고
  내부 에러 메시지가 그대로 노출됨 — 다음 작업 후보.
- `/care/admin` 페이지 셸 자체는 인증 없이 열람 가능 (데이터 호출은 전부 인증 필요).
