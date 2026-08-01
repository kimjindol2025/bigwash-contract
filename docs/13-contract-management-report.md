# 13. 계약관리(Contracts) 7주차 완료 보고

작성일: 2026-07-22 (Asia/Seoul)
작성 담당: Claude (Codex 팀장 dispatch, `task_f73110efe3b0`) — 문서·검증 정합
전용 작업. 이 문서 자체와 아래 "수정 허용 파일" 목록만 이번 세션에서
변경했다.
갱신: 2026-07-22 (`task_fa1073c5bcf2`) — P1-7(고객 상세 계약탭 전이 버튼)
구현·독립 QA(`/tmp/bigwash-week7-final-qa.md`) 반영, P1 closure 7/7로
갱신. `docs/13`만 수정.
근거: `docs/09-implementation-schedule.md` §8(7주차), `docs/10-week6-readiness.md`
§10, Cursor 읽기 전용 리뷰 4건(§2 provenance), `src/washcare.fl`/
`src/washcare-api.fl`/`src/phase1-db.fl`/`src/contract.fl`/
`src/washcare-admin.html`, `tests/test_contract_management.fl`.

## 1. 범위

### 포함 (7주차 완료분)

- `DESIGN.md`의 계약 5상태(`DRAFT`/`PENDING`/`APPROVED`/`COMPLETED`/
  `CANCELLED`)와 그 전이(`DRAFT→PENDING|CANCELLED`,
  `PENDING→APPROVED|CANCELLED`, `APPROVED→COMPLETED|CANCELLED`,
  `COMPLETED`/`CANCELLED`는 terminal)를 Care API로 완전히 노출.
- `contract_items`(계약당 최소 1개, `description`/`quantity`(양의 정수)/
  `unit_price`(0 이상 정수))와 `contract_history`(모든 상태전이마다
  old/new status 기록).
- Care API 5개 operation: `GET /care/contracts`(status/customer_id/
  site_id/q 전부 선택 필터), `POST /care/contracts`(생성), `GET
  /care/contracts/:id`(상세+items+history), `PUT /care/contracts/:id`
  (DRAFT 전체교체 수정), `PUT /care/contracts/:id/status`(상태전이).
- 기존 `POST /care/quotes/:id/convert`(승인 견적→계약 전환)는 그대로 유지 —
  전환도 동일한 items 원자성(전환 시 quote 기반 단일 item 자동 생성)을
  지킨다.
- `amount`는 항목 합계(`Σ quantity*unit_price`)로 서버가 계산·저장 —
  클라이언트가 보낸 값은 무시된다.
- `contract_date` 생략/공백 시 Asia/Seoul 기준 오늘 날짜 기본값(P1-1 해소,
  아래 §4).
- Admin UI 계약관리 모듈 실화면화: 목록(필터 5+전체, 검색)·상세·항목
  편집·이력·허용 전이 버튼만 노출·취소 confirm·인쇄, 고객 상세 계약 탭
  (배지+상세+전이 버튼 — `CONTRACT_NEXT`/`contractNextStatuses`로 DESIGN
  전이행렬만 노출, `CANCELLED` confirm, `contractBusy` 중복 호출 차단,
  고객 식별자 stale 가드, 전이 성공 시 동일 고객 계약탭 재로딩. 아래 §5
  P1-7 참조).
- 상태전이 정본을 `src/phase1-db.fl`의 `valid-contract-transition?` 하나로
  단일화 — 레거시 `src/contract.fl`의 `valid-transition?`이 이 함수를
  위임 호출(이중 스택 드리프트 방지, 과거 P0-5 해소).

### 명시적 비범위 (이번 완료 기준에 포함되지 않음)

