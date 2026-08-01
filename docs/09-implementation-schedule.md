# 09. 구현 6주 로드맵 (2026-07-21 기준)

작성일: 2026-07-21 (Asia/Seoul)
기준 문서: 2026-07-21 Cursor 문서↔코드 갭 리뷰(읽기 전용), `docs/01~08`,
`README.md`, `docs/RUN_GUIDE.md`
작성 담당: Claude 구현 (Codex 팀장 dispatch, `task_a29b26986f2f`)
범위: 이 문서만 신규 작성. 기존 코드·다른 문서·`db/contracts.sqlite`·`.gitignore`·
`orca.yaml`은 이 작업에서 건드리지 않는다.

## 0. 원칙

- **미수금은 이번 6주 로드맵에 포함하지 않는다.** `PaymentOrder`/입금원장 데이터
  모델을 먼저 정의(`docs/01` §10, `docs/05` §20, `docs/07` §9 — `PaymentOrder`/
  `PaymentEvent`, `source_type`+`source_id` 일반화 원장 여부 확정)한 뒤에야 착수
  대상이 된다. 그 전까지 "미수금" 카드·컬럼·집계는 UI에 자리만 만들거나 아예
  비워둔다 — 값을 임의로 채우지 않는다.
- **PG(결제 게이트웨이) 자동결제는 유료 고객·법적 준비 게이트 이후로 연기한다.**
  `docs/01` §10의 조건(유료 관리계약 10곳 이상, 갱신 누락 실사례, 통신판매업 신고 등
  법적 준비) 중 하나도 충족되지 않았으므로 이번 로드맵에 PG 작업을 넣지 않는다.
- **현재는 개발 단계이므로 화면과 API를 모두 공개 상태로 유지한다.** API 키 강제는
  운영 배포 승인 전 보안 게이트로 미룬다. 공개 개발 모드에서는 실고객·운영 데이터를
  사용하지 않고, localhost 또는 접근이 통제된 개발망에서만 실행한다.
- 이 문서는 gap review의 권장 순서 중 문서 정합 → 운영 집계 → CarePlan을 먼저
  수행한다. API 키 가드는 운영 배포 전 보안 게이트로, 결제(PaymentOrder/PG)는 위
  원칙에 따라 로드맵 범위 밖에 둔다.
- 각 주차는 **영업일 5일** 단위다. 기준일 2026-07-21(화)부터 시작하며 토·일은
  제외한다.
- 세 agent가 같은 작업 트리를 사용하므로 각 dispatch는 수정 가능 파일을 명시하고,
  Claude 한 명만 구현 파일을 쓴다. Cursor는 읽기 전용 리뷰, Codex는 지시·최종
  검수를 맡는다. 매 작업 시작/종료 시 `git status --short`로 기존 사용자 변경
  (`db/contracts.sqlite`, `.gitignore`, `orca.yaml` 포함)을 구분하고 보존한다.
- 커밋·푸시·운영 배포는 이 일정의 자동 단계가 아니다. 각 작업의 검수 완료 후 사용자가
  별도로 승인한 경우에만 실행한다.

## 1. 6주 요약

| 주차 | 기간(영업일) | 목표 | 대응 갭 ID |
|---|---|---|---|
| 1주차 | 07-21(화) ~ 07-27(월) | 문서 정합 + 개발 공개정책 + 에러계약 기준 | P1-3, P1-4, P1-5, P0-3 정책화 |
| 2주차 | 07-28(화) ~ 08-03(월) | 지연 A/S·일정 미정·오늘 방문·점검임박 운영집계 — ✅ 완료 | P0-1 (미수금 제외) |
| 3주차 | 08-04(화) ~ 08-10(월) | 주간 운영보고와 Admin 연결 — ✅ 완료 | P0-2 |
| 4~5주차 | 08-11(화) ~ 08-24(월) | CarePlan 데이터/API/UI — 4주차 백엔드 ✅ / 5주차 UI ✅ 완료(2026-07-21) | P1-1 |
| 6주차 | 08-25(화) ~ 08-31(월) | 회귀·운영 파일럿 및 다음 게이트 | 전체 회귀 + 게이트 결정 |
| 7주차(추가) | 2026-07-22 | 계약관리(Contracts) API·Admin 완전 통합 — ✅ 완료 | 05§32/07§6 계약관리 갭 해소 |

각 주차 상세는 아래 2~6장, 7주차는 8장. 모든 주차는 공통 항목(목표/범위/산출물/선행조건/완료기준/
테스트/담당 흐름/위험·중단조건)으로 기술한다.

---

## 2. 1주차 (07-21 화 ~ 07-27 월) — 문서 정합 + 개발 공개정책 + 에러계약 기준

### 목표

gap review P1-3(문서 회귀)·P1-4(OpenAPI 불일치)·P1-5(RUN_GUIDE/README 구식)를
먼저 닫아 이후 주차의 우선순위 판단이 낡은 문서에 왜곡되지 않게 한다. 동시에
당시 P0-3(API 키 fail-open)은 개발 중 의도된 공개 모드로 문서화하고 운영 배포 전
보안 게이트로 등록했다(6주차에 기본 fail-closed로 해소). 반복 등장하는 에러 응답
불일치(P1-6)는 "전수 리팩터"가
아니라 **계약(기준) 확정**으로 좁혀 처리한다.

### 범위

포함:
- `docs/05` §32, `docs/06` §5 재작성 — 타임라인(`list-customer-timeline`,
  `GET /care/timeline`)·전화 하이픈 정규화(`REPLACE(phone,'-','')`)·견적/담당자
  (`quotes`, `customer_contacts`)가 이미 구현됐다는 사실을 반영해 잘못된 ❌ 제거
