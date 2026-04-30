# bigwash-contract

빅워시(대한이엔지) 자체 계약서 앱 — **FreeLang v11 단일 스택**.

## 원칙

- Zero External Dependency (FreeLang v11 외 npm/패키지 0)
- 백엔드·프론트 모두 `.fl` (서버사이드 HTML, 인라인 JS만 허용)
- JSON 파일 저장 (`data/contracts/<id>.json`)

## 실행

```bash
node /home/kim/freelang-v11-latest/bootstrap.js run app.fl
# → http://localhost:40310
```

## 구조

```
app.fl                  # 진입점
routes/                 # CRUD / 서명 / 인쇄 핸들러
views/                  # HTML 렌더 함수
lib/                    # storage / contract_no / auth / escape / supplier
public/style.css        # 공통 CSS
data/                   # JSON 저장 (contracts/, seq.json, supplier.json)
```

## 파이프라인 위치

```
견적서 (별도 앱) → [전환] → 계약서 (이 앱) → 거래명세서 (예정) → 세금계산서 (예정)
```

## 상태

| Step | 내용 | 상태 |
|------|------|------|
| 1 | 골격 + 저장소 + 채번 + escape + /health | ✅ |
| 2 | 목록·신규·상세 페이지 | 🚧 다음 |
| 3 | 인쇄/PDF 뷰 | ⏸ |
| 4 | 서명 토큰 + 모바일 서명 | ⏸ |
| 5 | 상태 전환 + 검색·통계 | ⏸ |

다음 세션 진입점: [CHECKPOINT.md](./CHECKPOINT.md)
