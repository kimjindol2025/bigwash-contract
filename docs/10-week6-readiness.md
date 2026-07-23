# 10. 6주차 회귀 자동화·파일럿 준비 (2026-07-21)

작성일: 2026-07-22 (Asia/Seoul)
기준 커밋: `33f2b1f` (`master`, 2026-07-22 00:32:16 +0900)
근거 문서: `docs/09-implementation-schedule.md` §6(6주차 — 회귀·운영 파일럿 및
다음 게이트), `README.md`, `docs/RUN_GUIDE.md`, `docs/04-washcare-api.md`
"인증"·"운영 배포 전 인증 필수 게이트" 절

## 0. 이 문서·`scripts/verify-week6.sh`가 절대 하지 않는 것

이번 작업 지시(`scripts/verify-week6.sh`, `docs/10-week6-readiness.md`만
수정 허용, `db/contracts.sqlite` 수정 금지)에 따라, 이 문서와 동반 스크립트는
**아래 동작을 어디에서도 실행하지 않는다** — 실행 여부를 사람이 별도로
승인해야 하는 항목은 4·5장에 읽기 전용 체크리스트/승인 대기 목록으로만
남긴다.

- 운영 배포(‌`care.dclub.kr`/node25에 새 코드 반영)
- 운영 DB(`db/contracts.sqlite`) 마이그레이션·백업 복원
- `pm2 restart`/`pm2 reload` 등 프로세스 조작
- node25·node73 등으로의 `ssh` 접속
- `git pull`/`git push`(원격 갱신)

아래 3·4장에서 수행한 로컬 dry-run은 **격리 포트(40199)·격리 임시 DB·임시
API 키**만 사용했고, 현재 40101에서 pm2로 상주 중인 실제 `washcare-api`
프로세스나 운영 DB는 건드리지 않았다(1장 하단 "간섭 없음 확인" 참조).

## 1. 회귀 자동화 스크립트 — `scripts/verify-week6.sh`

새로 작성한 스크립트. 4단계를 순서대로 실행하고 각 단계 결과를 요약으로
출력한다.

1. `tests/test_*.fl` **정확히 12종**을 `mktemp` 격리 디렉터리에서 **직렬**
   실행(백그라운드·병렬 없음 — FreeLang v11 실행기가 병렬 프로세스 간 공유
   상태 충돌을 일으킬 수 있다는 `docs/RUN_GUIDE.md` "테스트" 절 원칙을 그대로
   따름). 테스트 목록은 코드에 하드코딩돼 있고, `tests/` 디렉터리의 실제
   `test_*.fl` 목록과 정확히 일치하는지도 매 실행마다 대조한다(드리프트
   가드 — 새 테스트 파일이 추가/삭제됐는데 스크립트가 갱신되지 않으면 즉시
   에러로 중단).
2. `src/washcare-admin.html`의 인라인 `<script>` 블록을 추출해 `new
   Function(...)`으로 구문만 파싱(실행하지 않음) — CSP 인라인 스크립트가
   문법 오류 없이 파싱 가능한지 확인.
3. `docs/openapi-washcare.yaml`을 PyYAML로 parse하고, `src/washcare-api.fl`의
   `server_get`/`server_post`/`server_put` 등록 전수와 대조해 (method, path)
   집합이 **완전히 일치**하는지 확인(정적 `/`·`/care/admin` 제외,
   `:id`→`{id}` 변환). 개수(55) 자체와 양방향 차집합(코드에만 있음/스펙에만
   있음)을 모두 출력한다.
4. `git diff --check`로 스테이지 안 된 변경의 공백 오류(trailing
   whitespace, 파일 끝 공백 등)를 확인한다.

### 저장소·bootstrap 위치 자체 계산

