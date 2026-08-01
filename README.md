# BigWash Contract System

계약 관리 시스템 - FreeLang v11로 구현

## 기능
- 계약서 생성 및 관리
- 계약 상태 추적
- 견적서 연동
- 계약금 관리

### WashCare (대한이엔지 장비 안심관리, Phase 1)

계약 시스템 위에 장비 자산·A/S 관리를 얹은 별도 도메인. `docs/01-product-payment-marketing-plan.md`
(제품기획), `docs/02-integration-architecture.md`(통합 아키텍처), `docs/04-washcare-api.md`
(API 문서), `docs/05-customer-management-design.md`(고객관리 상세 설계, 상담·견적·
미수금·사후관리 등 향후 확장 범위), `docs/06-customer-management-page-tree.md`
(고객관리 화면 구조·페이지 트리), `docs/07-company-system-menu.md`(회사 전체
관리시스템 최상위 메뉴 — 고객관리는 그중 한 모듈) 참조. E2E 검증 완료(2026-07-16)
— `docs/04-washcare-api.md` 참조. `docs/design-reference-smart-accounting.md`는
회계·수금 모듈(향후) 설계용 외부 디자인 레퍼런스 — 이 저장소의 실제 시각
규칙은 아니며 루트 `design.md`가 정본이다.

- 고객·사업장·장비대장, A/S 접수·상태추적·방문이력
- 고객용 공개 상태 링크 (토큰 해시 저장, rate limit, 완료 후 7일 유지 후 자동 만료)
- **부품판매**(매출 30%, A/S와 독립적으로도 등록 가능) — `part_sales`
- **휴면기 관리·홍보**(활동 20%, 판매 후 ~3년 휴면기 동안 주기적 접촉 → A/S·부품판매·
  교체판매로 전환 추적) — `outreach_touches`
- **판매 관리**(활동 40%) — `POST /care/sales`로 고객/사업장/장비 생성 + 사업장 단위
  장비관리 링크 발급 + 첫 접촉 자동 예약을 한 번에 처리. 보증 만료 임박 장비 목록으로
  재구매·교체판매 제안 대상 파악 (2026-07-17 추가)
- **운영 대시보드**(2주차, 2026-07-21 추가) — `GET /care/ops-summary`로 지연 A/S·
  일정 미정·오늘 방문 예정·보증 임박(ACTIVE 장비만) 4개 지표를 count+목록(최대
  50건)으로 집계. 담당자 배정 컬럼이 없어 "미배정"이 아니라 "일정 미정"으로
  부른다 — 상세는 `docs/04-washcare-api.md`, 시간대는 Asia/Seoul 고정
- **주간 운영 보고**(3주차, 2026-07-21 추가) — `GET /care/ops-weekly`로 미처리
  A/S·다음 ISO 주 방문·보증 만료 기반 점검 대상 집계. Admin `통계·보고서`에
  연동. 미수금은 포함하지 않음(`docs/04`, `docs/09`)
- **세차장 운영 기록실**(2026-08-01 추가) — `/care/operations`에서 사업장별
  일일 운영, 차량 작업, 재작업 원인, 장비 이상·중단시간, 운영 메모를 빠르게
  기록하고 7일 반복 원인을 본다. 차량번호·자유 메모만 키보드로 받고 차량 크기,
  작업 종류, 시간, 상태, 원인, 중단시간은 모바일 터치 칩과 `지금 기록`으로
  입력한다. 차량 상태는 입고/출차 단계별로 외부 10항목과 내부 10항목을
  분리해 저장한다. 후보지는 기존 `site_id`와 점검 이력을 유지한
  채 운영 사업장으로 전환된다. 상세는 `docs/14-wash-operations-mvp.md`
- **계약관리**(7주차, 2026-07-22 완료) — `DESIGN.md`의 계약 5상태
  (`DRAFT`/`PENDING`/`APPROVED`/`COMPLETED`/`CANCELLED`)와 items/history를
  `/care/contracts*` API 5종(목록 필터·생성·상세·수정·상태전이)과 Admin
  모듈로 완전히 연결. amount는 항목 합계로 서버가 계산, contract_date
  생략 시 Asia/Seoul 오늘이 기본값, 수정은 DRAFT 상태만 허용, DELETE·결제·
  미수금·PG 필드는 없음(취소는 `CANCELLED` 상태전이로만). 기존 견적→계약
  전환(`POST /care/quotes/:id/convert`)은 그대로 유지. 상세는
  `docs/13-contract-management-report.md`, API는 `docs/04-washcare-api.md`
  참조
- **연간관리 CarePlan**(4~5주차, 2026-07-21 백엔드+Admin UI 완료) — `site_id`
  단위 가입(`TRIAL_90`/`BASIC_360`/`FIELD_790`, 시작일 포함 기간 계산),
  조회·수정·취소·갱신 API 6종. 같은 현장의 겹치는 비취소 기간은 거부, 저장
  status는 자동 만료되지 않고 응답의 `effective_status`로만 파생.
  `GET /care/care-plans`는 `site_id`/`customer_id` 둘 다 선택 — 하나를
  주면 그 스코프(무제한), 둘 다 생략하면 고객·현장명을 조인한 최신 50건
  전체 목록을 반환한다(잘못된 정수는 400). `payment_status`/PG 연동 없음
  (`docs/04`). **Admin UI**: 연간관리 메뉴에서 무필터 전체 목록+
  `effective_status` 필터+가입/사용횟수 절대값 정정/`confirm()` 있는
  취소·갱신, 고객 상세의 "연간관리" 탭(현장 select 가입 폼)+상단 요약,
  새 A/S 접수 폼의 현장별 CarePlan 이용 현황 안내 배너(표시 전용 — 할인·
  과금·방문 자동차감·접수 차단 없음)까지 전부 연동됨. **운영 배포·운영 DB
  마이그레이션은 이번 범위에 없음**(로컬 개발 DB에만 반영)
