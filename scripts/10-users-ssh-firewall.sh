#!/usr/bin/env bash
# Run on the builder VM as a user with sudo.
# Usage: PUBKEY="$(cat ~/.ssh/fedora-lane-lab.pub)" sudo -E bash scripts/10-users-ssh-firewall.sh
set -euo pipefail

: "${PUBKEY:?Set PUBKEY env var to your SSH public key string}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo" >&2
  exit 1
fi

dnf -y install policycoreutils-python-utils firewalld

groupadd -f fladmins
for u in fladmin1 fladmin2; do
  id "$u" &>/dev/null || useradd -m -G fladmins -s /bin/bash "$u"
  mkdir -p "/home/$u/.ssh"
  echo "$PUBKEY" > "/home/$u/.ssh/authorized_keys"
  chmod 700 "/home/$u/.ssh"
  chmod 600 "/home/$u/.ssh/authorized_keys"
  chown -R "$u:$u" "/home/$u/.ssh"
done

echo '%fladmins ALL=(ALL) ALL' > /etc/sudoers.d/fladmins
chmod 440 /etc/sudoers.d/fladmins
visudo -cf /etc/sudoers.d/fladmins

semanage port -a -t ssh_port_t -p tcp 2222 2>/dev/null || \
  semanage port -m -t ssh_port_t -p tcp 2222

tee /etc/ssh/sshd_config.d/99-fedora-lane.conf >/dev/null <<'EOF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
EOF

sshd -t
systemctl restart sshd
systemctl enable sshd

systemctl enable --now firewalld
firewall-cmd --permanent --remove-service=ssh 2>/dev/null || true
firewall-cmd --permanent --add-port=2222/tcp
firewall-cmd --permanent --add-port=35443/tcp
firewall-cmd --reload

echo "DONE: set passwords with: passwd fladmin1 && passwd fladmin2"
echo "TEST SSH in a NEW terminal before closing this session: ssh -p 2222 fladmin1@HOST"
