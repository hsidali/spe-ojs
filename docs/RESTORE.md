# Restoring OJS from a backup

A backup folder (`~/ojs-backups/<YYYYmmdd-HHMMSS>[-label]/`) contains:

| File | Content |
|---|---|
| `db.sql.gz` | Full dump of the OJS database (`--single-transaction`, includes `CREATE DATABASE`) |
| `files.tar.gz` | `volumes/config`, `volumes/private` (uploads), `volumes/public`, `volumes/themes`, `scripts`, `.env`, compose files |
| `containers.inspect.json`, `meta.txt` | How the containers were configured (contains secrets, mode 600) |
| `SHA256SUMS` | Checksums of the two archives |
| `RESTORE_TEST.txt` | Result of `scripts/restore-test.sh`, if it was run on this backup |

## 0. Test first (no impact on the site)

```bash
cd ~/ojs-deploy
scripts/restore-test.sh ~/ojs-backups/<backup>      # must end with RESULT: PASS
```

## 1. Real restore on the same VM

```bash
cd ~/ojs-deploy
B=~/ojs-backups/<backup>
(cd "$B" && sha256sum -c SHA256SUMS)                 # 1. integrity
scripts/backup.sh pre-restore                         # 2. safety copy of the current state
docker compose stop app                               # 3. no writes during the restore

# 4. Database. The dump drops and recreates every table.
gunzip -c "$B/db.sql.gz" | docker exec -i pkp_db_ojs sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mariadb -uroot'

# 5. Files. Extract to a staging folder, then copy over the live ones.
S=$(mktemp -d); tar -xzf "$B/files.tar.gz" -C "$S"
#    (runs as root in a throwaway container from the image already on the VM; no download)
docker run --rm --entrypoint sh -v "$S:/from:ro" -v "$PWD/volumes:/to" pkpofficial/ojs:stable-3_5_0 -c \
  'cp -a /from/volumes/private/. /to/private/ && cp -a /from/volumes/public/. /to/public/ \
   && cp -a /from/volumes/themes/. /to/themes/ && chown -R 33:33 /to/private /to/public /to/themes'
#    Bind-mounted single files: copy the CONTENT (cat >), never mv.
cat "$S/volumes/config/pkp.config.inc.php.template" > volumes/config/pkp.config.inc.php.template
cat "$S/volumes/config/php.custom.ini"             > volumes/config/php.custom.ini
cat "$S/volumes/config/apache.htaccess"            > volumes/config/apache.htaccess
cat "$S/volumes/config/apache.security.conf"       > volumes/config/apache.security.conf
#    Secrets: only restore .env if the DB passwords in the dump's era differ from today's.
#    The dump does NOT change MariaDB user passwords (they live in the mysql schema).
# cp "$S/.env" .env && chmod 600 .env
rm -rf "$S"

# 6. Restart and check
docker compose start app
scripts/render-config.sh --check || { scripts/render-config.sh && docker compose restart app; }
scripts/healthcheck.sh -v
```

## 2. Restore on a new machine

1. Install Docker, then `git clone` the repository into `~/ojs-deploy`.
2. Extract `files.tar.gz` into `~/ojs-deploy` (this restores `.env`, `volumes/config`,
   `volumes/private`, `volumes/public`, `volumes/themes`).
3. `mkdir -p volumes/db volumes/logs/app volumes/logs/db volumes/db-import`
4. Create `volumes/config/pkp.config.inc.php` (any content, e.g. `touch`) so the bind
   mount is a file, then: `docker compose up -d --no-build`
   (MariaDB initialises an empty database with the passwords from `.env`).
5. Import: `gunzip -c db.sql.gz | docker exec -i pkp_db_ojs sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mariadb -uroot'`
6. `scripts/render-config.sh && docker compose restart app`, then fix ownership:
   `docker exec -u root pkp_app_ojs chown -R www-data:www-data /var/www/files /var/www/html/public`
7. Update `base_url` / `allowed_hosts` in the template if the address changed, render again.

## Rollback of a failed change (no data loss)

Config-only changes: restore the file from the latest backup's `files.tar.gz`
(`tar -xzOf "$B/files.tar.gz" <path> > <path>`), then `docker compose restart app`.
A compose change: `cp "$B/docker-compose.yml.before" docker-compose.yml` (if present)
or `git checkout -- docker-compose.yml`, then `docker compose up -d --no-build --pull never`.
