#!/usr/bin/env bash
# Health check for the OJS stack. Meant for cron (every 5 min), also handy by hand.
#
# Usage: scripts/healthcheck.sh [-v]     (-v: print the result line)
# Writes one line per run to volumes/logs/health.log (self-rotating at 1 MB).
# When the overall state changes (OK <-> FAIL) it also logs to syslog:
#   journalctl -t ojs-health
# Exit code: 0 OK, 1 WARN, 2 FAIL.
#
# Options (env vars): JOURNAL_PATH (default esi), DISK_WARN (%, default 85),
#                     SLOW_WARN (seconds, default 3)
set -uo pipefail
cd "$(dirname "$0")/.."

JOURNAL_PATH=${JOURNAL_PATH:-esi}
DISK_WARN=${DISK_WARN:-85}
SLOW_WARN=${SLOW_WARN:-3}
LOG=volumes/logs/health.log
STATE_FILE=${XDG_STATE_HOME:-$HOME/.local/state}/ojs-health.state
HTTP_PORT=$(grep -E '^HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- | tr -d "'\"")
HTTP_PORT=${HTTP_PORT:-8080}

level=0; problems=()
warn() { problems+=("$1"); [ $level -lt 1 ] && level=1; }
fail() { problems+=("$1"); level=2; }

# 1. Containers: running + Docker healthcheck status.
for svc in app db; do
  cid=$(docker compose ps -q "$svc" 2>/dev/null)
  if [ -z "$cid" ]; then fail "$svc:missing"; eval "st_$svc=missing"; continue; fi
  st=$(docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$cid")
  eval "st_$svc=\$st"
  case $st in
    running/healthy|running/nohealth) ;;
    running/starting) warn "$svc:starting" ;;
    *) fail "$svc:$st" ;;
  esac
done

# 2. HTTP: a real journal page through the published port.
read -r code secs < <(curl -s -o /dev/null -m 15 -H 'Host: localhost' \
  -w '%{http_code} %{time_total}' "http://127.0.0.1:$HTTP_PORT/index.php/$JOURNAL_PATH/en/index" || echo "000 0")
if [ "$code" != 200 ]; then fail "http:$code"
elif awk "BEGIN{exit !($secs > $SLOW_WARN)}"; then warn "http:slow:${secs}s"; fi

# 3. Disk.
disk=$(df -P . | awk 'NR==2{gsub("%","",$5); print $5}')
[ "${disk:-0}" -ge "$DISK_WARN" ] && warn "disk:${disk}%"

state=$([ $level -eq 0 ] && echo OK || { [ $level -eq 1 ] && echo WARN || echo FAIL; })
line="$(date -Is) $state app=$st_app db=$st_db http=$code ${secs}s disk=${disk}%${problems:+ problems=${problems[*]}}"

mkdir -p "$(dirname "$LOG")" "$(dirname "$STATE_FILE")"
if [ -f "$LOG" ] && [ "$(stat -c %s "$LOG")" -gt 1048576 ]; then mv -f "$LOG" "$LOG.1"; fi
echo "$line" >> "$LOG"

prev=$(cat "$STATE_FILE" 2>/dev/null || echo OK)
if [ "$state" != "$prev" ]; then
  prio=user.notice; [ "$state" = FAIL ] && prio=user.err
  logger -t ojs-health -p "$prio" "state $prev -> $state: $line"
  # Email alerts: hook in here once SMTP (M5) is configured.
fi
echo "$state" > "$STATE_FILE"

[ "${1:-}" = "-v" ] && echo "$line"
exit $level
