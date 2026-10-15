#!/usr/bin/env bash
# Install Podman httpd container on port 35443 + systemd unit
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo" >&2
  exit 1
fi

dnf -y install podman container-selinux policycoreutils-python-utils

semanage port -a -t http_port_t -p tcp 35443 2>/dev/null || \
  semanage port -m -t http_port_t -p tcp 35443

mkdir -p /opt/fedora-lane/www
cat >/opt/fedora-lane/www/index.html <<'HTML'
<html><body><h1>Fedora Lane e-commerce web — httpd OK</h1></body></html>
HTML

# Prefer UBI; fall back to docker.io httpd
IMAGE="registry.access.redhat.com/ubi9/httpd-24"
INNER_PORT=8080
MOUNT_TARGET=/var/www/html

if ! podman pull "$IMAGE"; then
  IMAGE="docker.io/library/httpd:2.4"
  INNER_PORT=80
  MOUNT_TARGET=/usr/local/apache2/htdocs
  podman pull "$IMAGE"
fi

podman rm -f fl-httpd 2>/dev/null || true
podman run -d --name fl-httpd \
  --restart=always \
  -p 35443:${INNER_PORT} \
  -v /opt/fedora-lane/www:${MOUNT_TARGET}:Z \
  "$IMAGE"

cd /tmp
rm -f container-fl-httpd.service
podman generate systemd --new --name fl-httpd --files
cp /tmp/container-fl-httpd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now container-fl-httpd.service

curl -fsS http://127.0.0.1:35443/ | head
echo "httpd container ready on 35443 using image: $IMAGE"
