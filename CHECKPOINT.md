# 작업 체크포인트

**마지막 업데이트**: 2026-05-10 (Step 2 ✅ 완료)

## 현재 위치

**Step 2 ✅ 완료. Step 3 (인쇄/PDF — `Ctrl+P`) 직전.**

플랜: `/home/kim/.claude/plans/purring-floating-kernighan.md` (승인됨)

## 완료된 것 (Step 1)

- ✅ 디렉토리 골격 (`/home/kim/contract-app/`)
- ✅ `lib/escape.fl` — `(esc v)` HTML XSS 방어
- ✅ `lib/storage.fl` — `load-contract` / `save-contract` / `list-contracts` / `find-by-token` / `new-contract-id`
- ✅ `lib/contract_no.fl` — `(next-contract-no)` → `BW-2026-0001`, seq.json 영속화
- ✅ `lib/supplier.fl` — `(load-supplier)` 자사정보 로더
- ✅ `data/supplier.json` (placeholder), `data/seq.json` (`{"2026":0}`)
- ✅ `app.fl` — `server_start 40310`, `/health`
- ✅ Gogs push: https://gogs.dclub.kr/kim/bigwash-contract (`aa862d8`)

## Step 2 자원 검증 결과 (2026-05-10)

`/home/kim/freelang-v11/src/stdlib-http-server.ts` 실측:

| 함수 | 상태 | 비고 |
|------|------|------|
| `server_post path handler` | ✅ :182 | POST 라우트 |
| `server_redirect url` | ✅ :552 | 302 |
| `server_html body` | ✅ :522 | text/html (FL_DEV=1에서 hot-reload 자동삽입) |
| `server_req_body req` | ✅ :596 | application/json은 객체로 자동파싱 |
| `server_req_param req "id"` | ✅ | path parameter `/x/:id` 지원 |
| `server_static` | ❌ **미구현** | CLAUDE.md 잘못 기재. → 회피 D1 |
| 폼 파서 (`server_req_form` 등) | ❌ 없음 | → 회피 D2 |

## 회피 결정 (Step 2 한정)

**D1. CSS 인라인.** `views/layout.fl` `<style>` 한 블록. `public/style.css`/`server_static` 미사용.

**D2. 폼 제출은 JSON fetch.** `<form>` submit을 JS가 가로채 `FormData`→객체로 직렬화 후 `application/json`으로 POST. items는 `items.{i}.{field}` 키 평탄화 → 서버에서 5행 재구성.

## Step 2 작업 (8 단계) — 모두 완료

| # | 파일 | 상태 |
|---|------|------|
| 1 | CHECKPOINT.md 갱신 | ✅ |
| 2 | `views/layout.fl` (page+style+JS) | ✅ |
| 3 | `views/contract_form.fl` (form-view) | ✅ |
| 4 | `views/contract_list.fl` (list-view) | ✅ |
| 5 | `views/contract_show.fl` (show-view) | ✅ |
| 6 | `routes/contracts.fl` (6 핸들러 + calc-totals + items-from-flat) | ✅ |
| 7 | `app.fl` 라우트 등록 | ✅ |
| 8 | 검증 V1~V7 | ✅ 모두 통과 |

## Step 2 진행 중 발견 (자원 수정사항)

| 잘못 알고 있던 것 | 실제 v11 stdlib | 영향 파일 |
|-------------------|-----------------|-----------|
| `regex_test` | **`regex_match`** (stdlib-crypto.ts:111) | `lib/storage.fl`, `routes/contracts.fl` |
| `wcrypto_random_hex` (서버 미로드) | **`random_bytes`** (stdlib-crypto.ts:74) | `lib/storage.fl` |
| `server_req_body` JSON 자동 객체 반환 | **string 반환** — 객체로 받으려면 **`server_req_json`** | `routes/contracts.fl` |
| `server_static` 미구현 | **존재함** (v11 CLAUDE.md 등록, 단일 파일 매핑) — 다만 인라인 결정 D1 유지 | (현재 미사용) |

→ Step 1 storage.fl이 한 번도 호출 안 됐던(/health만 검증) 결과. Step 2에서 첫 호출되며 표면화.
→ FreeLang v11 본 CLAUDE.md(`/home/kim/freelang-v11/CLAUDE.md`)는 정확. 우리 프로젝트 CLAUDE.md(`/home/kim/CLAUDE.md`)의 함수명 일부 부정확.

## 검증 결과 (실측)

