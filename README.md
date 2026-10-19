# Fedora Lane — RHEL 10 Gold Image (Server/Cloud OS TDP)

**Audience:** Fedora Lane stakeholders (Casey Novak, Alex Lee, Ren Tanaka) and Red Hat consultants reproducing this lab.  
**Goal:** A secure, standardized **Red Hat Enterprise Linux 10** gold image for the e-commerce **web server** fleet on AWS (Azure stretch).

---

## What we built (one sentence)

A **repeatable RHEL 10 gold image** defined in Image Builder TOML, published as an **AWS AMI**, and proven on a live EC2 instance with hardened SSH, SELinux, separate filesystems, and **httpd in a Podman container**.

---

## Fedora Lane challenges → this solution

| Challenge | What the gold image does |
|-----------|---------------------------|
| **Inconsistent servers** (mixed OS, drift, failed mass patching) | One **RHEL 10** AMI — identical layout and services every launch |
| **Untraceable admin changes** (long MTTR) | Named `fladmins`, no root/password SSH, sudo always asks for a password; known-good baseline |
| **Container skills gap** | **httpd** runs in Podman on port **35443**, managed as a **systemd** service |

Full narrative: [docs/solution-overview.md](docs/solution-overview.md)  
Customer context: [docs/01-what-we-are-solving.md](docs/01-what-we-are-solving.md)  
**Official Red Hat docs:** [docs/redhat-documentation.md](docs/redhat-documentation.md)

---

## Repository layout

```text
README.md                          ← you are here
image-builder/
  fedora-lane-gold.toml            ← RHEL 10 blueprint (distro = "rhel-10")
  10-create-toml-blueprint.md      ← how we built the TOML (password, keys, fields)
  09-weldr-permission-fix.md      ← composer-cli weldr socket permission fix
  08-rhel10-rebuild.md             ← how to compose on a RHEL 10 host
  README.md                        ← Image Builder notes
docs/
  solution-overview.md             ← client-facing architecture + why
  redhat-documentation.md          ← official Red Hat doc links
  07-rhel10-web-console-demo.md    ← optional day-2 Web Console demo (RHDP)
verify/verify.sh                   ← post-boot proof checklist
scripts/                           ← optional hardening helpers (EC2 path)
```

---

## Spec checklist (Expansion Pack)

- [x] Local Image Builder (not **hosted** Image Builder service)
- [x] Base: **RHEL 10** (`distro = "rhel-10"` in TOML — confirm exact id with `composer-cli distros list` / `image-builder list`)
- [x] Deployable on **AWS** (AMI → EC2); Azure VHD = stretch
- [x] httpd + index page; **container preferred** on port **35443**
- [x] Separate mounts `<5 GiB`: `/var/log`, `/home`, `/tmp`, `/var/tmp`
- [x] SELinux **enforcing**; `/tmp` **noexec**
- [x] SSH **2222**; no root SSH; no password SSH
- [x] Admin users + `fladmins` + sudo **with** password
- [x] Firewall: only SSH + httpd ports
- [x] Survives reboot; services enabled at boot

Lab sudo password (demo only): see comment in `image-builder/fedora-lane-gold.toml`  
SSH: use your lab public key already embedded for `fladmin1` / `fladmin2`.

---

## How to build and run

### Prerequisites

1. A **RHEL 10** machine with local Image Builder (`image-builder` / `osbuild-composer` + `weldr-client`) — not macOS.  
2. AWS sandbox/OPEN credentials (never commit them).  
3. Network access to Red Hat repos on the builder host.

### Build (high level)

```bash
# On RHEL 10 builder — first time only:
#   sudo dnf -y install osbuild-composer weldr-client composer-cli ...
#   sudo systemctl enable --now osbuild-composer.socket
#   sudo usermod -aG weldr "$USER"
#   then log out / SSH again  (see image-builder/09-weldr-permission-fix.md)

composer-cli distros list          # confirm rhel-10 / rhel-10.x name
# Edit image-builder/fedora-lane-gold.toml distro= if needed to match EXACTLY

composer-cli blueprints push image-builder/fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
composer-cli compose start fedora-lane-gold ami
composer-cli compose status
composer-cli compose image <UUID>
```

If Cockpit Image Builder only lists qcow2/ova/vmdk/iso: that is normal for local UI. Prefer CLI `ami`, **or** build `.qcow2` → convert to raw → AWS import (see [image-builder/08-rhel10-rebuild.md](image-builder/08-rhel10-rebuild.md)).

### Publish to AWS + prove

1. Upload disk to S3 → `import-snapshot` (needs `vmimport` role) → `register-image` → AMI.  
2. Launch EC2; security group: **2222** and **35443** from your IP.  
3. Wait for first-boot (Podman pull), then:

```bash
ssh -i <your-lab-key> -p 2222 fladmin1@<PUBLIC_IP>
sudo bash verify/verify.sh
curl -s http://127.0.0.1:35443/
cat /etc/redhat-release    # expect RHEL 10.x
sudo reboot                # re-check after reboot
```

Detailed AWS notes: [docs/04-easy-aws-ec2-ami.md](docs/04-easy-aws-ec2-ami.md)

---

## Live walkthrough (end-user view)

From the customer’s perspective (Casey / Alex):

1. New web server = launch from the **gold AMI** (no snowflake install).  
2. Admins connect with keys on **2222** as named users.  
3. Site answers on **35443**; container is a systemd service.  
4. Security baseline is already on: SELinux, firewall, partitions, sudo policy.

Optional day-2 GUI story (Web Console / Session Recording): [docs/07-rhel10-web-console-demo.md](docs/07-rhel10-web-console-demo.md) on RHDP **RHEL 10 Base** (gold AMI firewall still only 2222+35443 per brief).

---

## Recommended next step (for Fedora Lane)

1. Pilot this **RHEL 10** gold AMI on **staging** web nodes.  
2. Enable **Session Recording / Web Console** for production admin access.  
3. Automate rebuilds + Red Hat Insights at fleet scale.  
4. Stretch: Azure image from the **same** TOML.

---

## Publishing this repository (FASTER)

**Preferred (Core Pack):** Consulting **GitLab** — cohort sub-group under the FASTER group.

```bash
cd ~/Projects/fedora-lane-rhel-gold-image
git remote add origin <YOUR_FASTER_GITLAB_REPO_URL>
git push -u origin main
```

**Alternate (Expansion Pack):** private GitHub + add `mflaim-eng` for review.

Do **not** push `.pem`, `.aws/`, RHDP passwords, or raw disk images.
