# Changelog

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