`scripts/migrate-phase1.sh`와 동일한 관례: 스크립트 자신의 경로
(`BASH_SOURCE[0]`) 기준으로 저장소 루트를 계산하고, `BIGWASH_REPO_ROOT`가
설정돼 있으면 그 값을 우선한다. FreeLang bootstrap도 `FREELANG_BOOTSTRAP`
환경변수가 없으면 저장소의 형제 디렉터리(`<ROOT>/../freelang-v11/bootstrap.js`)를
기본값으로 찾고, 없으면 즉시 에러 메시지와 함께 종료한다(추측 실행 없음).

### 운영 DB 하드 가드

테스트마다 `${TMP_DIR}/<테스트명>.sqlite` 경로를 `BIGWASH_DB_PATH`로 명시
전달하고, 다음 두 가지를 코드로 단정한다(가정이 아니라 `realpath` 비교로
실측 검증):

- 이 경로가 운영 DB(`<ROOT>/db/contracts.sqlite`)의 실제 경로와 **절대 같을
  수 없다** — 같으면 그 자리에서 `exit 1`.
- 이 경로가 `mktemp`로 만든 격리 디렉터리 **하위**여야 한다 — 아니면 `exit 1`.
- `mktemp` 결과 자체가 저장소 내부 경로로 잡히면(사실상 불가능하지만) 그
  즉시 중단한다.

### bash -n 및 엣지케이스 실측 검증

```bash
$ bash -n scripts/verify-week6.sh
# 종료코드 0 (구문 오류 없음)
```

아래 두 실패 경로도 실제로 트리거해 에러 메시지·종료코드(1)를 확인했다
(임시로 만든 별도 사본/디렉터리에서 실행 — 이 저장소의 파일은 건드리지
않음):

- `FREELANG_BOOTSTRAP`이 존재하지 않는 경로를 가리킬 때 → 즉시
  `FreeLang bootstrap을 찾을 수 없습니다: ...` 출력 후 `exit 1`
- `tests/` 디렉터리에서 파일 하나를 뺀 사본으로 실행할 때 → "테스트 목록
  드리프트 감지" 메시지와 함께 실제/기대 목록을 나란히 출력 후 `exit 1`
- 운영 DB 경로와 테스트 DB 경로가 같아지는 상황을 별도로 재현해
  `realpath` 비교 로직 자체가 올바르게 참(guard 발동)이 되는 것도 단위
  확인함

## 2. 실제 실행 결과 (실측, 이 저장소에서 직접 실행)

```text
$ ./scripts/verify-week6.sh
=== BigWash 6주차 회귀 자동화·파일럿 준비 검증 ===
저장소 루트     : /home/kim/kim/bigwash-contract
FreeLang bootstrap: /home/kim/kim/bigwash-contract/../freelang-v11/bootstrap.js
운영 DB(미사용) : /home/kim/kim/bigwash-contract/db/contracts.sqlite


--- 1. 회귀 테스트 12종 (직렬 실행, mktemp 격리 DB) ---
  test_contract.fl                 ... PASS
  test_phase1_migration.fl         ... PASS
  test_washcare.fl                 ... PASS
  test_incoming_call.fl            ... PASS
  test_call_events.fl              ... PASS
  test_part_sales_outreach.fl      ... PASS
  test_customer_2nd_phase.fl       ... PASS
  test_customer_consultation.fl    ... PASS
  test_sales_flow.fl               ... PASS
  test_ops_summary.fl              ... PASS
  test_ops_weekly.fl               ... PASS
  test_careplan.fl                 ... PASS

--- 2. Admin UI 인라인 스크립트 구문 검사 (new Function) ---
  admin inline script syntax ok

--- 3. OpenAPI YAML parse + 코드↔spec API 라우트 55개 완전일치 ---
  spec operation count: 55 (기대 55)
  code operation count: 55 (기대 55)
  code에만 있음: []
  spec에만 있음: []

--- 4. git diff --check ---
  (변경 없음 또는 공백 오류 없음)

--- 요약 ---
- 테스트 12종: 12/12 PASS
- Admin inline script 구문: OK
- OpenAPI YAML parse + 라우트 55개 대조: OK (완전일치)
- git diff --check: OK (공백 오류 없음)

전체 통과.
```

