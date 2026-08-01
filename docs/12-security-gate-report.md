# 6주차 운영 보안 게이트 최종 보고서

작성일: 2026-07-22 (Asia/Seoul)
구현 시작 기준: `master` `966f580`
판정: **코드·격리 검증 GO / node25 배포·실고객 파일럿 HOLD**

## 1. 요청된 5개 작업 결과

| 작업 | 결과 | 근거 |
|---|---|---|
| 내부 API 기본 fail-closed | 완료 | 키 미설정·오류 키 401, 정확한 키 200. 로컬 예외는 `BIGWASH_ALLOW_INSECURE_DEV=1`만 허용 |
| Admin 접근 경계 | 완료 | `/care/admin`과 `/` 모두 별도 `BIGWASH_ADMIN_BASIC_AUTH` 필수, 401 challenge·`no-store` 적용 |
| 외부 오류 새니타이즈 | 완료 | 파일 경로·줄번호·스택·SQLite/SQL 세부정보를 응답에서 제거하고 전체 예외는 서버 로그에만 기록 |
| DB 백업·복원 리허설 | 완료 | 임시 DB에서 백업→고의 변경→복원, 원본 해시 복구·`integrity_check=ok`·FK 위반 0 |
| 회귀·문서 정합·최종 판정 | 완료 | 13/13 테스트, Admin 구문, OpenAPI 55/55, HTTP 보안, DB 복원, `git diff --check` 전부 PASS |

## 2. 팀 운영과 독립 검수

- Claude: 인증·오류 처리 구현과 보안 단위 테스트 작성.
- Cursor: 구현 전 공격 오라클과 구현 후 적대적 HTTP 검수. P0 없음으로 판정했고,
  남은 P1(루트 경계, Admin 개발 우회, DB 오류 문구, 401 캐시)을 Codex가 반영했다.
- 추가 Codex: 운영 DB와 분리된 백업·복원 리허설 작성.
- 팀장 Codex: 계약 확정, 변경 통합, Cursor 지적 보정, 전체 회귀와 최종 게이트 판정.

Cursor 검수 산출물은 `/tmp/bigwash-security-cursor-review.md`와
`/tmp/bigwash-security-post-review.md`에 있으며 저장소 파일은 수정하지 않았다.

## 3. 구현 계약

### API 인증

- `BIGWASH_INTERNAL_API_KEY`가 비어 있으면 내부 `/care` API는 기본 401이다.
- 정확한 `x-api-key`만 허용한다.
- 통화 webhook의 `?key=`도 같은 fail-closed 정책을 사용한다.
- 공개 상태 토큰 API는 기존 토큰·rate-limit 모델을 유지한다.
- `BIGWASH_ALLOW_INSECURE_DEV=1`은 로컬 데이터 API에만 적용하며 Admin을 열지 않는다.

### Admin 인증

- `BIGWASH_ADMIN_BASIC_AUTH`에는 완전한 `Authorization` 헤더 값
  (`Basic base64(user:password)`)을 설정한다.
- `/care/admin`과 `/`는 미설정·불일치 시 401이다.
- 401 응답에는 `WWW-Authenticate`와 `Cache-Control: no-store`가 포함된다.

### 오류 응답

- catch된 전체 예외는 서버 로그에 context와 함께 남긴다.
- 클라이언트에는 정제된 도메인 오류 또는 고정 `Request failed`만 반환한다.
- 내부 절대경로, 호출스택, 위치 정보, SQLite 제약 및 SQL 문장은 반환하지 않는다.

## 4. 검증 결과

`./scripts/verify-week6.sh` 최종 실행 결과:

- FreeLang 테스트: **13/13 PASS**
- Admin inline script 구문: **PASS**
- OpenAPI parse 및 코드↔명세 라우트: **55/55, 차이 0**
- `git diff --check`: **PASS**
- 격리 HTTP 보안 공격 검증: **PASS**
- 격리 DB 백업·복원 리허설: **PASS**

HTTP 검증에는 무키·오류 키·정상 키, Basic 누락·오류·정상, API/Basic 교차
사용, `/` 경계, 공개 토큰 예외, 오류 정보 비노출, 개발 플래그 정확값, 로그의
시크릿 비노출이 포함된다.

DB 리허설에서 변경 전 해시와 복원 후 해시는
`79b43fdd64e616e65ffcf79269cb128e384bede569929a4ebb8b15dba6b52bc4`로
일치했고, 고의 변경 해시는 달랐다. 운영 `db/contracts.sqlite` 직접 쓰기는
realpath 가드로 차단된다.

## 5. 배포 게이트 판정

코드와 격리 환경의 보안 게이트는 **GO**다. 그러나 다음은 이번 작업에서
실행하지 않았으므로 node25 배포와 실고객 파일럿은 계속 **HOLD**다.

1. node25에 `BIGWASH_INTERNAL_API_KEY`와 `BIGWASH_ADMIN_BASIC_AUTH` 설정
2. `BIGWASH_ALLOW_INSECURE_DEV` 부재 확인
3. 승인된 코드 배포와 PM2 재시작
4. 외부 HTTPS에서 무자격 401·정상 자격 200 스모크
5. reverse proxy의 CORS 허용 범위와 query-key 로그 마스킹 확인

PaymentOrder는 파일럿 근거 데이터가 없어 **HOLD**, PG 연기는 기존 사업·법적
조건 미충족으로 **유지**한다.

## 6. 변경 안전 경계

- 운영 DB 마이그레이션·복원, SSH, PM2 조작, 배포는 실행하지 않았다.
- 커밋과 푸시는 이 보고서 작성 범위에서 실행하지 않았다.
- 작업 전부터 변경돼 있던 `db/contracts.sqlite`는 이번 구현·검증의 입력이나
  수정 대상으로 사용하지 않았으며 커밋 대상에서 제외해야 한다.
