#!/usr/bin/env bash
# Runs the migrations and the RLS isolation test on a throwaway local Postgres.
# Needs Postgres server binaries (apt: postgresql). Run from anywhere: bash supabase/tests/db/run_local.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
[ -x "$PGBIN/initdb" ] || { echo "Postgres server binaries not found"; exit 1; }

WORK="$(mktemp -d)"
PORT=54329
# initdb refuses to run as root, so use the postgres OS user when needed
RUN=""
if [ "$(id -u)" = "0" ]; then
  chown postgres "$WORK"
  RUN="su postgres -s /bin/bash -c"
fi
run() { if [ -n "$RUN" ]; then $RUN "$*"; else bash -c "$*"; fi; }

cleanup() { run "$PGBIN/pg_ctl -D $WORK/data stop -m immediate >/dev/null 2>&1 || true"; rm -rf "$WORK"; }
trap cleanup EXIT

run "$PGBIN/initdb -D $WORK/data -A trust -U postgres >/dev/null"
run "$PGBIN/pg_ctl -D $WORK/data -o \"-p $PORT -k $WORK -c listen_addresses=''\" -l $WORK/log -w start >/dev/null"

PSQL="$PGBIN/psql -h $WORK -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
run "$PSQL -d postgres -c 'create database app'"
run "$PSQL -d app -f $ROOT/supabase/tests/db/local_stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "migration: $(basename "$f")"
  run "$PSQL -d app -f $f"
done

echo "running RLS test"
OUT="$(run "$PGBIN/psql -h $WORK -p $PORT -U postgres -d app -q -f $ROOT/supabase/tests/db/rls_test.sql" 2>&1 || true)"
echo "$OUT"
if echo "$OUT" | grep -q "RLS_TESTS_OK"; then echo "PASS"; else echo "FAIL"; exit 1; fi
