# BigWash 단일 제품 통합 아키텍처 (초안)

작성일: 2026-07-16

> 이 문서는 `01-product-payment-marketing-plan.md`의 7장(기존 자산 재사용)을 실행 가능한
> 규칙으로 구체화한다. 13장의 게이트를 통과하기 전에는 이 문서의 Phase 1도 구현하지 않는다.

## 1. 원칙

- **단일 제품·단일 DB·단일 배포**: BigWash Contract(`/root/apps/bigwash-contract`) 하나만
  실제로 배포되는 제품이다. People CRM(`/root/apps/people-crm`)과 SoloFlow(`/root/apps/soloflow`)는
  이 제품의 일부가 되지 않는다 — 계속 각자의 독립 앱으로 남는다.
- **코드 의존 금지**: BigWash는 People CRM/SoloFlow의 소스를 `import`/`load`하지 않고,
  그 두 저장소의 DB 파일을 직접 읽거나 쓰지 않는다. git submodule, npm link, 공유 패키지 등
  어떤 형태의 코드 결합도 하지 않는다.
- **개념만 차용, 재구현**: 아래 3장에 적은 개념만 참고해서 BigWash 자신의 스키마·화면으로
  **새로 짠다**. 원본 저장소의 필드명·구현을 그대로 복사하지 않는다 — 세차장 장비관리
  도메인에 맞는 이름과 제약으로 다시 설계한다.
- **역방향 의존 금지**: People CRM이나 SoloFlow가 나중에 BigWash를 참조하게 만들지 않는다.
  개념 차용은 한 방향(BigWash가 가져옴)으로만 흐른다.

## 2. 왜 코드 결합이 아니라 개념 차용인가

세 저장소는 각자 다른 가정 위에 있다.

| 저장소 | 사용자 모델 | 저장 방식 | 도메인 |
|---|---|---|---|
| BigWash Contract | 단일 사업자(대한이엔지) | SQLite (`contracts.sqlite`) | 계약 (장비·A/S는 아직 구현 안 됨 — 이 문서가 추가하려는 것) |
| SoloFlow | 단일 프리랜서 사용자 | JSONL append-only 이벤트 로그 | 대금·계약·일정 |
| People CRM | 단일 사용자 인맥관리 | SQLite (`app.db`, `people.db`), 포트 43000 독립 서버 | 사람·타임라인·연락주기 |

저장 방식과 사용자 모델이 셋 다 다르다. 코드 수준에서 합치면 "SQLite 트랜잭션 안에서
JSONL 이벤트 로그를 참조"하는 것 같은, 세 시스템 중 어느 쪽 계약도 지키지 못하는
어중간한 상태가 될 위험이 크다 — 그래서 이번엔 처음부터 재구현으로 간다.

## 3. 저장소별 차용 개념과 BigWash 내 재구현 대상

### SoloFlow → 일정·미수금·발송 흐름

| SoloFlow 개념 | BigWash 재구현 대상 |
|---|---|
| 계약(contract) 상태 전이 | 이미 BigWash `Contract.status`(DRAFT/PENDING/APPROVED/COMPLETED/CANCELLED)로 존재 — 그대로 유지, 확장 안 함 |
| 청구서(invoice)·미수금 추적 | Phase 3에서 `PaymentOrder`/`PaymentEvent`로 재구현 (4장 참조). `CarePlan.payment_status`는 그 결과를 보여주는 요약값일 뿐 원장이 아니다. SoloFlow의 JSONL 이벤트 로그 방식은 가져오지 않고, BigWash 기존 SQLite 테이블 방식을 그대로 쓴다 |
| 일정(schedule) 관리 | `ServiceTicket.scheduled_at`, `ServiceVisit.visited_at`로 재구현 — SoloFlow의 독립 캘린더 개념이 아니라 A/S 티켓에 종속된 날짜 필드로 단순화 |
| 발송 이력(템플릿 발송) | Phase 1에서는 가져오지 않는다. "보냈는가"(발송)와 "열어봤는가"(접근)는 서로 다른 개념이라 하나로 뭉치지 않는다 — 필요해지면 5장의 `NotificationDelivery`/`LinkAccessLog`로 분리해서 다룬다 |

