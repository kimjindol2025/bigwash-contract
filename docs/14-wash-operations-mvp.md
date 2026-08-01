# 세차장 운영 기록실 MVP

작성일: 2026-08-01
화면: `/care/operations`
구현: `src/operations.fl`, `src/operations-admin.html`

## 목적

> 오늘 몇 대를 세차했는지가 아니라, 오늘 왜 밀렸고 무엇을 다시 고쳐야 하는지를 남긴다.

기존 `sites`와 `equipment`를 기준정보로 재사용한다. 창업 검토 과정에서 후보지로
만든 주소는 운영 전환 뒤에도 같은 `site_id`를 쓰므로 주소별 체크리스트, 장비,
점검 이력이 끊기거나 복제되지 않는다.

## 창업 후보지 → 운영 사업장

```text
sites.site_stage = CANDIDATE
  └─ [운영 사업장으로 전환]
       └─ 같은 sites.id, site_stage = OPERATING
            └─ wash_ops_* 일일 기록 시작
```

전환 API는 `POST /care/operations/sites/:id/activate`다. `CANDIDATE`만 전환할
수 있고 이미 운영 중이거나 검토 제외인 주소를 조용히 덮어쓰지 않는다. Admin
고객 상세 → 현장 탭에서 후보지 행에 전환 버튼이 나타난다.

## 1차 제공 범위

- 운영 사업장 등록·선택
- 일일 운영 상태: 정상 / 주의 / 문제 발생
- 차량번호 중심 작업 기록
- 불만·무료 재작업과 원인 분류
- 장비 이상 상태와 영업 중단시간
- 운영 메모 원문과 주제 분류
- 일일 문제 중심 대시보드
- 최근 7일 반복 재작업 원인 리포트

직원 역할·교육, 소모품, 개선 과제, 오너 리포트는 화면 메뉴에 2차 범위로
표시하되 아직 저장 기능을 만들지 않는다.

## 현장 입력 원칙

빠른 기록 버튼이 긴 입력폼의 입구가 되면 안 된다. 기록 방식은 다음처럼
`키보드가 필요한 값`과 `터치로 충분한 값`을 나눈다.

- 키보드·말하듯 입력: 새 차량의 차량번호·차량명, 담당자 이름, 고객 요청,
  운영 메모
- DB 자동·단일 터치: 차량번호 최근 이력 3개, 차량명 기준 크기, 기본 작업,
  운영 상태, 사업주 개입, 재작업 원인, 장비 상태
- 복수 터치: 벌레·타르·철분·실내 집중·왁스 같은 추가 작업
- `지금 기록`: 입고, 작업 시작, 작업 완료, 출차, 영업 시작·종료
- `− / +`: 예약 차량 수와 출근 직원 수
- 조건부 상세: 문제 차량, 재작업 처리, 장비 조치, 주의·문제 운영 메모

390px 실제 Chrome 검증에서 차량 폼은 선택형 터치 컨트롤 24개, 시간 버튼 4개,
네이티브 select 0개로 구성됐다. 차량 크기·추가 작업·사업주 개입·시간이 기존
AFJ API payload로 변환되고 가로 넘침과 런타임 오류가 없음을 확인했다.

재방문 차량은 번호 일부를 입력하면 같은 사업장의 저장 이력 중 가까운 3개가
최근 차량명·크기·방문 횟수와 함께 나온다. 하나를 선택하면 차량명과 크기를
다시 입력하지 않는다. 새 차량은 차량명만 입력하며 크기는 DB 기준표에서 자동
판정한다. 기준표에 없는 차량만 `직접 수정`을 열어 크기를 고르고, 저장된
차량명·크기는 다음 입력부터 기준표가 학습한다. 자동 판정값이나 최근 차량
이력 복원값은 학습으로 취급하지 않는다. 차량명을 바꾸면 이전 자동 크기를
즉시 비우며, 일부 글자에 대한 fuzzy 후보는 목록에만 보여주고 확정값으로
저장하지 않는다.

## 데이터 경계

기존 회사 내부 A/S 운영 집계(`get-ops-summary`, `get-ops-weekly`)와 점주가
매일 쓰는 세차장 운영 기록은 다른 책임이다. 이름 충돌과 오해를 막기 위해
새 테이블은 모두 `wash_ops_` 접두사를 쓴다.

```text
sites
├─ wash_ops_daily_records       하루 운영 상태와 사업주 작업시간
├─ wash_ops_vehicle_jobs        차량번호별 작업·대기·추가작업
│  └─ wash_ops_vehicle_condition_checks
│       └─ 입고/출차 × 외부/내부 × 항목별 상태
├─ wash_ops_vehicle_models      차량명 → 크기 정본·현장 학습표
├─ wash_ops_reworks             불만·원인·무료시간·재발방지
├─ wash_ops_equipment_issues    이상 상태·중단시간·해결 여부
└─ wash_ops_notes               현장 메모 원문과 분류
```

