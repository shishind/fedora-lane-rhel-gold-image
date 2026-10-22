# Presentation script — Fedora Lane RHEL 10 Gold Image

**Audience:** Fedora Lane (Anya, Alex, Ren, Casey, Cameron)  
**Length:** ~15 minutes  
**Deck:** `docs/Fedora-Lane-RHEL-Gold-Image-FASTER.pptx` (14 slides)  
**Voice:** Speak to the customer — *you / your*

---

## ★ When to start the live demo

| Phase | Slides | Time | Action |
|-------|--------|------|--------|
| Talk only | **1 → 10** | ~6–7 min | Stay on PPT — needs, problems, config, how it solves, path to AWS |
| **★ START LIVE DEMO** | **Slide 11** | ~5–7 min | Switch to terminal — SSH into EC2 from the gold AMI |
| Close | **12 → 14** | ~2–3 min | Back to PPT — value per person, next step, Q&A |

**Do not open the terminal before slide 11.**  
Finish slides 8–10 (blueprint → AWS) so the room understands *what* they are about to see, then say the bridge line below and switch screen.

**Bridge line (end of slide 10 / open slide 11):**

> Everything so far is the standard we baked into the image.  
> Now I’ll prove it on a **fresh EC2 launched from your gold AMI** — not a hand-tuned lab box.

Then go to the terminal and run the demo commands in **Live demo (slide 11)** below.

---

## Before you start (5 minutes)

| Check | Ready? |
|-------|--------|
| EC2 from **gold AMI** is **running** — note `PUBLIC_IP` | ☐ |
| Security group: **your IP** on **2222** and **35443** | ☐ |
| Pre-test SSH: `ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP` | ☐ |
| First-boot done: `curl -s http://$PUBLIC_IP:35443/` returns HTML | ☐ |
| PPT on slide 1; second screen/window ready for terminal | ☐ |
| Optional: rebooted earlier so you can show “survives reboot” | ☐ |

```bash
export PUBLIC_IP=<paste-ec2-public-ip>
export KEY=~/.ssh/fedora-lane-lab
```

Speak mainly to **Casey + Ren** during the live demo; close with **Alex / Anya** on the staging pilot.

---

## Timing map

| Part | Slides | Time | What you do |
|------|--------|------|-------------|
| A. Opening | 1–4 | 2 min | Needs + three problems + agenda |
| B. Solution (talk) | 5–10 | 4–5 min | Config, what it solves, path to AWS |
| **C. Live demo** | **11** | **5–7 min** | **★ Terminal — prove the image** |
| D. Close | 12–14 | 2 min | Stakeholder value + next step + Q&A |

---

## A. Opening — slides 1–4 (~2 min)

### Slide 1 — Title

**Say:**

> Hi, I’m **[Name]**, Red Hat Consulting. Thanks for the time.  
> Today is about a **standard web platform for Fedora Lane** — one **RHEL 10 gold image** for your e-commerce web servers, so every launch is the same secure baseline. Proven on AWS; Azure when you’re ready.

### Slide 2 — What you need

**Say:**

> Quick confirm of what you’re working with: about **1,600** Linux servers — on-prem, AWS/Azure, boutiques. Crown jewel is **e-commerce on AWS**.  
> Ren’s bar: **PCI DSS, GDPR, CCPA**, Critical/High CVEs in **30 days**, least privilege, encryption, quarterly scans.  
> And each of you needs something different — Anya agility, Alex simpler ops, Casey one enforceable standard, Ren a baseline you can prove, Cameron containers ops can actually run.

*(Nod / short confirm — don’t over-explain.)*

### Slide 3 — Three problems

**Say:**

> We heard three problems. Please tell me if these still match.

1. **Inconsistent servers** — Rocky, Ubuntu, CentOS Stream, Amazon Linux; patch failed on **600+** hosts; missed the 30-day window.  
2. **Hard-to-trace admin changes** — undocumented tweaks; hours asking “who changed what?” when checkout fails.  
3. **Containers outpace ops** — long `podman run` strings to Casey’s team; typos and developer dependency.

### Slide 4 — Agenda

**Say:**

> Next: your gold standard in the image → how that configuration solves those three problems → then a **live proof** on a running instance → one concrete next step.

---

## B. Solution (talk only) — slides 5–10 (~4–5 min)

### Slide 5 — What’s baked in

**Say:**

> This is what every new web node gets: **RHEL 10**, separate mounts so root never fills, **SELinux enforcing**, SSH on **2222** key-only, named **fladmins** with sudo password, firewall only **2222** and **35443**, and **httpd as a systemd service** on 35443. Same blueprint can go to Azure later.

*(Point at 2–3 rows; don’t read every line.)*

### Slide 6 — How config solves your problems

**Say:**

> Challenge one: one RHEL 10 image — Casey gets a baseline to patch.  
> Challenge two: named admins, hardened SSH, known-good image to rebuild from — accountability now; session recording next.  
> Challenge three: httpd is a **service** — ops start/stop/status, not fragile one-liners for Cameron’s apps.

### Slide 7 — Why each control

**Say:**

> Short why: separate mounts protect checkout if logs explode; SELinux and `/tmp noexec` for Ren; SSH 2222 and sudo password for accountability; firewall minimal; systemd httpd for day-2; reboot-safe and rebuildable in Git.

### Slide 8 — Blueprint → web node

**Say:**

> Flow: blueprint → Image Builder → gold disk → cloud storage → machine image → your VM. Same story on AWS today and Azure when European teams need it.

### Slide 9 — Reviewable standard

**Say:**

