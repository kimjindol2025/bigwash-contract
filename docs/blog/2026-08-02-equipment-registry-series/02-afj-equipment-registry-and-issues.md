# [세차장 운영 기록실 2/3] AFJ 장비 등록과 이상 이력을 연결하다

- 날짜: 2026-08-02 KST
- 기능 체크포인트: `20c65a6 feat(washcare): add site equipment registry`
- 모달 경계 체크포인트: `00f103a fix(washcare): separate equipment issue modal`
- 핵심 언어: FreeLang/AFJ

## 구현 원칙

이 서버의 핵심 업무 규칙은 AFJ가 정본이다. 브라우저 JavaScript는 터치 선택과
same-origin API 호출만 담당한다. 장비 등록, 운영 사업장 확인, 날짜 검증, 장비
순번, 사업장 소유 경계는 `src/operations.fl`에 두었다.

기존 `equipment` 스키마는 이미 다음 정보를 갖고 있었다.

```text
equipment
├─ site_id
├─ contract_id
├─ category
├─ model
├─ serial_number
├─ installed_at
├─ warranty_ends_at
└─ status: ACTIVE | REPAIR | RETIRED
```

그래서 새 표나 마이그레이션 열은 필요하지 않았다. 운영 등록 함수
`create-wash-ops-equipment`가 운영 사업장을 확인하고, 종류를 필수값으로
정규화하고, 선택 입력된 설치일과 보증일을 실제 달력 날짜로 검증한 뒤 기존
`create-equipment`를 호출한다.

## 같은 종류의 자동 순번

순번은 별도 입력값으로 저장하지 않았다. 같은 사업장과 같은 종류에서 현재 장비의
ID 이하 행 수를 세어 `category_number`를 계산한다.

```sql
SELECT COUNT(*)
FROM equipment numbered
WHERE numbered.site_id = e.site_id
  AND numbered.category = e.category
  AND numbered.id <= e.id
```

이 방식은 점주가 `광택기 2`라는 이름을 타이핑하지 않아도 되고, 이상기록은
변하지 않는 `equipment.id`를 계속 참조한다. 퇴역 장비를 목록에서 숨겨도 뒤에
등록된 장비 번호가 과거 이력과 다른 장비로 바뀌지 않도록 순번 계산에는 기존
장비를 포함한다.

## API 경계

운영 장비 목록과 등록은 같은 경로에 메서드로 구분했다.

```text
GET  /care/operations/equipment?site_id=1
POST /care/operations/equipment
```

POST 본문은 `site_id`, `category`만 필수다. `model`, `serial_number`,
`installed_at`, `warranty_ends_at`는 선택이다. 운영 화면의 Admin Basic 또는
자동화용 `x-api-key`만 허용하는 기존 운영 API 정책을 그대로 사용했다.

이상기록 대시보드 조회에도 `equipment_category_number`를 포함했다. 따라서 과거
이상 행도 `광택기 · P-100`이 아니라 `광택기 2 · P-100`으로 어느 장비인지
구분할 수 있다.

## 터치 UI

장비 등록은 매일 하는 작업이 아니지만 현장에서도 쉽게 끝나야 한다. 자주 쓰는
종류는 큰 선택 칩으로 만들었다.

- 고압세척기
- 콤프레셔
- 진공청소기
- 광택기
- 매트세척기
- 폐수처리시설
- 온수기
- 목록에 없는 장비 직접 입력

등록 장비가 있으면 장비 이상 폼은 `미지정` 대신 첫 장비를 선택한다. 카드의
`이 장비 이상 기록`을 누르면 그 장비가 미리 선택된다. 장비가 0대여도 이상 버튼은
원인·상태·중단시간 폼을 그대로 열고, 장비 선택 영역에서 등록 이동을 제공한다.
저장은 등록 장비 선택 없이는 거부한다. 고압 장비 중심이던 증상에 `흡입력 저하`,
`회전 이상`, `전원 이상`을 추가해 진공청소기와 광택기도 터치로 기록할 수 있게
했다.

inline `onclick`은 쓰지 않았다. 이전 배포에서 CSP가 inline 이벤트를 차단했던
기록을 따라 `data-action` 이벤트 위임을 유지했다. 모바일 820px 이하에서는
장비 카드가 한 열로 바뀌고, 버튼은 한 손 터치에 맞는 높이를 유지한다.

## 회귀 검증

`test_wash_operations.fl`에는 한 사업장에 다음 장비를 실제로 만들었다.

```text
고압세척기 1, 2
콤프레셔 1
진공청소기 1
광택기 1, 2, 3
```

두 번째 고압세척기의 순번 2, 세 번째 광택기의 순번 3, 전체 장비 7대, 각 종류
보존을 단정했다. 다른 사업장의 장비를 이상기록에 연결하면 거부하는 기존 회귀도
함께 통과했다.

최종 검증 결과는 다음과 같다.

- FreeLang/AFJ 도메인 테스트 17/17
- Admin·운영 화면 JavaScript 구문과 장비 모달 경계 검사 통과
- OpenAPI와 코드 라우트 77/77 일치
- 격리 HTTP fail-closed·API key·Admin Basic·오류 은닉 통과
- 격리 DB 백업→변경→복원과 해시 복구 통과
- `git diff --check` 공백 오류 없음

별도 격리 HTTP 서버에서는 사업장 생성, 고압세척기와 광택기 2대 등록, 목록
조회, `광택기 2` 선택, `회전 이상` 10분 저장, 대시보드의
`equipment_category_number=2` 조회까지 실제 요청으로 확인했다.

운영 장비 0대에서 이상 버튼을 등록폼으로 바꾸는 코드가 다시 들어오면 검증
스크립트가 실패하도록 했다. 이상 모달에는 `이상 증상`, `현재 상태`,
`영업 중단시간`, 빈 장비 안내가 모두 있어야 한다.

## 구현 중 주의한 경계

HTTP 다중 등록 실증을 병렬로 호출했을 때 두 광택기의 응답 순서는 요청을 작성한
순서와 달랐다. 순번은 요청 배열 순서가 아니라 DB ID 순서라는 설계대로 정확했다.
실제 화면 저장은 사용자가 한 번씩 순차로 수행한다. 동시 등록 UI를 만들게 된다면
표시 순서를 클라이언트 요청 순서로 추정하지 말고 서버가 반환한 ID와 순번을 다시
읽어야 한다.

3편에서는 이 코드를 운영 서버에 반영하면서 DB 백업과 PM2 제어면을 어떻게
다뤘는지, 무엇을 운영 데이터에 남기지 않았는지 기록한다.
