# 작업 체크포인트

**마지막 업데이트**: 2026-04-30 (퇴근 직전)

## 현재 위치

**Step 2 (목록·신규·상세 페이지) 시작 직전.**

## 완료된 것 (Step 1)

- ✅ 디렉토리 골격 (`/home/kim/contract-app/`)
- ✅ `lib/escape.fl` — HTML XSS 방어 (`(esc v)`), 검증 통과
- ✅ `lib/storage.fl` — JSON 파일 저장소 (`load-contract` / `save-contract` / `list-contracts` / `find-by-token`)
- ✅ `lib/contract_no.fl` — `(next-contract-no)` → `BW-2026-0001` 채번, seq.json 영속화 검증
- ✅ `lib/supplier.fl` — `(load-supplier)` 자사정보 로더
- ✅ `data/supplier.json` (placeholder), `data/seq.json` (`{"2026":0}` 초기화)
- ✅ `app.fl` — `server_start 40310`, `/health` 라우트
- ✅ `README.md`, `.gitignore`
- ✅ Gogs push: https://gogs.dclub.kr/kim/bigwash-contract (`229a225`)

## 다음 작업 재개 (Step 2)

순서:
1. `views/layout.fl` — 공통 HTML 셸 (head, style 인라인 또는 link)
2. `public/style.css` — 공통 스타일
3. `views/contract_form.fl` — 신규/수정 폼 (type 4종 라디오, 품목 5행 고정)
4. `views/contract_list.fl` — 테이블 + 상태 필터
5. `views/contract_show.fl` — 상세 + 액션 버튼
6. `routes/contracts.fl` — 핸들러 작성
   - `GET /contracts`  → list
   - `GET /contracts/new`  → form (빈)
   - `POST /contracts`  → 저장 → redirect `/contracts/:id`
   - `GET /contracts/:id`  → show
   - `GET /contracts/:id/edit`  → form (채워진)
   - `POST /contracts/:id`  → 수정 저장
7. `app.fl`에 라우트 등록 + `(load "routes/contracts.fl")`
8. `server_static "/style.css"` 등록
9. 검증: 브라우저에서 신규 계약 입력 → JSON 파일 생성 → 목록 표시 → 상세 보기

## 검증 명령

```bash
cd /home/kim/contract-app
node /home/kim/freelang-v11-latest/bootstrap.js run app.fl
# → http://localhost:40310/health
# Step 2 후: → http://localhost:40310/contracts/new
```

## 기술 메모 (놓치기 쉬움)

- **`[FUNC ...]` 문법은 v11에서 인자 평가 이슈 발견** — `defn`만 사용한다.
- **`(do ...)` 명시 필요** — 다중 statement 함수 본문은 반드시 `(defn f [x] (do ...))` 형태.
- **`regex_replace s pat repl`** — global 치환 (str_replace_all 없음).
- **`(map fn arr)`** fn-first 표준. `(filter fn arr)` 도 fn-first.
- **`server_req_body`** JSON 자동 파싱 (CLAUDE.md 표기, fl-server-demo로 확인됨).
- **인쇄/PDF**는 브라우저 `Ctrl+P`로 처리. puppeteer 안 씀.
- **bootstrap.js 경로**: `/home/kim/freelang-v11-latest/bootstrap.js`

## 결정사항 (변경 금지)

| 항목 | 값 |
|------|-----|
| 위치 | `/home/kim/contract-app/` |
| 포트 | 40310 |
| 저장 | JSON 파일 (`data/contracts/<id>.json`) |
| 노출 | 로컬 시작, 검증 후 `dclub deploy contract 40310` |
| 양식 | 표준 장비 공급계약서 → 빅워시 양식 받으면 보정 |
| Repo | https://gogs.dclub.kr/kim/bigwash-contract |

## 플랜 파일

`/home/kim/.claude/plans/whimsical-noodling-bachman.md` (전체 5단계 상세)
