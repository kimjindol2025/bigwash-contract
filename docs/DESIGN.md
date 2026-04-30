# BigWash Contract System - 설계 문서

## 1. 데이터 모델

### Contract (계약)
```
id: 정수 (PK)
number: 텍스트 (계약번호)
status: 선택지 (DRAFT/PENDING/APPROVED/COMPLETED/CANCELLED)
client_id: 정수 (고객ID)
amount: 소수 (계약금액)
created_at: 시간
updated_at: 시간
```

### ContractItem (계약항목)
```
id: 정수
contract_id: 정수 (FK)
description: 텍스트
quantity: 정수
unit_price: 소수
subtotal: 소수
```

## 2. API 엔드포인트

### Contract 관리
- `POST /api/contracts` - 계약 생성
- `GET /api/contracts/:id` - 계약 조회
- `PUT /api/contracts/:id` - 계약 수정
- `GET /api/contracts?status=PENDING` - 상태별 조회
- `DELETE /api/contracts/:id` - 계약 삭제

### 상태 전이
```
DRAFT → PENDING → APPROVED → COMPLETED
  ↓         ↓         ↓          ↓
CANCELLED (언제든)
```

## 3. 비즈니스 로직

### 계약 생성
- 고객 정보 필수
- 최소 1개 항목 필수
- 상태: DRAFT로 시작

### 계약 승인
- PENDING 상태에서만 가능
- 금액 검증

### 계약 완료
- APPROVED에서만 가능
- 완료일자 기록

## 4. 데이터베이스 초기화
```sql
CREATE TABLE contracts (...)
CREATE TABLE contract_items (...)
CREATE TABLE contract_history (...)
```

## 5. 에러 처리
- 유효하지 않은 상태 전이
- 필수 필드 누락
- 참조 무결성 위반