- `docs/openapi-washcare.yaml`을 `src/washcare-api.fl`의 `server_*` 라우트
  전수와 동기화 (customers/{id}, consultations 5종, quotes+status/convert,
  contracts, timeline, customer-contacts/tasks/followups, sites/equipment GET 등)
- `README.md`, `docs/RUN_GUIDE.md`의 `/root/apps/...` 경로 표기 제거,
  PWD/`BIGWASH_REPO_ROOT` 기준 안내로 교체, 테스트 목록을 실제 7종
  (`tests/test_*.fl`)으로 갱신
- `src/washcare-api.fl`의 현재 공개 동작을 개발 정책으로 명시한다. 이번 주차에는
  `internal-authorized?`를 fail-closed로 바꾸지 않는다. API 키 강제와 공개/내부
  라우트 분리는 운영 배포 전 필수 보안 게이트로 백로그에 등록한다.
- 에러 응답 계약 기준 문서화: `{ok:false, error}` 형식 유지, 도메인 검증 실패는
  4xx, 서버 내부 오류만 5xx, 내부 파일명·줄번호(`at line`, `col`) 노출 금지 원칙을
  `docs/04`에 명문화. **이번 주차는 기준 수립 + 신규/변경 엔드포인트 적용까지만** —
  기존 다수 핸들러(P1-6, `handle-create-equipment` 등)의 전수 재작업은 이번
  범위 밖이며 백로그로 남긴다.

제외(명시적 연기):
- P1-6 전수 4xx 매핑(기존 코드 전체) — 기준만 세우고 실제 리팩터는 이후 별도 스프린트
- P1-7(고객 목록 전용 UX), P1-8(07 메뉴 placeholder 전부) — 이번 로드맵에 없음(후속 논의)

### 산출물

- `docs/05-customer-management-design.md` §32 갱신
- `docs/06-customer-management-page-tree.md` §5 갱신
- `docs/openapi-washcare.yaml` 갱신
- `README.md`, `docs/RUN_GUIDE.md` 갱신
- `docs/04-washcare-api.md` 개발 공개정책·운영 보안 게이트 + 에러 계약 절 갱신

### 선행조건

- 개발 환경이 localhost 또는 접근이 통제된 개발망인지 확인한다. 외부 인터넷에
  노출됐거나 실고객 데이터가 있으면 공개 모드 작업을 중단하고 인증 게이트를 먼저 연다.
- 2026-07-21 gap review의 표 3(P1-3)·표(P1-4)를 그대로
  작업 체크리스트로 사용 — 재조사 불필요.

### 완료기준 (DoD)

- `docs/05` §32, `docs/06` §5의 ✅/❌ 표가 `grep`으로 확인한 라우트·테이블
  존재 여부와 1:1 일치 (gap review P1-3 검증 방법)
- `docs/openapi-washcare.yaml`의 paths 집합이 `src/washcare-api.fl`의 API 라우트와
  일치한다. 정적 Admin HTML과 루트 안내 페이지는 OpenAPI 대상에서 명시적으로 제외한다.
- `README.md`/`docs/RUN_GUIDE.md`에 적힌 명령을 그대로 실행해 로컬 기동 +
  테스트 7종 재현 성공
- API 키 없이 개발 화면과 API가 정상 동작하고, 이 동작이 개발 전용임과 운영 배포
  차단조건이 문서에 명시됨
- 에러 계약 문서 존재 + 최소 1개 엔드포인트(`PUT /care/tickets/:id/status`
  잘못된 전이 등)로 규칙 적용을 실측 확인

### 테스트

- 기존 7종(`test_contract.fl`, `test_phase1_migration.fl`, `test_washcare.fl`,
  `test_part_sales_outreach.fl`, `test_sales_flow.fl`, `test_customer_consultation.fl`,
  `test_customer_2nd_phase.fl`) 전부 회귀 PASS 유지 — 이번 주차는 문서·설정
  변경 위주라 신규 자동 테스트 없음
- 키 없는 개발 공개 모드의 200 응답 스모크를 기록한다. 인증 200/401 테스트는 운영
  보안 게이트 구현 시 추가한다.

### 담당 흐름

- **Codex 지시·검수**: 개발 공개정책과 운영 차단조건 확인, 문서 정합 우선순위 확인, 주차
  종료 시 worker_done 검수
- **Claude 구현**: 문서(`05`/`06`/`openapi`/`README`/`RUN_GUIDE`/`04`) 수정,
  `washcare-api.fl` 가드 코드, 에러 계약 절 작성
- **Cursor 리서치·리뷰**: gap review 대비 최종 diff 제3자 검증(문서-코드
  대조 재확인), openapi 동기화 누락분 교차 검토

### 위험·중단조건

- 공개 개발 모드가 외부 인터넷이나 실고객 데이터와 함께 사용되는 정황이 발견되면
  즉시 작업을 중단하고 인증 가드를 최우선으로 전환한다.
- 문서 재작성 중 gap review에 없던 추가 불일치가 발견되면(예: `docs/05` §33
  8컬럼 계약과 실제 Admin 렌더의 추가 괴리) 범위를 확장하지 않고 즉시 Codex에
  에스컬레이션 후 별도 항목으로 분리한다.

---

## 3. 2주차 (07-28 화 ~ 08-03 월) — 지연 A/S·일정 미정·오늘 방문·점검임박 운영집계 — ✅ 완료(2026-07-21)

### 목표

`docs/01` §6 항목 6(운영 대시보드)의 미구현 부분 중 **미수금을 제외한** "지연
A/S·일정 미정·오늘 방문·점검임박" 집계를 구현한다 (P0-1의 부분 구현 — 미수금은
0장 원칙에 따라 이번 로드맵 범위 밖).

