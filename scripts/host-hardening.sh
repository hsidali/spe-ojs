#!/usr/bin/env bash
# Host settings that need root (run ONCE on the VM, by a person who has the sudo password):
#   ssh -t spe@10.0.3.31 "sudo bash ~/ojs-deploy/scripts/host-hardening.sh"
#
#  S5  host time zone -> Africa/Algiers
#  S4  NTP via the LAN gateway 10.0.3.254 (public NTP servers are blocked on this network)
#  M8  ufw firewall: deny incoming except SSH, OJS web (8080) and ZeroTier (9993/udp)
#
# Safe to run again. Rollback: sudo ufw disable ; sudo rm /etc/systemd/timesyncd.conf.d/10-local-ntp.conf
# Note: ports published by Docker (8080) bypass ufw; the ufw rule documents the intent.
# Restricting 8080 for real happens when a reverse proxy is added (bind 127.0.0.1:8080).
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

echo "== S5 time zone"
timedatectl set-timezone Africa/Algiers

echo "== S4 NTP"
mkdir -p /etc/systemd/timesyncd.conf.d
cat > /etc/systemd/timesyncd.conf.d/10-local-ntp.conf <<'CONF'
[Time]
NTP=10.0.3.254
FallbackNTP=ntp.ubuntu.com
CONF
systemctl restart systemd-timesyncd

echo "== M8 firewall"
ufw allow OpenSSH comment 'SSH'            # added BEFORE enabling, so SSH can't be locked out
ufw allow 8080/tcp comment 'OJS web'
ufw allow 9993/udp comment 'ZeroTier'
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

echo
echo "== Result"
sleep 8
timedatectl | grep -E 'Time zone|synchronized|NTP service'
timedatectl timesync-status 2>/dev/null | grep -E 'Server|Packet count' || true
ufw status verbose
