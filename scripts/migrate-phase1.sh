#!/usr/bin/env bash
set -euo pipefail

# 저장소 위치는 노드마다 다르므로(과거 /root/apps/bigwash-contract 고정 경로는
# 폐기됨 — docs/RUN_GUIDE.md, README.md와 동일 원칙) 이 스크립트 자신의 위치
# 기준으로 저장소 루트를 계산한다. BIGWASH_REPO_ROOT가 있으면 그 값을 우선한다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${BIGWASH_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
DB_PATH="${BIGWASH_DB_PATH:-${ROOT_DIR}/db/contracts.sqlite}"
BACKUP_DIR="${ROOT_DIR}/db/backups"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_PATH="${BACKUP_DIR}/contracts-before-phase1-${TIMESTAMP}.sqlite"

# FreeLang v11 bootstrap 위치도 배포마다 다르다. FREELANG_BOOTSTRAP을 명시하면
# 그 값을 쓰고, 없으면 저장소의 형제 디렉터리(<ROOT_DIR>/../freelang-v11)를
# 기본값으로 가정한다(README.md/docs/RUN_GUIDE.md가 문서화하는 배포 레이아웃과
# 동일 — 예: /root/kim/bigwash-contract 옆의 /root/kim/freelang-v11).
FREELANG_BOOTSTRAP="${FREELANG_BOOTSTRAP:-${ROOT_DIR}/../freelang-v11/bootstrap.js}"

if [[ ! -f "${FREELANG_BOOTSTRAP}" ]]; then
  echo "FreeLang bootstrap을 찾을 수 없습니다: ${FREELANG_BOOTSTRAP}" >&2
  echo "FREELANG_BOOTSTRAP 환경변수로 실제 경로를 지정하세요." >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

# The API must be stopped before this script. Checkpoint first so a raw copy
# cannot omit committed transactions that are still in the SQLite WAL file.
node -e '
const fs = require("node:fs");
const { DatabaseSync } = require("node:sqlite");
const [source, destination] = process.argv.slice(1);
const db = new DatabaseSync(source);
const checkpoint = db.prepare("PRAGMA wal_checkpoint(FULL)").all();
db.close();
fs.copyFileSync(source, destination);
console.log(JSON.stringify({ checkpoint }));
' "${DB_PATH}" "${BACKUP_PATH}"
echo "Backup created: ${BACKUP_PATH}"

BIGWASH_DB_PATH="${DB_PATH}" \
  node "${FREELANG_BOOTSTRAP}" run "${ROOT_DIR}/src/phase1-db.fl"

node -e '
const { DatabaseSync } = require("node:sqlite");
const path = process.argv[1];
const db = new DatabaseSync(path, { readOnly: true });
const unmapped = db.prepare("SELECT COUNT(*) AS count FROM contracts WHERE customer_id IS NULL").get().count;
const foreignKeys = db.prepare("PRAGMA foreign_key_check").all();
db.close();
if (unmapped !== 0 || foreignKeys.length !== 0) {
  console.error(JSON.stringify({ unmapped, foreignKeys }, null, 2));
  process.exit(1);
}
console.log("Phase 1 migration verified: no unmapped contracts or foreign-key errors");
' "${DB_PATH}"
