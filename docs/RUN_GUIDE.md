# BigWash Contract & Care — 실행 가이드

작성일: 2026-07-16 (경로 표기 갱신: 2026-07-21, `docs/09-implementation-schedule.md` 1주차)

## 요구사항

- FreeLang v11: `/home/kim/kim/freelang-v11/bootstrap.js`
- Node.js
- SQLite DB 기본 위치: `<저장소 루트>/db/contracts.sqlite` — `src/*.fl`의 `load`가
  entry 파일 기준 절대경로만 안전하게 풀리므로(`docs/08-code-review-2026-07-19.md`
  §1), 이 저장소는 실행 시점 `PWD`로 저장소 루트를 계산한다(`src/db.fl`).
  반드시 저장소 루트에서 실행하고, `PWD`가 안 잡히는 환경(pm2 등)에서는
  `BIGWASH_REPO_ROOT`를 명시로 지정한다. (과거 `/root/apps/bigwash-contract`
  고정 경로를 쓰던 버전은 폐기됨 — README.md "WashCare 실행" 절과 동일 원칙.)

테스트와 별도 환경에서는 `BIGWASH_DB_PATH`로 DB를 반드시 분리한다.

## Phase 1 배포

운영 DB를 직접 수정하기 전에 API 프로세스를 중지하고, 백업과 무결성 검사를 포함한 스크립트를 실행한다.

```bash
cd <저장소 루트>
./scripts/migrate-phase1.sh
```

`scripts/migrate-phase1.sh`는 자기 자신의 위치를 기준으로 저장소 루트를
계산한다(더 이상 `/root/apps/bigwash-contract`를 하드코딩하지 않음,
2026-07-21 수정) — 위 명령을 저장소 어디에 배포하든 그대로 실행 가능하다.
`PWD`가 안 잡히는 환경 등에서 저장소 루트를 강제로 지정하려면
`BIGWASH_REPO_ROOT`를 넘긴다. FreeLang bootstrap 경로는 기본적으로 저장소의
형제 디렉터리 `<저장소 루트>/../freelang-v11/bootstrap.js`를 찾고, 그
위치가 아니면 `FREELANG_BOOTSTRAP`으로 직접 지정한다(찾지 못하면 스크립트가
바로 에러 메시지를 내고 종료한다):

```bash
FREELANG_BOOTSTRAP=/home/kim/kim/freelang-v11/bootstrap.js ./scripts/migrate-phase1.sh
```

스크립트는 다음 순서를 보장한다.

1. SQLite WAL을 checkpoint해 커밋된 변경을 본 파일에 반영
2. 원본 SQLite를 `db/backups/`에 시각이 포함된 이름으로 복사
3. `Customer/Site/Equipment/ServiceTicket/ServiceVisit/LinkAccessLog` 생성
4. `contracts.customer_id` 추가
5. distinct `client_id`마다 `레거시 고객-{id}`를 생성하고 `NEEDS_REVIEW` 표시
6. 기존 계약의 `customer_id` 백필
7. 매핑 누락과 `PRAGMA foreign_key_check` 검사

`client_id`는 롤백 기간에만 남는다. 신규 계약 코드는 `customer_id`를 기준으로 쓰며,
레거시 NOT NULL 제약을 만족시키기 위한 shadow 값만 `client_id`에 기록한다. 검증이 끝난 뒤
별도 배포에서 `client_id`를 제거한다.

## 테스트

FreeLang v11 실행기는 병렬 프로세스 간 공유 상태가 충돌할 수 있으므로 아래 테스트를
동시에 실행하지 않는다. 각 테스트는 서로 다른 임시 DB를 사용한다.
전체 회귀는 개별 명령을 수동으로 반복하는 대신 다음 명령을 권장한다.

```bash
./scripts/verify-week6.sh
```

이 스크립트는 17종을 `mktemp` 하위의 서로 다른 DB로 직렬 실행하며 운영
`db/contracts.sqlite`와 경로가 같거나 저장소 내부에 임시 DB가 생기면 즉시
중단한다. Admin/운영 기록실 인라인 스크립트 구문, OpenAPI 75개 라우트 정합, 격리 HTTP
인증 공격표, DB 백업·복원도 함께 검증한다. 운영 배포 체크리스트와 롤백/승인 경계는
`docs/10-week6-readiness.md`를 따른다.