> We built this as a **file you own** — reviewable TOML in Git — not a snowflake or a black-box wizard. Define once, compose for AWS, same blueprint for Azure later.

### Slide 10 — Into your AWS account

**Say:**

> Into your account: gold disk in S3 → import snapshot → register AMI → security group **2222 + 35443** → launch EC2 → prove with SSH and curl.  
> New capacity = launch from the gold AMI, not another hand-built server.

**→ Then the bridge line and switch to live demo (slide 11).**

---

## C. ★ LIVE DEMO — start here (slide 11) (~5–7 min)

### Switch screens now

1. Leave PPT on **slide 11** (“What we will show you live”) as a checklist.  
2. Share / focus the **terminal**.  
3. Say the bridge line (above).  
4. Run the sequence below — **tell → show → tell** on each block.

### Demo 1 — Login (Challenge 2 / Ren)

**Tell:** Admins connect on non-standard SSH **2222**, key-only, named user.

```bash
ssh -i $KEY -p 2222 fladmin1@$PUBLIC_IP
```

**Show:** Login succeeds.  
**Tell:** Named account, not shared root — starts accountability.

```bash
sudo ss -tlnp | grep 2222
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication'
# expect: permitrootlogin no / passwordauthentication no
```

### Demo 2 — OS + SELinux + mounts (Challenge 1 / Ren + Casey)

**Tell:** One OS standard; SELinux on; logs/temp can’t fill root.

```bash
cat /etc/redhat-release
hostname
getenforce
# Enforcing

findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp
# must include noexec
```

### Demo 3 — Admins + sudo password (Challenge 2)

**Tell:** Your admins are in `fladmins`; sudo always asks for a password.

```bash
getent group fladmins
sudo -k
sudo id
# type password when prompted (lab: RedHat) — must NOT be passwordless
```

### Demo 4 — Firewall (Ren)

**Tell:** Only the ports you need.

```bash
sudo firewall-cmd --list-ports
# 2222/tcp  35443/tcp
```

### Demo 5 — httpd as a service (Challenge 3 / Casey + Cameron) ★ highlight

**Tell:** Instead of a fragile `podman run` paste, the site is a **systemd service**.

```bash
sudo ss -tlnp | grep 35443
systemctl status container-fl-httpd --no-pager
curl -s http://127.0.0.1:35443/ | head
```

From your laptop (if SG allows):

```bash
curl -s http://$PUBLIC_IP:35443/
```

**Tell:** Casey’s team uses start / stop / status like any other service — that closes the container skills gap for the web tier.

### Demo 6 — Optional reboot proof (only if time)

```bash
# If you rebooted earlier:
getenforce
systemctl is-enabled container-fl-httpd
curl -s http://127.0.0.1:35443/ | head
```

**Tell:** Controls and services survive reboot — permanent gold standard.

### After demo — return to PPT

> You’ve just seen a fresh node from the gold AMI. Let’s map that back to each of you, then one next step.

Go to **slide 12**.

---

## D. Close — slides 12–14 (~2 min)

### Slide 12 — What this means for each of you

**Say:**

> Anya — safer scale-out of the storefront.  
> Alex — fewer snowflakes; reboot-safe services.  
> Ren — hardened SSH, SELinux, minimal firewall.  
> Casey — a standard you can enforce and rebuild.  
> Cameron — containers ops can run without a war room.

### Slide 13 — Recommended next step

**Say:**

> Concrete ask: **pilot this gold AMI on staging web nodes next sprint**.  
> Casey validates day-2; Ren reviews SSH/SELinux.  
> Then Web Console + Session Recording for audit.  
> Automate rebuilds; Azure from the same blueprint when ready.

### Slide 14 — Close

**Say:**

> One gold image for Fedora Lane’s web fleet — secure, standardized, something ops can run. Proven live on AWS. Ready for your staging pilot.  
> Questions?

---

## Script card (print / second screen)

```text
SLIDES 1–4   Opening: needs → 3 problems → agenda          (~2 min)
SLIDES 5–10  Talk: config → solves → path to AWS           (~5 min)
★ SLIDE 11   LIVE DEMO — switch to terminal NOW            (~6 min)
             SSH 2222 → SELinux/mounts → sudo → firewall
             → systemctl httpd :35443 → curl
SLIDES 12–14 Stakeholder value → staging pilot → Q&A       (~2 min)
```

---

## Q&A cheat sheet

| Question | Short answer |
|----------|--------------|
| Why not hosted Image Builder? | You own a reviewable TOML in Git — rebuildable, not a black box. |
| Why port 2222 / 35443? | Non-standard ports + SELinux labels; smaller attack surface. |
| Password SSH? | Disabled; keys only. Sudo still needs a password. |
| Azure? | Same blueprint → `vhd`; AWS proven today. |
| Session recording? | Natural next step for Challenge 2; recommend after staging pilot. |
| Who maintains the image? | Casey’s team owns the blueprint; rebuild on a cadence + Insights later. |

---

## Live demo checklist (tick while on slide 11)

| # | Prove | Command / show |
|---|--------|----------------|
| 1 | SSH :2222 key-only | `ssh -p 2222 fladmin1@…` |
| 2 | RHEL 10 | `cat /etc/redhat-release` |
| 3 | SELinux enforcing | `getenforce` |
| 4 | Separate mounts + `/tmp noexec` | `findmnt …` |
| 5 | fladmins + sudo password | `sudo -k && sudo id` |
| 6 | Firewall 2222 + 35443 | `firewall-cmd --list-ports` |
| 7 | httpd systemd + curl :35443 | `systemctl status` + `curl` |
| 8 | (Optional) survives reboot | re-check after reboot |