실행 시간: 약 8초(`time` 실측, 12개 FreeLang 테스트 프로세스를 직렬로 띄운
비용이 대부분). 종료 코드 `0`.

## 3. `README.md`/`docs/RUN_GUIDE.md` 로컬 기동 dry-run (실측)

문서에 적힌 명령을 **격리된 포트·DB·키**로 그대로 재현했다 — 40101에서 pm2로
상주 중인 실제 서비스와 운영 DB는 전혀 사용하지 않았다.

```bash
BIGWASH_DB_PATH=<임시 sqlite 경로> \
BIGWASH_CARE_PORT=40199 \
BIGWASH_INTERNAL_API_KEY="dryrun-test-key" \
node /home/kim/kim/freelang-v11/bootstrap.js run src/washcare-api.fl
```

결과(전부 실측 `curl`):

| 요청 | 기대 | 실측 |
|---|---|---|
| `GET /care/admin` (키 없음) | 200, 정적 HTML | `status=200` |
| `GET /care/care-plans` (키 없음, 서버에 키가 **설정된** 상태) | 401 — fail-open은 키 미설정일 때만 적용 | `{"ok":false,"error":"Unauthorized"}` / `status=401` |
| `GET /care/care-plans` (`x-api-key: dryrun-test-key`) | 200, 빈 목록(신규 DB) | `{"ok":true,"data":[]}` / `status=200` |
| `POST /care/customers` (`{"name":"드라이런 테스트 고객"}`) | 200, 생성된 고객 row | `{"ok":true,"data":{"id":1,"name":"드라이런 테스트 고객",...}}` / `status=200` |

이 결과는 `docs/04-washcare-api.md` "인증" 절의 설명(“서버에 키가 설정돼
있으면 그 순간부터는 fail-open이 아니라 정상적으로 키를 검사한다”)과 정확히
일치한다 — 개발 공개 정책은 **키를 아예 설정하지 않았을 때만** 적용되는
것이 이번 dry-run으로 다시 실측 확인됐다.

dry-run 종료 후 프로세스를 정리하고(`kill`), 임시 DB 파일을 삭제했다. 포트
40199는 재확인 결과 다시 비어 있고, `git status --porcelain`에도 이 dry-run으로
인한 변경은 없다(원래부터 있던 `db/contracts.sqlite` 변경 외 추가 변경 없음).

## 4. node25 배포 상태 — 읽기 전용 점검 체크리스트 (미실행)

**아래 명령은 이 작업에서 실행하지 않았다.** 0장 원칙대로 `ssh`·`pm2`·
`git pull`을 이 세션에서 직접 실행할 권한/승인이 없으므로, 다음에 배포
담당자가 파일럿 개시 전 직접 실행할 **읽기 전용** 점검 목록만 남긴다. 모두
상태를 "보기"만 하고 아무것도 바꾸지 않는 명령이다.

```bash
# 1) 현재 배포된 코드 버전 확인(원격 저장소와 diff만, pull 안 함)
ssh node25 'cd ~/kim/bigwash-contract && git fetch --dry-run && git log -1 --oneline'
ssh node25 'cd ~/kim/bigwash-contract && git status --short'
ssh node25 'cd ~/kim/bigwash-contract && git log HEAD..origin/master --oneline'  # 반영 대기 커밋 목록

# 2) 프로세스 상태
ssh node25 'pm2 describe washcare-api'
ssh node25 'pm2 logs washcare-api --lines 100 --nostream'

# 3) 서비스 응답 확인(외부에서, 아무것도 쓰지 않는 GET만)
curl -sS -o /dev/null -w '%{http_code}\n' https://care.dclub.kr/care/admin

# 4) 운영 DB 상태(용량·백업 존재 여부만 확인, 열람/수정 없음)
ssh node25 'ls -la ~/kim/bigwash-contract/db/contracts.sqlite'
ssh node25 'ls -la ~/kim/bigwash-contract/db/backups/ | tail -5'

# 5) API 키 설정 여부만 확인(값 자체는 출력하지 않음)
ssh node25 "test -n \"\$(pm2 env washcare-api | grep -c BIGWASH_INTERNAL_API_KEY)\" && echo 'key set' || echo 'key NOT set (fail-open 상태 — 운영 배포 금지 조건)'"
```