### 확정 규칙 (Codex, 2026-07-21 — Cursor 리서치 `/tmp/bigwash-week2-rules-review.md` 기반)

- **지연(overdue)**: `status IN ('RECEIVED','SCHEDULED')`이고 `scheduled_at`이
  있으며 `datetime(scheduled_at) < datetime('now','+9 hours')`(strict `<`).
  `IN_PROGRESS`는 포함하지 않는다.
- **일정 미정(unscheduled)**: `status IN ('RECEIVED','SCHEDULED')`이고
  `scheduled_at`이 없음. **"미배정(담당자)"이 아니다** — `service_tickets`에
  담당자 컬럼이 없고 `service_visits.technician`은 방문 완료 후에만 존재하는
  사후 이력이라 배정 여부를 나타낼 수 없다. 신규 담당자 컬럼은 이번 주차에
  추가하지 않는다(이월, 아래 참고).
- **오늘 방문(visits_today)**: `status NOT IN ('COMPLETED','CANCELLED')`이고
  `date(scheduled_at)`이 Asia/Seoul 오늘. `service_visits`(완료 이력)는 쓰지
  않는다 — "오늘 나갈 일"이지 "오늘 끝난 일"이 아니다.
- **점검임박(warranty_expiring)**: 기존 `GET /care/warranty-expiring` 로직
  재사용(`list-warranty-expiring`/`count-warranty-expiring`)에
  `equipment.status = 'ACTIVE'` 필터를 추가 — 이 필터는 기존 엔드포인트
  자체에도 적용됐다(RETIRED/REPAIR 장비는 재구매 제안 대상이 아님).
- **미수금**: 키·가짜 데이터 모두 넣지 않음(0장 원칙 그대로).

### 범위 — 전부 구현됨

- `GET /care/ops-summary?warranty_days=30` — 4개 섹션(`overdue`,
  `unscheduled`, `visits_today`, `warranty_expiring`) 각각 `{count, items}`
  (`items`는 최대 50건, `count`는 캡의 영향을 받지 않는 별도 쿼리),
  `as_of`(Asia/Seoul ISO 문자열), `timezone: "Asia/Seoul"` 포함
  (`src/washcare.fl`의 `get-ops-summary`, `src/washcare-api.fl`의
  `handle-ops-summary`)
- `phase1-db.fl`에 `idx_tickets_status_scheduled ON service_tickets(status,
  scheduled_at)` 인덱스 추가
- Admin UI `home` placeholder를 실데이터 대시보드로 교체 — 카드 4개(지연/일정
  미정/오늘 방문/보증임박, `loadOpsSummary`) + 카드 클릭 시 해당 상세 목록으로
  스크롤(`ticketRow`/신규 `opsWarrantyTableHtml` 재사용). 기존 `오늘 접수`
  탭·`보증 임박` 탭·`reports` placeholder는 그대로 유지(라벨 충돌 없음)

제외(유지): 미수금 카드/집계, 원장 기반 잔액 계산, 담당자 배정 신규 컬럼

### 산출물 — 전부 반영됨

- `GET /care/ops-summary` API
- Admin UI 홈 대시보드(카드 4개 + 상세 목록)
- `docs/04-washcare-api.md`, `docs/openapi-washcare.yaml` 동기화(46개 라우트
  전체 일치 재검증), `README.md`/`docs/RUN_GUIDE.md` 테스트 목록 8종으로 갱신

### 선행조건 — 해소됨

- 지연·일정 미정 판정 규칙: 위 "확정 규칙" 절대로 Codex가 확정
- `scheduled_at`/`technician` 재사용 여부: `scheduled_at`만 재사용, 신규 필드
  없음으로 확정(담당자 배정은 아래 "다음 이월 항목" 참고)

### 완료기준 (DoD) — 전부 충족

- 픽스처(지연 2건, 일정 미정 2건, 오늘 방문 1건, 점검임박 ACTIVE 1건)로
  `tests/test_ops_summary.fl` 실행 → 정확한 count/items 반환 확인
- Admin 홈에 카드 4개 실데이터 표시(placeholder 아님), 클릭 시 상세 목록 스크롤
- 신규 테스트 PASS + 기존 7종 전부 PASS(격리 DB, 재실행 idempotent 확인)

### 테스트 — 완료

- `tests/test_ops_summary.fl` — 지연/일정미정/오늘방문/점검임박 각 positive+
  negative, `IN_PROGRESS` 제외, `COMPLETED`/`CANCELLED` 제외, `scheduled_at`이
  현재시각과 정확히 같을 때 비지연(strict `<`), Asia/Seoul 날짜 경계(오늘
  23:59 vs 내일 00:00 vs 어제 23:59), ACTIVE/RETIRED/REPAIR 보증 필터,
  `get-ops-summary` 조립 결과와 개별 count 함수 일치, `warranty_days` SQL
  조작 입력 거부까지 검증. `site_id`/`customer_id`로 스코프되지 않는 전역
  집계라 격리 `BIGWASH_DB_PATH` 필수(코드에 가드 하드코딩, 3주차 이전 3개
  테스트와 동일 패턴)

### 담당 흐름

- **Codex**: 지연·일정미정 규칙 확정, 완료 검수
- **Claude**: API·쿼리·Admin UI·인덱스·테스트 구현, docs 동기화
- **Cursor**: 규칙 리서치(`/tmp/bigwash-week2-rules-review.md`), 구현 후 대조 리뷰

### 위험·중단조건 — 해소됨 / 다음 이월 항목

