# AGENTS.md

Docker Compose deployment + image builder for PKP tools (OJS/OMP/OPS). Upstream: `pkp/containers`. No app source, tests, linters, or package managers here. CI (`.github/workflows/docker-image.yml`) only runs `docker build`.

## Commands

- Always `docker compose` (bare `docker` does NOT read `.env`).
- `docker compose up -d` / `docker compose pull` / `docker compose build app`
- `docker compose logs -f [app|db]` — first place to look; PHP/Apache errors go to stderr/stdout (`volumes/config/apache.pkp.conf`, `Dockerfile` forces `error_log = /dev/stderr`).
- `docker exec -it pkp_app_<project> <script>` — in-container helpers, e.g. `/usr/local/bin/pkp-upgrade`, `pkp-variable <key> <value>`. Full list in `templates/pkp/root/usr/local/bin/pkp-*`. Find name via `docker ps -a` (pattern `pkp_app_${COMPOSE_PROJECT_NAME}`, default = `PKP_TOOL`).
- `./buildRemoteRegistry.sh [TOOL] [VERSION]` — maintainer-only: tags + pushes to DockerHub. Refuses unless `IMAGE_SOURCE=local`; interactive alias prompts.

## `.env` drives everything

- `IMAGE_SOURCE`: `pkpofficial` = RUN prebuilt image, `local` = BUILD from `Dockerfile`. `PKP_TOOL` (ojs|omp|ops) + `PKP_VERSION` select the image/tag.
- `PKP_VERSION` uses `_` (e.g. `3_5_0-4`, `stable-3_5_0`); `Dockerfile` stage 1 converts to dots for the tarball URL.
- After editing `.env`, recreate with `docker compose up -d` (interpolated at container-create time).
- Web installer values: host `db`, driver `mysqli`, uploads dir `/var/www/files`, DB user/pass from `.env`. Never commit real `DB_PASS` values.
- Working tree currently has uncommitted local changes to `.env` / `docker-compose.yml` (image source, version, enabled bind mounts). Run `git diff` before committing; don't commit credentials.

## Volumes and permissions (biggest gotcha)

- Bind mounts live in `./volumes/`. Upstream keeps most commented out; this checkout has them enabled in `docker-compose.yml`. File-mounts (`pkp.config.inc.php`, `apache.htaccess`, `php.custom.ini`) fail if the file doesn't already exist in the container.
- Custom theme: `./volumes/themes/custom-theme` → `/var/www/html/plugins/themes/customTheme` (capital `T` in container).
- Fix perms after clone/restore (Linux): `sudo chown 33:33 ./volumes -R && sudo chown 999:999 ./volumes/db -R` (www-data=33, mysql=999). Wrong perms = silent write failures.
- `volumes/db/`, `volumes/logs/`, `volumes/private/`, `volumes/public/`, `volumes/themes/`, `volumes/plugins/` hold LIVE runtime state — never commit (`git add` would pick them up; they are not git-ignored), never delete blindly, never `chown` db dirs to 33. `volumes/db-import/*.sql` auto-imports on first DB creation only.
- `docker-compose.override.traefik.yml` has hardcoded hostnames — edit before use; it expects an external `proxy` network.

## Image internals

- `Dockerfile` is 3-stage: alpine downloads PKP tarball → `${WEB_SERVER}` stage builds PHP extensions via `install-php-extensions` → final `${WEB_SERVER}` runtime. Runs as `www-data` (33), entrypoint `pkp-start` → `pkp-pre-start` → `apache2-foreground`.
- `pkp-pre-start` rewrites `www.example.com`→`$SERVERNAME` in `pkp.conf` (source: `volumes/config/apache.pkp.conf`), forces `restful_urls=On` / `enable_cdn=Off` in `config.inc.php`, generates self-signed cert if CN mismatches. Helpers live in `templates/pkp/root/usr/local/bin/pkp-*` (`COPY`d to `/` → `/usr/local/bin`).
- Upgrade: bump `PKP_VERSION` in `.env`, `docker compose pull && docker compose up -d`, diff old/new `config.inc.php` (charset!), then `docker exec -it <app> /usr/local/bin/pkp-upgrade`. Supported stepping: `2.x > 2.4.8-5 > 3.1.2-4 > 3.2.1-4 > 3.3.x`.
