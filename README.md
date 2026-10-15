# Fedora Lane — RHEL Gold Image (Server/Cloud OS TDP)

**Role:** Junior Consultant (FASTER)  
**Geo:** APAC — Part 1 ~**19 Oct**, Part 2 **22/23 Oct** (check your POD)  
**Cloud:** AWS (manual gold image → AMI → EC2 proof)

Private deliverable repo. **Never commit secrets.** Add collaborator **`mflaim-eng`**.

---

## Start here (Mac + AWS)

Read in order:

1. **[docs/03-apac-mac-aws-why-guide.md](docs/03-apac-mac-aws-why-guide.md)** ← detailed steps **and why** (your main guide)
2. [docs/01-what-we-are-solving.md](docs/01-what-we-are-solving.md) — customer challenges → value
3. [docs/solution-overview.md](docs/solution-overview.md) — client-facing solution write-up
4. [docs/02-aws-build-commands.md](docs/02-aws-build-commands.md) — extra command reference
5. [docs/presentation-outline.md](docs/presentation-outline.md) — 15-min talk track

Helper scripts (run **on the EC2 builder**):

- `scripts/10-users-ssh-firewall.sh` — admins, SSH :2222, firewall
- `scripts/20-httpd-container.sh` — Podman httpd :35443 + systemd
- `verify/verify.sh` — post-boot checklist

---

## What we are solving (short)

| Challenge | Solution in this AMI |
|-----------|----------------------|
| Inconsistent OS / drift / failed patching | One hardened **RHEL** standard for web nodes |
| Untraceable admin changes | Named admins, no root/password SSH, sudo always prompts |
| Ops can’t run containers safely | **httpd in Podman**, managed via **systemd** |

---

## Repo setup (Mac)

```bash
brew install awscli gh git
cd ~/Projects/fedora-lane-rhel-gold-image

gh auth login
# after local commit:
gh repo create fedora-lane-rhel-gold-image --private --source=. --remote=origin --push
gh api repos/$(gh api user -q .login)/fedora-lane-rhel-gold-image/collaborators/mflaim-eng -X PUT -f permission=pull
```

---

## Build path (summary)

```text
Mac → launch RHEL EC2 builder → harden by hand → create AMI
    → launch NEW EC2 from AMI → verify/verify.sh → demo
```

Full why + commands: **docs/03-apac-mac-aws-why-guide.md**

---

## Spec checklist

- [ ] Manual gold image (no hosted Image Builder)
- [ ] AWS AMI → EC2
- [ ] httpd + index (container preferred) on **35443**
- [ ] Separate mounts `/var/log` `/home` `/tmp` `/var/tmp` (&lt; 5 GiB)
- [ ] SELinux enforcing; `/tmp` noexec
- [ ] SSH **2222**; no root SSH; no password SSH
- [ ] `fladmins` + sudo password required
- [ ] Firewall: only SSH + httpd
- [ ] Survives reboot
- [ ] Stretch: OpenSCAP / second cloud

---

## Part 1 / Part 2

| Step | When (APAC) | Action |
|------|-------------|--------|
| Part 1 | ~19 Oct | RHSH recording + form (Server/Cloud OS TDP) + this repo URL |
| Part 2 | 22 or 23 Oct | Live 15-min demo; SMEs as Casey / Alex |
| Follow-up | &lt; 2 days after live | Email SMEs; CC Pod Host, Manager, faster@redhat.com |
