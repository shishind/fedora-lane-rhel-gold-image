# Fedora Lane — RHEL 10 Gold Image

**Audience:** Fedora Lane infrastructure, security, and Linux operations (e-commerce web fleet).  
**Goal:** A secure, standardized **Red Hat Enterprise Linux 10** gold image for web servers on **AWS** and **Microsoft Azure**, from one Image Builder blueprint.

**Start here (full steps):** [docs/00-end-to-end-guide.md](docs/00-end-to-end-guide.md)

---

## What we built

A **repeatable RHEL 10 gold image** defined in Image Builder TOML (`distro = "rhel-10.0"`), published as:

| Cloud | Image Builder type | Result |
|-------|--------------------|--------|
| **AWS** | `ami` | AMI → EC2 |
| **Azure** | `vhd` | Managed image → VM |

Proven controls: hardened SSH **2222**, SELinux enforcing, separate filesystems, firewall only **2222** + **35443**, **httpd in Podman** managed as a **systemd** service.

---

## Challenges → this solution

| Challenge | What the gold image does |
|-----------|---------------------------|
| **Inconsistent servers** (mixed OS, drift, failed mass patching) | One **RHEL 10** image — identical layout and services every launch |
| **Untraceable admin changes** (long MTTR) | Named `fladmins`, no root/password SSH, sudo always asks for a password |
| **Container skills gap** | **httpd** on port **35443**, managed as **`container-fl-httpd.service`** |

Full narrative: [docs/solution-overview.md](docs/solution-overview.md)  
Context: [docs/01-what-we-are-solving.md](docs/01-what-we-are-solving.md)  
**Official Red Hat docs:** [docs/redhat-documentation.md](docs/redhat-documentation.md)

---

## Repository layout

```text
README.md
docs/
  00-end-to-end-guide.md           ← full AWS + Azure step path (start here)
  solution-overview.md
  08-verify-customizations.md      ← post-launch checks (both clouds)
  redhat-documentation.md
  07-rhel10-web-console-demo.md
image-builder/
  fedora-lane-gold.toml            ← single blueprint for ami + vhd
  README.md                        ← Image Builder CLI overview
  08-rhel10-rebuild.md             ← build ami / vhd on RHEL 10
  12-aws-access-s3-upload.md       ← AWS credentials, S3, snapshot, AMI, Console
  13-image-builder-aws-examples.md ← AWS copy-paste commands
  15-azure-vhd-upload.md           ← Azure CLI + Portal (detailed)
  16-azure-examples.md             ← Azure copy-paste commands
  10-create-toml-blueprint.md
  11-depsolve-cdn-repo-fix.md
  14-distro-ami-not-found.md
scripts/
```

---

## Requirements checklist

- [x] Local Image Builder (not the hosted Image Builder cloud service)
- [x] Base: **RHEL 10** (`distro = "rhel-10.0"` — confirm with `image-builder list`)
- [x] Deployable on **AWS** (AMI → EC2) and **Azure** (VHD → managed image → VM)
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

## How to build and run (detailed)

### 1) Prerequisites

1. A **RHEL 10** host with local Image Builder (`image-builder` package / CLI).  
2. Network access to Red Hat repositories on the builder host.  
3. For **AWS:** credentials + S3 + `vmimport` role (never commit keys).  
4. For **Azure:** `az` CLI login + subscription rights (never commit storage keys).  
5. Matching SSH private key for `fladmin1` on your laptop.

### 2) Install Image Builder and confirm distro id

```bash
sudo dnf install -y image-builder cockpit-image-builder

# Must show e.g. rhel-10.0 type:ami and type:vhd  (NOT bare "rhel-10")
sudo image-builder list --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
```

Set `distro = "rhel-10.0"` (exact id) in `fedora-lane-gold.toml`.

CDN / subscription problems: [image-builder/11-depsolve-cdn-repo-fix.md](image-builder/11-depsolve-cdn-repo-fix.md)

### 3) Build for AWS (`ami`)

```bash
cd image-builder

sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

**Build + upload to AWS (example):**

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

**Manual path** (S3 → import-snapshot → register-image → launch — CLI **and** Console):  
[image-builder/12-aws-access-s3-upload.md](image-builder/12-aws-access-s3-upload.md)

**All AWS examples:** [image-builder/13-image-builder-aws-examples.md](image-builder/13-image-builder-aws-examples.md)

Security group: your IP on **2222** and **35443**.

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

### 4) Build for Azure (`vhd`)

`/var` needs **≥ 15–20 GiB free** during the VHD compose.

```bash
df -h /var

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

Then:

1. Create resource group + storage account + container  
2. Upload `.vhd` as a **page** blob  
3. Create managed image (**Linux**, **Gen 2**)  
4. NSG: **2222** + **35443** from your IP  
5. Create VM (`fladmin1` + blueprint SSH public key)  
6. SSH on port **2222**

**Full Azure guide (CLI + Portal):** [image-builder/15-azure-vhd-upload.md](image-builder/15-azure-vhd-upload.md)  
**Azure copy-paste sheet:** [image-builder/16-azure-examples.md](image-builder/16-azure-examples.md)

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

### 5) Verify (same commands on AWS EC2 and Azure VM)

[docs/08-verify-customizations.md](docs/08-verify-customizations.md)

Official Image Builder CLI: [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

---

## Day-2 operations (end-user view)

1. New web server = launch from the **gold AMI** (AWS) or **gold managed image** (Azure).  
2. Admins connect with keys on **2222** as named users.  
3. Site answers on **35443**; container is a systemd service.  
4. Security baseline is already on: SELinux, firewall, partitions, sudo policy.

Optional GUI management (Web Console / Session Recording): [docs/07-rhel10-web-console-demo.md](docs/07-rhel10-web-console-demo.md).  
Gold image firewall still allows only **2222** and **35443**.

---

## Recommended next step

1. Pilot this **RHEL 10** gold image on **staging** web nodes (AWS and/or Azure).  
2. Enable **Session Recording / Web Console** for production admin access.  
3. Automate rebuilds + Red Hat Insights at fleet scale.

---

## Repository hygiene

Do **not** commit Access Keys, Secret Keys, Azure storage keys, session tokens, private SSH keys (`.pem`), `azure.toml` with secrets, or raw / VHD disk images.
