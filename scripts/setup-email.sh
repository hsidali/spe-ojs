#!/usr/bin/env bash
# Configure OJS to send email through a Gmail account.
#
#   scripts/setup-email.sh                    interactive setup
#   scripts/setup-email.sh --dry-run          ask, test the Gmail login, show what would change, change nothing
#   scripts/setup-email.sh --test ADDRESS     send a test email with the current configuration
#   scripts/setup-email.sh --rollback [DIR]   undo: restore .env + config template from the backup
#
# Before you start (on the Gmail / Google account):
#   1. Turn on 2-Step Verification:   https://myaccount.google.com/security
#   2. Create an App Password:        https://myaccount.google.com/apppasswords
#      Google shows 16 letters (e.g. "abcd efgh ijkl mnop"). That is what this script asks for,
#      NOT the normal account password. For a Google Workspace account (e.g. @esi.dz),
#      the Workspace admin must allow App Passwords.
#
# The App Password is stored only in .env (mode 600). It is never printed.
# OJS then sends every email from this Gmail address; the original sender's name is
# kept ("Name via Journal") and replies still go to the original sender.
source "$(dirname "$0")/lib/setup-common.sh"

SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587

# Run lib/smtp-test.php inside the app container. $1 = stdin|live, input on stdin.
smtp_test() {
  docker compose exec -T app sh -c 'cat > /tmp/ojs-smtp-test.php' < scripts/lib/smtp-test.php
  local rc=0
  docker compose exec -T app php /tmp/ojs-smtp-test.php "$1" || rc=$?
  docker compose exec -T app rm -f /tmp/ojs-smtp-test.php </dev/null
  return $rc
}

explain_failure() {
  cat <<'TXT'
  Common causes:
   - You typed the normal Google password: an App Password (16 letters) is required.
   - 2-Step Verification is not enabled on the account (App Passwords need it).
   - Google Workspace account: the admin has disabled App Passwords / SMTP access.
   - The App Password was deleted or the account password was changed (that revokes it).
TXT
}

do_rollback() {
  local b=${1:-$(latest_backup pre-email)}
  [ -n "$b" ] && [ -d "$b" ] || die "no 'pre-email' backup found in $BACKUP_ROOT"
  info "Rollback: restore .env and the config template from $b"
  ask_yes_no "Continue?" n || exit 0
  take_backup before-email-rollback
  restore_file "$b" "$ENV_FILE"; chmod 600 "$ENV_FILE"
  restore_file "$b" "$TEMPLATE"
  render_and_restart
  report_add CRITICAL ".env" "restored from the backup (SMTP credentials removed or set back)"
  report_add HIGH "$TEMPLATE" "restored from the backup ([email] section set back)"
  report_add HIGH "volumes/config/pkp.config.inc.php" "regenerated live config (never edit by hand)"
  report_add INFO "container pkp_app_ojs" "restarted"
  report_print "EMAIL ROLLBACK DONE" email-rollback
}

do_test() {
  local to=$1
  info "Sending a test email to $to with the current configuration"
  printf '%s\n' "$to" | smtp_test live || { explain_failure; exit 1; }
}

case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=1 ;;
  --test) [ -n "${2:-}" ] || die "usage: $0 --test you@example.com"; do_test "$2"; exit 0 ;;
  --rollback) do_rollback "${2:-}"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  *) die "unknown option: $1 (see $0 --help)" ;;
esac

echo "${BOLD}OJS email setup (Gmail)${RST}"
sed -n '9,14p' "$0" | sed 's/^#/ /'

info "Checks"
preflight