- **PaymentOrder/PaymentEvent, 계약금·중도금·잔금 등 분납 상태, PG(결제
  게이트웨이) 연동** — `docs/09` 0장·`docs/07` §6·§9 원칙대로 여전히 HOLD.
  `contracts.status`는 DESIGN 5값 그대로이며, `docs/05` §17이 나열한
  "계약금 대기/작업 진행/잔금 대기" 등 세분화 라벨은 저장 status가 아니라
  Admin 표시 맵(또는 향후 파생 뷰) 몫으로만 남는다.
- **하드 DELETE** — `/care/contracts/:id`에 DELETE는 등록돼 있지 않다.
  계약 취소는 `PUT .../status`로 `CANCELLED` 전이만 쓴다(과거 P0-2 해소
  유지).
- 계약서 양식 파일, 전자서명 워크플로, 현장 다중 연결, `frontend/
  ContractApp.tsx` 별도 스택 통합 — 전부 후속.

## 2. 팀 역할·작업 provenance

| 단계 | 담당 | 산출물 |
|---|---|---|
| 사전 갭 분석(구현 전, 읽기 전용) | Cursor | `/tmp/bigwash-week7-contract-review.md` — DESIGN/05§17/07§6 삼각 대조, P0 함정 8개·최소 엔드포인트 계약 확정 |
| API·도메인·Admin 구현 | Claude | `src/washcare.fl`(list-contracts/get-contract-detail/create-contract/update-contract/update-contract-status), `src/washcare-api.fl`(handle-list-contracts 등 5개 핸들러+라우트), `src/phase1-db.fl`(valid-contract-transition? 단일화, 스키마 컬럼), `src/contract.fl`(valid-transition? 위임), `src/washcare-admin.html`(계약관리 모듈) |
| 회귀 테스트 작성 | Claude | `tests/test_contract_management.fl` — 생성/서버 합계/계약일 기본값/필터·검색·고객격리/사전검증 롤백/DRAFT 수정/전이 행렬/이력/견적전환 원자성/404 |
| 구현 후 최종 검수(읽기 전용) | Cursor | `/tmp/bigwash-week7-contract-final-review.md` — DoD 6개 대조표, P0 8개 전부 미관측(blocking 없음), P1 7건 식별 |
| 추가 QA 재검증(읽기 전용) | Cursor | `/tmp/bigwash-week7-contract-qa.md` — 격리 DB 재실행 4종(`test_contract_management.fl`, `verify-week6.sh`, `verify-security-http.sh`, 수동 추가 QA 스크립트) 전부 PASS 재확인, P0/P1 신규 없음 |
| 문서·검증 정합(1차) | Claude(Codex 팀장 dispatch, `task_f73110efe3b0`) | `docs/04`·`docs/openapi-washcare.yaml`·`README.md`·`docs/RUN_GUIDE.md`·`docs/05`§32·`docs/07`§6·`docs/09`§8·`docs/10`§10 갱신, `scripts/verify-week6.sh` TEMP_ALLOWED_EXTRAS 제거, 본 보고서 최초 작성 |
| P1-7 구현(고객 상세 계약탭 전이 버튼) | Cursor | `src/washcare-admin.html`의 `renderContractsTab`/`CONTRACT_NEXT`/`contractNextStatuses`/`updateContractStatus`에 고객 상세 탭 전이 버튼 추가 |
| P1-7 독립 QA(읽기 전용) | Cursor | `/tmp/bigwash-week7-final-qa.md` — 전이행렬 정합, `contractBusy` 중복차단, `CANCELLED` confirm, 고객 식별자 stale 가드, 전이 후 동일 고객 탭 재로딩, `actionAttrs`/`escapeHtml`, COMPLETED/CANCELLED·결제/PG/DELETE 비노출, Admin 구문·회귀 14/14·라우트 59개·git diff --check·HTTP 보안·DB 백업복원 전부 PASS, P0/P1 신규 0건 |
| 문서·검증 정합(2차 closure, 본 작업) | Claude(Codex 팀장 dispatch, `task_fa1073c5bcf2`) | `/tmp/bigwash-week7-final-qa.md` 근거로 P1-7 closure 반영, 본 보고서 최소 수정 |

