# Fedora Lane — RHEL 10 Gold Image

**Audience:** Fedora Lane infrastructure, security, and Linux operations (e-commerce web fleet).  
**Goal:** A secure, standardized **Red Hat Enterprise Linux 10** gold image for web servers on **AWS** (Azure as a stretch).

---

## What we built

A **repeatable RHEL 10 gold image** defined in Image Builder TOML, published as an **AWS AMI**, and proven on a live EC2 instance with hardened SSH, SELinux, separate filesystems, and **httpd in a Podman container**.

---

## Challenges → this solution

| Challenge | What the gold image does |
|-----------|---------------------------|
| **Inconsistent servers** (mixed OS, drift, failed mass patching) | One **RHEL 10** AMI — identical layout and services every launch |
| **Untraceable admin changes** (long MTTR) | Named `fladmins`, no root/password SSH, sudo always asks for a password; known-good baseline |
| **Container skills gap** | **httpd** runs in Podman on port **35443**, managed as a **systemd** service |

Full narrative: [docs/solution-overview.md](docs/solution-overview.md)  
Context: [docs/01-what-we-are-solving.md](docs/01-what-we-are-solving.md)  
**Official Red Hat docs:** [docs/redhat-documentation.md](docs/redhat-documentation.md)

---

## Repository layout

```text
README.md                          ← you are here
image-builder/
  fedora-lane-gold.toml            ← RHEL 10 blueprint (distro = "rhel-10")
  12-aws-access-s3-upload.md       ← AWS credentials, S3 bucket, CLI upload
  10-create-toml-blueprint.md      ← how the TOML is built (password, keys, fields)
  09-weldr-permission-fix.md      ← composer-cli weldr socket permission fix
  08-rhel10-rebuild.md             ← compose on a RHEL 10 host
  README.md                        ← Image Builder notes
docs/
  solution-overview.md             ← architecture + why
  08-verify-customizations.md      ← simple commands to test after AMI launch
  redhat-documentation.md          ← official Red Hat doc links
  07-rhel10-web-console-demo.md    ← optional day-2 Web Console operations
scripts/                           ← optional hardening helpers
```

---

## Requirements checklist

- [x] Local Image Builder (not the hosted Image Builder cloud service)
- [x] Base: **RHEL 10** (`distro = "rhel-10"` — confirm with `composer-cli distros list`)
- [x] Deployable on **AWS** (AMI → EC2); Azure VHD = stretch
- [x] httpd + index page; **container preferred** on port **35443**
- [x] Separate mounts `<5 GiB`: `/var/log`, `/home`, `/tmp`, `/var/tmp`
- [x] SELinux **enforcing**; `/tmp` **noexec**
- [x] SSH **2222**; no root SSH; no password SSH
- [x] Admin users + `fladmins` + sudo **with** password
- [x] Firewall: only SSH + httpd ports
- [x] Survives reboot; services enabled at boot

Admin sudo password (environment-specific): see comment in `image-builder/fedora-lane-gold.toml`.  
SSH: public key embedded for `fladmin1` / `fladmin2` in the blueprint.

---

## How to build and run

### Prerequisites

1. A **RHEL 10** host with local Image Builder (`osbuild-composer` + `weldr-client` / `composer-cli`).  
2. AWS credentials with permission to use S3 and EC2 (never commit them).  
3. Network access to Red Hat repositories on the builder host.

### Build (high level)

```bash
# On RHEL 10 builder — first time only:
#   sudo dnf -y install osbuild-composer weldr-client composer-cli ...
#   sudo systemctl enable --now osbuild-composer.socket
#   sudo usermod -aG weldr "$USER"
#   then log out / SSH again  (see image-builder/09-weldr-permission-fix.md)

composer-cli distros list
# Edit image-builder/fedora-lane-gold.toml distro= if needed to match EXACTLY

composer-cli blueprints push /path/to/fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
composer-cli compose start fedora-lane-gold ami
composer-cli compose status
composer-cli compose image <UUID>
```

If the Cockpit UI only lists qcow2/ova/vmdk/iso, prefer CLI type `ami`, or build `.qcow2` → convert to raw → AWS import ([image-builder/08-rhel10-rebuild.md](image-builder/08-rhel10-rebuild.md)).

### Publish to AWS + prove

1. Configure AWS access → create S3 bucket in Console → `aws s3 cp` the `.raw` —  
   [image-builder/12-aws-access-s3-upload.md](image-builder/12-aws-access-s3-upload.md).  
2. `import-snapshot` (needs `vmimport` role) → `register-image` → AMI.  
3. Launch EC2; security group allows **2222** and **35443** from admin networks.  
4. Wait for first-boot (Podman pull), then:

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

Then run the simple checks in [docs/08-verify-customizations.md](docs/08-verify-customizations.md) (SELinux, mounts, SSH, firewall, httpd, reboot).

---

## Day-2 operations (end-user view)

1. New web server = launch from the **gold AMI** (no snowflake install).  
2. Admins connect with keys on **2222** as named users.  
3. Site answers on **35443**; container is a systemd service.  
4. Security baseline is already on: SELinux, firewall, partitions, sudo policy.

Optional GUI management (Web Console / Session Recording): [docs/07-rhel10-web-console-demo.md](docs/07-rhel10-web-console-demo.md).  
Gold AMI firewall still allows only **2222** and **35443**.

---

## Recommended next step

1. Pilot this **RHEL 10** gold AMI on **staging** web nodes.  
2. Enable **Session Recording / Web Console** for production admin access.  
3. Automate rebuilds + Red Hat Insights at fleet scale.  
4. Stretch: Azure image from the **same** TOML.

---

## Repository hygiene

Do **not** commit Access Keys, Secret Keys, session tokens, private SSH keys (`.pem`), or raw disk images.
