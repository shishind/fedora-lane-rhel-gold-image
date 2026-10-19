# Verify gold-image customizations (post-launch)

After launching an EC2 instance from the Fedora Lane gold AMI, confirm every customization from the blueprint and first-boot script.

**Security group:** allow your admin IP on **TCP 2222** (SSH) and **TCP 35443** (httpd).

---

## 1) Connect

From your admin workstation (key must match the public key in the TOML):

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

If this times out, check the security group source IP first.

Wait a few minutes after first boot so Podman can pull the httpd image and start `container-fl-httpd.service`.

---

## 2) One-shot script (recommended)

Copy `verify/verify.sh` onto the instance (or clone this repo there), then:

```bash
sudo bash verify/verify.sh
```

Expect all checks **PASS** (or investigate any **FAIL**).

---

## 3) Manual checks — customization → command

| Customization | What to run | Expect |
|---------------|-------------|--------|
| **RHEL 10 base** | `cat /etc/redhat-release` | Red Hat Enterprise Linux release **10.x** |
| **Hostname** | `hostname` | `fl-web-gold` (or similar from blueprint) |
| **SELinux enforcing** | `getenforce` | `Enforcing` |
| **Separate mounts** | `findmnt /var/log /home /tmp /var/tmp` | Each is its own mount |
| **`/tmp` noexec** | `findmnt -no OPTIONS /tmp` | includes `noexec` |
| **SSH on 2222** | `sudo ss -tlnp \| grep 2222` | `sshd` listening |
| **No root SSH** | `sudo sshd -T \| grep permitrootlogin` | `permitrootlogin no` |
| **No password SSH** | `sudo sshd -T \| grep passwordauthentication` | `passwordauthentication no` |
| **Admins group** | `getent group fladmins` | `fladmin1`, `fladmin2` listed |
| **Sudo with password** | `sudo -k; sudo id` | Prompts for password (lab: `RedHat`) — no NOPASSWD |
| **Firewall only 2222+35443** | `sudo firewall-cmd --list-ports` | `2222/tcp` and `35443/tcp` (no default ssh/http) |
| **httpd container port** | `sudo ss -tlnp \| grep 35443` | listener on 35443 |
| **httpd content** | `curl -s http://127.0.0.1:35443/` | HTML with “Fedora Lane…httpd OK” |
| **systemd unit** | `systemctl status container-fl-httpd.service` | **active (running)** |
| **Unit enabled** | `systemctl is-enabled container-fl-httpd.service` | `enabled` |
| **From laptop (optional)** | `curl -s http://<PUBLIC_IP>:35443/` | same page (SG must allow 35443) |

Copy-paste block on the instance:

```bash
cat /etc/redhat-release
hostname
getenforce
findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp
sudo ss -tlnp | egrep '2222|35443'
sudo sshd -T | egrep 'permitrootlogin|passwordauthentication'
getent group fladmins
sudo firewall-cmd --list-ports
curl -s http://127.0.0.1:35443/
systemctl is-active container-fl-httpd.service
systemctl is-enabled container-fl-httpd.service
sudo -k; sudo id    # must ask for password
```

---

## 4) Survive reboot (required)

```bash
sudo reboot
```

Reconnect after ~2 minutes:

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
sudo bash verify/verify.sh
curl -s http://127.0.0.1:35443/
```

SSH, firewall, mounts, SELinux, and httpd must still be correct after reboot.

---

## 5) Map back to the blueprint

| You verified | Defined in |
|--------------|------------|
| RHEL 10 / packages / mounts / users / firewall / sshd drop-in | `image-builder/fedora-lane-gold.toml` |
| SELinux, `/tmp` noexec, SELinux ports, Podman httpd, systemd unit | first-boot script in the same TOML |
| Automated PASS/FAIL | `verify/verify.sh` |

---

## Related

- [image-builder/12-aws-access-s3-upload.md](../image-builder/12-aws-access-s3-upload.md) — publish `.raw` to AWS  
- [image-builder/10-create-toml-blueprint.md](../image-builder/10-create-toml-blueprint.md) — what the TOML contains  
- [docs/solution-overview.md](solution-overview.md) — why these controls exist  
