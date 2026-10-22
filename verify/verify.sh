#!/usr/bin/env bash
# Post-deploy verification for Fedora Lane RHEL gold image
#
# Usage (on the instance as fladmin1):
#   curl -fsSL https://raw.githubusercontent.com/shishind/fedora-lane-rhel-gold-image/main/verify/verify.sh -o verify.sh
#   bash verify.sh
#
# Needs sudo for: sshd -T, firewall-cmd, reading /etc/sudoers.d (mode 0440 / dir 0750).
set -euo pipefail

PASS=0
FAIL=0

ok()   { echo "[PASS] $*"; PASS=$((PASS+1)); }
bad()  { echo "[FAIL] $*"; FAIL=$((FAIL+1)); }
info() { echo "[INFO] $*"; }

echo "=== Fedora Lane gold image verification ==="

if ! sudo -n true 2>/dev/null; then
  info "sudo password required for firewalld / sshd / sudoers checks"
fi
if ! sudo -v; then
  echo "[FAIL] sudo is required to verify this image"
  exit 1
fi

# Base OS
if grep -qi 'Red Hat Enterprise Linux.*release 10' /etc/redhat-release 2>/dev/null; then
  ok "Base OS is RHEL 10 ($(cat /etc/redhat-release))"
else
  bad "Base OS is not RHEL 10 (got: $(cat /etc/redhat-release 2>/dev/null || echo missing))"
fi

# Hostname (blueprint sets fl-web-gold)
if [[ "$(hostname -s 2>/dev/null || hostname)" == "fl-web-gold" ]]; then
  ok "hostname is fl-web-gold"
else
  info "hostname is $(hostname) (blueprint default is fl-web-gold)"
fi

# SELinux
if [[ "$(getenforce 2>/dev/null || true)" == "Enforcing" ]]; then
  ok "SELinux is Enforcing"
else
  bad "SELinux is not Enforcing (got: $(getenforce 2>/dev/null || echo missing))"
fi

# /tmp noexec
if findmnt -no OPTIONS /tmp 2>/dev/null | tr ',' '\n' | grep -qx noexec; then
  ok "/tmp mounted with noexec"
else
  bad "/tmp missing noexec"
fi

# Separate mounts
for m in /var/log /home /tmp /var/tmp; do
  if findmnt "$m" >/dev/null 2>&1; then
    ok "$m is a separate mount"
  else
    bad "$m is not a separate mount"
  fi
done

# SSH port
if ss -tlnp 2>/dev/null | grep -q ':2222'; then
  ok "sshd listening on 2222"
else
  bad "sshd not listening on 2222"
fi

# httpd / container port
if ss -tlnp 2>/dev/null | grep -q ':35443'; then
  ok "service listening on 35443"
else
  bad "nothing listening on 35443"
fi

# httpd content
if curl -fsS http://127.0.0.1:35443/ >/dev/null 2>&1; then
  ok "httpd responds on 35443"
else
  bad "httpd does not respond on 35443"
fi

# Root SSH config
if sudo sshd -T 2>/dev/null | grep -qi '^permitrootlogin no$'; then
  ok "PermitRootLogin no"
else
  bad "PermitRootLogin not disabled"
fi

# PasswordAuthentication
if sudo sshd -T 2>/dev/null | grep -qi '^passwordauthentication no$'; then
  ok "PasswordAuthentication no"
else
  bad "PasswordAuthentication not disabled"
fi

# firewalld ports — must use sudo; also check active zone (public)
if command -v firewall-cmd >/dev/null 2>&1; then
  if ! sudo firewall-cmd --state >/dev/null 2>&1; then
    bad "firewalld is not running"
  else
    ZONE=$(sudo firewall-cmd --get-default-zone 2>/dev/null || echo public)
    PORTS=$(sudo firewall-cmd --zone="$ZONE" --list-ports 2>/dev/null || true)
    # Fallback: merge runtime --list-ports
    PORTS_ALL=$(sudo firewall-cmd --list-ports 2>/dev/null || true)
    COMBINED="$PORTS $PORTS_ALL"
    info "firewall zone=$ZONE ports: ${PORTS:-<none>}"
    echo "$COMBINED" | grep -q '2222/tcp' && ok "firewall allows 2222/tcp" || bad "firewall missing 2222/tcp"
    echo "$COMBINED" | grep -q '35443/tcp' && ok "firewall allows 35443/tcp" || bad "firewall missing 35443/tcp"
  fi
else
  bad "firewall-cmd not installed"
fi

# fladmins group
if getent group fladmins >/dev/null; then
  ok "group fladmins exists"
else
  bad "group fladmins missing"
fi

# sudoers — /etc/sudoers.d is often 0750 root:root; fladmin1 cannot see files without sudo
if sudo test -f /etc/sudoers.d/fladmins; then
  if sudo grep -q NOPASSWD /etc/sudoers.d/fladmins; then
    bad "fladmins sudoers contains NOPASSWD"
  else
    ok "fladmins sudoers has no NOPASSWD"
  fi
else
  bad "/etc/sudoers.d/fladmins missing"
fi

# container unit enabled (best effort)
if systemctl is-enabled container-fl-httpd.service >/dev/null 2>&1; then
  ok "container-fl-httpd.service enabled"
else
  info "container-fl-httpd.service not enabled (check your unit name)"
fi

echo
echo "=== Summary: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