- 요약을 다시 만들어도 원본 기록은 수정하거나 버리지 않는다.
- 사업장 ID와 날짜를 모든 운영 기록의 기본 경계로 둔다.
- 일일 운영 상태만 사업장·날짜당 하나이며 수정 저장(upsert)한다.
- 차량·재작업·장비 이상·메모는 append 방식으로 누적한다.
- 장비나 차량 작업을 다른 사업장 기록에 연결할 수 없도록 서버에서 확인한다.
- 차량번호 원문과 별도로 공백·하이픈을 제거한 검색 키를 보존한다.
- 차량명·크기는 재방문 이력 → 차량 기준 DB 순서로 자동 보완한다.

### 차량 상태 체크포인트 스키마

차량 상태는 차량 행의 JSON이나 메모로 덮어쓰지 않고 항목별 행으로 저장한다.

```text
wash_ops_vehicle_condition_checks
├─ vehicle_job_id       어느 차량 작업인가
├─ inspection_stage     ARRIVAL | FINAL
├─ area_group           EXTERIOR | INTERIOR
├─ checkpoint_code      변경되지 않는 정본 코드
├─ checkpoint_label     당시 화면에 보인 항목명 스냅샷
├─ condition_status     NORMAL | CONTAMINATED | WET_ODOR |
│                       DAMAGE | RECHECK | NOT_APPLICABLE
└─ note                 필요한 경우만 쓰는 추가 메모
```

외부 정본 10항목은 앞 범퍼, 보닛, 전면 유리, 루프, 좌측 차체, 우측 차체,
후면·트렁크 외부, 휠·타이어, 문틈·몰딩, 도장 손상이다. 내부 정본 10항목은
운전석, 조수석, 뒷좌석, 대시보드·콘솔, 바닥·매트, 도어 트림, 실내 유리·거울,
트렁크 내부, 냄새·습기, 소지품·기존 손상이다.

`(vehicle_job_id, inspection_stage, checkpoint_code)`는 유일하다. 같은 단계의
항목을 다시 확인하면 그 행만 갱신하고, 입고 상태와 출차 검수는 서로 덮어쓰지
않는다. 차량과 체크포인트는 AFJ 트랜잭션 하나로 저장해 잘못된 코드가 있으면
차량 행도 함께 롤백한다.

## 운영 브리핑의 현재 경계

현재 브리핑은 외부 LLM 호출이 아니라 저장된 숫자와 최근 문제 기록을 조합한
결정론적 초안이다. 화면에 `기록 기반 초안`이라고 명시한다. AI가 없어도 모든
입력·조회·주간 집계가 동작한다.

생성형 AI를 붙일 때도 다음 경계를 유지한다.

1. 외부에는 해당 사업장·기간의 집계와 필요한 문제 요약만 전달한다.
2. AI 답변에는 근거가 된 차량·재작업·장비 기록 ID를 함께 저장한다.
3. AI 요약이 원본 기록을 덮어쓰지 않는다.
4. 사용자가 승인하지 않은 AI 해석은 확정 운영 이력으로 취급하지 않는다.

## API

| Method | Path | 역할 |
|---|---|---|
| GET/POST | `/care/operations/sites` | 운영 사업장 목록 / 신규 등록 |
| POST | `/care/operations/sites/:id/activate` | 후보지 운영 전환 |
| GET | `/care/operations/equipment?site_id=` | 사업장 장비 선택 목록 |
| GET | `/care/operations/vehicle-suggestions?site_id=&q=` | 저장 차량번호 근접 이력 3개 |
| GET | `/care/operations/vehicle-models?q=` | 차량명 기준 크기 제안 3개 |
| POST | `/care/operations/day` | 일일 운영 상태 저장 |
| POST | `/care/operations/vehicles` | 차량 작업 추가 |
| POST | `/care/operations/reworks` | 재작업 추가 |
| POST | `/care/operations/equipment-issues` | 장비 이상 추가 |
| PUT | `/care/operations/equipment-issues/:id/resolve` | 장비 문제 해결 처리 |
| POST | `/care/operations/notes` | 운영 메모 추가 |
| GET | `/care/operations/dashboard` | 날짜별 지표·원본·브리핑 |
| GET | `/care/operations/weekly` | 최근 7일 지표·원인·일별 흐름 |

운영 기록실 HTML은 Admin과 같은 HTTP Basic을 요구하고, 같은 출처에서 호출하는
운영 JSON API도 그 Basic 인증을 재사용한다. 자동화·내부 연동은 기존처럼
`x-api-key`를 사용할 수 있다. 둘 다 없으면 기본 401인 fail-closed 정책이다.

## 검증

```bash
BIGWASH_DB_PATH=/tmp/bigwash-wash-operations-test.sqlite \
node /home/kim/kim/freelang-v11/bootstrap.js run tests/test_wash_operations.fl
```

도메인 테스트는 후보지의 동일 ID 전환, 차량명 크기 자동 판정, 재방문 차량
정보 상속, 차량번호 제안 3개 제한, 수동 크기 교정만 학습, 부분 차량명 확정
거부, 영문 키 대소문자 병합, 재작업, 장비 중단, 메모,
일일 지표, 장비 해결, 주간 원인 집계, 다른 사업장 장비 연결 거부를 확인한다.

## 다음 단계

1. 직원 역할·검수 담당·교육 기록
2. 사업주 직접 개입을 차량·업무 유형별로 세분화
3. 개선 과제 3개 제한과 결과 확인
4. 외부 AI 선택 연결과 근거 ID·사용자 승인 상태 저장
