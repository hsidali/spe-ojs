# Operations: OJS on the VM

VM: `spe@10.0.3.31` (also `10.184.150.225` over ZeroTier). Project: `~/ojs-deploy`.
Site: http://10.0.3.31:8080 (journal `esi`). Compose project name: `ojs`
(containers `pkp_app_ojs`, `pkp_db_ojs`).

## Rules

- Run every `docker compose` command from `~/ojs-deploy`. `.env` sets the project
  name `ojs`; without it, compose sees no containers.
- Apply a config change with `docker compose restart app`. Don't use
  `up --force-recreate` or `down -v`, and never delete anything under `./volumes`.
- Single files are bind-mounted (`config.inc.php`, `php.custom.ini`, `.htaccess`,
  `apache.security.conf`). Edit them in place. **Never use `sed -i` or `mv`** on them:
  that replaces the file and the container keeps seeing the old one.
- **Never run the image's `pkp-variable` helper.** It rewrites the config with
  `sed -i` and sets `installed = Off`.
- Secrets live only in `.env` (mode 600, not in git). Never paste them into chat,
  commits or scripts.

## Changing `config.inc.php`

`volumes/config/pkp.config.inc.php` is **generated**. Edit the template instead:

```bash
nano volumes/config/pkp.config.inc.php.template    # non-secret settings
nano .env                                           # secrets (OJS_*, MYSQL_PASSWORD)
scripts/render-config.sh                            # writes config.inc.php in place
docker compose restart app
scripts/render-config.sh --check                    # live file == template + .env ?
```

OJS's config parser does not expand `${VAR}`, which is why the values are rendered
into the file.

## Scripts (`scripts/`)

| Script | What it does |
|---|---|
| `backup.sh [label]` | DB dump + config/files/theme/.env into `~/ojs-backups/<date>/` (mode 700) with checksums. `KEEP=14` prunes older ones |
| `restore-test.sh [dir]` | Restores a backup into a throwaway MariaDB and compares every table with live. Doesn't touch the site |
| `pull-backups.sh` | **Run on your PC.** Copies new backups to `E:\2CS\Stage 2CS\ojs-backups` and verifies the checksums |
| `render-config.sh [--check]` | Template + `.env` → `config.inc.php` |
| `rotate-secrets.sh [db] [root] [salt] [api]` | New random secrets, applied and verified (takes a backup first) |
| `healthcheck.sh [-v]` | Containers, HTTP, disk → `volumes/logs/health.log`; state changes → `journalctl -t ojs-health` |
| `rotate-logs.sh` | Rotates Apache log files > 10 MB (Docker logs are capped in compose: 10 MB × 5) |
| `host-hardening.sh` | Root-only, run once: time zone, NTP, ufw |

## Domain name and email (for the administrator)

Both scripts are interactive. Run them on the VM, as `spe` (not with sudo), from
`~/ojs-deploy`. Each one checks everything it can **before** changing anything, takes a
backup, applies the change, verifies it, and ends with a table of every file it modified and
its importance (also saved in `volumes/logs/`). Try `--dry-run` first: it asks the same
questions and shows the exact changes without applying them.

| Command | What it asks | What it changes |
|---|---|---|
| `scripts/setup-domain.sh` | domain name; HTTPS yes/no; email for certificate notices (optional); keep access by IP? | config template (`base_url`, `allowed_hosts`, `trust_x_forwarded_for`, OAI id), `.env` (turns on the Caddy proxy), `volumes/config/Caddyfile`; starts container `pkp_proxy_ojs` on ports 80/443 |
| `scripts/setup-email.sh` | Gmail address; Gmail **App Password** (hidden); test recipient | `.env` (`OJS_SMTP_USER`, `OJS_SMTP_PASSWORD`), `[email]` section of the config template |
| `scripts/setup-email.sh --test you@example.com` | — | nothing: sends a test email with the current settings |
| `scripts/setup-domain.sh --rollback` / `scripts/setup-email.sh --rollback` | confirmation | restores the files from the backup taken before the last run |

Before `setup-domain.sh` with HTTPS: the domain's DNS must point to the VM's public IP, and
ports 80 + 443 on that IP must reach the VM (ask IT). Without that, answer "no" to HTTPS:
the site then works on `http://<domain>`, and you can run the script again later.

Before `setup-email.sh`: on the Google account, turn on 2-Step Verification and create an
App Password (https://myaccount.google.com/apppasswords). For a Google Workspace account,
the Workspace admin must allow App Passwords.

## Cron (user `spe`, `crontab -l`)

- every 5 min: `healthcheck.sh`
- hourly: delete OJS page-cache files older than 2 h
- Sunday 03:30: `rotate-logs.sh`
- **Not yet scheduled (M6):** the OJS scheduler (`lib/pkp/tools/scheduler.php run`)
  and the daily `backup.sh`. Until then `task_runner = On` runs tasks during web requests.

## Everyday commands

```bash
docker compose ps                         # status + health
scripts/healthcheck.sh -v
docker compose logs --tail 100 app
docker compose restart app
# Clear the anonymous-visitor page cache right after editing public content:
docker exec pkp_app_ojs sh -c 'rm -f /var/www/html/cache/wc-*.html'
```

## Git on the VM

`~/ojs-deploy` is a clone. Commit `323a39a` and later ones **untrack**
`volumes/config/pkp.config.inc.php` and `backups/pre-seed-backup.sql`. Before any
`git pull` on the VM, run `scripts/backup.sh pre-pull` and check that both files still
exist after the pull (git deletes untracked-in-new-commit files that were unmodified).
