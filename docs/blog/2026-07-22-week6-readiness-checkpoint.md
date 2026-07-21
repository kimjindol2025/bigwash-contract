# 2026-07-22 WashCare 6주차 출시 준비도 체크포인트

## 이번 작업

- 운영 DB를 절대 사용하지 않는 `scripts/verify-week6.sh`를 추가했다.
- 최신 `master`의 통화 조회·통화 이벤트 기능까지 포함해 FreeLang 테스트 12종을
  각각 별도 임시 DB에서 직렬 실행하도록 구성했다.
- Admin 인라인 JavaScript 구문, 구현과 OpenAPI의 API 55개 완전일치,
  `git diff --check`를 한 번에 검증하도록 했다.
- node25 읽기 전용 점검, 승인 필요한 배포 명령, 코드·DB 롤백, 샌드박스
  관찰 항목을 `docs/10-week6-readiness.md`에 정리했다.
- 6주 일정과 README·RUN_GUIDE를 최신 테스트·라우트 수에 맞췄다.

## 중요한 결정

- 로컬·격리 회귀는 GO다.
- 실고객 파일럿과 재배포는 fail-open 인증, Admin 접근 경계, 예외 응답 내부
  정보 노출이 해결될 때까지 HOLD다.
- PaymentOrder 설계는 보안 게이트와 실제 미수금 관찰 근거가 마련될 때까지
  HOLD다.
- PG 연기는 유료 고객·갱신 누락·법적 준비 조건이 충족될 때까지 유지한다.
- 운영 `db/contracts.sqlite`는 이번 체크포인트에 포함하지 않는다.

## 검증

- 기준 커밋: `33f2b1f` (`master`, Gogs와 동기)
- `bash -n scripts/verify-week6.sh` 통과
- `./scripts/verify-week6.sh` 실측 약 7.6초
- FreeLang 테스트 12/12 PASS
- Admin 인라인 JavaScript 구문 검사 PASS
- 코드·OpenAPI API 라우트 55/55 일치
- `git diff --check` PASS

## 다음 작업

키 미설정 시 fail-closed 전환, Admin 접근 통제, 외부 오류 응답 새니타이즈,
격리 복사본 기반 백업·복원 리허설 순서로 운영 보안 게이트를 닫는다. 이 조건이
충족되기 전에는 node25 배포·PM2 재시작·운영 DB 마이그레이션을 실행하지 않는다.

예정 체크포인트 커밋: `chore(washcare): 6주차 출시 준비 검증 자동화`