- Admin UI (`/care/admin`) — 홈(운영 대시보드), 통계·보고서(주간 보고),
  오늘접수/진행중/완료/고객검색/홍보대상/보증임박/연간관리, 접수생성, 부품판매,
  판매등록, 상태변경, 상세조회

## 기술 스택
- FreeLang v11
- SQLite
- REST API

## 폴더 구조
```
├── src/                    # FreeLang 소스 코드
│   ├── contract.fl         # 계약 관리 로직
│   ├── db.fl                # DB 스키마
│   ├── api.fl                # 계약 API 엔드포인트
│   ├── phase1-db.fl          # WashCare Phase 1 스키마 + 레거시 마이그레이션
│   ├── washcare.fl            # WashCare 도메인 로직
│   ├── operations.fl          # 세차장 점주용 운영 기록·집계 도메인
│   ├── washcare-api.fl         # WashCare HTTP API (포트 40101)
│   ├── washcare-admin.html     # WashCare Admin UI (정적 HTML+JS)
│   └── operations-admin.html   # 모바일 우선 운영 기록실 UI
├── tests/                  # 테스트 17종 (test_contract.fl, test_phase1_migration.fl,
│                           #   test_washcare.fl, test_part_sales_outreach.fl,
│                           #   test_sales_flow.fl, test_customer_consultation.fl,
│                           #   test_customer_2nd_phase.fl, test_site_checklist.fl,
│                           #   test_ops_summary.fl,
│                           #   test_ops_weekly.fl, test_careplan.fl,
│                           #   test_incoming_call.fl, test_call_events.fl,
│                           #   test_contract_management.fl, test_field_service_qa.fl,
│                           #   test_security_gate.fl, test_wash_operations.fl —
│                           #   실행 방법은 docs/RUN_GUIDE.md)
├── docs/                   # 문서 (제품기획, 아키텍처, API 문서, OpenAPI 스펙)
├── scripts/verify-week6.sh # 운영 DB를 배제한 전체 회귀·문서 정합 검증
└── db/                     # SQLite 데이터베이스
```

전체 회귀는 저장소 루트에서 `./scripts/verify-week6.sh`로 실행한다. 17개 테스트를
각각 별도 임시 DB에서 직렬 실행하고 Admin/운영 기록실 구문·OpenAPI 73개 라우트·공백 오류를
함께 확인한다. 격리 HTTP 보안 검증과 DB 백업·복원 리허설도 포함한다. 운영
준비 판정과 승인 경계는 `docs/10-week6-readiness.md`가 정본이다.

### WashCare 실행

```bash
BIGWASH_INTERNAL_API_KEY="<API 키>" \
BIGWASH_ADMIN_BASIC_AUTH="Basic <base64(user:password)>" \
node /home/kim/kim/freelang-v11/bootstrap.js run src/washcare-api.fl
# 관리자 UI: http://localhost:40101/care/admin
# 세차장 운영 기록실: http://localhost:40101/care/operations
# 브라우저 Basic 인증 후 페이지 상단에 별도 API 키 입력
```

로컬 실행 시 저장소 절대경로가 노드마다 다르므로(`load`는 entry 파일 기준
절대경로만 안전), `src/*.fl`의 `load`는 실행 시점 `PWD`로 저장소 루트를
계산한다 — 반드시 저장소 루트에서 실행할 것. `PWD`가 안 잡히는 환경(pm2 등)
에서는 `BIGWASH_REPO_ROOT`를 명시로 지정한다.

### 배포 (2026-07-20~, node 25) — 과거 배포 기록, 승인 후 갱신

> 2026-07-22 코드부터 내부 API는 기본 fail-closed이고 Admin은 별도 HTTP
> Basic을 요구한다. 다만 Gogs 코드 변경은 node25의 실행 중 프로세스에 자동
> 반영되지 않는다. `BIGWASH_INTERNAL_API_KEY`·`BIGWASH_ADMIN_BASIC_AUTH` 설정,
> `BIGWASH_ALLOW_INSECURE_DEV` 미설정, 격리 보안 검증 통과를 확인하고 사용자
> 승인을 받은 뒤에만 아래 갱신 명령을 실행한다.

- **운영 주소**: `https://care.dclub.kr` (node 25 `192.168.45.25:40101` →
  node73 nginx 리버스 프록시, DNS Manager v2로 배포)
- **프로세스**: node25에서 pm2 `washcare-api`로 상주(`pm2 save` 완료,
  재부팅 생존). 설정은 저장소 밖 `~/pm2-configs/washcare-api.config.js`
  (API 키 등 시크릿 포함이라 git에는 안 올림)
- 배포 갱신: node25 `~/kim/bigwash-contract`에서 `git pull` 후
  `pm2 restart washcare-api`
