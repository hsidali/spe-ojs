# Shared helpers for scripts/setup-domain.sh and scripts/setup-email.sh.
# Sourced, not run directly.
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$PROJECT_DIR"

CFGEDIT=(python3 "$PROJECT_DIR/scripts/lib/cfgedit.py")
TEMPLATE=volumes/config/pkp.config.inc.php.template
ENV_FILE=.env
BACKUP_ROOT=${BACKUP_ROOT:-$HOME/ojs-backups}
DRY_RUN=0
STAMP=$(date +%Y%m%d-%H%M%S)
REPORT=()       # "IMPORTANCE|path|why"
MANUAL=()       # things the admin must check by hand
BACKUP_DIR=""

if [ -t 1 ]; then BOLD=$'\e[1m'; RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RST=$'\e[0m'
else BOLD=""; RED=""; GRN=""; YEL=""; RST=""; fi

info() { echo; echo "${BOLD}==> $*${RST}"; }
ok()   { echo "  ${GRN}OK${RST}  $*"; }
warn() { echo "  ${YEL}WARNING${RST}  $*"; }
die()  { echo; echo "${RED}ERROR:${RST} $*" >&2; exit 1; }

# ask VAR "question" [default]      -> non-empty answer (default used on Enter)
ask() {
  local __var=$1 __q=$2 __def=${3:-} __a
  while :; do
    read -r -p "  $__q${__def:+ [$__def]}: " __a || die "no input (run this script in a terminal)"
    __a=${__a:-$__def}
    [ -n "$__a" ] && break
    echo "  (an answer is required)"
  done
  printf -v "$__var" '%s' "$__a"
}

# ask_optional VAR "question"       -> may be empty
ask_optional() {
  local __var=$1 __q=$2 __a
  read -r -p "  $__q: " __a || die "no input (run this script in a terminal)"
  printf -v "$__var" '%s' "$__a"
}

# ask_secret VAR "question"         -> hidden input
ask_secret() {
  local __var=$1 __q=$2 __a
  read -r -s -p "  $__q: " __a || die "no input (run this script in a terminal)"
  echo
  printf -v "$__var" '%s' "$__a"
}

# ask_yes_no "question" y|n         -> exit status 0 = yes
ask_yes_no() {
  local __q=$1 __def=${2:-n} __a __hint="[y/N]"
  [ "$__def" = y ] && __hint="[Y/n]"
  while :; do
    read -r -p "  $__q $__hint: " __a || die "no input (run this script in a terminal)"
    __a=${__a:-$__def}
    case $__a in [Yy]*) return 0 ;; [Nn]*) return 1 ;; esac
  done
}

# Checks shared by both scripts. Nothing is changed here.
preflight() {
  [ "$(id -u)" -ne 0 ] || die "do not run this with sudo; run it as the normal user (spe)"
  [ -f "$ENV_FILE" ] && [ -f "$TEMPLATE" ] || die "run this on the VM, in ~/ojs-deploy (.env or the config template is missing)"
  command -v docker >/dev/null && command -v python3 >/dev/null || die "docker and python3 are required"
  [ -n "$(docker compose ps -q app 2>/dev/null)" ] || die "the OJS containers are not running (check: docker compose ps)"
  if ! scripts/render-config.sh --check >/dev/null 2>&1; then
    die "config.inc.php differs from template + .env (someone edited it by hand?).
       Fix that first: see docs/OPERATIONS.md, section 'Changing config.inc.php'."
  fi
  ok "pre-checks passed"
}

# In --dry-run mode, edits go to copies in a temp folder; the live files stay untouched.
use_work_copies() {
  WORK_DIR=$(mktemp -d)
  trap 'rm -rf -- "$WORK_DIR"' EXIT
  install -m 600 "$ENV_FILE" "$WORK_DIR/env"
  cp "$TEMPLATE" "$WORK_DIR/template"
  W_ENV="$WORK_DIR/env"; W_TEMPLATE="$WORK_DIR/template"
}

take_backup() {
  info "Backup before changing anything"
  BACKUP_DIR=$(scripts/backup.sh "$1" </dev/null | sed -n 's/^\[backup\] -> //p')
  [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/SHA256SUMS" ] || die "backup failed: nothing was changed"
  ok "backup: $BACKUP_DIR"
}

latest_backup() { ls -1d "$BACKUP_ROOT"/20*-"$1" 2>/dev/null | sort | tail -1; }

# restore_file BACKUP_DIR PATH  -> copies PATH's content back from files.tar.gz (same inode)
restore_file() {
  local b=$1 p=$2 tmp
  tmp=$(mktemp)
  if tar -xzOf "$b/files.tar.gz" "$p" > "$tmp" 2>/dev/null; then
    cat "$tmp" > "$p"; rm -f "$tmp"; ok "restored $p"
  else
    rm -f "$tmp"; warn "$p is not in that backup, left as is"
  fi
}

wait_healthy() {  # wait_healthy SERVICE [seconds]
  local svc=$1 max=${2:-120} i cid st
  for ((i = 0; i < max; i += 3)); do
    cid=$(docker compose ps -q "$svc" 2>/dev/null || true)
    st=$([ -n "$cid" ] && docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo missing)
    case $st in healthy|running) ok "$svc is $st"; return 0 ;; esac
    sleep 3
  done
  warn "$svc is not healthy after ${max}s (status: $st)"; return 1
}

# Render config.inc.php from template + .env and restart OJS.
render_and_restart() {
  info "Applying the configuration"
  scripts/render-config.sh >/dev/null
  ok "config.inc.php regenerated"
  docker compose restart app >/dev/null 2>&1
  wait_healthy app 120 || die "OJS did not come back. Undo with: $0 --rollback"
}

report_add()  { REPORT+=("$1|$2|$3"); }
manual_add()  { MANUAL+=("$1"); }

# report_print "Title" name   -> prints the table and saves it to volumes/logs/<name>-<stamp>.txt
report_print() {
  local title=$1 name=$2 out r imp path why m
  out=$(
    echo
    echo "=================================================================================="
    echo " $title"
    echo "=================================================================================="
    [ "$DRY_RUN" = 1 ] && echo " DRY RUN: nothing below was changed; this is what a real run would modify."
    echo
    printf ' %-9s  %-46s  %s\n' "IMPORTANCE" "FILE / ITEM" "WHY IT MATTERS"
    printf ' %-9s  %-46s  %s\n' "---------" "-----------" "--------------"
    for r in "${REPORT[@]}"; do
      IFS='|' read -r imp path why <<<"$r"
      printf ' %-9s  %-46s  %s\n' "$imp" "$path" "$why"
    done
    echo
    echo " CRITICAL = holds secrets, or the site stops working if it is lost or broken."
    echo "            Keep it in backups, never share it, never commit it."
    echo " HIGH     = changes how the site behaves. Change it only through the template/scripts."
    echo " MEDIUM   = generated or easy to recreate."
    echo " INFO     = runtime change (containers); nothing to keep."
    if [ ${#MANUAL[@]} -gt 0 ]; then
      echo
      echo " To do / check by hand:"
      for m in "${MANUAL[@]}"; do echo "   - $m"; done
    fi
    if [ -n "$BACKUP_DIR" ]; then
      echo
      echo " Backup taken before the change: $BACKUP_DIR"
      echo " Undo everything with:            $0 --rollback"
    fi
    echo
  )
  echo "$out"
  if [ "$DRY_RUN" = 0 ]; then
    mkdir -p volumes/logs
    printf '%s\n' "$out" > "volumes/logs/$name-$STAMP.txt"
    echo " (report saved to volumes/logs/$name-$STAMP.txt)"
  fi
}