- "일정 미정" 정의는 이번 주차 안에 확정·구현 완료 — 중단·이월 없었음
- **다음 스프린트 이월**: 진짜 "담당자 미배정"이 필요해지면
  `assigned_technician TEXT NULL` 컬럼을 `service_tickets`에 ALTER ADD하는
  방안이 유력(마이그레이션 위험 낮음) — 이번 로드맵 범위 밖, 별도 결정 필요

---

## 4. 3주차 (08-04 화 ~ 08-10 월) — 주간 운영보고와 Admin 연결

### 목표

`docs/01` §6 항목 8(주간 운영 보고, P0-2)을 구현한다. 발송 채널(카톡/메일)은
후순위로 미루고 화면/JSON 응답만으로 MVP를 완성한다.

### 확정 규칙 (Codex, 2026-07-21 — Cursor 계약 `/tmp/bigwash-week3-cursor-contract.md` 승인)

- **주차**: ISO 8601(월~일), Asia/Seoul. 응답 `week.kind`는 항상 `"next"` —
  `as_of`(Seoul 달력일, 쿼리 `YYYY-MM-DD`, 생략 시 오늘)가 속한 주의 **다음**
  ISO 주. `label`=`YYYY-Www`, `start_date`/`end_date`는 그 주 월·일.
- **미처리 A/S(`unprocessed`)**: `status NOT IN ('COMPLETED','CANCELLED')`
  — **IN_PROGRESS 포함**(열린 티켓 전체). **"담당자 미배정" 명칭·정의 금지.**
- **다음 주 방문(`visits_next_week`)**: `status NOT IN ('COMPLETED','CANCELLED')`
  이고 `date(scheduled_at)` ∈ `[start_date, end_date]`.
  **`service_visits` 완료 이력 미사용.**
- **점검 대상(`inspection_due`)**: ACTIVE 장비의 `warranty_ends_at`이 같은
  다음 ISO 주에 해당하는 **보증 만료 기반 점검 대상**(Admin 표기 동일).
- **미수금**: 응답 키·UI 카드·가짜 값 모두 금지. Admin에는
  「PaymentOrder/입금원장 도입 후 제공하며 현재 보고에 포함하지 않음」
  설명 문장만 둔다.
- 각 섹션 `{count, items}`, `items` 최대 50, `count`는 캡과 무관.

### 범위

포함:
- `GET /care/ops-weekly?as_of=YYYY-MM-DD` — 위 3개 섹션 + `as_of`/`timezone`/`week`
- Admin `reports` → `loadOpsWeekly` 실데이터(placeholder 제거)
- `docs/04` · `openapi-washcare.yaml`(47 routes) · README/RUN_GUIDE 테스트 9종

제외: 카카오/메일 자동 발송, 미수금 실제 집계, `week=current`(MVP 비포함)

### 산출물

- `GET /care/ops-weekly` API (ISO 주차 계산·`as_of` 포함) — ✅
  (Claude 백엔드·결정적 테스트, Cursor Admin·OpenAPI·문서, Codex 통합 검증)
- Admin reports 화면 실데이터 연동 — ✅ (`src/washcare-admin.html` `loadOpsWeekly`)
- API 문서·OpenAPI — ✅

### 선행조건

- 2주차 집계 API(`GET /care/ops-summary`) 완료

### 완료기준 (DoD)

- [x] 응답에 미처리 A/S·다음 주 방문·점검 대상 3개 섹션이 존재하고 스냅샷
  테스트(`tests/test_ops_weekly.fl`)로 값을 검증한다. 미수금 키나 추정값이
  포함되지 않는다.
- [x] Admin `reports`가 더 이상 "준비 중" placeholder를 보여주지 않고 실데이터
  렌더(계약 shape 기준). 점검 대상 제목 = 「보증 만료 기반 점검 대상」
- [x] `docs/04` / OpenAPI에 route·query·response·400·당시 인증 정책 표기, 테스트
  목록 9종 문서화

### 테스트

- 신규 `tests/test_ops_weekly.fl`(주차 경계·`as_of` 고정 픽스처), 기존 8종 유지
  → 문서상 전체 **9종** (`docs/RUN_GUIDE.md`)

### 담당 흐름

- **Codex**: 주간 집계 범위와 미수금 제외를 승인하고 검수
- **Claude**: API 구현, 도메인 테스트
- **Cursor**: Admin UI·OpenAPI·docs 동기화, ISO 주차 엣지 리뷰(계약서)

### 위험·중단조건

- 사용자가 미수금까지 기대할 수 있으므로 화면 설명에 범위를 명시하되, 비어
  있거나 가짜인 집계 카드는 만들지 않는다.

---

## 5. 4~5주차 (08-11 화 ~ 08-24 월) — CarePlan 데이터/API/UI — 4주차 백엔드 ✅ / 5주차 UI ✅ 완료(2026-07-21)

### 목표

`docs/01` §8 `CarePlan`, `docs/05` §19, `docs/07` §8(연간관리)를 구현한다
(P1-1). Admin `careplan` placeholder를 실 데이터로 대체하고 고객 상세에
"연간관리 여부" 요약을 표시한다. **4·5주차 모두 완료** — 아래 DoD 참조.

### 범위 (4주차: 백엔드 — 완료 / 5주차: UI+연동 — 완료)

4주차 — ✅ 완료:
- `care_plans` 테이블 신설(`phase1-db.fl`), `site_id` 앵커. `plan_code`
  3종 확정: `TRIAL_90`(90일·포함방문 0·99,000원) / `BASIC_360`(365일·0·
  360,000원) / `FIELD_790`(365일·2·790,000원, 가입 시 override 가능).
  `starts_at`/`ends_at`(시작일 포함 계산)·`price_snapshot`·
  `included_visits`·`used_visits`·`next_inspection_at`·`status`
  (`ACTIVE`/`CANCELLED`/`RENEWED`, 응답에는 파생 `effective_status` 추가).
  `payment_status` 컬럼 없음(PaymentOrder 도입 전 원칙 그대로).
