#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${BIGWASH_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
FREELANG_BOOTSTRAP="${FREELANG_BOOTSTRAP:-${ROOT_DIR}/../freelang-v11/bootstrap.js}"
PORT="${BIGWASH_SECURITY_TEST_PORT:-40399}"
BASE_URL="http://127.0.0.1:${PORT}"
PROD_DB_REAL="$(realpath -m "${ROOT_DIR}/db/contracts.sqlite")"

for required in node curl realpath mktemp; do
  if ! command -v "${required}" >/dev/null 2>&1; then
    echo "필수 명령이 없습니다: ${required}" >&2
    exit 1
  fi
done

if [[ ! -f "${FREELANG_BOOTSTRAP}" ]]; then
  echo "FreeLang bootstrap을 찾을 수 없습니다: ${FREELANG_BOOTSTRAP}" >&2
  exit 1
fi

if command -v ss >/dev/null 2>&1 && ss -tln | grep -q ":${PORT} "; then
  echo "보안 검증 포트가 이미 사용 중입니다: ${PORT}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bigwash-security-http.XXXXXX")"
DB_PATH="${TMP_DIR}/security.sqlite"
LOG_PATH="${TMP_DIR}/server.log"
SERVER_PID=""
REQUEST_SEQ=0

if [[ "$(realpath -m "${DB_PATH}")" == "${PROD_DB_REAL}" ]]; then
  echo "격리 DB가 운영 DB와 같습니다 — 중단" >&2
  exit 1
fi

cleanup_server() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
  SERVER_PID=""
}

