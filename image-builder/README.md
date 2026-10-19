# Local Image Builder (TOML) — AWS + Azure

Fedora Lane’s gold image is built with **local** Image Builder on a RHEL host (`osbuild-composer` + `composer-cli` + a TOML blueprint).  
Do **not** use the hosted Image Builder cloud service for this standard.

One blueprint can produce:

- `ami` → upload/register on AWS  
- `vhd` (or related Azure type) → upload to Azure (stretch)

## Blueprint file

`fedora-lane-gold.toml`

It encodes partitions, users, firewall ports, SSH hardening, and a first-boot script for SELinux ports + Podman httpd on 35443.

**How the TOML is structured** (password hash, SSH key, every block):  
[10-create-toml-blueprint.md](10-create-toml-blueprint.md)

## What you need

A **RHEL 9/10** builder host (EC2, on-prem VM, or similar) with:

```bash
sudo dnf install -y osbuild-composer composer-cli cockpit-composer weldr-client
sudo systemctl enable --now osbuild-composer.socket
sudo usermod -aG weldr "$USER"
# log out / SSH again (or: newgrp weldr), then:
id | grep weldr
composer-cli status
composer-cli distros list
```

If you get **permission denied on `/run/weldr/api.socket`**, see  
[09-weldr-permission-fix.md](09-weldr-permission-fix.md).

If **depsolve** fails with CDN / `repomd.xml` / `RepoError`, see  
[11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md).

After you have a `.raw` image: AWS credentials, Console S3 bucket, CLI upload —  
[12-aws-access-s3-upload.md](12-aws-access-s3-upload.md).

## Build flow (high level)

1. Set the admin SSH **public** key and password hash in `fedora-lane-gold.toml` (see [10-create-toml-blueprint.md](10-create-toml-blueprint.md)).  
2. Push blueprint:

```bash
composer-cli blueprints push fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
```

3. Compose for AWS:

```bash
composer-cli compose start fedora-lane-gold ami
# note COMPOSE_ID, wait until FINISHED
composer-cli compose image COMPOSE_ID
```

4. Compose for Azure (stretch):

```bash
composer-cli compose start fedora-lane-gold vhd
```

5. Upload to AWS/Azure, launch a VM, and verify after reboot (first-boot must have run once).

Official references: RHEL docs *Deploying RHEL on Amazon Web Services* / *on Microsoft Azure*.

## Spec coverage

| Requirement | In TOML / first-boot |
|-------------|----------------------|
| Separate `/var/log` `/home` `/tmp` `/var/tmp` | `customizations.filesystem` |
| SELinux enforcing | first-boot script |
| `/tmp` noexec | remount in first-boot (verify after boot) |
| SSH 2222, no root, no password | sshd drop-in file |
| httpd container :35443 | first-boot Podman + systemd |
| fladmins + sudo password | users + sudoers.d |
| Firewall only SSH+httpd | firewall customization + first-boot |
| Survive reboot | systemd units enabled |
| AWS + Azure | `ami` and `vhd` compose types |

**Always verify** on a cloud VM with `verify/verify.sh`.

## Marketplace AMI vs gold AMI

A random marketplace RHEL AMI is only a starting OS. This project’s gold image is a **defined blueprint** composed to AMI so every web node is identical. You still launch and run that AMI in AWS (or Azure) for day-2 proof.