- CRUD API 6개 확정: `POST/GET /care/care-plans`,
  `GET/PUT /care/care-plans/:id`, `PUT /care/care-plans/:id/cancel`,
  `POST /care/care-plans/:id/renew`. 같은 현장에 겹치는 비취소 기간은
  트랜잭션에서 거부, `update`/`cancel`/`renew`는 `ACTIVE`만 허용, 404/400
  계약 확정.
- 백엔드 테스트(`tests/test_careplan.fl`) 완료.

5주차 — ✅ 완료(2026-07-21):
- 백엔드 선행: `GET /care/care-plans`가 `site_id`/`customer_id` 둘 다
  없어도 더 이상 400이 아니라 고객·현장명을 JOIN한 최신 50건 전체 목록을
  반환하도록 확장(`list-all-careplans`, `src/washcare.fl`/
  `washcare-api.fl`). `site_id`/`customer_id` 필터 목록은 기존처럼
  무제한·격리 유지, 잘못된 정수는 여전히 400.
- Admin UI: `careplan` placeholder 대체 — 무필터 전체 목록 + `effective_status`
  클라이언트 필터 + 가입(site_id+plan_code 3종+시작일+선택 가격/포함횟수/
  점검일/memo)/사용횟수 절대값 정정/`confirm()` 있는 취소·갱신 + 공유 busy
  가드(`loadCarePlans`/`renderCarePlanHome`/`createCarePlan`/
  `updateCarePlanUsedVisits`/`cancelCarePlan`/`renewCarePlan`,
  `src/washcare-admin.html`)
- 고객 상세 페이지에 "연간관리" 탭(현장 select 가입 폼 포함) + 상단 요약
  칩("플랜명 / 잔여 N회"/"미가입") 표시(`docs/05` §8.1 상단 요약 확장). `viewCustomer`
  요청에 요청 토큰 기반 identity guard를 추가해 느린 응답이 다른 고객
  화면을 덮어쓰지 않게 막았다.
- 출장 접수 시 연간관리 가입 여부 확인(참고 표시만, 자동 할인 적용 로직은
  이번 범위 아님 — `docs/05` §19 "자동 확인" 중 표시까지만): 새 A/S 접수
  폼에서 `site_id` 변경 시 해당 현장의 ACTIVE 플랜·종료일·잔여 방문횟수를
  `role="status"` 배너로 안내. 요청 토큰으로 빠른 site_id 변경 시 응답
  레이스를 막았고, 할인·과금·방문 자동차감·접수 차단은 어디에도 넣지 않았다.
- 운영 배포·운영 DB 마이그레이션은 이번 범위에 없다 — 로컬 개발 DB
  (`db/contracts.sqlite`)에만 반영, `scripts/migrate-phase1.sh` 등 운영
  스크립트는 실행하지 않았다.

### 산출물 — 4·5주차분 전부 반영됨

- `phase1-db.fl`에 `care_plans` 테이블 + 인덱스 2개(`site_id`,
  `status`+`ends_at`) — 신규 테이블의 순수 추가라 `CREATE TABLE/INDEX IF
  NOT EXISTS`만으로 충분했고 `scripts/migrate-phase1.sh`(레거시 client_id
  백필용 1회성 스크립트)는 쓰지 않았다. 운영 DB 실행은 하지 않았다.
- `washcare.fl`/`washcare-api.fl` CarePlan 도메인 로직·6개 라우트(5주차에
  `GET /care/care-plans` 무필터 응답 계약만 확장, 라우트 수는 그대로)
- `docs/04-washcare-api.md`/`docs/openapi-washcare.yaml`에 신규 엔드포인트·
  무필터 계약·`CarePlanRow` 목록 전용 optional 필드(`customer_id`/
  `customer_name`/`site_name`) 문서화(이 갱신 포함)
- `washcare-admin.html` careplan 화면 + 고객 상세 요약/탭 + 티켓 배너 확장(5주차)

### 선행조건 — 해소됨

- 상품 유형·포함 방문 횟수·가격을 Codex가 확정: 위 "범위" 절 표(3종 기간/
  방문/가격)와 정확히 일치, `docs/04-washcare-api.md` "CarePlan" 절에 상세

### 완료기준 (DoD)

4주차(완료):
- CarePlan CRUD·취소·갱신 API 동작 + `tests/test_careplan.fl` 통과
  (3종 기본값, 날짜/윤년 검증, 가격·횟수 검증, 고객/현장 격리, 중복기간
  거부, 수정 멱등, 취소, 갱신 트랜잭션과 `effective_status` 검증)
- 기존 9종 테스트 + 신규 1종 총 10종 회귀 전부 PASS

5주차(완료, 2026-07-21):
- Admin `careplan` placeholder 대체 + 고객 상세 "연간관리 여부" 표시 — 완료.
  `MODULE_PLACEHOLDERS.careplan`은 정의는 남아 있지만 nav 배선이
  `loadCarePlans()`로 교체돼 더 이상 호출되지 않는다
- `GET /care/care-plans` 무필터 최신 50건 전체 목록 + 클라이언트
  `effective_status` 필터, 가입/사용횟수 정정/취소·갱신(confirm)/busy 가드,
  고객 상세 연간관리 탭+요약, 티켓 폼 CarePlan 안내 배너(표시 전용, 레이스
  가드 포함) — 전부 실측 확인