cleanup() {
  cleanup_server
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

start_server() {
  cleanup_server
  rm -f "${DB_PATH}" "${DB_PATH}-wal" "${DB_PATH}-shm"
  : > "${LOG_PATH}"
  env -u BIGWASH_INTERNAL_API_KEY \
      -u BIGWASH_ADMIN_BASIC_AUTH \
      -u BIGWASH_ALLOW_INSECURE_DEV \
      BIGWASH_REPO_ROOT="${ROOT_DIR}" \
      BIGWASH_DB_PATH="${DB_PATH}" \
      BIGWASH_CARE_PORT="${PORT}" \
      "$@" \
      node "${FREELANG_BOOTSTRAP}" run "${ROOT_DIR}/src/washcare-api.fl" \
      >"${LOG_PATH}" 2>&1 &
  SERVER_PID=$!

  for _ in $(seq 1 50); do
    if curl -sS -o /dev/null "${BASE_URL}/care/status/readiness-probe" 2>/dev/null; then
      return 0
    fi
    if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
      echo "격리 서버가 시작 전에 종료됐습니다:" >&2
      tail -n 30 "${LOG_PATH}" >&2
      return 1
    fi
    sleep 0.1
  done
  echo "격리 서버 시작 시간 초과: ${PORT}" >&2
  return 1
}

request_expect() {
  local label="$1"
  local expected="$2"
  shift 2
  REQUEST_SEQ=$((REQUEST_SEQ + 1))
  local body="${TMP_DIR}/response-${REQUEST_SEQ}.body"
  local headers="${TMP_DIR}/response-${REQUEST_SEQ}.headers"
  local status
  status="$(curl -sS -D "${headers}" -o "${body}" -w '%{http_code}' "$@")"
  if [[ "${status}" != "${expected}" ]]; then
    echo "FAIL ${label}: expected ${expected}, got ${status}" >&2
    sed -n '1,30p' "${headers}" >&2
    sed -n '1,20p' "${body}" >&2
    exit 1
  fi
  LAST_BODY="${body}"
  LAST_HEADERS="${headers}"
  echo "PASS ${label}: ${status}"
}

assert_header() {
  local label="$1"
  local pattern="$2"
  if ! grep -qiE "${pattern}" "${LAST_HEADERS}"; then
    echo "FAIL ${label}: header pattern missing: ${pattern}" >&2
    sed -n '1,30p' "${LAST_HEADERS}" >&2
    exit 1
  fi
  echo "PASS ${label}"
}

assert_body_clean() {
  local label="$1"
  if grep -qiE '/home/|__flCallStack|"stack"|at line|db_exec|SQLITE|constraint failed|SELECT |INSERT |UPDATE |DELETE ' "${LAST_BODY}"; then
    echo "FAIL ${label}: internal detail leaked" >&2
    sed -n '1,20p' "${LAST_BODY}" >&2
    exit 1
  fi
  echo "PASS ${label}"
}

KEY="security-http-test-key"
BASIC="Basic d2FzaGNhcmU6c2VjdXJpdHktdGVzdA=="

echo "--- fail-closed 기본값 ---"
start_server
request_expect "무키 내부 API" 401 "${BASE_URL}/care/customers"
assert_header "API 401 no-store" '^Cache-Control: no-store'
request_expect "무인증 Admin" 401 "${BASE_URL}/care/admin"
assert_header "Admin Basic challenge" '^WWW-Authenticate: Basic realm="BigWash Admin"'
assert_header "Admin 401 no-store" '^Cache-Control: no-store'
request_expect "무인증 루트" 401 "${BASE_URL}/"
request_expect "favicon 정적 응답" 204 "${BASE_URL}/favicon.ico"
request_expect "공개 토큰 모델 유지" 404 "${BASE_URL}/care/status/not-a-real-token"

echo "--- 키·Basic 분리 ---"
start_server BIGWASH_INTERNAL_API_KEY="${KEY}" BIGWASH_ADMIN_BASIC_AUTH="${BASIC}"
request_expect "정확한 API 키" 200 -H "x-api-key: ${KEY}" "${BASE_URL}/care/customers"
request_expect "잘못된 API 키" 401 -H "x-api-key: wrong" "${BASE_URL}/care/customers"
request_expect "Basic을 API 키로 사용" 401 -H "x-api-key: ${BASIC}" "${BASE_URL}/care/customers"
request_expect "Basic만으로 API 호출" 401 -H "Authorization: ${BASIC}" "${BASE_URL}/care/customers"
request_expect "정확한 Admin Basic" 200 -H "Authorization: ${BASIC}" "${BASE_URL}/care/admin"
request_expect "잘못된 Admin Basic" 401 -H "Authorization: Basic wrong" "${BASE_URL}/care/admin"
request_expect "Admin Basic으로 운영 API 호출" 200 -H "Authorization: ${BASIC}" "${BASE_URL}/care/operations/sites"
request_expect "API 키로 운영 API 호출" 200 -H "x-api-key: ${KEY}" "${BASE_URL}/care/operations/sites"
request_expect "잘못된 Basic으로 운영 API 호출" 401 -H "Authorization: Basic wrong" "${BASE_URL}/care/operations/sites"
request_expect "인증된 루트 리다이렉트" 302 -H "Authorization: ${BASIC}" "${BASE_URL}/"
request_expect "에러 본문 새니타이즈" 400 -H "x-api-key: ${KEY}" -H 'Content-Type: application/json' -d '{}' -X POST "${BASE_URL}/care/customers"
assert_body_clean "경로·스택·DB 정보 비노출"
request_expect "통화 webhook 무키" 401 -H 'Content-Type: application/json' -d '{}' -X POST "${BASE_URL}/care/call-events"
request_expect "통화 webhook 오키" 401 -H 'Content-Type: application/json' -d '{}' -X POST "${BASE_URL}/care/call-events?key=wrong"

echo "--- 명시적 개발 예외 ---"
start_server BIGWASH_ALLOW_INSECURE_DEV=1 BIGWASH_ADMIN_BASIC_AUTH="${BASIC}"
request_expect "ALLOW=1 내부 API" 200 "${BASE_URL}/care/customers"
request_expect "ALLOW=1이어도 Admin 무인증 거부" 401 "${BASE_URL}/care/admin"
request_expect "ALLOW=1 Admin Basic" 200 -H "Authorization: ${BASIC}" "${BASE_URL}/care/admin"

echo "--- 유사 플래그 거부 ---"
start_server BIGWASH_ALLOW_INSECURE_DEV=true BIGWASH_ADMIN_BASIC_AUTH="${BASIC}"
request_expect "ALLOW=true 거부" 401 "${BASE_URL}/care/customers"

if grep -Fq "${KEY}" "${LOG_PATH}" || grep -Fq "${BASIC}" "${LOG_PATH}"; then
  echo "FAIL 서버 로그에 테스트 시크릿이 노출됐습니다" >&2
  exit 1
fi

echo "Security HTTP verification passed."