이번 문서·검증 정합 작업은 **`src/**`, `tests/**`, `db/contracts.sqlite`,
`orca.yaml`을 전혀 수정하지 않았다** — 위 표의 구현·테스트 산출물은 이
세션 이전에 이미 완료된 상태를 그대로 대조·문서화한 것이다.

## 3. 구현 증거 (코드 1:1 대조)

`src/washcare-api.fl`의 라우트 등록(926행 부근)과 실제 코드를 대조한 결과:

```
(server_get  "/care/contracts"        "handle-list-contracts")
(server_post "/care/contracts"        "handle-create-contract")
(server_get  "/care/contracts/:id"    "handle-contract-detail")
(server_put  "/care/contracts/:id"    "handle-update-contract")
(server_put  "/care/contracts/:id/status" "handle-update-contract-status")
```

- `handle-list-contracts` → `list-contracts` (`src/washcare.fl`): status/
  customer_id/site_id/q 전부 선택, SQL은 파라미터 바인딩(`?`)만 사용해
  SQL 유사 검색어가 섞여도 0건으로 안전 처리, `LIMIT 50`.
- `handle-create-contract` → `create-contract` → `validate-contract-fields`:
  items 최소 1개, 날짜 실재성·역전 검증, `site_id` 소유권 검증(다른 고객
  현장 차단), `contract_date` 기본값은 `SELECT date('now','+9 hours')`
  (Asia/Seoul). 트랜잭션 실패 시 ROLLBACK — 생성 실패는 `contracts` 행을
  남기지 않는다.
- `handle-update-contract` → `update-contract`: 현재 status가 `DRAFT`가
  아니면 즉시 400, items는 DELETE 후 재삽입(전체교체), amount 재계산.
- `handle-update-contract-status` → `update-contract-status` →
  `valid-contract-transition?`(`src/phase1-db.fl`): 허용 전이만 통과,
  `APPROVED` 전이 시 `signed_at` 자동 기록(요청값 있으면 보존), 매 성공
  전이마다 `contract_history` 1행 INSERT.
- `src/contract.fl`의 `valid-transition?`은 자체 `cond` 없이
  `(valid-contract-transition? from to)`를 그대로 위임 호출 — 레거시
  스택과 전이 규칙이 물리적으로 하나다.

## 4. 검증 증거

### 4.1 회귀 자동화 (`scripts/verify-week6.sh`, 이번 세션에서 실행)

```
--- 1. 회귀 테스트 14종 (직렬 실행, mktemp 격리 DB) ---
  (14개 전부 PASS, test_contract_management.fl 포함)
--- 3. OpenAPI YAML parse + 코드↔spec API 라우트 59개 완전일치 ---
  spec operation count: 59 (기대 59)
  code operation count: 59 (기대 59)
  code에만 있음: []
  spec에만 있음: []
--- 4. git diff --check ---
  (변경 없음 또는 공백 오류 없음)
--- 5. 격리 HTTP 인증·오류 노출 검증 ---  PASS
--- 6. 격리 DB 백업·복원 리허설 ---        PASS

요약: 테스트 14종 14/14 PASS, OpenAPI/라우트 59개 완전일치,
git diff --check 공백 오류 없음, 격리 HTTP·DB 리허설 전부 OK.
전체 통과. (종료 코드 0)
```

`scripts/verify-week6.sh`는 `TEMP_ALLOWED_EXTRAS` 임시 허용 목록을 이번
작업에서 완전히 제거했다 — 이제 code/spec 라우트 집합은 예외 없이
59/59로 완전일치해야 통과한다.

### 4.2 OpenAPI 정합

- `python3 -c "import yaml; yaml.safe_load(open('docs/openapi-washcare.yaml'))"`
  parse 성공(45개 path 아래 59개 operation).
- route set diff(코드 `server_get/post/put` 전수 vs spec paths, `:id`→`{id}`
  변환, 정적 `/`·`/care/admin` 제외): `code에만 있음: []`, `spec에만
  있음: []` — 4.1의 실행 결과와 동일하게 0.