- 운영 배포·운영 DB 마이그레이션은 이번 DoD에 포함하지 않는다(범위 밖 —
  위 "산출물"·"위험·중단조건" 참조)

### 테스트 — 완료

- `tests/test_careplan.fl` — plan_code 3종 기본값(기간/방문/가격),
  날짜 형식·실존 검증(윤년 포함), 가격·횟수 음수/범위 검증, 고객·현장
  격리, 겹치는 기간 거부(취소 시 겹침 해제 포함), 수정 멱등(증가·감소
  모두)과 COALESCE 보존, 취소, 갱신 트랜잭션과 `effective_status` 파생
  전부 검증. `site_id`/`customer_id`로 항상 스코프돼 2~3주차 전역집계
  테스트와 달리 격리 DB 하드 가드는 필수는 아니지만 동일 관례로 사용.
  5주차 백엔드 선행분으로 무필터 전체 목록의 JOIN 필드(`customer_id`/
  `customer_name`/`site_name`) 존재, 필터 목록 회귀 없음, 최신순 정렬 +
  최대 50건 캡(51건 픽스처로 정확히 50건만 반환되는지) 검증을 같은 파일에
  추가했다 — **5주차 완료 시점에는 새 테스트 파일을 만들지 않아
  `tests/test_*.fl` 총 10개**였다. 이후 통화 자동화 기능에서 2개가 추가되어
  통화 자동화 기능에서 2개, 보안 게이트에서 1개가 추가되어 6주차 최종
  회귀 기준은 13개다.

### 담당 흐름

- **Codex**: 상품 유형·가격 필드 확정(완료), 계약 보충 확인(겹침 판정
  범위·조기 갱신 계산·used_visits 감소 허용 — 전부 기존 구현과 일치 확인됨)
- **Claude**: 스키마·API 구현, 테스트, 문서화(4주차 완료) / UI 구현·문서
  동기화(5주차 완료)
- **Cursor**: 데이터 모델 설계 리뷰(기존 `quotes`/`contracts` 패턴과의 일관성),
  UX 검토(고객 상세 요약 배치) — 5주차 완료분 대조 필요 시 후속 리뷰

### 위험·중단조건

- 4주차 위험(가격/상품유형 확정 지연)은 해소됨 — 지연 없이 진행 완료
- 운영 DB(`db/contracts.sqlite`) 마이그레이션 원칙은 5주차에도 그대로
  유지: 실 스키마 변경이 필요해지면 백업 후 진행하며, 이 작업 지시
  (`db/contracts.sqlite`, `.gitignore`, `orca.yaml` 미변경 원칙)와 충돌하지
  않게 별도 마이그레이션 절차로만 수행한다. 5주차 UI 작업도 이 원칙을
  그대로 따랐다 — **운영 배포·운영 DB 마이그레이션 실행 없음**, 로컬 개발
  DB에만 반영됐다

---

## 6. 6주차 (08-25 화 ~ 08-31 월) — 회귀·운영 파일럿 및 다음 게이트 — ✅ 준비도 검증 완료·운영 HOLD (2026-07-22)

### 목표

5주간 누적 변경 전체를 회귀 검증하고, 운영 병행(파일럿) 개시 조건을
점검한 뒤 다음 단계(미수금 원장 설계 착수 여부, PG는 계속 연기)를 결정한다.

### 범위

- 기존 7종 + 2~5주차 신규 테스트 전체 재실행
- `README.md`/`docs/RUN_GUIDE.md` 명령으로 로컬 기동 재현(1주차 갱신 내용
  최종 검증)
- node25 배포 절차의 **읽기 전용 점검과 로컬/격리 환경 dry-run**. 실제
  `git pull`·`pm2 restart`·운영 DB 마이그레이션은 별도 사용자 승인 후 실행한다.
- `docs/01` §13.2 게이트는 이미 "인터뷰·유료 파일럿 스킵" 결정이 내려져
  있으므로(§13, 2026-07-16 결정) 재검증 대상이 아니다 — 대신 "운영 병행
  안정성"(누락/중복 입력/현장 입력 불편 여부, §13.3 2주차 기준과 동일한
  관찰 항목)을 이번 6주차에 확인한다.
- 미수금 원장(`PaymentOrder`) 설계 착수 여부와 PG 연기 지속 여부를 다음
  로드맵 게이트로 문서화

### 산출물

- `scripts/verify-week6.sh` — 운영 DB 하드 가드가 있는 13종 직렬 회귀,
  Admin 구문, OpenAPI 55개 라우트, 격리 HTTP 보안 공격표, DB 백업·복원,
  공백 오류 자동 검증
- `docs/10-week6-readiness.md` — 실측 회귀 결과, node25 읽기 전용 체크리스트,
  승인 필요 명령 분리, 롤백, 샌드박스/파일럿 관찰표
- 보안 게이트 코드: 기본 fail-closed, Admin HTTP Basic, 오류 응답 새니타이즈
  완료. 운영 환경변수 설정·node25 반영은 별도 승인 대기다.
- 다음 게이트 결정: **운영 배포 승인 대기 / PaymentOrder HOLD / PG 연기 GO**.

### 선행조건

- 1~5주차 산출물이 각 주차 DoD를 충족한 상태

### 완료기준 (DoD)

- [x] 전체 테스트 13종 PASS
- [x] 배포 체크리스트와 롤백 절차가 문서화되고, 실제 운영 반영이 필요한 명령은
  승인 대기 상태로 명확히 분리됨
- [x] 다음 게이트 문서에 PaymentOrder HOLD와 PG 연기 근거가 명시됨
- [x] fail-open 인증·Admin 접근 경계·예외 응답 노출 코드 해소
- [ ] node25에 두 인증 시크릿 설정·배포 후 운영 스모크 및 실고객 파일럿 승인

