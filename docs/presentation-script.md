# Presentation script — Fedora Lane RHEL 10 Gold Image

**Audience:** Fedora Lane leadership (Anya, Alex, Ren, Casey, Cameron)  
**Length:** ~15 minutes  
**Deck:** `docs/Fedora-Lane-RHEL-Gold-Image-FASTER.pptx` — **customer voice** (you / your)  
**Live proof:** EC2 launched from the gold AMI

Speak to the customer. Keep FASTER / pack language off the slides and out of the spoken opening.

---

## Before you start (5 minutes)

| Check | Ready? |
|-------|--------|
| EC2 from gold AMI is **running**; note **public IP** | ☐ |
| Security group allows **your IP** on **2222** and **35443** | ☐ |
| SSH works: `ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$IP` | ☐ |
| First-boot done (~2–5 min): `curl http://$IP:35443/` returns html | ☐ |
| PPT open on slide 1; terminal ready with commands below | ☐ |
| Repo link + solution overview ready if asked | ☐ |
| Optional: `reboot` earlier so you can say “survives reboot” — Expansion Pack §7 | ☐ |

**Audience personas (Core Pack):** Anya Sharma (CIO), Alex Lee (Infra), Ren Tanaka (Security), Casey Novak (Linux Eng), Cameron Shaw (App Dev) — speak to **Casey + Ren** during the live demo; close with **Alex / Anya** next step.

---

## Timing map (Core Pack)

| Part | Time | What Core Pack requires |
|------|------|-------------------------|
| **A. Opening** | 1–2 min | Introduce team; restate **customer’s technical challenges**; agenda |
| **B. Live walkthrough** | 5–10 min | Implementation from **end-user** view; explain **why** for key choices |
| **C. Value summary** | 2–5 min | How solution addresses **each** challenge; what it unlocks next |
| **D. Closing** | 1–2 min | Core message + **one concrete next step** |

---

## A. Opening (1–2 min) — slides 1–4

**Slide 2 — What you need:** estate size, hybrid cloud, PCI/GDPR/CCPA, 30-day CVE policy, least privilege, what each of you needs.

**Say:**

> Hi, I’m **[Name]**, Red Hat Consulting. Thanks for the time today.  
>  
> You’re running a global luxury brand — boutiques plus e-commerce on **AWS** — under PCI DSS / GDPR and a **30-day** Critical/High patch window, across about **1,600** Linux servers.  
>  
> You’ve asked us to help with the **web fleet**. We heard **three** problems — please confirm these still match:

**1 — Inconsistent servers**  
> Mixed Rocky, Ubuntu, CentOS Stream, Amazon Linux — drift from regional autonomy. A critical patch **failed on 600+** hosts and you missed the 30-day window.

**2 — Hard-to-trace admin changes**  
> Undocumented tweaks on production. When checkout fails, teams burn hours asking who changed what.

**3 — Containers outpace ops**  
> Developers hand Casey’s team long `podman run` one-liners. Ops can’t manage containers cleanly.

**Objective:**  
> Today I’ll show a **RHEL 10 gold image** for your **e-commerce web** nodes — one standard you can rebuild, published as an **AWS AMI**, proven on a live instance.

**Agenda:**  
> Confirm your needs → show what’s in the image → how that solves your three problems → live proof → one next step.

---

## B. Live walkthrough (5–10 min) — slides 5–11

**Slides 5–7 (before SSH):** show exact TOML configuration, then **what we solved using the configuration** (challenge → control → outcome), then config detail → issue prevented.

### B0. Bridge (30 sec) — slide 8 (architecture)

**Say:**  
> We defined one blueprint — `fedora-lane-gold.toml`, **distro `rhel-10.0`** — composed with the **local `image-builder` CLI** on RHEL 10, then published to AWS: **S3 → snapshot → AMI → EC2**.  
> Everything I show is on a **fresh instance from that AMI**, so you’re seeing the gold standard, not a hand-tuned lab VM.