이 체크리스트는 **결과가 어떻게 나오든 배포 여부를 자동으로 결정하지
않는다.** `docs/04-washcare-api.md` "운영 배포 전 인증 필수 게이트" 3조건
(① 배포 환경에 키 실제 설정 확인 ② 키 미설정 시 fail-closed 전환 ③ 두 경우
모두 실측 확인)이 전부 충족되기 전까지는, 위 점검 결과가 전부 "정상"이어도
`care.dclub.kr`에 실고객 데이터를 다루는 새 배포를 진행하지 않는다
(`README.md` "배포" 절 동일 원칙).

## 5. 승인 필요 명령 (사람 승인 후에만 실행 — 이 문서는 실행하지 않음)

아래는 상태를 **바꾸는** 명령이라 반드시 사람이 명시적으로 승인한 뒤에만
실행한다. 이 작업 세션에서는 하나도 실행하지 않았다.

| 명령 | 효과 | 선행 조건 |
|---|---|---|
| `ssh node25 'cd ~/kim/bigwash-contract && git pull'` | node25의 코드를 `origin/master`로 갱신 | 4장 점검에서 반영 대기 커밋이 실제로 원하는 변경(CarePlan 5주차 등)인지 확인, 롤백 대상 SHA(현재 `git log -1`) 기록 |
| `ssh node25 'pm2 restart washcare-api'` | 새 코드를 반영해 프로세스 재기동 | 위 `git pull` 완료 직후에만. 재기동 직후 `pm2 describe`로 상태 재확인 |
| 운영 DB 마이그레이션(`scripts/migrate-phase1.sh` 류를 운영 DB 대상으로 실행) | 스키마 변경 적용 | **이번 6주차 변경분(4~5주차 CarePlan, 6주차 스크립트/문서)에는 신규 스키마 변경이 없다** — `care_plans` 테이블은 이미 4주차에 로컬/개발 환경 기준으로 도입됐고 이번 작업은 문서·검증 스크립트만 추가했다. 따라서 **지금 시점엔 이 명령이 필요 없다.** 향후 실제 스키마 변경이 생기면 그때 별도 승인을 받는다 |

## 6. 롤백 절차

### 코드 롤백 (git 기반)

1. `git pull` 실행 **직전에** `ssh node25 'git -C ~/kim/bigwash-contract log -1 --oneline'`로 이전 SHA를 기록해 둔다(승인 절차의 일부로 4장 점검 시 이미 확보됨).
2. 문제가 발견되면 작업 트리가 깨끗한지 확인한 뒤, 승인된 이전 SHA로 임시
   전환한다: `ssh node25 'cd ~/kim/bigwash-contract && git status --short && git switch --detach <이전 SHA>'`.
   변경 파일이 하나라도 있으면 전환하지 말고 중단한다. 복구 완료 후에는 별도
   승인 아래 `git switch master`로 돌아온다.
3. `ssh node25 'pm2 restart washcare-api'`로 이전 코드를 재기동.
4. 4장의 읽기 전용 점검(§1·§3)을 다시 돌려 정상 응답을 재확인.

### DB 롤백

- **이번 6주차 변경분은 DB 스키마·데이터 마이그레이션을 포함하지 않는다** —
  롤백 시 별도 DB 복원이 필요 없다.