전체 17개 테스트 파일(`tests/test_*.fl`) 목록:

```bash
BIGWASH_DB_PATH=/tmp/bigwash-contract-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_contract.fl

BIGWASH_DB_PATH=/tmp/bigwash-migration-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_phase1_migration.fl

BIGWASH_DB_PATH=/tmp/bigwash-care-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_washcare.fl

BIGWASH_DB_PATH=/tmp/bigwash-part-sales-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_part_sales_outreach.fl

BIGWASH_DB_PATH=/tmp/bigwash-incoming-call-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_incoming_call.fl

BIGWASH_DB_PATH=/tmp/bigwash-call-events-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_call_events.fl
```

아래 11개는 격리된 `BIGWASH_DB_PATH`가 없으면 테스트 자체가 즉시 에러로
거부한다(운영 DB 오염 방지 가드, 코드에 하드코딩됨) — 위 4개처럼 "권장"이
아니라 **필수**다. `test_ops_summary.fl` / `test_ops_weekly.fl`은 운영 집계가
`site_id`/`customer_id`로 스코프되지 않고 테이블 전체를 세므로,
공유 DB에 실행하면 카운트 단정 자체가 무의미해져 격리가 특히 더 중요하다.
`test_careplan.fl`/`test_contract_management.fl`은 각각 CarePlan/계약이
`site_id`·`customer_id`로 스코프되지만 동일한 안전 관례로 같은 가드를 둔다
(`test_contract_management.fl`은 다수 테이블 상태를 바꾸므로 운영 DB 경로와
같으면 즉시 거부). `test_security_gate.fl`은 추가로
`BIGWASH_SKIP_SERVER_START=1`을 요구해 테스트 중 포트를 열지 않는다.

```bash
BIGWASH_DB_PATH=/tmp/bigwash-customer-2nd-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_customer_2nd_phase.fl

BIGWASH_DB_PATH=/tmp/bigwash-site-checklist-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_site_checklist.fl

BIGWASH_DB_PATH=/tmp/bigwash-wash-operations-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_wash_operations.fl

BIGWASH_DB_PATH=/tmp/bigwash-customer-consultation-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_customer_consultation.fl

BIGWASH_DB_PATH=/tmp/bigwash-sales-flow-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_sales_flow.fl

BIGWASH_DB_PATH=/tmp/bigwash-ops-summary-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_ops_summary.fl

BIGWASH_DB_PATH=/tmp/bigwash-ops-weekly-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_ops_weekly.fl

BIGWASH_DB_PATH=/tmp/bigwash-careplan-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_careplan.fl

BIGWASH_DB_PATH=/tmp/bigwash-contract-management-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_contract_management.fl

BIGWASH_DB_PATH=/tmp/bigwash-field-service-qa-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_field_service_qa.fl

BIGWASH_SKIP_SERVER_START=1 \
BIGWASH_DB_PATH=/tmp/bigwash-security-gate-test.sqlite \
  node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_security_gate.fl
```

이미 같은 이름의 임시 DB가 있으면 삭제하거나 새 경로를 사용한다.

## 계약 API (레거시, `src/contract.fl`+`src/api.fl`)

`src/api.fl`/`src/contract.fl`은 WashCare 이전 레거시 계약 도메인이다.
7주차(2026-07-22)부터 실제로 쓰는 계약관리 API는 아래 "Phase 1 Care API"의
`/care/contracts*` 5종(목록 필터·생성·상세·수정·상태전이)이며, 상세는
`docs/04-washcare-api.md`·`docs/13-contract-management-report.md`를 따른다.
레거시 서버는 참고용으로만 남긴다:

```bash
node /home/kim/kim/freelang-v11/bootstrap.js run src/api.fl
```

- `GET /contracts`
- `GET /contracts/:id`
- `POST /contracts` — `customer_id`, `amount`, `items`
- `PUT /contracts/:id` — `status`

