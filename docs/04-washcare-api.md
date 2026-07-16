# WashCare Phase 1 API 문서

작성일: 2026-07-16
기준 파일: `src/washcare-api.fl`
OpenAPI 스펙: [`openapi-washcare.yaml`](openapi-washcare.yaml) (같은 폴더)

## 인증

- **내부 엔드포인트** (`/care/customers`, `/care/sites`, `/care/equipment`, `/care/tickets`,
  `/care/tickets/:id/*`): 헤더 `x-api-key: <BIGWASH_INTERNAL_API_KEY>` 필요. 환경변수
  `BIGWASH_INTERNAL_API_KEY`가 비어있거나 미설정이면 **모든 내부 엔드포인트가 항상
  401을 반환한다** (fail-closed로 실측 확인됨, 2026-07-16).
- **공개 엔드포인트** (`/care/status/:token`): 인증 없음. 토큰 자체가 접근 권한이다.

## 내부 엔드포인트

| Method | Path | 설명 | 인증 |
|---|---|---|---|
| POST | `/care/customers` | 고객 생성 | O |
| POST | `/care/sites` | 사업장 생성 | O |
| POST | `/care/equipment` | 장비 등록 | O |
| POST | `/care/tickets` | A/S 접수 (공개 토큰 발급) | O |
| PUT | `/care/tickets/:id/status` | 티켓 상태 변경 | O |
| POST | `/care/tickets/:id/visits` | 방문·수리 이력 추가 | O |
| POST | `/care/tickets/:id/link/revoke` | 공개 링크 폐기 | O |
| POST | `/care/tickets/:id/link/reissue` | 공개 링크 재발급 | O |

### POST /care/customers

요청 본문: `{name, phone, email, memo}` (name 필수)

응답 200: `{ok: true, data: {id, name, phone, email, memo, legacy_client_id, migration_status, created_at, updated_at}}`

응답 401: `{ok: false, error: "Unauthorized"}`

### POST /care/sites

요청: `{customer_id, name, address, contact_phone}`

응답 200: `{ok: true, data: {id, customer_id, name, address, contact_phone, status, created_at, updated_at}}`

### POST /care/equipment

요청: `{site_id, contract_id, category, model, serial_number, installed_at, warranty_ends_at}`

`serial_number`는 UNIQUE — 중복 시 500 에러(현재 별도 에러 코드로 구분 안 됨, 개선 후보).

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
그 외 조합은 현재 500으로 응답한다(아래 개선 후보 참조).

- `COMPLETED`로 전이 시: `closed_at` 기록. 공개 링크는 **즉시 폐기되지 않고 7일간
  유지**된다 (`TICKET-COMPLETED-VISIBILITY-DAYS`, 2026-07-16 수정 — 이전에는 완료 즉시
  폐기되어 고객이 완료 상태를 확인할 방법이 없었던 버그를 고침).
- `CANCELLED`로 전이 시: 공개 링크 즉시 폐기.

응답 200: `{ok: true, data: {success: true, old_status, new_status}}`

**실측 확인(2026-07-16): 잘못된 전이·존재하지 않는 티켓 모두 400이 아니라 500으로
응답하며, 에러 메시지에 내부 파일명·줄번호가 그대로 노출된다** (예:
`"[update-ticket-status] [error] Service ticket not found (at line 75, col 0)"`).
Admin UI에서 이 에러를 그대로 사용자에게 보여주면 안 되고, 별도로 파싱해서 표시해야
한다. 서버 쪽에서 도메인 에러를 400으로 구분해 내려주는 것은 개선 후보로 남겨둔다
(아래 "알려진 개선 후보" 참조).

### POST /care/tickets/:id/visits

요청: `{technician, visited_at, diagnosis, action_taken, parts_used, labor_cost, parts_cost, next_inspection_at}`

응답 200: `{ok: true, data: {...visit row}}`

### POST /care/tickets/:id/link/revoke

요청 본문 없음. 응답 200: `{ok: true}`

### POST /care/tickets/:id/link/reissue

`COMPLETED`/`CANCELLED` 티켓은 재발급 불가(에러). 응답 200: `{ok: true, data: {ticket_id, public_token}}`
(이전 토큰은 즉시 무효화됨.)

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

## 알려진 개선 후보 (실측 확인됨, 미수정)

- **도메인 에러가 전부 500으로 내려온다.** `serial_number` 중복(`POST /care/equipment`),
  잘못된 상태 전이·존재하지 않는 티켓(`PUT /care/tickets/:id/status`) 모두 실측 결과
  500이었다. 클라이언트 입력 실수(4xx여야 할 것)와 서버 내부 오류(진짜 5xx)가 구분이
  안 된다.
- **에러 메시지에 내부 파일명·줄번호가 그대로 노출된다.** 운영 환경에서는 정보 노출
  최소화 원칙에 어긋난다 — Admin UI/공개 API 앞단에서 별도 에러 매핑이 필요하다.
- Admin UI에서 호출할 목록 조회 엔드포인트(`GET /care/tickets?status=...`,
  `GET /care/customers?search=...`)가 아직 없음 — MVP 관리자 화면 구현 시 함께 추가 필요
