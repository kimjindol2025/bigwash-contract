#!/usr/bin/env bash
set -euo pipefail

# BigWash 6주차 회귀 자동화·파일럿 준비 검증 스크립트.
#
# 이 스크립트는 읽기 전용 검증만 수행한다 — 다음 동작은 **절대 하지 않는다**:
#   운영 배포, 운영 DB(db/contracts.sqlite) 마이그레이션, PM2 재시작, SSH 접속,
#   git pull/push. 그런 명령을 이 스크립트에 추가하지 말 것 — 승인이 필요한
#   작업은 docs/10-week6-readiness.md의 "승인 필요 명령" 절에서 사람이 직접
#   실행한다.
#
# 검증 순서: (1) tests/test_*.fl 17종 직렬 실행(mktemp 격리 DB)
#            (2) Admin/운영 기록실 UI 인라인 <script> 구문 검사(new Function)
#            (3) OpenAPI YAML parse + 코드↔spec API 라우트 76개 완전일치
#            (4) git diff --check (공백 오류)
#            (5) 격리 HTTP 인증·오류 노출 공격 검증
#            (6) 격리 DB 백업·변경·복원 리허설
#
# 사용법: scripts/verify-week6.sh
# 환경변수: BIGWASH_REPO_ROOT(선택, 저장소 루트 강제 지정)
#           FREELANG_BOOTSTRAP(선택, freelang-v11/bootstrap.js 강제 지정)

# ---- 0. 저장소 위치 자체 계산 ----
# 노드마다 절대경로가 다르므로 이 스크립트 자신의 위치를 기준으로 저장소
# 루트를 계산한다(scripts/migrate-phase1.sh, docs/RUN_GUIDE.md와 동일 원칙).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${BIGWASH_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# FreeLang v11 bootstrap 위치도 배포마다 다르다. FREELANG_BOOTSTRAP을 명시하면
# 그 값을 쓰고, 없으면 저장소의 형제 디렉터리(<ROOT_DIR>/../freelang-v11)를
# 기본값으로 가정한다(scripts/migrate-phase1.sh와 동일 관례).
FREELANG_BOOTSTRAP="${FREELANG_BOOTSTRAP:-${ROOT_DIR}/../freelang-v11/bootstrap.js}"

if [[ ! -f "${FREELANG_BOOTSTRAP}" ]]; then
  echo "FreeLang bootstrap을 찾을 수 없습니다: ${FREELANG_BOOTSTRAP}" >&2
  echo "FREELANG_BOOTSTRAP 환경변수로 실제 경로를 지정하세요." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node를 찾을 수 없습니다 — FreeLang 실행에 필요합니다." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3을 찾을 수 없습니다 — OpenAPI YAML 검증에 필요합니다." >&2
  exit 1
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "python3의 PyYAML(yaml 모듈)을 찾을 수 없습니다 — 'pip install pyyaml'로 설치하세요." >&2
  exit 1
fi

# 운영 DB 경로(참조용) — 아래 하드 가드가 테스트 DB 경로와 절대 겹치지
# 않는지 이 값과 대조한다. 이 스크립트는 이 파일을 열거나 쓰지 않는다.
PROD_DB_PATH="${ROOT_DIR}/db/contracts.sqlite"
PROD_DB_REAL="$(realpath -m "${PROD_DB_PATH}")"

echo "=== BigWash 6주차 회귀 자동화·파일럿 준비 검증 ==="
echo "저장소 루트     : ${ROOT_DIR}"
echo "FreeLang bootstrap: ${FREELANG_BOOTSTRAP}"
echo "운영 DB(미사용) : ${PROD_DB_REAL}"
echo

FAILED=0
declare -a SUMMARY=()

section() {
  echo
  echo "--- $1 ---"
}

