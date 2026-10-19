# Verify gold-image customizations

Works the same on **AWS EC2** and **Azure VM**.

SSH in (cloud firewall must allow your IP on **2222**):

| Cloud | Open these inbound ports to your IP |
|-------|-------------------------------------|
| AWS | Security group: TCP **2222**, **35443** |
| Azure | Network security group: TCP **2222**, **35443** |

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

Wait a few minutes after first boot for the httpd container to start, then run these on the instance.

Build/publish paths: [00-end-to-end-guide.md](00-end-to-end-guide.md) · AWS [12](../image-builder/12-aws-access-s3-upload.md) · Azure [15](../image-builder/15-azure-vhd-upload.md)

---

## Base OS and hostname

```bash
cat /etc/redhat-release
# expect: Red Hat Enterprise Linux release 10.x

hostname
# expect: fl-web-gold
```

---

## SELinux and filesystems

```bash
getenforce
# expect: Enforcing

findmnt /var/log /home /tmp /var/tmp
# each path should be its own mount

findmnt -no OPTIONS /tmp
# must include: noexec
```

---

## SSH hardening

```bash
sudo ss -tlnp | grep 2222
# sshd listening on 2222

sudo sshd -T | grep permitrootlogin
# permitrootlogin no

sudo sshd -T | grep passwordauthentication
# passwordauthentication no
```

---

## Admins and sudo

```bash
getent group fladmins
# fladmin1 and fladmin2 present

sudo -k
sudo id
# must ask for password (lab password: RedHat)
```

---

## Firewall

```bash
sudo firewall-cmd --list-ports
# expect: 2222/tcp and 35443/tcp
```

---

## httpd container (port 35443)

```bash
sudo ss -tlnp | grep 35443
curl -s http://127.0.0.1:35443/
systemctl is-active container-fl-httpd.service
systemctl is-enabled container-fl-httpd.service
# active / enabled, and HTML page with Fedora Lane httpd OK
```

From your laptop (SG must allow **35443**):

```bash
curl -s http://<PUBLIC_IP>:35443/
```

---

## After reboot

```bash
sudo reboot
```

Reconnect, then re-run the same commands above. SSH, mounts, SELinux, firewall, and httpd must still work.

---

## If these three fail (common on first AMI)

| Result | Meaning | Fix on this instance (then rebuild AMI later) |
|--------|---------|-----------------------------------------------|
| hostname is `ip-…compute.internal` | AWS cloud-init overwrote `fl-web-gold` | See hostname fix below |
| `firewall-cmd --list-ports` empty | firewalld active but ports not in zone | See firewall fix below |
| `/etc/sudoers.d/fladmins` missing | sudo still works via `wheel`; fladmins file absent | See sudoers fix below |

### Hostname

```bash
sudo hostnamectl set-hostname fl-web-gold
echo 'preserve_hostname: true' | sudo tee /etc/cloud/cloud.cfg.d/99-fedora-lane.cfg
hostname
```

### Firewall (public zone)

```bash
sudo systemctl enable --now firewalld
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --permanent --zone=public --add-port=2222/tcp
sudo firewall-cmd --permanent --zone=public --add-port=35443/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
# expect: 2222/tcp 35443/tcp
```

### sudoers for fladmins

```bash
echo '%fladmins ALL=(ALL) ALL' | sudo tee /etc/sudoers.d/fladmins
sudo chmod 440 /etc/sudoers.d/fladmins
sudo visudo -cf /etc/sudoers.d/fladmins
ls -l /etc/sudoers.d/fladmins
```

Blueprint **0.1.2** first-boot applies these automatically on the next compose.