## Phase 1 Care API

```bash
BIGWASH_INTERNAL_API_KEY='replace-with-a-secret' \
BIGWASH_ADMIN_BASIC_AUTH='Basic <base64(user:password)>' \
BIGWASH_CARE_PORT=40101 \
node /home/kim/kim/freelang-v11/bootstrap.js run src/washcare-api.fl
```

내부 관리 API는 기본 fail-closed다. `BIGWASH_INTERNAL_API_KEY`가 없거나
요청의 `x-api-key`가 틀리면 401을 반환한다. 로컬 데이터 API만 임시로 열어야
할 때는 `BIGWASH_ALLOW_INSECURE_DEV=1`을 명시할 수 있지만 운영에서는 금지한다.
이 개발 예외도 Admin HTTP Basic 경계는 풀지 않는다.

Admin 브라우저 인증과 데이터 API 키는 서로 독립이다. 정책·차단조건·에러
응답 계약은 `docs/04-washcare-api.md` "인증" 절이 정본이다.

### 운영 기록실 임시 고정 계정 정책

- 현재 소유자용 운영 기록실 계정은 서버 내부 문서
  `/home/kim/kim/private-ops/bigwash/washcare-login.md`를 정본으로 한다.
- kim의 별도 지시 전에는 현재 아이디·비밀번호를 임의 변경하지 않는다.
- 계정 원문은 Gogs 저장소·블로그·일반 로그에 기록하지 않는다.
- 현재 비밀번호는 간단한 소유자 확인용 임시값이다. 외부·고객 배포 직전에
  길고 고유한 비밀번호로 교체하고 정상 계정 200, 이전·오류 계정 401,
  `pm2 save`까지 다시 검증한다.

내부 API는 57개 라우트(정적 Admin UI·루트 리다이렉트·공개 2개 제외,
7주차 2026-07-22 계약관리 API 4개 추가 반영)로 늘어나 이 문서에 개별 나열하지
않는다 — **전체
라우트 목록과 요청/응답 스키마는 `docs/openapi-washcare.yaml`(기계 판독용)과
`docs/04-washcare-api.md`(설명)가 정본**이다. 기동 확인용 스모크 예시만 남긴다:

- `POST /care/tickets` — 응답의 `public_token`은 고객에게 전달한 뒤 별도 저장하지 않는다
- `PUT /care/tickets/:id/status`
- `POST /care/care-plans` — 연간관리 가입(site_id 앵커, plan_code 3종)
- `GET /care/care-plans` — `site_id`/`customer_id` 둘 다 생략하면 고객·현장명을
  조인한 최신 50건 전체 목록(5주차 Admin `연간관리` 모듈 홈 화면용)
- `GET /care/ops-summary?warranty_days=30` — 운영 대시보드 집계(지연·일정미정·
  오늘방문·보증임박), Asia/Seoul 기준
- `GET /care/ops-weekly?as_of=YYYY-MM-DD` — 주간 운영 보고(미처리·다음 주 방문·
  보증 만료 기반 점검 대상). `as_of` 생략 시 Seoul 오늘
- `GET/POST /care/contracts`, `GET/PUT /care/contracts/:id`,
  `PUT /care/contracts/:id/status` — 계약관리(7주차, DESIGN 5상태·items·
  history, DRAFT만 수정 가능, DELETE 없음)
- `GET /care/status/:token` — 고객 공개 조회(인증 없음)

공개 조회(`/care/status/:token`, `/care/site-status/:token`)는 성공·404·429
모두 `Cache-Control: no-store`를 반환한다. 서버는 `x-real-ip`를 IP 제한과
접근 로그에 사용하므로, 외부에서 이 헤더를 덮어쓰는 신뢰 가능한 리버스
프록시 뒤에서만 배포한다. 접근 로그는 요청 시 자동으로 90일 초과분을 삭제한다.

## 기존 UI 서버

```bash
node /home/kim/kim/freelang-v11/bootstrap.js run src/server.fl
```

기본 주소는 `http://localhost:40100`이다.
