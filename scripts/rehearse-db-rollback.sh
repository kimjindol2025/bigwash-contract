#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${BIGWASH_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
ROOT_REAL="$(realpath -m "${ROOT_DIR}")"
PROD_DB_REAL="$(realpath -m "${ROOT_DIR}/db/contracts.sqlite")"
FREELANG_BOOTSTRAP="${FREELANG_BOOTSTRAP:-${ROOT_DIR}/../freelang-v11/bootstrap.js}"
REPORT_PATH="/tmp/bigwash-db-rollback-rehearsal.md"

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "치명적 오류: 명령어가 없습니다: ${cmd}" >&2
    exit 1
  }
}

assert_not_repo_path() {
  local target="$1"
  local real_target
  real_target="$(realpath -m "${target}")"

  case "${real_target}" in
    "${ROOT_REAL}"|"${ROOT_REAL}"/*)
      echo "치명적 오류: 저장소 내부 경로는 사용할 수 없습니다: ${real_target}" >&2
      exit 1
      ;;
  esac
  if [[ "${real_target}" == "${PROD_DB_REAL}" ]]; then
    echo "치명적 오류: 운영 DB 경로를 직접 사용합니다: ${real_target}" >&2
    exit 1
  fi
}

run_node_snapshot() {
  local db_file="$1"
  assert_not_repo_path "${db_file}"
  DB_PATH="${db_file}" node <<'NODE'
const { DatabaseSync } = require("node:sqlite");
const crypto = require("node:crypto");
const db = new DatabaseSync(process.env.DB_PATH);

db.prepare("PRAGMA foreign_keys = ON").all();

const tables = ["customers", "sites", "contracts", "equipment", "service_tickets", "care_plans"];

function hashRows(rows) {
  return crypto.createHash("sha256").update(JSON.stringify(rows)).digest("hex");
}

const parts = [];
for (const table of tables) {
  try {
    const cols = db.prepare(`PRAGMA table_info(${table})`).all();
    const orderBy = cols.some((c) => c.name === "id") ? " ORDER BY id" : "";
    const rows = db.prepare(`SELECT * FROM ${table}${orderBy}`).all();
    parts.push(`${table}:${rows.length}:${hashRows(rows)}`);
  } catch (e) {
    parts.push(`${table}:missing`);
  }
}

const overall = crypto.createHash("sha256").update(parts.join("\n")).digest("hex");
console.log(`OVERALL ${overall}`);
for (const p of parts) {
  console.log(p);
}
NODE
}

run_pragma_checks() {
  local db_file="$1"
  assert_not_repo_path "${db_file}"
  DB_PATH="${db_file}" node <<'NODE'
const { DatabaseSync } = require("node:sqlite");
const db = new DatabaseSync(process.env.DB_PATH);

const integrity = db.prepare("PRAGMA integrity_check").all();
const fk = db.prepare("PRAGMA foreign_key_check").all();
const first = integrity[0] && Object.values(integrity[0])[0];
console.log(`integrity=${first || "ok"}`);
console.log(`foreign_key_violations=${fk.length}`);
if (first !== "ok" || fk.length !== 0) process.exit(1);
NODE
}

append() {
  echo "$1" >> "${REPORT_PATH}"
}

append_title() {
  echo -e "\n### $1" >> "${REPORT_PATH}"
}

require_cmd node
require_cmd cp
require_cmd rm

if [[ ! -f "${FREELANG_BOOTSTRAP}" ]]; then
  echo "치명적 오류: bootstrap이 없습니다: ${FREELANG_BOOTSTRAP}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bigwash-db-rollback.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT
case "${TMP_DIR}" in
  "${ROOT_REAL}"/*)
    echo "치명적 오류: 임시 디렉터리가 저장소 내부입니다: ${TMP_DIR}" >&2
    exit 1
    ;;
esac

DB_PATH="${TMP_DIR}/rehearsal-contracts.sqlite"
BACKUP_PATH="${TMP_DIR}/rehearsal-contracts.backup.sqlite"
assert_not_repo_path "${DB_PATH}"
assert_not_repo_path "${BACKUP_PATH}"

{
  echo "# BigWash DB rollback rehearsal"
  echo "작성일: $(date '+%Y-%m-%d %H:%M:%S %:z')"
  echo "root: ${ROOT_DIR}"
  echo "tmp_dir: ${TMP_DIR}"
  echo "db_path: ${DB_PATH}"
  echo "backup_path: ${BACKUP_PATH}"
  echo "bootstrap: ${FREELANG_BOOTSTRAP}"
  echo
} > "${REPORT_PATH}"

append_title "1) 격리 DB init"
append "- running: BIGWASH_REPO_ROOT=${ROOT_DIR} BIGWASH_DB_PATH=${DB_PATH}"
BIGWASH_REPO_ROOT="${ROOT_DIR}" BIGWASH_DB_PATH="${DB_PATH}" node "${FREELANG_BOOTSTRAP}" run "${ROOT_DIR}/src/phase1-db.fl" >"${TMP_DIR}/init.log" 2>&1
append "- init.log: ${TMP_DIR}/init.log"
if grep -qi "error\|failed" "${TMP_DIR}/init.log"; then
  append "- init: FAIL (error in log)"
  append "  $(sed -n '1,5p' "${TMP_DIR}/init.log")"
  exit 1
fi
append "- init: PASS"

append_title "2) fixture 생성"
DB_PATH="${DB_PATH}" node <<'NODE'
const { DatabaseSync } = require("node:sqlite");
const db = new DatabaseSync(process.env.DB_PATH);

db.prepare(
  "INSERT INTO customers (name, phone, email, memo, customer_type, address, migration_status, legacy_client_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
).run("리허설고객", "010-1111-2222", "rehearsal@example.com", "재현용", "CUSTOMER", "서울시 종로구", "VERIFIED", 99001);

const customerId = db.prepare("SELECT id FROM customers WHERE name = ?").get("리허설고객").id;
db.prepare("INSERT INTO sites (customer_id, name, address, contact_phone) VALUES (?, ?, ?, ?)")
  .run(customerId, "리허설사업장", "서울시 종로구 A동", "010-3333-4444");
const siteId = db.prepare("SELECT id FROM sites WHERE customer_id = ?").get(customerId).id;

db.prepare("INSERT INTO care_plans (site_id, plan_code, status, starts_at, ends_at, price_snapshot, included_visits, used_visits, next_inspection_at, memo) VALUES (?, 'TRIAL_90', 'ACTIVE', date('now'), date('now','+90 day'), 0, 90, 10, date('now','+30 day'), 'rehearsal')")
  .run(siteId);
db.prepare("INSERT INTO contracts (number, status, client_id, customer_id, amount) VALUES (?, ?, ?, ?, ?)")
  .run("REHEARSAL-CTR-001", "DRAFT", 99001, customerId, 0);
console.log("fixtures_inserted");
NODE
append "- fixture: PASS"

SNAP_BEFORE="$(run_node_snapshot "${DB_PATH}")"
append "- baseline snapshot"
append "${SNAP_BEFORE}"

append_title "3) WAL checkpoint + backup"
DB_PATH="${DB_PATH}" BACKUP_PATH="${BACKUP_PATH}" node <<'NODE'
const fs = require("node:fs");
const { DatabaseSync } = require("node:sqlite");

const source = process.env.DB_PATH;
const dest = process.env.BACKUP_PATH;
const db = new DatabaseSync(source);
db.prepare("PRAGMA wal_checkpoint(FULL)").all();
db.close();
fs.copyFileSync(source, dest);
console.log("backup_created");
NODE
append "- checkpoint+backup: PASS"
append "- backup_file: ${BACKUP_PATH}"

append_title "4) 의도적 변경"
DB_PATH="${DB_PATH}" node <<'NODE'
const { DatabaseSync } = require("node:sqlite");
const db = new DatabaseSync(process.env.DB_PATH);

const memoRow = db.prepare("SELECT id FROM customers WHERE name = '리허설고객'").get();
if (memoRow && memoRow.id) {
  db.prepare("UPDATE customers SET memo = ? WHERE id = ?").run("변경됨-" + Date.now(), memoRow.id);
}

const siteRow = db.prepare("SELECT id FROM sites WHERE name = '리허설사업장'").get();
if (siteRow && siteRow.id) {
  db.prepare("INSERT INTO equipment (site_id, category, model, serial_number, status) VALUES (?, 'WASHER', 'X1', 'SN-' || hex(randomblob(4)), 'ACTIVE')").run(siteRow.id);
  db.prepare("INSERT INTO service_tickets (site_id, symptom, priority, source, scheduled_at) VALUES (?, '리허설증상', 'NORMAL', 'PHONE', datetime('now'))").run(siteRow.id);
}
console.log("intentional_change_applied");
NODE

SNAP_MUT="$(run_node_snapshot "${DB_PATH}")"
append "- mutated snapshot"
append "${SNAP_MUT}"

BEFORE_HASH="$(printf '%s\n' "${SNAP_BEFORE}" | awk '/^OVERALL /{print $2}')"
MUTATED_HASH="$(printf '%s\n' "${SNAP_MUT}" | awk '/^OVERALL /{print $2}')"
if [[ "${BEFORE_HASH}" == "${MUTATED_HASH}" ]]; then
  append "- mutation_check: FAIL (baseline과 변경 후 해시가 동일)"
  echo "intentional mutation did not change the snapshot" >&2
  exit 1
fi
append "- mutation_check: PASS"

append_title "5) restore from backup"
cp "${BACKUP_PATH}" "${DB_PATH}"
append "- restored db copied from backup"

SNAP_RESTORED="$(run_node_snapshot "${DB_PATH}")"
append "- restored snapshot"
append "${SNAP_RESTORED}"

append_title "6) integrity + fk check + hash 비교"
while IFS= read -r line; do
  append "- ${line}"
done < <(run_pragma_checks "${DB_PATH}")

RESTORED_HASH="$(printf '%s\n' "${SNAP_RESTORED}" | awk '/^OVERALL /{print $2}')"
if [[ "${BEFORE_HASH}" == "${RESTORED_HASH}" ]]; then
  append "- hash_match: PASS"
else
  append "- hash_match: FAIL"
fi

append "- before_hash=${BEFORE_HASH}"
append "- restored_hash=${RESTORED_HASH}"
append "- rehearsal_result=$([ "${BEFORE_HASH}" = "${RESTORED_HASH}" ] && echo PASS || echo FAIL)"
append "- report: ${REPORT_PATH}"
append "- production-db direct-write: blocked by realpath guards"
append "- temporary artifacts cleanup: trap rm -rf ${TMP_DIR}"

if [[ "${BEFORE_HASH}" != "${RESTORED_HASH}" ]]; then
  echo "hash mismatch" >&2
  exit 1
fi

echo "rehearsal complete" >> "${REPORT_PATH}"
