# Fedora Lane — RHEL 10 Gold Image

*Exact configuration · Issues solved · Architecture*  
Local Image Builder (TOML) → AWS AMI → live EC2 proof  
**Red Hat Enterprise Linux 10 · `image-builder` CLI · `distro = rhel-10.0`**

---

## 1. Agenda

Fifteen minutes — customer story to live proof.

1. **Challenges** — Inconsistent estate, untraceable change, container ops gap  
2. **Exact configuration** — RHEL 10.0 blueprint — partitions, SSH, SELinux, httpd  
3. **Architecture & Image Builder** — Official RHEL docs path + TOML → AMI pipeline  
4. **Value & next step** — What each control prevents — staging pilot  

---

## 2. Three challenges

~1,600 Linux servers — mixed OS, drift, brittle ops.

### Challenge 1 — Inconsistent estate
Rocky, Ubuntu, CentOS Stream, Amazon Linux — config drift. Critical patch failed on 600+ hosts; missed 30-day remediation.

### Challenge 2 — Untraceable changes
Interactive edits with no audit trail. Long MTTR when outages hit — who changed what, when?

### Challenge 3 — Container skills gap
Ops handed fragile `podman` one-liners. No clean start/stop/status model for the web tier.

---

## 3. Exact configuration

Blueprint: `fedora-lane-gold.toml` · version **0.1.3** · `distro = "rhel-10.0"`

| Area | Setting |
|------|---------|
| Base platform | RHEL 10 via local Image Builder — exact id `rhel-10.0` (not `rhel-10`) |
| Filesystems | `/var/log`, `/home`, `/tmp`, `/var/tmp` — 2 GiB each; `/tmp` noexec |
| Hardening | SELinux enforcing · SSH :2222 key-only · no root · no password SSH |
| Admins | `fladmin1` / `fladmin2` in `fladmins` · sudo always requires password |
| Network | firewalld: only TCP **2222** + **35443** (source: operator IP) |
| Web tier | httpd in Podman + systemd (`container-fl-httpd`) on :35443 |

---

## 4. Challenge → what solves it

| Challenge | Solution | Detail |
|-----------|----------|--------|
| Inconsistent estate | One RHEL 10 AMI | Identical layout, packages, and policy on every launch |
| Untraceable changes | Named admins + hard SSH | fladmins, key-only :2222, sudo password — known-good baseline |
| Container skills gap | systemd-managed httpd | `container-fl-httpd.service` — start / stop / status |

---

## 5. Architecture

```
TOML (rhel-10.0) → Local Image Builder → Gold disk (.raw) → S3 → Snapshot (snap-…) → AMI (ami-…) → EC2
```

**Every web node:** SSH fladmin* :2222 · httpd container :35443 · SELinux · tight firewalld · separate mounts · `/tmp` noexec  

**Publish options:** `image-builder` upload (preferred) · or S3 → import-snapshot → register-image · CLI or Console · needs `vmimport` IAM role once  

---

## 6. RHEL Image Builder (official Red Hat docs)

**Book:** [Composing a customized RHEL system image](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index) (RHEL 10)

### What it is
Tool to create deployment-ready customized images (disks, VMs, cloud images) faster than hand-building each format.

### How Fedora Lane uses it
- Local Image Builder on a **RHEL 10** host — **not** hosted Image Builder on console.redhat.com  
- Packages: `image-builder` (+ optional `cockpit-image-builder`)  
- Blueprint = TOML (packages + customizations)  

### Builder host (from Red Hat docs)
- ≥2 cores · ≥4 GiB RAM · ≥20 GiB free in `/var/cache/`  
- Root · RHSM/Satellite · CDN (or mirrored repos)  
- Not supported in containers / UBI  

### Key chapters
| Chapter | Topic |
|---------|--------|
| Ch 2 | Installing — `dnf install image-builder cockpit-image-builder` |
| Ch 4 | Creating images with the CLI |
| Ch 6 | Creating images with the web console |
| AMI chapter | Preparing and uploading AMI images to AWS |

---

## 7. Image Builder workflow

1. **Install** — `# dnf install -y image-builder cockpit-image-builder`  
2. **List distro** — `# image-builder list --filter distro:rhel-10*` → use exact id (`rhel-10.0`)  
3. **Build** — `# image-builder build ami --blueprint ./fedora-lane-gold.toml --distro rhel-10.0`  
4. **Publish** — upload to AWS, or S3 → snapshot → AMI  

Tip: short distro id `rhel-10` fails — always confirm with `image-builder list`.

---

## 8. AWS: disk → AMI → launch

S3 stores the file — EC2 boots only from an **AMI**.

```
.raw in S3 → Import snapshot → Create AMI → Security group → Launch EC2 → SSH :2222
```

### CLI
- `aws ec2 import-snapshot`  
- `aws ec2 register-image`  
- `aws ec2 run-instances`  
- Or: `image-builder upload --to=aws`  

### Console
- EC2 → Snapshots → **Import snapshot** (RAW + S3 key)  
- Snapshot → **Create image from snapshot** → `ami-…`  
- SG: TCP **2222** + **35443** from **My IP**  
- AMIs → **Launch instance** (public IP on)  

Official: *Preparing and uploading AMI images to AWS* (same RHEL 10 book).

---

## 9. Config → issue prevented

| Configuration | Issue prevented |
|---------------|-----------------|
| Separate mounts | Logs/temp cannot fill root and kill checkout |
| `/tmp` noexec + SELinux | Reduces malware execution & lateral movement |
| SSH :2222 + keys + sudo password | Accountable admins; harder remote attack path |
| firewalld 2222+35443 only | Minimal network attack surface |
| systemd httpd container | Ops-manageable web tier |
| Exact `rhel-10.0` + TOML | Repeatable rebuilds |

---

## 10. What we prove on EC2

After first-boot (2–5 min):

| Check | Command / expectation |
|-------|------------------------|
| SSH | `ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$IP` |
| Release | `cat /etc/redhat-release` → RHEL 10 |
| SELinux | `getenforce` → Enforcing |
| Firewall | `firewall-cmd --list-ports` → 2222/tcp 35443/tcp |
| Web | `curl http://$IP:35443/` |
| Service | `systemctl status container-fl-httpd` |

---

## 11. Next step

1. Pilot gold AMI on staging web nodes  
2. Add Web Console + Session Recording for audited day-2 access  
3. Automate rebuilds + Insights; stretch Azure from the same TOML  

---

## 12. Red Hat documentation (keep open)

[Composing a customized RHEL system image — RHEL 10](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index)

- Installing RHEL image builder  
- Creating system images by using the RHEL image builder CLI  
- Creating system images by using the RHEL image builder web console  
- Preparing and uploading AMI images to AWS  

Repo guides: `image-builder/12-aws-access-s3-upload.md` · `image-builder/13-image-builder-aws-examples.md`

---

*Fedora Lane · RHEL 10 Gold Image · Local Image Builder*
