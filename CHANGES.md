# Manual changes log

Changes made by hand on the deployment (VM `spe@10.0.3.31`, `~/ojs-deploy`), so future OJS
upgrades know what differs from a stock install. Newest first.

## 2026-11-02: journal name, logo and favicon

Backup first: `~/ojs-backups/20261102-185245-pre-branding`.

- Journal name (English) `ESI` -> `ESI Journal` (`journal_settings.name`, same as
  Settings > Journal > Journal title).
- Logo: `esi-logo.png` (white on transparent, 644x472) installed as
  `volumes/public/journals/1/pageHeaderLogoImage_en.png` + setting `pageHeaderLogoImage`
  (same as Settings > Website > Appearance > Logo).
- Favicon: the logo on the header colour `#0B1220`, 192x192, generated with PHP GD ->
  `volumes/public/journals/1/favicon_en.png` + setting `favicon`.
- Theme `custom-theme`: `templates/frontend/components/header.tpl` shows the logo **and**
  the journal name together (stock OJS shows only one); styles in `styles/head.less`
  (`.pkp_site_brand`).
- Caches cleared (`cache/t_compile`, compiled CSS, `wc-*.html`).

To change the logo later, use the OJS admin pages (Settings > Website > Appearance); the
header keeps showing the name next to it.

## 2026-11-02: admin scripts for domain name and email

- `scripts/setup-domain.sh` (Caddy proxy via `docker-compose.proxy.yml`, optional HTTPS) and
  `scripts/setup-email.sh` (Gmail SMTP, App Password kept in `.env`). Not run yet: the
  domain and the Gmail account don't exist yet. Tested with `--dry-run` (no change) and with
  a fake Gmail account (refused, nothing changed).
- `render-config.sh` now replaces every `${OJS_*}` placeholder found in the template.
- `apache.security.conf`: `SetEnvIf X-Forwarded-Proto https → HTTPS=on` (secure cookies behind
  the proxy; no effect without it). App restarted, verified.
- `backup.sh` also saves `volumes/caddy` (certificates); `healthcheck.sh` accepts
  `HTTP_PORT=127.0.0.1:8080`.

## 2026-11-02: hardening after audit

| Item | Change |
|---|---|
| M1 / S6 | `scripts/backup.sh`, `scripts/restore-test.sh`, `scripts/pull-backups.sh`. Backups in `~/ojs-backups` (VM) and `E:\2CS\Stage 2CS\ojs-backups` (PC). Restore test PASS (132/132 tables) |
| M2 | `.env` rebuilt from the values the containers were started with (it had drifted: wrong project name, OJS 3.3 tag, other root password). Mode 600 |
| M4 | `config.inc.php` is generated from `volumes/config/pkp.config.inc.php.template` + `.env` (`scripts/render-config.sh`); the generated file and the old SQL dump are no longer tracked in git |
| M3 | Rotated DB user + root passwords, `salt`, `api_key_secret` (`scripts/rotate-secrets.sh`). Old leaked values verified rejected. **Admin web password must be changed by the admin.** |
| M7 | `allowed_hosts` = 10.0.3.31, 10.184.150.225, localhost |
| S5 | OJS `time_zone` and PHP `date.timezone` = Africa/Algiers (host: `host-hardening.sh`) |
| S9 | `php.custom.ini`: display_errors Off, expose_php Off, memory_limit 256M, OPcache keys fixed (were ignored) |
| N1 | `web_cache = On` (1 h) + hourly cleanup cron |
| N3 | `volumes/config/apache.security.conf` → `conf-enabled/zz-security.conf`: loads mod_headers, security headers, ServerTokens Prod, denies composer files, `.tpl`, config files |
| S8 / S10 / N2 / M8 | `docker-compose.yml`: no shared `env_file` (app gets no secrets), json-file logs 10 MB × 5, healthchecks for app and db, port 443/8443 no longer published, `/etc/localtime` read-only. Containers recreated once |
| N2 / S8 | User crontab: health check every 5 min, weekly Apache log rotation |
| N5 | Docker build cache pruned (1.25 GB) |
| M8 / S4 / S5 | `scripts/host-hardening.sh` (run by the admin with sudo): ufw enabled (SSH, 8080/tcp, 9993/udp), NTP via 10.0.3.254 (clock synchronized, offset ~7 ms), host time zone Africa/Algiers. Verified: site, healthchecks and container outbound traffic still OK |

Not done yet (deferred): M0 repo private, M5 Gmail SMTP, M6 OJS scheduler + daily
backup cron, S1 HTTPS, S2 SSH hardening, S3 reboot, S7 pinned versions, S11 content,
S12 git history purge, N4 host trimming.