### People CRM → 고객·타임라인 개념

| People CRM 개념 | BigWash 재구현 대상 |
|---|---|
| 사람(Person) 엔티티 | `Customer` 테이블로 재구현 — People CRM은 개인 인맥이 대상이지만 BigWash는 점주(사업자)가 대상이므로 `phone`/`email`/`memo`만 차용하고 개인정보 항목(생일, 관계 등)은 가져오지 않는다 |
| 타임라인(연락 이력) | `ServiceVisit` + A/S 상태 변경 로그로 재구현 — "이 고객과 있었던 일을 시간순으로 본다"는 개념만 가져오고, People CRM의 자유 메모 타임라인이 아니라 A/S·방문·결제 이벤트로 종류를 고정한다 |
| 연락주기 알림(remind) | `CarePlan`의 점검 임박 목록(6장 운영 대시보드)으로 재구현 — "정해진 주기가 지나면 알려준다"는 개념만 차용 |

### Gmail 연동 (MVP 이후)

- 지금은 손대지 않는다. `01-product...md` 7장에 명시된 대로 MVP 이후 견적 발송·문의
  분류에만 검토한다. Phase 1/2 스키마에 포함하지 않는다.

## 4. 단계별 데이터 모델

### Phase 0 — 게이트 검증 (코드 없음)

13.1의 수동 유료 파일럿은 스프레드시트·카카오톡으로 진행한다. **이 단계에서는 어떤 테이블도
만들지 않는다.** 검증 결과(고객 응답, 원가 계산)만 문서나 스프레드시트에 남긴다.

### Phase 1 전에 반드시 정할 것 — 기존 Contract ↔ 신규 Customer 연결

`src/db.fl:10`의 `contracts.client_id INTEGER NOT NULL`은 FK 제약이 없는 평범한 정수
컬럼이다. `Customer` 테이블을 그냥 추가하면 고객 식별자가 두 곳(`client_id`와 신규
`Customer.id`)으로 이중화된다. Phase 1 스키마 작업을 시작하기 전에 아래를 먼저 정한다.

1. **전환 여부**: 기존 `client_id`를 신규 `Customer.id`를 가리키는 FK로 바꾼다 (새 컬럼을
   추가해 병행 운영하지 않는다 — 두 식별자를 오래 유지하면 어느 쪽이 진짜인지 헷갈린다).
2. **매핑 규칙**: 마이그레이션 시점에 `contracts` 테이블에 남아있는 distinct `client_id`
   값 각각에 대해 `Customer` 레코드를 1개씩 생성하고 그 값을 그대로 새 PK로 잇는다.
   (실행 전 실제 distinct 값 개수와 내용을 먼저 조회해서 확인 — 지금은 검증되지 않은
   테스트 데이터일 가능성이 있다.)
3. **매핑 불가능한 계약**: 이름·연락처 등 고객 정보가 비어 있어 매핑할 수 없는 계약은
   삭제하지 않고 "미분류(레거시)" 고정 `Customer` 1건에 묶는다.
4. **마이그레이션·롤백**: SQLite `ALTER TABLE`로 `customer_id` 컬럼을 추가하고 백필한 뒤,
   운영 확인이 끝나기 전까지 기존 `client_id` 컬럼은 지우지 않고 남겨 둔다 (문제 발생 시
   `customer_id` 없이 되돌릴 수 있게). 배포 전 `db/contracts.sqlite`를 복사해 백업한다.

### Phase 1 — 게이트 통과 직후 (13.3의 1주차)

기존 `docs/DESIGN.md`의 `Contract`/`ContractItem`은 그대로 두고, 위 마이그레이션과 아래만
추가한다. 한 번에 8장 전체를 만들지 않고 A/S 흐름이 실제로 도는 데 필요한 최소 집합부터
만든다.

```text
Customer          (신규, 위 마이그레이션으로 기존 client_id에서 생성)
Site              (신규, Customer에 종속)
Equipment         (신규, Site·기존 Contract에 연결 — contract_id FK만 추가, Contract 자체는 무변경)
ServiceTicket     (신규)
ServiceVisit      (신규)
```