### B1. SSH on 2222 (Expansion: SSH port + key-only + no root/password)

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP
```

**Tell → show → tell:**  
> **Tell:** Admins connect on **non-standard SSH 2222**, key-only.  
> **Show:** Login succeeds as `fladmin1`.  
> **Tell:** That shrinks the attack surface and gives **named accounts** instead of shared root — starts Challenge 2.

```bash
sudo ss -tlnp | grep 2222
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication'
# expect: permitrootlogin no / passwordauthentication no
```

### B2. SELinux + filesystems (Expansion: enforcing, separate mounts, /tmp noexec)

```bash
cat /etc/redhat-release
hostname
getenforce
# Enforcing

findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp
# must include noexec
```

**Say:**  
> Separate mounts under **5 GiB** so logs/temp can’t fill **root** and kill checkout — operational reliability.  
> **SELinux enforcing** and **`/tmp` noexec** for Ren’s compliance baseline.

### B3. Admins + sudo password (Expansion: own users/group, sudo always prompts)

```bash
getent group fladmins
sudo -k
sudo id
# type password when prompted (lab: RedHat) — must NOT be passwordless
```

**Say:**  
> `fladmin1` / `fladmin2` in **`fladmins`**. Sudo **always** asks for a password — no silent privilege escalation. Accountable admins for Challenge 2.

### B4. Firewall — only 2222 + 35443 (Expansion: only SSH + httpd ports)

```bash
sudo firewall-cmd --list-ports
# 2222/tcp 35443/tcp
```

**Say:**  
> Network attack surface is minimal — only the ports we need for admin and the web tier.

### B5. httpd in a container + systemd (Expansion: httpd, prefer container, port 35443)

```bash
sudo ss -tlnp | grep 35443
systemctl status container-fl-httpd --no-pager
curl -s http://127.0.0.1:35443/ | head
```

From your laptop (if SG allows):

```bash
curl -s http://$PUBLIC_IP:35443/
```

**Tell → show → tell (Challenge 3):**  
> **Tell:** Instead of a fragile `podman run` string from developers, httpd runs in **Podman** and is managed as **`container-fl-httpd.service`**.  
> **Show:** `systemctl status` + curl on **35443**.  
> **Tell:** Casey’s team uses **start / stop / status** like any other service — this closes the container skills gap for the web tier.

### B6. Why local Image Builder (10–20 sec) — if asked / slide 7–8

**Say:**  
> Spec required a **manual** gold image — **not** hosted Image Builder. We used RHEL’s documented **`image-builder` CLI** with a TOML blueprint so the build is **repeatable** and reviewable in Git.

### B7. Optional — reboot survival (Expansion §7) — only if time

```bash
# Earlier you rebooted; now:
getenforce
systemctl is-enabled container-fl-httpd
curl -s http://127.0.0.1:35443/ | head
```

**Say:**  
> Controls and services survive reboot — permanent gold standard, not a one-shot tweak.

---

## C. Value summary (2–5 min) — slides 6–7, 12–13

Map **each Expansion Pack challenge** explicitly (Success Criteria: articulate how it addresses core challenges). Use **slide 6** (“What we solved using the configuration”).

| Challenge (Expansion Pack) | Configuration used | Value for Fedora Lane |
|----------------------------|--------------------|------------------------|
| **1. Inconsistent estate** | One **RHEL 10.0** TOML → identical packages, mounts, services | Same OS, layout, packages, policy on every web node — patching/automation can target one baseline |
| **2. Untraceable changes** | `fladmins`, key SSH :2222, sudo password, no root/password SSH, known-good AMI | Accountability + ability to **rebuild** from gold; **next:** Session Recording |
| **3. Container skills gap** | Podman httpd + `container-fl-httpd.service` on :35443 | Ops manage the web container without copying long CLI; aligns Casey + Cameron |

**Say:**  
> Challenge 1: stop the mixed-OS snowflake problem for **web** nodes — one gold AMI.  
> Challenge 2: start with hardened, named access and a rebuildable baseline; Session Recording on Web Console is the natural day-2 for Ren’s audit trail.  
> Challenge 3: containerized httpd is **service-managed**, so ops aren’t stuck on `podman` one-liners.

**Possibilities left open (Core Pack value summary):**  
> Same blueprint can stretch to **Azure VHD**, OpenSCAP CIS (stretch), Insights-driven rebuilds, and fleet scale-out under Alex’s infra team.

---

## D. Closing (1–2 min) — slides 13–14

**Core message:**  
> One **manual RHEL 10 gold image** for Fedora Lane’s e-commerce web fleet — secure, standardized, and ops-manageable — proven live on AWS.

**One concrete next step (pick one):**  
> **Pilot this AMI on staging web nodes next sprint**, with Casey’s team validating day-2 ops (`systemctl` + firewall) and Ren reviewing the SSH/SELinux baseline — then decide Session Recording + Web Console for audit.

**Optional ask:**  
> If useful, we can schedule a follow-up to walk OpenSCAP CIS hardening or an Azure image from the same TOML.

**Thank them / invite questions.**

---

## Q&A cheat sheet

| Likely question | Short answer |
|-----------------|--------------|
| Why not hosted Image Builder? | Expansion Pack: create **manually** — we used **local** `image-builder` + TOML in Git. |
| Why `rhel-10.0` not `rhel-10`? | Exact distro id from `image-builder list`; short id fails compose. |
| Why import snapshot? | S3 holds a file; EC2 boots an **AMI** — import snapshot → register image (CLI or Console). |
| Why ports 2222 / 35443? | Expansion Pack non-standard ports + SELinux port labels. |
| Password SSH? | Disabled; keys only. Sudo still needs password. |
| Azure? | Stretch: same TOML → `image-builder build vhd`; AWS proven today. |
| OpenSCAP? | Stretch: `scap-security-guide` in blueprint; can demo scan next. |
| Session recording? | Addresses Challenge 2 fully; recommended **next phase**, not required for gold image minimum. |

---

## Expansion Pack checklist (say “done” only if proven)

| # | Spec | Proven in walkthrough? |
|---|------|------------------------|
| 1 | Manual gold image (not hosted IB) | ☐ (mention TOML + local IB) |
| 2 | Deployable on AWS (or Azure) | ☐ EC2 from AMI |
| 3 | httpd + index; prefer container | ☐ curl :35443 + systemd unit |
| 4 | Separate `/var/log` `/home` `/tmp` `/var/tmp` &lt; 5 GiB | ☐ findmnt |
| 5a | SELinux enforcing | ☐ getenforce |
| 5b | `/tmp` noexec | ☐ findmnt OPTIONS |
| 5c | httpd :35443 | ☐ ss / curl |
| 5d | SSH :2222 | ☐ ssh -p 2222 |
| 5e | Admin users + group + sudo | ☐ fladmins |
| 5f | sudo always password | ☐ sudo -k && sudo id |
| 5g | No root SSH | ☐ sshd -T |
| 5h | No password SSH | ☐ sshd -T |
| 5i | Only SSH + httpd ports open | ☐ firewall-cmd |
| 6 | Upload + provision + show config | ☐ live EC2 |
| 7 | Survive reboot / enable at boot | ☐ optional reboot proof |

---

## Success Criteria (Core Pack — Junior Consultant)

Aim for **Meets / Exceeds**:

- **Solution:** meets Expansion Pack specs; works live  
- **Rationale:** explain **what + why** (esp. local IB, ports, systemd container)  
- **Presentation:** logical flow; answer questions calmly; anticipate “why not hosted IB?” and “how does this help Casey?”

---

## Script card (print / second screen)

```text
OPEN (2)   3 challenges → gold AMI objective → agenda
LIVE (8)   SSH 2222 → SELinux/mounts → sudo pw → firewall → httpd systemd :35443
VALUE (3)  Challenge1 AMI | Challenge2 access+baseline | Challenge3 systemd container
CLOSE (2)  Pilot staging next → Session Recording later → questions
```
