# BigWash Contract & Care — 실행 가이드

## 요구사항

- FreeLang v11: `/root/kim/freelang-v11/bootstrap.js`
- Node.js
- SQLite DB 기본 위치: `/root/apps/bigwash-contract/db/contracts.sqlite`

테스트와 별도 환경에서는 `BIGWASH_DB_PATH`로 DB를 반드시 분리한다.

## Phase 1 배포

운영 DB를 직접 수정하기 전에 API 프로세스를 중지하고, 백업과 무결성 검사를 포함한 스크립트를 실행한다.

```bash
cd /root/apps/bigwash-contract
./scripts/migrate-phase1.sh
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

```bash
BIGWASH_DB_PATH=/tmp/bigwash-contract-test.sqlite \
  node /root/kim/freelang-v11/bootstrap.js run tests/test_contract.fl

BIGWASH_DB_PATH=/tmp/bigwash-migration-test.sqlite \
  node /root/kim/freelang-v11/bootstrap.js run tests/test_phase1_migration.fl

BIGWASH_DB_PATH=/tmp/bigwash-care-test.sqlite \
  node /root/kim/freelang-v11/bootstrap.js run tests/test_washcare.fl
```

이미 같은 이름의 임시 DB가 있으면 삭제하거나 새 경로를 사용한다.

## 계약 API

```bash
node /root/kim/freelang-v11/bootstrap.js run src/api.fl
```

- `GET /contracts`
- `GET /contracts/:id`
- `POST /contracts` — `customer_id`, `amount`, `items`
- `PUT /contracts/:id` — `status`

## Phase 1 Care API

내부 관리 API는 키가 없으면 모든 쓰기 요청을 거부한다.

```bash
BIGWASH_INTERNAL_API_KEY='replace-with-a-secret' \
BIGWASH_CARE_PORT=40101 \
node /root/kim/freelang-v11/bootstrap.js run src/washcare-api.fl
```

내부 요청에는 `x-api-key` 헤더가 필요하다.

- `POST /care/customers`
- `POST /care/sites`
- `POST /care/equipment`
- `POST /care/tickets` — 응답의 `public_token`은 고객에게 전달한 뒤 별도 저장하지 않는다
- `PUT /care/tickets/:id/status`
- `POST /care/tickets/:id/visits`
- `POST /care/tickets/:id/link/revoke`
- `POST /care/tickets/:id/link/reissue`
- `GET /care/status/:token` — 고객 공개 조회

공개 조회는 성공·404·429 모두 `Cache-Control: no-store`를 반환한다. 서버는
`x-real-ip`를 IP 제한과 접근 로그에 사용하므로, 외부에서 이 헤더를 덮어쓰는 신뢰 가능한
리버스 프록시 뒤에서만 배포한다. 접근 로그는 요청 시 자동으로 90일 초과분을 삭제한다.

## 기존 UI 서버

```bash
node /root/kim/freelang-v11/bootstrap.js run src/server.fl
```

기본 주소는 `http://localhost:40100`이다.
