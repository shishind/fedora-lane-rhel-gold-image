# 15-minute presentation outline (Junior Consultant)

## Opening (1–2 min)

- Introduce yourself / role (Red Hat Consultant)
- Restate Fedora Lane’s three problems:
  1. Inconsistent Linux estate → failed mass patching
  2. Untraceable admin changes → long outages
  3. Ops skills gap for containers
- Objective: show a **manual RHEL gold AMI on AWS** for e-commerce web nodes
- Agenda: walkthrough → value → next step

## Live walkthrough (5–10 min)

On the **test** EC2 (from AMI), not only the builder:

1. SSH on **2222** as `fladmin1` (show port + key auth)
2. `getenforce` → Enforcing — *why: mandatory security baseline*
3. `findmnt /var/log /home /tmp /var/tmp` + `/tmp` noexec — *why: root won’t fill / reliability + temp exec blocked*
4. `sudo -k && sudo id` — password required — *why: accountability*
5. `curl localhost:35443` + `systemctl status container-fl-httpd` — *why: container as a service*
6. `firewall-cmd --list-all` — only 2222 + 35443
7. Optional: reboot story or negative tests (root SSH / port 22 fail)

If you made architecture choices (second EBS, UBI vs docker httpd), say **why**.

## Value summary (2–5 min)

| Challenge | Proof point |
|-----------|-------------|
| Inconsistency | Same AMI → same layout/services |
| Untraceable changes | Named admins, no root/password SSH, known-good baseline (+ Session Recording next) |
| Container gap | systemd unit, not a pasted podman one-liner |

Tie to stakeholders: Casey (standards), Alex (ops simplicity), Ren (risk), Anya (safer scale).

## Closing (1–2 min)

One concrete next step, e.g.:

> Pilot this AMI on staging web nodes, enable Session Recording for prod admin access, then automate rebuilds with Image Builder + Insights once the standard is approved.
