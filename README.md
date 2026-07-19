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
- Admin UI (`/care/admin`) — 오늘접수/진행중/완료/고객검색/홍보대상/보증임박, 접수생성,
  부품판매, 판매등록, 상태변경, 상세조회

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
│   ├── washcare-api.fl         # WashCare HTTP API (포트 40101)
│   └── washcare-admin.html     # WashCare Admin UI (정적 HTML+JS)
├── tests/                  # 테스트 (test_contract.fl, test_phase1_migration.fl, test_washcare.fl)
├── docs/                   # 문서 (제품기획, 아키텍처, API 문서, OpenAPI 스펙)
└── db/                     # SQLite 데이터베이스
```

### WashCare 실행

```bash
BIGWASH_INTERNAL_API_KEY="<임의의 키>" node /root/kim/freelang-v11/bootstrap.js run src/washcare-api.fl
# 관리자 UI: http://localhost:40101/care/admin (API 키를 페이지 상단에 입력)
```
