# Local Image Builder (TOML) — AWS + Azure

## Hosted vs local (read this)

| Method | Allowed by FASTER brief? |
|--------|---------------------------|
| **Hosted** Image Builder (console.redhat.com / cloud service) | **No** — brief says do not use hosted Image Builder |
| **Local** Image Builder on a RHEL box (`osbuild-composer` + `composer-cli` + TOML blueprint) | **Often what mentors mean** — confirm with your POD/mentor |
| Manual EC2 harden → `create-image` | Yes — we already documented this |

If mentors said “use Image Builder + TOML for AWS and Azure,” they almost always mean **local** Image Builder with one blueprint producing:

- `ami` → upload/register on AWS  
- `vhd` (or Azure type) → upload to Azure  

That matches stretch goal #2 (two cloud images from one standard).

## Can we use a TOML file?

**Yes.** Blueprints are TOML. File in this folder:

`fedora-lane-gold.toml`

It encodes partitions, users, firewall ports, SSH hardening files, and a first-boot script for SELinux ports + Podman httpd on 35443.

## What you need

Image Builder does **not** run natively on Mac. You need a **RHEL 9/10 machine** (another EC2, RHDP VM, or local UTM RHEL) with:

```bash
sudo dnf install -y osbuild-composer composer-cli cockpit-composer
sudo systemctl enable --now osbuild-composer.socket
sudo usermod -aG weldr $USER
# log out/in, then:
composer-cli status
```

## Build flow (high level)

1. Edit `fedora-lane-gold.toml` — replace `SSHKEY_REPLACE_ME` with your `fedora-lane-lab.pub` contents.  
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

5. Upload AMI/VHD to AWS/Azure OPEN envs, launch a VM, prove specs after reboot (first-boot script must have run).

Exact upload steps: RHEL docs “Deploying RHEL on Amazon Web Services” / “on Microsoft Azure” (Image Builder image types).

## Spec coverage notes

| Spec | In TOML / first-boot |
|------|----------------------|
| Separate `/var/log` `/home` `/tmp` `/var/tmp` | `customizations.filesystem` |
| SELinux enforcing | first-boot script |
| `/tmp` noexec | remount in first-boot (verify after boot!) |
| SSH 2222, no root, no password | sshd drop-in file |
| httpd container :35443 | first-boot Podman + systemd |
| fladmins + sudo password | users + sudoers.d |
| Firewall only SSH+httpd | firewall customization + first-boot |
| Survive reboot | systemd units enabled |
| AWS + Azure | `ami` and `vhd` compose types |

**Always verify on a cloud VM** with `verify/verify.sh` — first-boot must succeed once.

## Mentors said “don’t use AWS AMI”?

They usually mean: don’t start from a random marketplace AMI and call that the gold image **without** a defined build process.  
Using Image Builder to **produce** an AMI (or producing AMI via local IB) is different from “just launch RHEL and claim it’s gold.”

Either way you still **upload and run** on AWS/Azure OPEN — the brief requires provisioning a VM from your gold image in cloud.