### 테스트

- 전체 회귀(모든 `tests/test_*.fl`, `BIGWASH_DB_PATH`로 격리 DB 사용 —
  `RUN_GUIDE.md` 병렬 실행 금지 원칙 준수)

### 담당 흐름

- **Codex**: 다음 게이트(미수금 원장 착수 여부) 최종 판단·승인
- **Claude**: 회귀 실행, 로컬/격리 환경 dry-run, 배포 체크리스트 작성
- **Cursor**: 5주간 누적 리스크 리뷰, 운영 데이터 기반 관찰 항목 정리

### 위험·중단조건

- 이번 6주 동안 새로 발견된 P0/P1 미해결 항목이 남아 있으면, 다음 게이트를
  "미수금 원장 착수"로 넘기지 않고 잔여 항목 정리를 우선한다.
- 2026-07-22 보안 게이트 코드는 해소됐다. 다만 node25 환경 설정·배포·운영
  스모크는 미실행이므로 운영 파일럿은 사용자 승인 전까지 HOLD다. PaymentOrder도
  실제 미수금 관찰 근거가 생길 때까지 HOLD다.

---

## 7. 첫 10영업일 상세 작업 순서 (1~2주차, 07-21 화 ~ 08-03 월)

| 영업일 | 날짜 | 작업 |
|---|---|---|
| Day 1 | 07-21(화) | 이 로드맵 문서 작성/확정, 개발 전체 공개정책과 운영 보안 게이트 기록, gap review 체크리스트를 작업 항목으로 전환 |
| Day 2 | 07-22(수) | `docs/05` §32, `docs/06` §5 재작성 착수 — grep 기반 실측 재대조 |
| Day 3 | 07-23(목) | `docs/05`·`06` 정합 완료 + Cursor 리뷰 요청, `openapi-washcare.yaml` 누락 경로 목록화 |
| Day 4 | 07-24(금) | openapi 동기화 완료, `README.md`/`docs/RUN_GUIDE.md` 경로·엔드포인트·테스트 목록 갱신 |
| Day 5 | 07-27(월) | 개발 공개 모드 스모크, 에러 계약 문서 초안 작성 → 1주차 DoD 점검, Codex 검수 |
| Day 6 | 07-28(화) | 지연·일정미정 규칙 확정(Codex), 집계 쿼리 설계 — ✅ |
| Day 7 | 07-29(수) | `GET /care/ops-summary` 구현(지연·일정미정·오늘방문·점검임박 4개 섹션) — ✅ |
| Day 8 | 07-30(목) | 인덱스 추가, Admin 홈 카드 UI 연결 — ✅ |
| Day 9 | 07-31(금) | `tests/test_ops_summary.fl` 작성, 픽스처 검증 — ✅ |
| Day 10 | 08-03(월) | 2주차 회귀 + 문서화, 1~2주차 통합 DoD 체크리스트 완료 보고 → Codex 검수, 3주차 착수 준비 — ✅ |

### DoD 체크리스트 (10영업일 종료 시점, 08-03 기준) — 2026-07-21 전부 충족

- [x] `docs/05` §32, `docs/06` §5의 ✅/❌ 표가 `grep` 재대조 결과와 100% 일치
- [x] `docs/openapi-washcare.yaml` paths가 정적 페이지를 제외한 API 라우트와 일치
      (46개 전수 재검증, 2주차 `/care/ops-summary` 포함)
- [x] `README.md`/`docs/RUN_GUIDE.md` 명령 그대로 실행 시 로컬 기동 + 테스트
      8종 재현 성공(경로 오류 없음)
- [x] API 키 없이 개발 화면/API가 정상 동작하며, 운영 배포 전 인증 강제가 필수
      게이트로 문서화됨
- [x] 에러 계약 문서 작성 완료 + 최소 1개 엔드포인트에서 실측 반영 확인
- [x] `GET /care/ops-summary`가 지연·일정미정·오늘 방문·점검임박 4개 섹션의
      count와 목록(최대 50건)을 정확히 반환(`tests/test_ops_summary.fl`로 검증)
- [x] Admin 홈에 카드 4개가 placeholder가 아닌 실데이터로 표시됨
- [x] 신규 테스트(`test_ops_summary.fl`) PASS + 기존 7종 전부 PASS 유지(8종 전체 회귀)
- [x] 미수금 카드/집계는 값이 채워지지 않은 상태(PaymentOrder 정의 대기)로
      유지 — 이번 구간에서 임의 구현 금지
- [ ] 1~2주차 전체 변경사항에 대해 Codex worker_done 보고 및 검수 완료

---

## 8. 7주차 (2026-07-22) — 계약관리(Contracts) API·Admin 완전 통합 — ✅ 완료

### 목표

6주차까지 `GET /care/contracts?customer_id=X`(목록 1개)와 견적→계약 전환만
있던 계약관리를 `DESIGN.md`의 5상태(`DRAFT`/`PENDING`/`APPROVED`/`COMPLETED`/
`CANCELLED`)+items+history 전체로 확장해 Care API와 Admin 모듈에 완전히
연결한다(`docs/05` §32, `docs/07` §6이 표시해 둔 갭 해소). P1-8(07 메뉴
placeholder)의 계약관리 항목을 이번 주차에 닫는다.

### 범위 — 전부 구현됨

- API 4개 신설: `POST /care/contracts`, `GET /care/contracts/:id`,
  `PUT /care/contracts/:id`, `PUT /care/contracts/:id/status`. 기존
  `GET /care/contracts`는 `customer_id` 필수에서 `status`/`customer_id`/
  `site_id`/`q` 전부 선택으로 확장.
