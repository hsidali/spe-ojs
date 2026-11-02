#!/usr/bin/env bash
# Give the journal its domain name (e.g. revue.esi.dz), with or without HTTPS.
#
#   scripts/setup-domain.sh                  interactive setup (can be re-run to change domain)
#   scripts/setup-domain.sh --dry-run        ask, check, show what would change, change nothing
#   scripts/setup-domain.sh --rollback [DIR] undo: restore .env + config template, remove the proxy
#
# What it does
#   - starts a small reverse proxy (Caddy, container pkp_proxy_ojs) on ports 80 and 443
#   - HTTPS (optional): Caddy gets and renews a free Let's Encrypt certificate by itself.
#     This only works if, BEFORE you run the script:
#       * the domain's DNS "A" record points to the public IP address of this VM, and
#       * ports 80 and 443 on that public IP reach this VM (NAT / firewall: ask your IT team).
#     Without that, answer "no" to HTTPS: the site works over http://<domain> on the local
#     network, and you can re-run the script later to switch to HTTPS.
#   - updates OJS: base_url, allowed_hosts, trust_x_forwarded_for, OAI repository id
#   - takes a backup first, verifies at the end, prints every file it changed.
source "$(dirname "$0")/lib/setup-common.sh"

CADDYFILE=volumes/config/Caddyfile
CADDY_IMAGE_DEFAULT=caddy:2.10

project_name() { "${CFGEDIT[@]}" env-get "$ENV_FILE" COMPOSE_PROJECT_NAME; }

do_rollback() {
  local b=${1:-$(latest_backup pre-domain)} proxy
  [ -n "$b" ] && [ -d "$b" ] || die "no 'pre-domain' backup found in $BACKUP_ROOT"
  proxy="pkp_proxy_$(project_name)"
  info "Rollback: restore .env + config template from $b and remove the proxy container ($proxy)"
  ask_yes_no "Continue?" n || exit 0
  take_backup before-domain-rollback
  restore_file "$b" "$ENV_FILE"; chmod 600 "$ENV_FILE"
  restore_file "$b" "$TEMPLATE"
  restore_file "$b" "$CADDYFILE"
  docker rm -f "$proxy" >/dev/null 2>&1 && ok "proxy container removed (certificates kept in volumes/caddy/)" || true
  scripts/render-config.sh >/dev/null
  docker compose up -d --no-build --pull never >/dev/null 2>&1   # re-applies the app port if it had changed
  docker compose restart app >/dev/null 2>&1
  wait_healthy app 120 || die "OJS did not come back; check: docker compose logs app"
  report_add CRITICAL ".env" "restored from the backup (proxy disabled, ports back as before)"
  report_add HIGH "$TEMPLATE" "restored (base_url, allowed_hosts, proxy trust as before)"
  report_add HIGH "volumes/config/pkp.config.inc.php" "regenerated live config (never edit by hand)"
  report_add INFO "container $proxy" "removed"
  report_add INFO "container pkp_app_ojs" "restarted"
  report_print "DOMAIN ROLLBACK DONE" domain-rollback
}

case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=1 ;;
  --rollback) do_rollback "${2:-}"; exit 0 ;;
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) die "unknown option: $1 (see $0 --help)" ;;
esac

echo "${BOLD}OJS domain name setup${RST}"
sed -n '8,16p' "$0" | sed 's/^#/ /'

