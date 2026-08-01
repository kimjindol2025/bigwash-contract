# [세차장 운영 기록실 3/3] 운영 배포와 Gogs 증거까지 남기다

- 날짜: 2026-08-02 KST
- 기능 커밋: `20c65a6 feat(washcare): add site equipment registry`
- 배포 기록 커밋: `a98c8c0 docs(blog): record equipment registry deployment`
- 후속 모달 교정: `00f103a fix(washcare): separate equipment issue modal`
- 운영 주소: `https://care.dclub.kr/care/operations`

## 승인 전에는 운영을 건드리지 않았다

구현과 격리 검증을 먼저 끝내고 운영 서비스는 그대로 두었다. 이 서버의 규칙상
DB 백업, 서비스 재시작, PM2 제어는 영향 범위를 설명한 뒤 kim의 명시 승인이
필요하다. 승인 후에도 일반 `pm2` 명령은 사용하지 않았다.

이유는 이전 차량 CRM 배포에서 확인된 PM2 제어면 문제다. 기존 PM2 데몬은 여러
서비스를 정상 관리하지만 `/home/kim/.pm2/rpc.sock`과 `pub.sock` 파일 경로가
없다. 평범한 PM2 CLI 호출은 기존 데몬에 붙지 못하고 같은 PM2_HOME에 새 데몬을
만들 수 있다. 기능 하나를 배포하려다 서버 전체 프로세스 관리가 갈라질 위험이
있다.

## 운영 DB 백업

운영 반영 직전 `VACUUM INTO`로 일관된 SQLite 백업을 만들었다.

```text
/home/kim/kim/backups/bigwash-contract/
contracts-before-equipment-registry-20260802T013835KST.sqlite
```

- 크기: 339,968 bytes
- SHA-256: `d77fa2cf9d1a307a35f7baa5c1581c109921b63b3125ee917d495e963e2e8f01`
- 원본 integrity: `ok`
- 백업 integrity: `ok`
- 원본·백업 외래키 위반: 0
- 운영 장비 수: 0

첫 백업 명령은 셸, Node `-e`, SQLite SQL의 작은따옴표가 겹치면서 JavaScript
구문 단계에서 중단됐다. 운영 DB와 백업 대상은 변경되지 않았다. 다음 시도에서는
SQL 작은따옴표를 `String.fromCharCode(39)`로 구성해 셸·JavaScript·SQL의 인용
경계를 분리했다.

이 실수의 교훈은 명령 한 줄에 언어가 세 겹이면 눈에 보이는 따옴표가 어느
파서의 것인지 먼저 표시해야 한다는 점이다. 실패 직후 대상 파일이 생기지 않았는지
확인한 것도 중요했다. 백업 실패를 성공으로 오인하고 재시작하지 않았다.

## 대상 프로세스만 재기동

운영 중인 washcare 자식 PID는 `2310549`, 부모 PM2 PID는 `2218515`였다. 부모
데몬은 건드리지 않고 자식에만 TERM을 보냈다. 기존 PM2가 자동으로 새 자식을
올렸고 다음 상태를 확인했다.

```text
PM2 parent: 2218515
washcare child: 2423283
listen: *:40101
```

새 프로세스는 현재 작업트리의 AFJ API를 읽어 기동했다. 이번 기능은 기존
`equipment` 스키마를 재사용하므로 새 운영 테이블이나 열 마이그레이션은 없었다.

## 공개 운영 검증

실제 `care.dclub.kr`에서 다음을 확인했다.

- 정상 소유자 Basic 인증 운영 화면: 200
- 무인증 운영 화면: 401
- 오류 비밀번호: 401
- `GET /care/operations/equipment?site_id=1`: 200, 빈 목록
- `POST /care/operations/equipment`의 category 누락 요청: 400
- 공개 HTML의 `내 장비 등록`, `내 장비·이상 기록`, `흡입력 저하`, `회전 이상`
- 반영 후 DB integrity `ok`, 외래키 위반 0, 운영 장비 0건

운영 API 실증을 위해 가짜 광택기를 만들지 않았다. 격리 DB에서 생성·이상기록
흐름을 이미 검증했으므로 운영에서는 비변경 400 요청으로 POST 라우트와 검증만
확인했다. 사용자 데이터가 없는 것과 테스트 데이터가 들어간 것은 전혀 다른
운영 상태다.

## Gogs 체크포인트

런타임 `db/contracts.sqlite`는 stage하지 않았다. 의도된 AFJ, UI, OpenAPI,
검증 스크립트, 테스트, MVP 문서만 `20c65a6`으로 커밋했다. 이어 기존 운영
기록 문서에 사용자 교정, 구현, 검증, 배포와 백업 실수를 남겨 `a98c8c0`으로
커밋했다.

```text
a98c8c0 docs(blog): record equipment registry deployment
20c65a6 feat(washcare): add site equipment registry
```

두 커밋은 Gogs `reconcile-security-gates` 브랜치에 push했고 `git ls-remote`가
원격 head `a98c8c06c8c6c6fc4c7a5215c276e0af5ebcd4da`를 반환했다. 코드가 운영에만
있고 원격 증거가 없는 상태를 남기지 않았다.

## 오늘 작업 전체에서 남은 것

장비 등록과 이상기록 연결은 운영 반영됐다. 아직 남은 범위는 명확히 분리한다.

- 장비 수정·퇴역·정기점검은 다음 단계다.
- 사진 선기록, IndexedDB 로컬 우선 저장, 서버 경유 다기기 동기화는 미래 계획이다.
- 운영 장비 0건이므로 점주가 실제 첫 장비를 등록한 뒤 모델·시리얼 입력 분포를
  관찰해야 한다.
- PM2 제어 소켓은 여전히 별도 유지보수 과제다. 전체 dump와 복구 계획 없이
  기존 데몬을 재기동하지 않는다.
- 런타임 SQLite는 계속 Git에서 제외한다.

오늘 작업의 핵심은 장비 종류를 몇 개 늘린 것이 아니다. 이상기록 앞에 점주의
실제 소유 장비를 정본으로 세웠고, 같은 종류 여러 대를 최소 입력으로 구분했고,
AFJ 규칙·운영 배포·Gogs 증거·다음 실행자를 위한 실패 기록까지 하나의 작업
단위로 닫은 것이다.

배포 직후 운영 장비가 0대인 상태에서 kim이 `장비 등록`과 `장비 이상`이 같은
등록 모달을 연다는 사실을 확인했다. 장비가 없으면 이상 버튼을 등록폼으로 바꾸는
자동 전환이 원인이었다. 이상 버튼은 언제나 고장 원인·상태·중단시간을 보여주고,
장비 선택 영역에서만 등록을 안내하도록 후속 교정했다. 이 교정은 별도 검증과
체크포인트 `00f103a`와 전체 회귀를 통과했으며 운영 반영 승인은 별도로 받아야
한다.