info "Gmail account"
while :; do
  ask GMAIL_USER "Gmail address that OJS will send from"
  GMAIL_USER=$(echo "$GMAIL_USER" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  [[ $GMAIL_USER =~ ^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$ ]] && break
  echo "  that does not look like an email address"
done

for try in 1 2 3; do
  ask_secret APP_PASSWORD "App Password (16 letters, spaces are fine; input is hidden)"
  APP_PASSWORD=$(printf '%s' "$APP_PASSWORD" | tr -d '[:space:]')
  [[ $APP_PASSWORD =~ ^[A-Za-z]{16}$ ]] && break
  echo "  An App Password is exactly 16 letters. Create one at https://myaccount.google.com/apppasswords"
  [ "$try" = 3 ] && die "no valid App Password given; nothing was changed"
done

ask TEST_TO "Send the final test email to" "$GMAIL_USER"

info "Testing the Gmail login (nothing is changed yet)"
if ! printf '%s\n%s\n\n' "$GMAIL_USER" "$APP_PASSWORD" | smtp_test stdin; then
  explain_failure
  die "Gmail refused the login: nothing was changed."
fi

info "Summary"
cat <<TXT
  SMTP server    : $SMTP_SERVER:$SMTP_PORT (STARTTLS)
  Account        : $GMAIL_USER   (App Password: hidden, stored only in .env)
  Sender address : every email is sent from $GMAIL_USER, shown as "Name via <journal>"
  Test email to  : $TEST_TO
TXT
ask_yes_no "Apply these changes?" n || { echo "  Cancelled, nothing was changed."; exit 0; }

# Edit copies in --dry-run, the real files otherwise.
if [ "$DRY_RUN" = 1 ]; then use_work_copies; E=$W_ENV; T=$W_TEMPLATE
else take_backup pre-email; E=$ENV_FILE; T=$TEMPLATE; fi

info "Writing the settings"
printf '%s' "$GMAIL_USER"   | "${CFGEDIT[@]}" env-set "$E" OJS_SMTP_USER
printf '%s' "$APP_PASSWORD" | "${CFGEDIT[@]}" env-set "$E" OJS_SMTP_PASSWORD
unset APP_PASSWORD
ok ".env: OJS_SMTP_USER, OJS_SMTP_PASSWORD"

set_email() { "${CFGEDIT[@]}" ini-set "$T" email "$1" "$2"; }
set_email default                          smtp
set_email smtp                             On
set_email smtp_server                      "$SMTP_SERVER"
set_email smtp_port                        "$SMTP_PORT"
set_email smtp_auth                        tls
set_email smtp_username                    '"${OJS_SMTP_USER}"'
set_email smtp_password                    '"${OJS_SMTP_PASSWORD}"'
set_email allow_envelope_sender            On
set_email default_envelope_sender          '"${OJS_SMTP_USER}"'
set_email force_default_envelope_sender    On
set_email force_dmarc_compliant_from       On
set_email dmarc_compliant_from_displayname '"%n via %s"'
ok "config template: [email] section"

report_add CRITICAL ".env" "now holds OJS_SMTP_USER and OJS_SMTP_PASSWORD (the Gmail App Password)"
report_add HIGH "$TEMPLATE" "[email]: default=smtp, smtp.gmail.com:587 tls, sender + DMARC settings"
report_add HIGH "volumes/config/pkp.config.inc.php" "regenerated live config, contains the App Password (never edit by hand)"
report_add INFO "container pkp_app_ojs" "restarted to load the new settings"
manual_add "Log in to OJS and use 'Forgot password' or invite a test user to see a real OJS email arrive."
manual_add "Gmail sending limit: about 2,000 emails/day (Workspace) or 500/day (personal account)."
manual_add "If the account password changes, Google revokes the App Password: run this script again."
manual_add "Journal > Settings > Workflow > Emails: check the email signature still shows the right address."

if [ "$DRY_RUN" = 1 ]; then
  info "Changes that would be made to the config template"
  diff -u "$TEMPLATE" "$T" | sed 's/^/  /' || true
  info ".env keys that would change (values hidden)"
  "${CFGEDIT[@]}" env-changed "$ENV_FILE" "$E" | sed 's/^/  /'
  report_print "EMAIL SETUP (DRY RUN)" email
  exit 0
fi

render_and_restart

info "Verifying"
scripts/render-config.sh --check >/dev/null && ok "live config matches template + .env"
if printf '%s\n' "$TEST_TO" | smtp_test live; then
  ok "OJS's configuration can send email. Check the inbox of $TEST_TO (and its spam folder)."
else
  explain_failure
  warn "the configuration was applied but the test failed. Undo with: $0 --rollback"
fi

report_print "EMAIL SETUP DONE" email
