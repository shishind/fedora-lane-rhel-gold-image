# 15-minute presentation outline (Junior Consultant)

## Opening (1–2 minutes)

- Introduce yourself / role (Red Hat Consultant)
- Restate Fedora Lane’s three problems:
  1. Inconsistent Linux estate → failed mass patching  
  2. Untraceable admin changes → long outages  
  3. Ops skills gap for containers  
- Objective: show a **RHEL 10 gold AMI** for e-commerce web nodes  
- Agenda: walkthrough → value → next step  

## Live walkthrough (5–10 minutes)

On the **test EC2 launched from the gold AMI**:

1. `cat /etc/redhat-release` → **RHEL 10**  
2. SSH as `fladmin1` on port **2222** (key auth)  
3. `getenforce` → Enforcing  
4. `findmnt` for `/var/log` `/home` `/tmp` `/var/tmp` + `/tmp` noexec  
5. `sudo -k && sudo id` — password required  
6. `curl http://127.0.0.1:35443/` + container/systemd status  
7. `firewall-cmd --list-all` — only 2222 + 35443  
8. Optional: reboot and re-check persistence  

## Value summary (2–5 minutes)

| Challenge | Proof point |
|-----------|-------------|
| Inconsistency | One RHEL 10 AMI → same layout/services |
| Untraceable changes | Named admins, no root/password SSH, known-good baseline |
| Container gap | httpd as systemd service, not a pasted podman one-liner |

## Closing (1–2 minutes)

> Pilot this RHEL 10 gold AMI on staging web nodes, then enable Session Recording / Web Console for production admin access, and automate rebuilds with Insights.

Slides: [Fedora-Lane-RHEL-Gold-Image-FASTER.pdf](Fedora-Lane-RHEL-Gold-Image-FASTER.pdf)
