# Changelog

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
