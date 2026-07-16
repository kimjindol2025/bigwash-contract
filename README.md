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
(API 문서) 참조. E2E 검증 완료(2026-07-16) — `docs/04-washcare-api.md` 참조.

- 고객·사업장·장비대장, A/S 접수·상태추적·방문이력
- 고객용 공개 상태 링크 (토큰 해시 저장, rate limit, 완료 후 7일 유지 후 자동 만료)
- Admin UI (`/care/admin`) — 오늘접수/진행중/완료/고객검색, 접수생성, 상태변경, 상세조회

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