- 향후 실제 마이그레이션이 생기면 `scripts/migrate-phase1.sh`가 이미 쓰는
  패턴을 그대로 따른다: 마이그레이션 직전 `db/backups/`에 타임스탬프
  포함 백업 생성(스크립트가 자동 수행) → 문제 발생 시 pm2 프로세스를 멈추고
  백업 파일을 `db/contracts.sqlite` 위치로 복사 → pm2 재기동 → 4장 점검
  재실행.

### 롤백 검증

- `curl https://care.dclub.kr/care/admin` 200 확인
- `pm2 describe washcare-api`로 프로세스 `online`·재시작 카운트 확인
- `pm2 logs washcare-api --lines 50 --nostream`에 새 에러가 없는지 확인

## 7. 파일럿 관찰 항목 초안 (draft — 다음 게이트 논의 입력용)

`docs/01` §13.3와 동일한 원칙(운영 병행 중 누락/중복 입력, 현장 입력 불편
여부)을 CarePlan 5주차 반영분에 맞춰 구체화한 초안. **아직 실측 데이터
없음 — 파일럿 시작 후 채워 넣을 항목 목록만 정리.**

- **CarePlan 가입/취소/갱신 성공·실패율**: `POST/PUT /care/care-plans*`
  400/401/500 비율. 겹치는 기간 거부(`"overlapping non-cancelled care
  plan"`)가 실제 사용자 혼란으로 이어지는지.
- **Admin `연간관리` 모듈 실사용성**: 무필터 최신 50건 목록이 실사용
  규모에서 충분한지(50건 초과 시 오래된 가입을 못 찾는다는 불만이 나오는지
  — 이 경우 `docs/09` "P1-7류" 후속 백로그로).
- **`used_visits` 절대값 정정 오입력**: 스테퍼가 아니라 절대값 입력이라
  실수로 큰 값을 넣는 사고가 있는지(서버가 `0..included_visits` 범위로
  막아주지만 UX 관점에서 재확인).
- **고객 상세 identity guard 효과**: 여러 탭/여러 고객을 빠르게 오갈 때
  다른 고객 데이터가 섞여 보인다는 신고가 있는지(5주차에 추가한 요청 토큰
  가드가 실사용에서도 충분한지).
- **티켓 접수 CarePlan 배너 오해 여부**: "이용 중" 배너를 보고 고객이 할인·
  자동 차감을 기대하는 문의가 들어오는지 — 들어온다면 UI 문구 보강이
  필요하다는 신호.
- **API 키 강제 여부**: 실고객 파일럿은 fail-closed 전환과 무키 401 실측 후에만
  시작한다. 전환 전에는 가짜 고객·격리 DB 샌드박스에서만 아래 관찰표를
  예행한다.
- **서버 에러 응답의 내부 정보 노출**: `docs/04-washcare-api.md` "알려진
  개선 후보"에 이미 기록된, `(str e)`로 그대로 내려가는 예외 직렬화가
  실제 파일럿 트래픽에서 얼마나 자주 사용자에게 노출되는지.
- **`db/contracts.sqlite` 파일 크기·WAL 증가 추이**: 체크포인트 필요
  시점을 파일럿 중 미리 가늠.
- **미수금 문의 발생 빈도**: PaymentOrder 착수 여부 판단에 쓰일 실측 근거
  데이터(문의 건수·금액 규모) — 8장 참조.

## 8. 다음 게이트 — Codex 최종 결정: 운영 파일럿·PaymentOrder **HOLD**

회귀 자동화, Claude의 격리 dry-run, Cursor의 누적 리스크 리뷰, Codex의 운영
보안·데이터 안전 감사를 합쳐 다음과 같이 결정한다.

- **로컬/격리 회귀: GO.** 12종 테스트, Admin 스크립트 구문, OpenAPI 55개
  라우트 정합이 모두 통과했다.
