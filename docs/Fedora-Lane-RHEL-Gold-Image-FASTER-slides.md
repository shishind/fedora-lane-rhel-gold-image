# Fedora Lane — RHEL Gold Image
**FASTER Practice Activity | Server / Cloud OS TDP | Junior Consultant**  
*Local Image Builder (TOML) → AWS AMI → live proof*

---

## Slide 1 — Title
**Fedora Lane — RHEL Gold Image**  
Secure, standardized platform for the e-commerce web fleet

---

## Slide 2 — Agenda (15 minutes)
1. Opening — confirm the three technical challenges  
2. Solution overview — one RHEL gold standard for web nodes  
3. How we built it — local Image Builder + AWS path  
4. Live walkthrough — prove controls on a running EC2  
5. Value & next step  

---

## Slide 3 — Fedora Lane’s challenges today
~1,600 Linux servers across on-prem, AWS, Azure, and boutiques

| 1. Inconsistent estate | 2. Untraceable changes | 3. Container skills gap |
|---|---|---|
| Mixed OS (Rocky/Ubuntu/CentOS/Amazon Linux) | Undocumented admin tweaks | Devs hand ops long `podman run` lines |
| Config drift by region | No reliable audit trail | Typos → long troubleshooting |
| Critical patch failed on 600+ hosts | Long MTTR / revenue impact | Ops depends on developers |
| Missed 30-day CVE window | Hard to prove who changed what | Need service-like ops |

---

## Slide 4 — Who we are speaking to
- **Anya Sharma (CIO)** — agility & CX; safer scale-out  
- **Alex Lee (VP Infra)** — stability and simpler ops  
- **Ren Tanaka (Security)** — provable baseline, least privilege  
- **Casey Novak (Linux Eng)** — one standard fleet  
- **Cameron Shaw (App Dev)** — containers ops can run  

---

## Slide 5 — Our solution: one RHEL gold image
- Single standardized **Red Hat Enterprise Linux** image  
- Defined as a **local Image Builder TOML** blueprint (not hosted Image Builder)  
- Composed once → published as **AWS AMI** (Azure VHD as stretch)  
- Every new web node boots identical: partitions, SELinux, SSH, firewall, httpd  
- Demo: live EC2 launched from that gold AMI  

---

## Slide 6 — How the gold image reaches AWS
1. **TOML blueprint** — define packages, users, partitions, SSH/firewall  
2. **Local Image Builder** — compose on RHEL 9 → disk file (`.raw`)  
3. **S3 upload** — park the file (not bootable yet)  
4. **Snapshot + AMI** — import snapshot = AWS disk; register AMI = catalog  
5. **Launch EC2** — boot proof VM and demonstrate  

---

## Slide 7 — Why import snapshot? (30-second answer)
- Image Builder creates a **disk file** — not an EC2 server  
- **S3** only stores the file — EC2 cannot boot from S3  
- **Import snapshot** = file → AWS-native disk (EBS snapshot)  
- **Register AMI** = launchable gold template  
- **Launch instance** = prove it in the cloud  

**One line:** *S3 holds the file; snapshot is AWS’s disk; AMI is what we launch.*

---

## Slide 8 — What’s baked into the gold image
- Separate mounts: `/var/log`, `/home`, `/tmp`, `/var/tmp` (<5 GiB)  
- `/tmp` mounted **noexec**  
- **SELinux enforcing**  
- SSH on **2222** — key only; no root SSH; no password SSH  
- **httpd in Podman** on **35443**  
- firewalld: only 2222 + 35443  
- `fladmins` + sudo (password required)  
- Services survive reboot  

---

## Slide 9 — Live walkthrough
On the EC2 from the gold AMI:
1. SSH as `fladmin1` on port **2222**  
2. `getenforce` → Enforcing  
3. `findmnt` partitions + `/tmp` noexec  
4. `sudo` asks for password  
5. `curl http://127.0.0.1:35443/` + container/systemd status  
6. `firewall-cmd` — only SSH + httpd  
7. Optional: reboot and re-check  

---

## Slide 10 — How this solves the three challenges
| Inconsistency | Untraceable changes | Container skills gap |
|---|---|---|
| One RHEL AMI | Named admins | httpd as Podman + systemd |
| Same layout every launch | No root / no password SSH | Ops starts a **service** |
| Predictable patching | Sudo always prompts | Not a fragile CLI paste |
| Less drift | Known-good baseline | Repeatable on every node |
| | Next: Session Recording | |

---

## Slide 11 — Recommended next step
1. Pilot this gold AMI on **staging** e-commerce web nodes  
2. Enable **Session Recording / Web Console** for prod admin access  
3. Expand rebuild automation + **Red Hat Insights**  
4. Stretch: Azure image from the **same TOML**  

---

## Slide 12 — Close
**One standard. Every web node.**

A secure RHEL gold AMI that reduces drift, hardens access, and makes container workloads operable for Fedora Lane.

Questions? → Walk the live instance
