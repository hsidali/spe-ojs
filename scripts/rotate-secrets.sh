#!/usr/bin/env bash
# Rotate OJS / MariaDB secrets. New values are generated here, written to .env (mode 600)
# and applied; they are never printed.
#
# Usage: scripts/rotate-secrets.sh [db] [root] [salt] [api]     (default: all four)
#   db    MariaDB password of the OJS user (MYSQL_PASSWORD, also DB_PASS / PKP_DB_PASSWORD)
#   root  MariaDB root password (MYSQL_ROOT_PASSWORD)
#   salt  OJS [security] salt   (invalidates pending password-reset links / access keys)
#   api   OJS [security] api_key_secret (invalidates existing user API tokens)
#
# A backup is taken first (scripts/backup.sh pre-rotate). Rollback: restore .env from that
# backup, set the DB passwords back, then scripts/render-config.sh && docker compose restart app.
set -euo pipefail
cd "$(dirname "$0")/.."

what=("$@"); [ ${#what[@]} -eq 0 ] && what=(db root salt api)
has() { local x; for x in "${what[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }

scripts/backup.sh pre-rotate >/dev/null
echo "[rotate] backup taken"

# Current root password: .env first, else the one the db container was started with.
old_root=$(grep -E '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2- | sed -E "s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/")

umask 077
# Generate new values and rewrite .env (python: exact, no sed -i).
python3 - "${what[@]}" <<'PY'
import re, secrets, string, sys
alpha = string.ascii_letters + string.digits
gen = lambda n: ''.join(secrets.choice(alpha) for _ in range(n))
want = set(sys.argv[1:])
new = {}
if 'db' in want:
    p = gen(32); new.update(MYSQL_PASSWORD=p, DB_PASS=p, PKP_DB_PASSWORD=p)
if 'root' in want: new['MYSQL_ROOT_PASSWORD'] = gen(32)
if 'salt' in want: new['OJS_SALT'] = gen(48)
if 'api' in want: new['OJS_API_KEY_SECRET'] = gen(64)
lines = open('.env').read().split('\n')
done = set()
for i, l in enumerate(lines):
    m = re.match(r'^([A-Z0-9_]+)=', l)
    if m and m.group(1) in new:
        lines[i] = f"{m.group(1)}='{new[m.group(1)]}'"; done.add(m.group(1))
lines += [f"{k}='{v}'" for k, v in new.items() if k not in done]
open('.env.tmp', 'w').write('\n'.join(lines).rstrip('\n') + '\n')
print("[rotate] new values generated for:", ', '.join(sorted(new)))
PY
mv .env.tmp .env; chmod 600 .env

envget() { grep -E "^$1=" .env | tail -1 | cut -d= -f2- | sed -E "s/^'(.*)'$/\1/"; }

# Apply DB password changes. SQL (with the new passwords) goes through stdin only.
if has db || has root; then
  {
    printf '%s\n' "$old_root"
    has db   && printf "ALTER USER '%s'@'%%' IDENTIFIED BY '%s';\n" "$(envget MYSQL_USER)" "$(envget MYSQL_PASSWORD)"
    has root && printf "ALTER USER 'root'@'%%' IDENTIFIED BY '%s';\nALTER USER 'root'@'localhost' IDENTIFIED BY '%s';\n" \
                       "$(envget MYSQL_ROOT_PASSWORD)" "$(envget MYSQL_ROOT_PASSWORD)"
    printf 'FLUSH PRIVILEGES;\n'
  } | docker compose exec -T db sh -c '
      IFS= read -r p || true
      if [ -z "$p" ] || ! MYSQL_PWD="$p" mariadb -uroot -e "SELECT 1" >/dev/null 2>&1; then p="$MYSQL_ROOT_PASSWORD"; fi
      MYSQL_PWD="$p" exec mariadb -uroot'
  echo "[rotate] database passwords changed"
fi

scripts/render-config.sh
docker compose restart app >/dev/null
echo "[rotate] app restarted"

# Verify: new credentials work.
printf '%s\n' "$(envget MYSQL_ROOT_PASSWORD)" | docker compose exec -T db sh -c 'IFS= read -r p; MYSQL_PWD="$p" mariadb -uroot -N -e "SELECT \"root login OK\""'
printf '%s\n' "$(envget MYSQL_PASSWORD)" | docker compose exec -T db sh -c 'IFS= read -r p; MYSQL_PWD="$p" mariadb -u"$MYSQL_USER" -N -e "SELECT \"ojs user login OK\""'