- **실고객 운영 파일럿·재배포: HOLD.** `BIGWASH_INTERNAL_API_KEY`가 없으면
  내부 API를 허용하는 fail-open 코드가 남아 있고, 다수 핸들러의 `(str e)`가
  내부 파일 경로·줄번호·스택을 응답에 노출할 수 있다. `/care/admin` 셸의
  접근 경계도 운영용 reverse proxy/VPN/IP 제한 중 하나로 확정해야 한다.
- **PaymentOrder 설계 착수: HOLD.** 6주차 위험·중단조건에 따라 위 P0/P1을
  먼저 닫고, 가짜 데이터 샌드박스 예행 또는 승인된 파일럿에서 미수금 문의
  빈도·금액 규모를 확보한 뒤 다시 판단한다.
- **PG 연기 지속: GO.** 유료 관리계약 10곳, 갱신 누락 실사례, 법적 준비
  조건이 충족되지 않았다.

- **회귀 상태**: 2장 실측대로 전체 12종 PASS, OpenAPI/코드 라우트 완전
  일치, 공백 오류 없음 — 이번 6주 로드맵 산출물이 문서·코드 정합 측면에서
  다음 단계로 넘어갈 준비는 돼 있다.
- **PG(결제 게이트웨이)**: `docs/01` §10 조건(유료 관리계약 10곳 이상,
  갱신 누락 실사례, 통신판매업 신고 등) 미충족 그대로 — 이번 문서에서
  다시 확인했을 뿐 상태 변경 없음. 계속 연기.
보안 게이트 해소 순서는 (1) 키 미설정 시 fail-closed, (2) Admin 접근 경계,
(3) 외부 응답의 예외 새니타이즈, (4) 격리 복사본 백업·복원 리허설이다. 서버
런타임이 실제 응답에 CSP/X-Frame-Options 등의 헤더를 주입하는 것은 확인된
기존 실측과 일치하므로, 정적 소스에 헤더 코드가 없다는 이유만으로 별도 P0로
판정하지 않는다. 다만 운영 CORS 허용 범위는 배포 리허설 때 다시 확인한다.

### 게이트 진행 상황 (2026-07-23 갱신)

- **(1) fail-closed 전환 — ✅ 완료.** `BIGWASH_INTERNAL_API_KEY` 미설정 시
  서버가 기동 자체를 거부하도록 변경(`process_exit 1`, 요청 단위 401보다
  강함). 실측 확인: 키 없이 기동 → 즉시 종료(exit 1)·포트 안 열림, 키로
  기동 후 무인증 요청 → 401, 올바른 키 → 200, 틀린 키 → 401. 전체 12종
  테스트 + `scripts/verify-week6.sh`(OpenAPI 55개 라우트 완전일치 포함)
  재통과 확인. `docs/04-washcare-api.md` "인증" 절, `openapi-washcare.yaml`
  전체 `security` 선언에서 fail-open 대안(`, {}`) 제거 완료.
- **(2) Admin 접근 경계** — 미착수.
- **(3) 예외 응답 새니타이즈** — 미착수.
- **(4) 격리 복사본 백업·복원 리허설** — 미착수.

(2)~(4)를 마저 닫아야 §8의 "실고객 운영 파일럿 HOLD"가 풀린다.

## 9. `docs/09` §6 DoD 대조

| DoD 항목(`docs/09` §6) | 상태 |
|---|---|
| 전체 테스트(12종) PASS | ✅ 2장 실측(12/12 PASS) |
| 배포 체크리스트와 롤백 절차가 검증되고, 운영 반영 필요 명령이 승인 대기로 분리됨 | ✅ 4·5·6장 — 읽기 전용 점검/승인 필요 명령/롤백 절차 분리 완료(실행은 안 함) |
| 다음 게이트 문서에 미수금 원장 착수 여부와 근거가 명시됨 | ✅ 8장 — PaymentOrder HOLD, PG 연기 GO, 선행 보안 게이트와 재판단 근거 명시 |
