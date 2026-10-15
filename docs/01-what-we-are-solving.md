# What We Are Solving — Fedora Lane Server/Cloud OS TDP

## Customer context

**Fedora Lane** is a global luxury retail brand with:

- ~1,600 Linux servers (900 on-prem VMware, 600 AWS/Azure, 100 boutique servers)
- Hybrid multi-cloud (AWS primary for e-commerce, Azure secondary)
- Strict compliance: PCI DSS, GDPR, CCPA
- Internal rule: Critical/High CVEs patched within **30 days**
- Crown-jewel app: global e-commerce (Java monoliths + modern microservices)

This gold image is the standard foundation for their **e-commerce web server fleet on AWS**.

---

## Challenge 1 — Inconsistent server environment

### Pain today

| Fact | Impact |
|------|--------|
| Mix of Rocky Linux, Ubuntu, CentOS Stream, Amazon Linux | No single patch/automation path |
| Regional teams configure servers differently | Configuration drift |
| Critical patch failed on 600+ servers | Manual firefight; miss 30-day compliance window |

### What we deliver

A **single RHEL gold AMI** with:

- Fixed partition layout (`/var/log`, `/home`, `/tmp`, `/var/tmp`)
- SELinux enforcing
- Locked-down SSH/httpd ports
- Same packages and services every time

### Business / technical value

- One OS standard → predictable patching and automation
- New web servers launch identical → less drift
- Supports Casey Novak’s goal: proactive platform engineering instead of ticket firefighting

---

## Challenge 2 — Untraceable admin changes and long outages

### Pain today

- Admins make undocumented “helpful” config tweaks
- No reliable audit trail → MTTR measured in hours
- Example: checkout outage from an undocumented timeout change

### What we deliver (this TDP)

- **Immutable baseline**: known-good image; changes stand out against the standard
- Hardened access: no root SSH, no password SSH, sudo always requires password
- Separate admin accounts/group (accountability)

### Narrative for next phase (mention in presentation)

RHEL **Session Recording** + **Web Console** let Fedora Lane review *who changed what* — map this to Challenge 2 even if the gold-image lab focuses on the secure baseline.

### Business / technical value

- Shorter outages (faster “what changed?”)
- Stronger operational accountability for Alex Lee’s ops team
- Better evidence posture for Ren Tanaka (security/compliance)

---

## Challenge 3 — Ops skills gap for container workloads

### Pain today

- Developers hand ops long `podman run` commands
- Typos (wrong ports) → hours of troubleshooting
- Ops depends on developers for basic container tasks

### What we deliver

- **httpd runs in a Podman container** on a fixed port (**35443**)
- Content + systemd unit so ops starts/stops a **service**, not a raw CLI string
- Same pattern on every instance from the gold AMI

### Business / technical value

- Ops can manage the web tier without deep Podman expertise
- Fewer misconfigurations; repeatable deploy
- Bridges Cameron Shaw’s container apps and Casey’s Linux ops team

---

## How the gold image maps to stakeholders

| Stakeholder | Concern | How we speak to them |
|-------------|---------|----------------------|
| **Anya Sharma (CIO)** | Agility + customer experience | Standard platform → faster, safer e-commerce scale-out |
| **Alex Lee (VP Infra)** | Stability, simpler ops | One AMI, reboot-safe services, less snowflake servers |
| **Ren Tanaka (Security)** | Risk, audits, least privilege | SELinux, firewall, SSH hardening, no root login |
| **Casey Novak (Linux Eng)** | Fleet standards at scale | Gold image + partitions + container as a service |
| **Cameron Shaw (App Dev)** | Ship containers without ops bottleneck | httpd container baked into the standard image |

---

## One-sentence pitch

> We give Fedora Lane a **secure, standardized RHEL gold AMI on AWS** so every e-commerce web server boots the same way: hardened access, SELinux, isolated partitions, and httpd in a container — cutting drift, security risk, and container ops friction.