- 신규 스키마 `ContractSummary`/`ContractItem`/`ContractDetail`을
  `components/schemas`에 추가하고 4개 신규 operation·확장된
  `GET /care/contracts` 전부 이 스키마를 참조하도록 반영.

### 4.3 도메인 테스트 (`tests/test_contract_management.fl`, 이번 세션 실행 결과 PASS)

생성 시 서버 합계(`amount=250000`)·항목 2개 저장·고객명/현장명 join,
`contract_date` 생략/공백 시 Asia/Seoul 오늘 기본값, 필터(`status`/
`customer_id`/`site_id`/`q`) 및 SQL 유사 검색어 0건, 다른 고객 현장으로
생성 차단·실재하지 않는 날짜 거부·일정 역전 거부·빈 항목 거부·소수 단가
거부(전부 사전검증 롤백으로 계약 행 미생성), DRAFT 전체교체 수정,
DRAFT→PENDING→APPROVED→COMPLETED 전이(3건 history)와 PENDING→COMPLETED
직행 거부·COMPLETED/CANCELLED terminal 확인, 승인 견적→계약 전환의
원자성(item 1개 자동 생성, 중복 전환 거부), 존재하지 않는 계약 상세
nil→404 매핑까지 전부 검증한다.

### 4.4 Cursor 독립 재검증 (읽기 전용, `/tmp/bigwash-week7-contract-qa.md`)

- `test_contract_management.fl`(mktemp DB) PASS
- `./scripts/verify-week6.sh` PASS(당시 14종/55개+임시허용4개 — 이번
  세션에서 TEMP_ALLOWED_EXTRAS 제거 후 재실행한 §4.1 결과가 최신)
- `BIGWASH_SECURITY_TEST_PORT=40321 ./scripts/verify-security-http.sh` PASS
- 별도 추가 스크립트(`/tmp/test_contract_qa_extra.fl`) 1회 수동 재검증 PASS
- 결론: P0 없음, P1 없음(신규 발견 없음)

## 5. P0/P1 closure

### P0 (구현 전 필수 가드, `/tmp/bigwash-week7-contract-review.md` §4) — 전부 미관측/해소

| ID | 함정 | 상태 |
|---|---|---|
| P0-1 | 05§17 한글 세분화 상태를 CHECK enum에 추가 | ✅ 미관측 — status는 DESIGN 5값만 |
| P0-2 | 하드 DELETE `/care/contracts/:id` | ✅ 미구현 — DELETE 라우트 없음(404) |
| P0-3 | convert가 items 없이 DRAFT만 생성 | ✅ 해소 — convert도 1개 item 자동 생성 |
| P0-4 | amount와 items 합 불일치 방치 | ✅ 해소 — 서버가 항상 합계로 계산·재계산 |
| P0-5 | `contract.fl`과 Care 이중 전이 스택 | ✅ 해소 — `valid-transition?`이 `valid-contract-transition?` 위임 |
| P0-6 | 보안 게이트 회귀(fail-open 복귀 등) | ✅ 미관측 — 신규 라우트도 `internal-authorized?`+`safe-error-response` 동일 적용 |
| P0-7 | 고객 격리 누락(IDOR) | ✅ 해소 — `list-contracts` customer_id 필터 시 다른 고객 계약 0건(테스트로 확인) |
| P0-8 | 미수금/분납 가짜 구현 | ✅ 미구현 — API/UI 어디에도 키 없음 |

### P1 (후속 권고, `/tmp/bigwash-week7-contract-final-review.md` §3) — closure 대조

