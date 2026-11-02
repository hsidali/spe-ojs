#!/usr/bin/env bash
# Build OJS's config.inc.php from the committed template + secrets in .env.
#
#   volumes/config/pkp.config.inc.php.template   (in git, placeholders like ${OJS_SALT})
#   .env                                         (NOT in git, mode 600, holds the values)
#   volumes/config/pkp.config.inc.php            (NOT in git, generated, bind-mounted)
#
# Usage:
#   scripts/render-config.sh           render, write in place, then: docker compose restart app
#   scripts/render-config.sh --check   only report whether the live file matches the template
#
# Why not ${VAR} directly in config.inc.php? OJS's own config parser does not expand
# environment variables, so the values must be written into the file.
#
# The live file is written THROUGH the app container with `cat >`: this keeps the same
# inode, so the single-file bind mount keeps working (never use mv or sed -i on it),
# and it works although the file is owned by www-data on the host.
set -euo pipefail
cd "$(dirname "$0")/.."

TEMPLATE=volumes/config/pkp.config.inc.php.template
CONTAINER_PATH=/var/www/html/config.inc.php
[ -f "$TEMPLATE" ] || { echo "missing $TEMPLATE" >&2; exit 1; }
[ -f .env ] || { echo "missing .env" >&2; exit 1; }

# Placeholders = every ${OJS_...} or ${MYSQL_PASSWORD} found in the template.
# Only those are replaced; any other "$" in the file is left alone.
NAMES=$(grep -oE '\$\{(OJS_[A-Z0-9_]+|MYSQL_PASSWORD)\}' "$TEMPLATE" | tr -d '${}' | sort -u)
VARS=$(for n in $NAMES; do printf '${%s} ' "$n"; done)

set -a; . ./.env; set +a

for v in $NAMES; do
  [ -n "${!v:-}" ] || { echo "ERROR: $v is used in the template but empty or missing in .env" >&2; exit 1; }
done

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
envsubst "$VARS" < "$TEMPLATE" > "$tmp"
if grep -qE '\$\{(OJS_[A-Z0-9_]+|MYSQL_PASSWORD)\}' "$tmp"; then
  echo "ERROR: unresolved placeholder left in output" >&2; exit 1
fi

if [ "${1:-}" = "--check" ]; then
  if docker compose exec -T app cat "$CONTAINER_PATH" </dev/null | cmp -s - "$tmp"; then
    echo "config.inc.php matches template + .env"
  else
    echo "config.inc.php DIFFERS from template + .env"; exit 3
  fi
  exit 0
fi

docker compose exec -T -u root app sh -c "cat > $CONTAINER_PATH" < "$tmp"
# www-data owns it (OJS may write it); host user's group may read it (for backups); nobody else.
docker compose exec -T -u root app sh -c "chown 33:$(id -g) $CONTAINER_PATH && chmod 640 $CONTAINER_PATH" </dev/null
docker compose exec -T app cat "$CONTAINER_PATH" </dev/null | cmp -s - "$tmp" \
  || { echo "ERROR: written file does not match rendered output" >&2; exit 1; }
echo "rendered $CONTAINER_PATH (restart the app to apply: docker compose restart app)"
