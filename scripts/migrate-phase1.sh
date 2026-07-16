#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root/apps/bigwash-contract"
DB_PATH="${BIGWASH_DB_PATH:-${ROOT_DIR}/db/contracts.sqlite}"
BACKUP_DIR="${ROOT_DIR}/db/backups"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_PATH="${BACKUP_DIR}/contracts-before-phase1-${TIMESTAMP}.sqlite"

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
  node /root/kim/freelang-v11/bootstrap.js run "${ROOT_DIR}/src/phase1-db.fl"

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
