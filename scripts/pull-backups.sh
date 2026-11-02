#!/usr/bin/env bash
# Off-site copy: pull backups from the VM to this computer (run on your PC, Git Bash).
#
# Usage: scripts/pull-backups.sh [destination]
#   default destination: ../ojs-backups next to this repository (outside git)
# Only backup folders not already present locally are copied; each one is verified
# against its SHA256SUMS after the copy. Backups contain secrets (.env) and the full
# database: keep the destination private.
set -euo pipefail
VM=${VM:-spe@10.0.3.31}
REMOTE_DIR=${REMOTE_DIR:-ojs-backups}
DEST=${1:-"$(cd "$(dirname "$0")/../.." && pwd)/ojs-backups"}
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10)

mkdir -p "$DEST"
remote=$("${SSH[@]}" "$VM" "ls -1 $REMOTE_DIR | grep -E '^20[0-9]{6}-[0-9]{6}' || true")
copied=0
for b in $remote; do
  [ -d "$DEST/$b" ] && continue
  echo "[pull] $b"
  scp -q -o BatchMode=yes -r "$VM:$REMOTE_DIR/$b" "$DEST/$b.partial"
  if ( cd "$DEST/$b.partial" && sha256sum -c --quiet SHA256SUMS ); then
    mv "$DEST/$b.partial" "$DEST/$b"; copied=$((copied+1))
  else
    echo "[pull] checksum FAILED for $b (left as $b.partial)" >&2
  fi
done
echo "[pull] $copied new backup(s) copied to $DEST"
