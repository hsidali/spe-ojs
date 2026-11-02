#!/usr/bin/env bash
# Back up OJS: database dump + config, uploaded files, theme, .env, compose files.
#
# Usage:   scripts/backup.sh [label]          (run from anywhere)
# Output:  $BACKUP_ROOT/<YYYYmmdd-HHMMSS>[-label]/   (default ~/ojs-backups, mode 700)
# Options (env vars):
#   BACKUP_ROOT   where backups go           (default: ~/ojs-backups)
#   KEEP          keep only the N newest     (default: unset = never delete anything)
#   DB_CONTAINER  database container name    (default: pkp_db_ojs)
#
# Secrets: the DB password is read from .env and passed to the container on stdin,
# so it never appears on a command line or in the output.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR=$PWD
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/ojs-backups}"
DB_CONTAINER="${DB_CONTAINER:-pkp_db_ojs}"
STAMP=$(date +%Y%m%d-%H%M%S)
DEST="$BACKUP_ROOT/$STAMP${1:+-$1}"

umask 077
mkdir -p "$DEST"
chmod 700 "$BACKUP_ROOT" "$DEST"

# Read one value from .env without sourcing the whole file.
envget() {
  grep -E "^$1=" "$PROJECT_DIR/.env" 2>/dev/null | tail -1 | cut -d= -f2- \
    | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true
}

DB_NAME=$(envget MYSQL_DATABASE); DB_NAME=${DB_NAME:-pkp}

echo "[backup] -> $DEST"

# 1. Database. Try the root password from .env; fall back to the one the
#    container was started with (they can differ right after a rotation).
envget MYSQL_ROOT_PASSWORD | docker exec -i "$DB_CONTAINER" sh -c '
  IFS= read -r p || true
  if [ -z "$p" ] || ! MYSQL_PWD="$p" mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then
    p="$MYSQL_ROOT_PASSWORD"
  fi
  MYSQL_PWD="$p" exec mariadb-dump -uroot --single-transaction --routines --triggers \
    --events --hex-blob --databases "$0"' "$DB_NAME" | gzip -9 > "$DEST/db.sql.gz"

gzip -t "$DEST/db.sql.gz"
if ! zcat "$DEST/db.sql.gz" | tail -1 | grep -q 'Dump completed'; then
  echo "[backup] ERROR: database dump is incomplete" >&2; exit 1
fi

# 2. Files (only paths that exist). volumes/db is NOT copied raw: the dump above is
#    the consistent copy of the database.
paths=()
for p in volumes/config volumes/private volumes/public volumes/themes volumes/plugins volumes/caddy \
         scripts .env .env.example docker-compose.yml docker-compose.override*.yml Dockerfile; do
  [ -e "$p" ] && paths+=("$p")
done
tar --warning=no-file-changed -czf "$DEST/files.tar.gz" -C "$PROJECT_DIR" "${paths[@]}"
tar -tzf "$DEST/files.tar.gz" >/dev/null

# 3. Metadata needed to rebuild the containers exactly (contains secrets: file is 600).
{
  echo "date: $(date -Is)"
  echo "host: $(hostname)"
  echo "git:  $(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo n/a)"
  docker compose ls -a 2>/dev/null || true
  docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}'
} > "$DEST/meta.txt"
docker inspect pkp_app_ojs pkp_db_ojs > "$DEST/containers.inspect.json" 2>/dev/null || true

# 4. Checksums.
( cd "$DEST" && sha256sum db.sql.gz files.tar.gz > SHA256SUMS )

# 5. Optional retention: keep the KEEP newest backups, never touch anything else.
if [ -n "${KEEP:-}" ]; then
  ls -1d "$BACKUP_ROOT"/20[0-9][0-9][01][0-9][0-3][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]* 2>/dev/null \
    | sort | head -n -"$KEEP" | while read -r old; do echo "[backup] pruning $old"; rm -rf -- "$old"; done
fi

echo "[backup] OK"
du -sh "$DEST"/db.sql.gz "$DEST"/files.tar.gz
