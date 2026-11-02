#!/usr/bin/env bash
# Prove that a backup can be restored, WITHOUT touching the live site.
#
# Usage: scripts/restore-test.sh [backup-dir]     (default: newest in ~/ojs-backups)
#
# 1. verifies the checksums
# 2. restores db.sql.gz into a throwaway MariaDB (same image, no network, data in RAM)
#    and compares the exact row count of every table with the live database
# 3. extracts files.tar.gz to a temp dir and compares file counts with the live volumes
# 4. writes the result to <backup-dir>/RESTORE_TEST.txt, cleans everything up
# Exit code 0 = PASS. Rows that change on their own (sessions, stats, jobs) are reported
# as INFO when the backup is older than the live data.
set -euo pipefail
cd "$(dirname "$0")/.."
BACKUP_ROOT=${BACKUP_ROOT:-$HOME/ojs-backups}
B=${1:-$(ls -1d "$BACKUP_ROOT"/20* | sort | tail -1)}
NAME=ojs-restore-test-$$
DB_IMAGE=$(docker inspect -f '{{.Config.Image}}' pkp_db_ojs)
WORK=$(mktemp -d "$BACKUP_ROOT/.restore-test.XXXXXX")
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf -- "$WORK"; }
trap cleanup EXIT
result=PASS
say() { echo "$*" | tee -a "$WORK/report"; }

say "restore test of $B  ($(date -Is))"

# 1. Checksums
( cd "$B" && sha256sum -c --quiet SHA256SUMS ) && say "[1/3] checksums OK" || { say "[1/3] checksums FAILED"; exit 1; }

# 2. Database
docker run -d --name "$NAME" --network none --tmpfs /var/lib/mysql:rw,size=2g \
  -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1 "$DB_IMAGE" >/dev/null
ready=no
for i in $(seq 1 90); do   # the final server (not the temporary init one) listens on port 3306
  logs=$(docker logs "$NAME" 2>&1 || true)
  if grep -q 'port: 3306' <<<"$logs"; then ready=yes; break; fi
  sleep 1
done
[ "$ready" = yes ] || { say "[2/3] throwaway MariaDB did not start"; exit 1; }
gunzip -c "$B/db.sql.gz" | docker exec -i "$NAME" mariadb -uroot
DBN=$(docker exec pkp_db_ojs printenv MYSQL_DATABASE)

counts() {  # $1 = "live" or "restored" ; prints "table count" lines
  local q="SELECT GROUP_CONCAT(CONCAT('SELECT ''',table_name,''', COUNT(*) FROM \`',table_name,'\`') SEPARATOR ' UNION ALL ') FROM information_schema.tables WHERE table_schema='$DBN' AND table_type='BASE TABLE'"
  if [ "$1" = live ]; then
    docker exec -i pkp_db_ojs sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mariadb -uroot -N "$0"' "$DBN" \
      <<<"SET SESSION group_concat_max_len=1000000; SET @q=($q); PREPARE s FROM @q; EXECUTE s;"
  else
    docker exec -i "$NAME" mariadb -uroot -N "$DBN" \
      <<<"SET SESSION group_concat_max_len=1000000; SET @q=($q); PREPARE s FROM @q; EXECUTE s;"
  fi | sort
}
counts live > "$WORK/live.txt"; counts restored > "$WORK/restored.txt"
nl=$(wc -l < "$WORK/live.txt"); nr=$(wc -l < "$WORK/restored.txt")
volatile='^(sessions|usage_stats_.*|jobs|job_batches|failed_jobs|access_keys|email_log.*|notifications|event_log.*|metrics_.*|cache)$'
diffs=$(join -a1 -a2 -e MISSING -o 0,1.2,2.2 "$WORK/live.txt" "$WORK/restored.txt" | awk '$2!=$3')
hard=$(echo "$diffs" | awk -v v="$volatile" 'NF && $1 !~ v')
soft=$(echo "$diffs" | awk -v v="$volatile" 'NF && $1 ~ v')
say "[2/3] database: $nr tables restored (live: $nl), rows compared table by table"
[ -n "$soft" ] && say "      INFO tables that change by themselves (live vs backup): $(echo "$soft" | awk '{printf "%s(%s/%s) ",$1,$2,$3}')"
if [ -n "$hard" ] || [ "$nl" != "$nr" ]; then
  result=FAIL; say "      MISMATCH (table live backup): $(echo "$hard" | tr '\n' ';')"
else
  say "      all other tables identical"
fi
say "      sample: $(grep -E '^(journals|users|sections|issues|submissions|navigation_menu_items|journal_settings)[[:space:]]' "$WORK/restored.txt" | tr '\t\n' '= ')"

# 3. Files
mkdir -p "$WORK/files"; tar -xzf "$B/files.tar.gz" -C "$WORK/files"
for d in volumes/config volumes/private volumes/public volumes/themes; do
  [ -d "$d" ] || continue
  live=$(find "$d" -type f | wc -l); rest=$(find "$WORK/files/$d" -type f 2>/dev/null | wc -l)
  if [ "$live" = "$rest" ]; then say "[3/3] $d: $rest files OK"
  else say "[3/3] $d: backup has $rest files, live has $live (expected if files changed since the backup)"; fi
done
[ -s "$WORK/files/.env" ] && say "      .env present in backup" || { say "      .env MISSING from backup"; result=FAIL; }

say "RESULT: $result"
cp "$WORK/report" "$B/RESTORE_TEST.txt"
[ "$result" = PASS ]