# ============================================================
# 1. tests/test_*.fl 정확히 17종, 직렬 실행, mktemp 격리 DB
# ============================================================
# `test_contract.fl`은 기존 Contract 도메인 스모크, `test_contract_management.fl`은
# Care 계약 관리 회귀(실제 운영 경로) 확장을 보완한다.
EXPECTED_TEST_COUNT=17
section "1. 회귀 테스트 ${EXPECTED_TEST_COUNT}종 (직렬 실행, mktemp 격리 DB)"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bigwash-week6-verify.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

# 하드 가드: mktemp 결과가 실수로라도 저장소 안쪽이면 즉시 중단한다 — 격리
# 디렉터리는 반드시 저장소 밖(시스템 임시 디렉터리)에 있어야 한다.
case "${TMP_DIR}" in
  "${ROOT_DIR}"/*)
    echo "치명적 오류: 임시 디렉터리가 저장소 내부에 생성됐습니다 — 중단: ${TMP_DIR}" >&2
    exit 1
    ;;
esac

# 이 목록이 정확히 EXPECTED_TEST_COUNT종이어야 한다(개수 자체를 코드로 단정).
TEST_FILES=(
  test_contract.fl
  test_phase1_migration.fl
  test_washcare.fl
  test_incoming_call.fl
  test_call_events.fl
  test_part_sales_outreach.fl
  test_customer_2nd_phase.fl
  test_site_checklist.fl
  test_customer_consultation.fl
  test_sales_flow.fl
  test_contract_management.fl
  test_ops_summary.fl
  test_ops_weekly.fl
  test_careplan.fl
  test_field_service_qa.fl
  test_security_gate.fl
  test_wash_operations.fl
)

if [[ ${#TEST_FILES[@]} -ne ${EXPECTED_TEST_COUNT} ]]; then
  echo "내부 오류: TEST_FILES 목록이 ${EXPECTED_TEST_COUNT}종이 아닙니다(${#TEST_FILES[@]}개) — 스크립트 버그" >&2
  exit 1
fi

# tests/ 디렉터리 실제 내용과 위 목록이 정확히 일치하는지 확인 — 새 테스트
# 파일이 추가/삭제됐는데 이 스크립트가 갱신되지 않은 드리프트를 잡는다.
ACTUAL_TESTS="$(cd "${ROOT_DIR}/tests" && ls test_*.fl | sort | tr '\n' ' ')"
EXPECTED_TESTS="$(printf '%s\n' "${TEST_FILES[@]}" | sort | tr '\n' ' ')"
if [[ "${ACTUAL_TESTS}" != "${EXPECTED_TESTS}" ]]; then
  echo "테스트 목록 드리프트 감지 — tests/ 디렉터리와 이 스크립트의 TEST_FILES가 다릅니다:" >&2
  echo "  실제 tests/: ${ACTUAL_TESTS}" >&2
  echo "  스크립트 기대: ${EXPECTED_TESTS}" >&2
  exit 1
fi

TEST_PASS=0
TEST_FAIL=0
FAILED_TEST_NAMES=()

for t in "${TEST_FILES[@]}"; do
  DB_PATH="${TMP_DIR}/${t%.fl}.sqlite"
  DB_REAL="$(realpath -m "${DB_PATH}")"

  # 하드 가드: 테스트 DB 경로가 운영 DB(db/contracts.sqlite)와 절대 같을 수
  # 없다. mktemp 격리 디렉터리 하위 경로만 허용한다.
  if [[ "${DB_REAL}" == "${PROD_DB_REAL}" ]]; then
    echo "치명적 오류: 테스트 DB 경로가 운영 DB와 동일합니다 — 중단" >&2
    exit 1
  fi
  case "${DB_REAL}" in
    "${TMP_DIR}"/*) : ;;
    *)
      echo "치명적 오류: 테스트 DB 경로(${DB_REAL})가 격리 디렉터리(${TMP_DIR}) 밖입니다 — 중단" >&2
      exit 1
      ;;
  esac

  printf '  %-32s ... ' "${t}"
  LOG_FILE="${TMP_DIR}/${t}.log"
  # 직렬 실행: 다음 테스트로 넘어가기 전에 반드시 이 테스트가 끝난다(백그라운드
  # 실행·& 없음, FreeLang v11 실행기는 병렬 프로세스 간 공유 상태가 충돌할 수
  # 있으므로 — docs/RUN_GUIDE.md "테스트" 절과 동일 원칙).
  if [[ "${t}" == "test_security_gate.fl" ]]; then
    TEST_COMMAND_OK=0
    BIGWASH_SKIP_SERVER_START=1 BIGWASH_DB_PATH="${DB_PATH}" node "${FREELANG_BOOTSTRAP}" run "${ROOT_DIR}/tests/${t}" >"${LOG_FILE}" 2>&1 || TEST_COMMAND_OK=$?
  else
    TEST_COMMAND_OK=0
    BIGWASH_DB_PATH="${DB_PATH}" node "${FREELANG_BOOTSTRAP}" run "${ROOT_DIR}/tests/${t}" >"${LOG_FILE}" 2>&1 || TEST_COMMAND_OK=$?
  fi

  if [[ ${TEST_COMMAND_OK} -eq 0 ]]; then
    echo "PASS"
    TEST_PASS=$((TEST_PASS + 1))
  else
    echo "FAIL"
    TEST_FAIL=$((TEST_FAIL + 1))
    FAILED_TEST_NAMES+=("${t}")
    FAILED=1
    echo "    로그 마지막 20줄 (${LOG_FILE}):"
    tail -n 20 "${LOG_FILE}" | sed 's/^/    | /'
  fi
done

if [[ ${TEST_FAIL} -eq 0 ]]; then
  SUMMARY+=("테스트 ${EXPECTED_TEST_COUNT}종: ${TEST_PASS}/${EXPECTED_TEST_COUNT} PASS")
else
  SUMMARY+=("테스트 ${EXPECTED_TEST_COUNT}종: ${TEST_PASS}/${EXPECTED_TEST_COUNT} PASS, ${TEST_FAIL}개 FAIL(${FAILED_TEST_NAMES[*]})")
fi

# ============================================================
# 2. Admin/운영 기록실 UI 인라인 <script> 구문 검사 (new Function)
# ============================================================
section "2. Admin/운영 기록실 UI 인라인 스크립트 구문 검사 (new Function)"

ADMIN_HTML="${ROOT_DIR}/src/washcare-admin.html"
OPERATIONS_HTML="${ROOT_DIR}/src/operations-admin.html"
if ADMIN_CHECK_OUT="$(node -e '
const fs = require("fs");
for (const path of process.argv.slice(1)) {
  const html = fs.readFileSync(path, "utf8");
  const m = html.match(/<script>([\s\S]*?)<\/script>/i);
  if (!m) { console.error(`script block not found: ${path}`); process.exit(1); }
  new Function(m[1]);
}
console.log("admin and operations inline script syntax ok");
' "${ADMIN_HTML}" "${OPERATIONS_HTML}")"; then
  echo "  ${ADMIN_CHECK_OUT}"
  SUMMARY+=("Admin inline script 구문: OK")
else
  echo "  ${ADMIN_CHECK_OUT}"
  FAILED=1
  SUMMARY+=("Admin inline script 구문: FAIL")
fi

# ============================================================
# 3. OpenAPI YAML parse + 코드↔spec API 라우트 76개 완전일치
# ============================================================
section "3. OpenAPI YAML parse + 코드↔spec API 라우트 76개 완전일치"

if ROUTE_CHECK_OUT="$(python3 - "${ROOT_DIR}" <<'PY'
import sys, re, json
import yaml

root = sys.argv[1]

with open(root + "/docs/openapi-washcare.yaml") as f:
    spec = yaml.safe_load(f)

methods = {"get", "post", "put", "delete", "patch"}
spec_ops = {
    (k, p)
    for p, item in spec["paths"].items()
    for k in item
    if k in methods
}

with open(root + "/src/washcare-api.fl") as f:
    code = f.read()

code_ops = set()
for m in re.finditer(r'\(server_(get|post|put|delete|patch)\s+"([^"]+)"', code):
    method, path = m.group(1), m.group(2)
    # 정적 루트(/)와 정적 Admin UI(/care/admin)는 JSON API 스펙 대상이 아니다
    # (docs/04-washcare-api.md, docs/openapi-washcare.yaml과 동일 원칙).
    if path in ("/", "/care/admin", "/care/operations", "/favicon.ico"):
        continue
    # FreeLang 라우트는 :id 스타일, OpenAPI는 {id} 스타일이라 변환해서 비교한다.
    openapi_path = re.sub(r":([a-zA-Z_]+)", r"{\1}", path)
    code_ops.add((method, openapi_path))

only_in_code = sorted(code_ops - spec_ops)
only_in_spec = sorted(spec_ops - code_ops)

print(f"  spec operation count: {len(spec_ops)} (기대 76)")
print(f"  code operation count: {len(code_ops)} (기대 76)")
print(f"  code에만 있음: {only_in_code}")
print(f"  spec에만 있음: {only_in_spec}")

ok = (
    len(spec_ops) == 76
    and len(code_ops) == 76
    and not only_in_code
    and not only_in_spec
)
sys.exit(0 if ok else 1)
PY
)"; then
  echo "${ROUTE_CHECK_OUT}"
  SUMMARY+=("OpenAPI YAML parse + 라우트 76개 대조: OK (완전일치)")
else
  echo "${ROUTE_CHECK_OUT}"
  FAILED=1
  SUMMARY+=("OpenAPI YAML parse + 라우트 76개 대조: FAIL")
fi

# ============================================================
# 4. git diff --check (공백 오류)
# ============================================================
section "4. git diff --check"

if GIT_DIFF_OUT="$(cd "${ROOT_DIR}" && git diff --check)"; then
  if [[ -n "${GIT_DIFF_OUT}" ]]; then
    echo "${GIT_DIFF_OUT}"
  else
    echo "  (변경 없음 또는 공백 오류 없음)"
  fi
  SUMMARY+=("git diff --check: OK (공백 오류 없음)")
else
  echo "${GIT_DIFF_OUT}"
  FAILED=1
  SUMMARY+=("git diff --check: FAIL (공백 오류 발견 — 위 출력 참조)")
fi

# ============================================================
# 5. 격리 HTTP 보안 검증
# ============================================================
section "5. 격리 HTTP 인증·오류 노출 검증"

if "${ROOT_DIR}/scripts/verify-security-http.sh" >/dev/null 2>&1; then
  echo "  fail-closed/API key/Admin Basic/public token/error sanitize: PASS"
  SUMMARY+=("격리 HTTP 보안 검증: OK")
else
  echo "  격리 HTTP 보안 검증: FAIL"
  FAILED=1
  SUMMARY+=("격리 HTTP 보안 검증: FAIL")
fi

# ============================================================
# 6. 격리 DB 백업·변경·복원 리허설
# ============================================================
section "6. 격리 DB 백업·복원 리허설"

if "${ROOT_DIR}/scripts/rehearse-db-rollback.sh" >/dev/null 2>&1; then
  echo "  backup → mutation → restore → integrity/FK/hash: PASS"
  SUMMARY+=("격리 DB 백업·복원 리허설: OK")
else
  echo "  격리 DB 백업·복원 리허설: FAIL"
  FAILED=1
  SUMMARY+=("격리 DB 백업·복원 리허설: FAIL")
fi

# ============================================================
# 요약
# ============================================================
section "요약"
for line in "${SUMMARY[@]}"; do
  echo "- ${line}"
done

echo
if [[ ${FAILED} -eq 0 ]]; then
  echo "전체 통과."
  exit 0
else
  echo "실패 항목이 있습니다 — 위 로그를 확인하세요." >&2
  exit 1
fi
