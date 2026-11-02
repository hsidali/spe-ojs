#!/usr/bin/env bash
# Rotate Apache's log files in volumes/logs/app (owned by www-data, so done inside the
# container). Docker's own container logs are already capped in docker-compose.yml
# (json-file, 10 MB x 5). Meant for a weekly cron job.
#
# copy + truncate: Apache keeps writing to the same open file, no reload needed.
# Options (env vars): MAX_BYTES (default 10 MB), KEEP (rotated files per log, default 8)
set -euo pipefail
cd "$(dirname "$0")/.."
MAX_BYTES=${MAX_BYTES:-10485760}
KEEP=${KEEP:-8}

docker compose exec -T -u root app sh -c '
  cd /var/log/apache2 || exit 0
  for f in *.log; do
    [ -f "$f" ] || continue
    size=$(stat -c %s "$f")
    if [ "$size" -gt "$0" ]; then
      gzip -c "$f" > "$f.$(date +%Y%m%d-%H%M).gz" && : > "$f"
      echo "rotated $f ($size bytes)"
    fi
    ls -1t "$f".*.gz 2>/dev/null | tail -n +$(( $1 + 1 )) | xargs -r rm -f --
  done' "$MAX_BYTES" "$KEEP" </dev/null