info "Checks"
preflight
CUR_BASE=$("${CFGEDIT[@]}" ini-get "$TEMPLATE" general base_url | tr -d '"')
CUR_HOST=$(echo "$CUR_BASE" | sed -E 's#^[a-z]+://##; s#[:/].*$##')
CUR_PORT=$("${CFGEDIT[@]}" env-get "$ENV_FILE" HTTP_PORT); APP_PORT=${CUR_PORT##*:}
PROXY_NAME="pkp_proxy_$(project_name)"
echo "  current address: $CUR_BASE"

info "Domain name"
while :; do
  ask DOMAIN "Domain name of the journal (e.g. revue.esi.dz)"
  DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]' | sed -E 's#^[a-z]+://##; s#/.*$##; s/[[:space:]]//g')
  [[ $DOMAIN =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] && break
  echo "  '$DOMAIN' is not a valid domain name"
done

info "DNS check"
DNS_IPS=$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)
PUBLIC_IP=$(curl -s -m 6 https://api.ipify.org 2>/dev/null || true)
echo "  $DOMAIN resolves to : ${DNS_IPS:-nothing (no DNS record yet)}"
echo "  this VM's addresses   : $(hostname -I | xargs)"
echo "  public IP of this VM  : ${PUBLIC_IP:-unknown (no outbound access to check)}"
if [ -z "$DNS_IPS" ]; then
  warn "the domain does not resolve. Visitors will not reach it until the DNS record exists."
elif [ -n "$PUBLIC_IP" ] && ! grep -qw "$PUBLIC_IP" <<<"$DNS_IPS" && ! grep -qwE "$(hostname -I | xargs | tr ' ' '|')" <<<"$DNS_IPS"; then
  warn "the domain points to $DNS_IPS, which is neither this VM's public IP nor one of its addresses."
fi

info "HTTPS"
echo "  HTTPS needs: DNS pointing to this VM's PUBLIC IP + ports 80 and 443 open from the internet."
HTTPS=0; LE_EMAIL=""
if ask_yes_no "Enable HTTPS with a free Let's Encrypt certificate?" n; then
  HTTPS=1
  ask_optional LE_EMAIL "Email for certificate expiry notices (optional, Enter to skip)"
fi

if [ -z "$(docker ps -q -f name="^${PROXY_NAME}$")" ]; then
  busy=$(ss -ltnH '( sport = :80 or sport = :443 )' 2>/dev/null || true)
  [ -z "$busy" ] || die "ports 80/443 are already used by another program on this VM:
$busy"
fi

info "Access by IP address"
KEEP_IP=1
ask_yes_no "Keep direct access on the local network (http://${CUR_HOST}:${APP_PORT})?" y || KEEP_IP=0

SCHEME=http; [ "$HTTPS" = 1 ] && SCHEME=https
NEW_BASE="$SCHEME://$DOMAIN"

info "Summary"
cat <<TXT
  New journal address : $NEW_BASE   (was $CUR_BASE)
  HTTPS               : $([ "$HTTPS" = 1 ] && echo "yes, automatic Let's Encrypt certificate${LE_EMAIL:+ (notices to $LE_EMAIL)}" || echo "no (plain HTTP)")
  Proxy               : container $PROXY_NAME on ports 80 and 443
  Access by IP        : $([ "$KEEP_IP" = 1 ] && echo "kept on port $APP_PORT" || echo "closed (port $APP_PORT only reachable from the VM itself)")
TXT
ask_yes_no "Apply these changes?" n || { echo "  Cancelled, nothing was changed."; exit 0; }

if [ "$DRY_RUN" = 1 ]; then
  use_work_copies; E=$W_ENV; T=$W_TEMPLATE; CF="$WORK_DIR/Caddyfile"
else
  info "Downloading the proxy image (before changing anything)"
  CADDY_IMAGE=$("${CFGEDIT[@]}" env-get "$ENV_FILE" CADDY_IMAGE); CADDY_IMAGE=${CADDY_IMAGE:-$CADDY_IMAGE_DEFAULT}
  docker pull -q "$CADDY_IMAGE" >/dev/null || die "could not download $CADDY_IMAGE (no access to Docker Hub?). Nothing was changed."
  ok "$CADDY_IMAGE available"
  take_backup pre-domain
  E=$ENV_FILE; T=$TEMPLATE; CF=$CADDYFILE
fi

info "Writing the settings"
# 1. OJS config template
"${CFGEDIT[@]}" ini-set "$T" general base_url "\"$NEW_BASE\""
hosts=$("${CFGEDIT[@]}" allowed-hosts-add "$T" "$DOMAIN")
"${CFGEDIT[@]}" ini-set "$T" general trust_x_forwarded_for On
"${CFGEDIT[@]}" ini-set "$T" oai repository_id "\"ojs2.$DOMAIN\""
ok "config template: base_url, allowed_hosts ($hosts), trust_x_forwarded_for, repository_id"

# 2. Caddyfile (written in place: it is bind-mounted into the proxy)
{
  echo "# Generated by scripts/setup-domain.sh on $(date -Is). Re-run the script to change it."
  if [ -n "$LE_EMAIL" ]; then printf '{\n\temail %s\n}\n\n' "$LE_EMAIL"; fi
  [ "$HTTPS" = 1 ] && echo "$DOMAIN {" || echo "http://$DOMAIN {"
  printf '\tencode zstd gzip\n\treverse_proxy app:80\n}\n'
} > "$CF.new"
cat "$CF.new" > "$CF"; rm -f "$CF.new"
ok "Caddyfile: $([ "$HTTPS" = 1 ] && echo "HTTPS for $DOMAIN (HTTP redirects to HTTPS)" || echo "HTTP for $DOMAIN")"

# 3. .env
printf '%s' "docker-compose.yml:docker-compose.proxy.yml" | "${CFGEDIT[@]}" env-set "$E" COMPOSE_FILE
printf '%s' "${CADDY_IMAGE:-$CADDY_IMAGE_DEFAULT}"      | "${CFGEDIT[@]}" env-set "$E" CADDY_IMAGE
printf '%s' "$DOMAIN"                                    | "${CFGEDIT[@]}" env-set "$E" PUBLIC_DOMAIN
NEW_PORT=$APP_PORT; [ "$KEEP_IP" = 1 ] || NEW_PORT="127.0.0.1:$APP_PORT"
printf '%s' "$NEW_PORT"                                  | "${CFGEDIT[@]}" env-set "$E" HTTP_PORT
ok ".env: COMPOSE_FILE (turns the proxy on), CADDY_IMAGE, PUBLIC_DOMAIN, HTTP_PORT=$NEW_PORT"

report_add CRITICAL ".env" "COMPOSE_FILE turns the proxy on; HTTP_PORT, PUBLIC_DOMAIN, CADDY_IMAGE (+ all secrets)"
report_add HIGH "$TEMPLATE" "base_url=$NEW_BASE, allowed_hosts += $DOMAIN, trust_x_forwarded_for=On, repository_id"
report_add HIGH "volumes/config/pkp.config.inc.php" "regenerated live config (never edit by hand)"
report_add HIGH "$CADDYFILE" "which domain the proxy answers for, and whether it uses HTTPS"
if [ "$HTTPS" = 1 ]; then
  report_add CRITICAL "volumes/caddy/data/" "HTTPS certificate + Let's Encrypt account. Losing it forces a new certificate (rate limits)"
else
  report_add MEDIUM "volumes/caddy/data/" "proxy data (will hold the certificate once HTTPS is enabled)"
fi
report_add MEDIUM "volumes/caddy/config/" "proxy runtime state, recreated automatically"
report_add INFO "container $PROXY_NAME" "reverse proxy on ports 80/443 (restarts automatically, like OJS)"
report_add INFO "container pkp_app_ojs" "$([ "$KEEP_IP" = 1 ] && echo restarted || echo "recreated: port $APP_PORT now bound to 127.0.0.1")"

if [ "$DRY_RUN" = 1 ]; then
  info "Changes that would be made to the config template"
  diff -u "$TEMPLATE" "$T" | sed 's/^/  /' || true
  info "Caddyfile that would be written"
  sed 's/^/  /' "$CF"
  info ".env keys that would change (values hidden)"
  "${CFGEDIT[@]}" env-changed "$ENV_FILE" "$E" | sed 's/^/  /'
  report_print "DOMAIN SETUP (DRY RUN)" domain
  exit 0
fi

mkdir -p volumes/caddy/data volumes/caddy/config
scripts/render-config.sh >/dev/null && ok "config.inc.php regenerated"

info "Starting the proxy and restarting OJS"
docker compose up -d --no-build >/dev/null 2>&1 || die "docker compose up failed. Undo with: $0 --rollback"
docker compose restart app >/dev/null 2>&1
wait_healthy app 150 || die "OJS did not come back. Undo with: $0 --rollback"
docker compose restart proxy >/dev/null 2>&1      # reload the Caddyfile if the proxy already existed
wait_healthy proxy 30 || die "the proxy did not start: docker compose logs proxy. Undo with: $0 --rollback"

info "Verifying"
FAILED=0
loc=$(curl -s -o /dev/null -m 15 -w '%{http_code} %{redirect_url}' --resolve "$DOMAIN:80:127.0.0.1" "http://$DOMAIN/index.php/index/en" || true)
if [ "$HTTPS" = 1 ]; then
  [[ $loc == 30[178]\ https://$DOMAIN* ]] && ok "http://$DOMAIN redirects to HTTPS" || { warn "http://$DOMAIN answered: $loc"; FAILED=1; }
  echo "  Waiting for the Let's Encrypt certificate (up to 2 minutes)..."
  cert=no
  for _ in $(seq 1 24); do
    if curl -s -o /dev/null -m 10 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/index.php/index/en"; then cert=yes; break; fi
    sleep 5
  done
  if [ "$cert" = yes ]; then
    ok "valid HTTPS certificate for $DOMAIN"
    curl -s -m 10 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/index.php/index/en" -L | grep -q "$NEW_BASE" \
      && ok "OJS pages link to $NEW_BASE" || warn "OJS pages do not mention $NEW_BASE yet (page cache?)"
  else
    FAILED=1
    warn "no certificate yet. Let's Encrypt could not reach http://$DOMAIN from the internet."
    echo "  Last proxy messages:"
    docker compose logs --since 5m proxy 2>&1 | grep -iE 'error|challenge|acme|obtain' | tail -5 | cut -c1-220 | sed 's/^/    /'
    manual_add "Fix DNS / NAT for ports 80 and 443; Caddy keeps retrying and the certificate will then appear by itself."
  fi
else
  [[ $loc == 200* || $loc == 30[0-9]\ http://$DOMAIN* ]] && ok "http://$DOMAIN answers through the proxy ($loc)" || { warn "http://$DOMAIN answered: $loc"; FAILED=1; }
fi
if [ "$KEEP_IP" = 1 ]; then
  ipc=$(curl -s -o /dev/null -m 10 -w '%{http_code}' -H "Host: $CUR_HOST" "http://127.0.0.1:$APP_PORT/index.php/index/en" || true)
  [[ $ipc == 200 || $ipc == 30? ]] && ok "access by IP still works ($ipc)" || warn "access by IP answered $ipc"
fi
scripts/healthcheck.sh >/dev/null 2>&1 && ok "health check OK" || warn "health check reports a problem: scripts/healthcheck.sh -v"

# Old address stored in OJS content (not changed automatically)
old_refs=$(docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mariadb -uroot -N "$MYSQL_DATABASE"' 2>/dev/null <<SQL || true
SELECT CONCAT(t, ':', n) FROM (
  SELECT 'site_settings' t, COUNT(*) n FROM site_settings WHERE setting_value LIKE '%$CUR_HOST%'
  UNION ALL SELECT 'journal_settings', COUNT(*) FROM journal_settings WHERE setting_value LIKE '%$CUR_HOST%'
  UNION ALL SELECT 'navigation_menu_item_settings', COUNT(*) FROM navigation_menu_item_settings WHERE setting_value LIKE '%$CUR_HOST%'
  UNION ALL SELECT 'plugin_settings', COUNT(*) FROM plugin_settings WHERE setting_value LIKE '%$CUR_HOST%'
) x WHERE n > 0;
SQL
)
if [ -n "$old_refs" ]; then
  manual_add "OJS content still contains the old address '$CUR_HOST' ($(echo $old_refs | tr ' ' ',')): e.g. Settings > Workflow > Emails (signature), Website > Navigation, Website > Appearance (footer)."
fi
manual_add "Tell users the new address: $NEW_BASE"
[ "$HTTPS" = 1 ] && manual_add "Optional (needs sudo): document the open ports in the firewall: sudo ufw allow 80/tcp && sudo ufw allow 443"
[ "$FAILED" = 1 ] && manual_add "Something did not verify (see WARNING lines above). Undo with: $0 --rollback"

report_print "DOMAIN SETUP $([ "$FAILED" = 0 ] && echo DONE || echo "DONE WITH WARNINGS")" domain