`CarePlan`(연간 상품·결제 상태)과 결제 상태 컬럼 전부 Phase 1에 넣지 않는다 — 13.1에서
이미 스프레드시트로 수동 결제를 확인했으니, 이 단계의 결제 기록도 계속 스프레드시트에
남긴다. 사업장의 운영 상태(`Site.status`: 정상/휴업 등)와 결제 상태는 서로 다른 개념이라
하나의 컬럼에 섞지 않는다. 결제 상태를 위한 컬럼·테이블은 Phase 2의 `CarePlan`에서 처음
생긴다.

### Phase 2 — 확장 판매 단계 (13.3의 3~4주차 이후)

- `CarePlan` 추가 — 연 36만/79만 원 상품과 자동 갱신 추적이 실제로 필요해지는 시점
- 운영 대시보드(6장 항목 6) — 고객이 5곳을 넘어가 수기 확인이 버거워지는 시점
- 주간 운영 보고(6장 항목 8) — 담당자가 매일 대시보드를 보고도 놓치는 사례가 나오는 시점

### Phase 3 — 자동결제 (10장 기준 충족 시)

`CarePlan.payment_status` 하나로는 부족하다 — "지금 상태가 뭔지" 보여주는 요약값과
"실제로 무슨 일이 있었는지"의 원장은 분리한다.

```text
PaymentOrder
  id, care_plan_id, billing_period, amount, status,
  idempotency_key(= care_plan_id + billing_period)

PaymentEvent
  id, payment_order_id, pg_event_id, event_type,
  raw_payload, received_at
```

- `PaymentOrder`: 결제 주문과 청구 기간(`billing_period`) 단위 기록. `CarePlan.payment_status`는
  이 테이블의 최신 상태를 보여주는 캐시일 뿐이다.
- `PaymentEvent`: PG가 보내는 웹훅 원문과 이벤트 ID를 그대로 저장해 중복·순서바뀜 수신을
  가려낸다.
- 10장에 이미 정리된 멱등키·웹훅 안전성·부분환불 규칙을 위 두 테이블에 그대로 적용한다.

## 5. 외부 공유 링크

`01-product...md` 8장에 이미 명시된 대로, 고객용 링크는 내부 순번 ID를 노출하지 않고
추측 불가능한 별도 토큰을 쓴다. Phase 1부터 이 규칙을 적용한다 — 나중에 추가하는 게 아니라
처음 만드는 `ServiceTicket` 조회 링크부터 아래 규칙으로 만든다. 토큰 난수성만으로는
부족하다.

- **저장**: 토큰 원문을 DB에 저장하지 않는다. 해시(예: SHA-256)만 저장하고, 요청이 오면
  같은 방식으로 해시해서 대조한다.
- **폐기·재발급**: A/S 티켓이 완료되거나 고객이 요청하면 토큰을 무효화하고 새로 발급할 수
  있어야 한다. 무효화된 토큰은 조회 시 404로 응답한다 (링크가 존재했다는 사실 자체를
  노출하지 않는다).
- **최소 노출**: 링크로 보여주는 응답에는 상태·예정일·연락처처럼 고객 본인에게 필요한
  값만 담는다. 다른 고객·다른 사업장 정보, 내부 메모, 원가는 포함하지 않는다.
- **캐싱 금지**: 응답 헤더에 `Cache-Control: no-store`를 넣어 프록시·브라우저 캐시에
  남지 않게 한다.
- **요청 횟수 제한**: 토큰당·IP당 요청 빈도를 제한해 무차별 대입으로 다른 토큰을 추측하지
  못하게 한다.
- **접근 로그 보관기간**: `LinkAccessLog`(요청 시각·IP 정도만)를 남기되 보관기간을 정해두고
  (예: 90일) 그 이후 자동 삭제한다 — 개인정보 최소 수집 원칙에 맞춘다.

## 6. 이 문서가 다루지 않는 것

- People CRM/SoloFlow 자체의 향후 개발 방향 — 이 문서는 BigWash 쪽에서 무엇을 가져올지만
  다룬다. 두 저장소를 어떻게 바꿀지는 각자의 문서에서 별도로 다룬다.
- design.md(시각 디자인) — `03-design-system.md`(가칭)에서 별도로 다룬다.