| ID | 이슈 | 상태 | 근거 |
|---|---|---|---|
| P1-1 | `contract_date` 생략/공백 시 400(기본값 미적용) | ✅ 해소 | `validate-contract-fields`가 `date('now','+9 hours')`로 기본값 계산(`src/washcare.fl`), `test_contract_management.fl` "계약일 기본값" 검증 PASS |
| P1-2 | UI 라벨 "고객 ID (선택)" vs API 필수 | ✅ 해소 | `src/washcare-admin.html`에 "고객 ID (필수)"로 라벨 일치 확인 |
| P1-3 | `safe-error` 응답에 `[error]` 접두 잔존 | ✅ 해소 | `sanitize-error-text`가 소문자 대괄호 접두(`[error]`류)를 정규식으로 일괄 제거 |
| P1-4 | Admin 목록이 클라 필터만 쓰고 서버 status/q 미전달 | ✅ 해소 | `contractListUrl()`이 `status`/`q`를 쿼리 파라미터로 서버에 전달(`src/washcare-admin.html`) |
| P1-5 | `MODULE_PLACEHOLDERS.contracts` dead entry 잔존 | ✅ 해소 | 해당 키 자체가 `MODULE_PLACEHOLDERS` 객체에서 삭제됨(확인 완료) |
| P1-6 | OpenAPI/docs 05·04 미동기화, dirty 트리(`db/contracts.sqlite`) | ✅ 해소(본 작업) | `docs/04`·`openapi-washcare.yaml`·`README`·`RUN_GUIDE`·`05`§32·`07`§6·`09`§8·`10`§10 전부 갱신, `db/contracts.sqlite`는 여전히 커밋 대상 아님(§6) |
| P1-7 | 고객탭에 전이 버튼 없음(배지+상세만) | ✅ 해소 | Cursor가 고객 상세 계약 탭에 전이 버튼을 구현(`src/washcare-admin.html`의 `renderContractsTab`/`CONTRACT_NEXT`/`contractNextStatuses`/`updateContractStatus`) — DESIGN 전이행렬만 노출, `CANCELLED` confirm, `contractBusy` 중복 호출 차단, 고객 식별자 stale 가드, 전이 성공 시 동일 고객 계약탭 재로딩까지 독립 QA(`/tmp/bigwash-week7-final-qa.md`)로 PASS 확인 |

**요약: P0 8/8 해소, P1 7/7 해소.**

## 6. 커밋·푸시·배포·운영 DB 접촉 여부

- 이번 문서·검증 정합 작업에서 `git commit`/`git push`/`git merge`를
  실행하지 않았다 — 현재 저장소는 여전히 사용자 검토 대기 상태(dirty
  working tree)다.
- `db/contracts.sqlite`(운영 DB)를 열거나 쓰지 않았다.
  `scripts/verify-week6.sh`/`tests/test_contract_management.fl`은 모두
  `mktemp` 격리 디렉터리의 별도 DB만 사용했고, 스크립트 자체에 운영 DB
  경로와의 `realpath` 동일성 하드 가드가 있다(§0 원칙, `docs/10` 참조).
- node25 배포(`git pull`/`pm2 restart`)나 SSH 접속을 전혀 수행하지 않았다.
- `orca.yaml`, `.gitignore`는 건드리지 않았다.

## 7. 남은 위험·후속 항목

- **PaymentOrder/PG**는 여전히 HOLD — `docs/09` 0장·`docs/07` §9 조건
  (유료 관리계약 10곳 이상, 갱신 누락 실사례, 통신판매업 신고 등)이
  충족되기 전까지 착수하지 않는다.
- **운영 배포**는 이번 작업 범위에 포함되지 않는다 — `docs/10` §4·§5의
  읽기 전용 점검/승인 필요 명령 분리 원칙을 그대로 따른다.
- `docs/05-customer-management-design.md` §17(한글 세분화 상태 표시)과
  `docs/07-company-system-menu.md` §6 메뉴 트리 자체는 목표 스펙 원문이라
  이번 작업에서 재작성하지 않았다 — 두 문서 모두 §32/§6 실측 대조 절에만
  이번 구현 완료 사실을 추가했다(기존 사용자 작성 내용 보존).