- `amount`는 항목(`contract_items`) 합계로 서버가 계산·유지(요청 값 무시),
  `contract_date` 생략/공백은 Asia/Seoul 오늘이 기본값.
- 상태전이 정본을 `phase1-db.fl`의 `valid-contract-transition?` 하나로
  단일화하고 레거시 `contract.fl`의 `valid-transition?`이 그 함수를
  위임 호출하도록 정리(이중 스택 드리프트 방지).
- Admin UI 계약관리 모듈: placeholder 제거, 목록/필터/검색/상세/항목/이력/
  허용 전이 버튼/취소 confirm/인쇄, 고객 상세 계약 탭(배지+상세).
- DELETE 엔드포인트·결제/미수금/PG 필드는 어디에도 추가하지 않음(`docs/09`
  0장·`docs/07` §6 원칙 그대로 — 취소는 `CANCELLED` 상태전이로만).
- `docs/openapi-washcare.yaml`에 신규 4개 operation +
  `ContractSummary`/`ContractItem`/`ContractDetail` 스키마 반영, 전체
  operation 55→59개.
- `scripts/verify-week6.sh`의 임시 `TEMP_ALLOWED_EXTRAS` 허용 목록을
  완전히 제거하고 기대값을 실제 code/spec 59/59 완전일치로 갱신.
- 신규 테스트 `tests/test_contract_management.fl` 추가로 회귀 13→14종.

### 산출물

- `src/washcare.fl`/`src/washcare-api.fl`/`src/phase1-db.fl`/`src/contract.fl`
  계약관리 도메인·API·전이 단일화 구현
- `src/washcare-admin.html` 계약관리 모듈 UI
- `tests/test_contract_management.fl`
- `docs/04-washcare-api.md`·`docs/openapi-washcare.yaml`·`README.md`·
  `docs/RUN_GUIDE.md`·`docs/05` §32·`docs/07` §6·`docs/10` 동기화
- `docs/13-contract-management-report.md` — 범위·팀 역할·구현/검증 증거·
  P0/P1 closure 종합 보고
- `scripts/verify-week6.sh` TEMP_ALLOWED_EXTRAS 제거 + 14종/59개 기대값 갱신

### 완료기준 (DoD)

- [x] `tests/test_contract_management.fl` PASS(격리 DB) — 생성/서버 합계/
  DRAFT 수정/전이 행렬/history/견적 전환 원자성/고객 격리/SQL 유사 검색/404
  전부 검증
- [x] `./scripts/verify-week6.sh` 전체 PASS: 테스트 14/14, OpenAPI↔코드
  라우트 59/59 완전일치(임시 허용 목록 없이), git diff --check 공백 오류
  없음, 격리 HTTP 보안 검증·DB 백업/복원 리허설 PASS
- [x] `docs/openapi-washcare.yaml` `python3 -c "import yaml; yaml.safe_load(...)"`
  parse 성공 + route set diff 0
- [x] DELETE `/care/contracts/:id` 라우트 미등록(구현 금지 유지)
- [x] 운영 DB(`db/contracts.sqlite`)·커밋·푸시·배포 미수행

### 테스트

- 신규 `tests/test_contract_management.fl` 1종 + 기존 13종 = **14종 전체 PASS**
  (`scripts/verify-week6.sh` 1단계)

### 담당 흐름

- **Claude**: API·도메인 로직·전이 단일화·Admin UI·테스트·문서 구현
- **Cursor**: 읽기 전용 리뷰 2회(`/tmp/bigwash-week7-contract-review.md` 구현
  전 갭 분석, `/tmp/bigwash-week7-contract-final-review.md` 구현 후 DoD 대조 —
  P0 blocking 없음, P1 7건 중 날짜 기본값(P1-1)은 이번 주차에 반영 완료)
- **Codex**: 팀장 dispatch·최종 문서·검증 정합 지시(본 작업)

### 위험·중단조건

- Cursor 최종 검수(`/tmp/bigwash-week7-contract-final-review.md`)의 P1 중
  라벨 문구(P1-2)·에러 접두 잔존(P1-3)·서버측 필터 미사용(P1-4)·
  `MODULE_PLACEHOLDERS.contracts` dead entry(P1-5)는 이번 문서 동기화 범위
  밖의 후속 정리 항목으로 남는다(코드 변경 없이 문서만 동기화하는 이번
  작업의 범위 제약 — src/**, tests/** 수정 금지).
- 운영 배포·운영 DB 반영은 이번 주차에도 하지 않는다 — HOLD 원칙 유지.

## 9. 로드맵 밖(참고, 이번 6주 범위 아님)

2026-07-21 gap review의 나머지 항목은 이번 로드맵 이후 별도로 재계획한다.

- P1-2 결제/PaymentOrder/PaymentEvent/PG — 0장 원칙에 따라 연기
- P1-6 기존 코드 전수 4xx 에러 매핑 리팩터 — 1주차는 "기준 수립"까지만, 전수
  적용은 별도 스프린트
- P1-7 고객 목록 전용 UX(전용 URL/메뉴, 정렬) — `docs/05` §33 계약 재대조 필요
- P1-8 `docs/07` 14개 메뉴 중 남은 placeholder(상품·판매/견적/계약/메시지/
  일정/사진/통계/설정 등) — CarePlan(4~5주차) 이후 모듈별 순차 진행
- P2-* 전체(PG 자동결제, 생성형 AI, 재고 차감, 문자/카카오 발송, 사진·문서
  attachments, 고객 상태 11종, frontend/ 통합, SoloFlow/People CRM 이전 등)