| # | 시나리오 | 결과 |
|---|----------|------|
| V1 | `/contracts` 빈 상태 | ✅ "계약 없음" empty 박스 |
| V2 | `/contracts/new` | ✅ supplier 자동, items 5행, type 4종 |
| V3 | POST → 302 → 상세 | ✅ `BW-2026-0001`, seq.json `{"2026":1}` |
| V4 | 목록 재진입 | ✅ 1행, 장비공급/회사/22000/작성중/2026-05-10 |
| V5 | 수정 → 저장 | ✅ no/created_at 불변, updated_at만 변경, qty 2→3 후 total 22000→33000 |
| V6 | `<script>alert(1)</script>` 입력 | ✅ 목록·상세에서 `&lt;script&gt;...` |
| V7 | qty=2 price=10000 | ✅ subtotal 20000, vat 2000, total 22000 |

## DB 스키마 (data/contracts/<id>.json)

```json
{
  "id": "ct-<ms>-<rand4>", "no": "BW-2026-0001",
  "type": "supply | install | maintain | etc",
  "status": "draft | sent | signed | done | cancelled",
  "supplier": { "company","biz_no","rep","addr","phone" },
  "client":   { "company","biz_no","rep","addr","phone" },
  "items": [ {"name","spec","qty","price","amount"}, ...5행 고정 ],
  "subtotal": 0, "vat": 0, "total": 0,
  "payment": "", "warranty": "", "notes": "",
  "sign_token": null, "signed_at": null, "signed_by": null,
  "created_at": "...", "updated_at": "..."
}
```

**합계는 서버 계산** — `subtotal=Σ(qty*price)`, `vat=⌊subtotal*0.1⌋`, `total=subtotal+vat`.

## 라우트 매핑

```
server_get  "/contracts"          "handle-list"
server_get  "/contracts/new"      "handle-new"
server_post "/contracts"          "handle-create"   ; 새 id, 채번, supplier 주입, status=draft, redirect
server_get  "/contracts/:id"      "handle-show"
server_get  "/contracts/:id/edit" "handle-edit"
server_post "/contracts/:id"      "handle-update"   ; 머지, no/created_at 보존, redirect
```

## 검증 시나리오

| # | 시나리오 | 기대 |
|---|----------|------|
| V1 | `/contracts` 빈 상태 | "계약 없음" 빈 테이블 |
| V2 | `/contracts/new` | supplier 자동 채움, items 5행 |
| V3 | 폼 저장 → 302 → 상세 | `data/contracts/ct-*.json` 생성, 번호 `BW-2026-0001`, `seq.json` `{"2026":1}` |
| V4 | `/contracts` 재진입 | 1행, 금액·상태, created_at desc |
| V5 | 상세 → 수정 → 저장 | `updated_at`만 변경, `no`/`created_at` 불변 |
| V6 | 품명에 `<script>alert(1)</script>` | `&lt;script&gt;...` 출력 |
| V7 | qty=2 price=10000 | `subtotal=20000 vat=2000 total=22000` |

## 검증 명령

```bash
cd /home/kim/contract-app
node /home/kim/freelang-v11-latest/bootstrap.js run app.fl
# 브라우저: http://localhost:40310/contracts
# 점검: ls data/contracts/, cat data/seq.json
```

## v11 작성 규칙 (강제)

- `[FUNC ...]` X — `defn`만
- 다중 statement는 `(do ...)` 필수
- `(map fn arr)` `(filter fn arr)` — fn-first
- `regex_replace s pat repl` — global
- 핸들러는 문자열 등록: `(server_post "/x" "handle-x")`
- POST body는 `(server_req_body req)` — JSON이면 객체 자동
- path param은 `(server_req_param req "id")`

## 결정사항 (변경 금지)

| 항목 | 값 |
|------|-----|
| 위치 | `/home/kim/contract-app/` |
| 포트 | 40310 |
| 저장 | JSON 파일 (`data/contracts/<id>.json`) |
| 노출 | 로컬 시작, Step 2 검증 후 `dclub deploy contract 40310` |
| 양식 | 표준 장비 공급계약서 → 빅워시 양식 받으면 보정 |
| Repo | https://gogs.dclub.kr/kim/bigwash-contract |
| 런타임 | `node /home/kim/freelang-v11-latest/bootstrap.js run app.fl` |

## Step 2 후 후속

- 검증 통과 → Gogs push
- `dclub deploy contract 40310` (사용자 확인 후)
- CLAUDE.md 정정: `server_static` 미구현 사실 메모리 갱신
- Step 3 (인쇄/PDF — `Ctrl+P`) 진입
