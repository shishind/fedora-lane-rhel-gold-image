# Solution Overview — Fedora Lane RHEL Gold Image (AWS)

## Purpose

Design and demonstrate a **secure, standardized Red Hat Enterprise Linux gold AMI** for Fedora Lane’s e-commerce web server fleet on **Amazon Web Services**. The image is built **manually** (not via hosted Image Builder), uploaded/registered in AWS, and proven on a freshly launched EC2 instance.

## Problems addressed

### 1. Inconsistent server environment

Fedora Lane runs ~1,600 servers across Rocky, Ubuntu, CentOS Stream, and Amazon Linux. Regional autonomy caused configuration drift; a critical patch failed on 600+ hosts and breached the 30-day remediation policy.

**Our approach:** One RHEL gold AMI with a fixed disk layout, SELinux enforcing, firewall policy, SSH/httpd ports, admin model, and containerized web tier. Every new web server boots identical.

### 2. Untraceable administrative changes / long outages

Undocumented interactive changes extend MTTR and hide accountability.

**Our approach:** Harden access (no root SSH, no password SSH, sudo always requires a password, named admin accounts in `fladmins`). The gold image is a known-good baseline; deviations are easier to detect. Recommend RHEL Session Recording / Web Console as the next operational control.

### 3. Operational skills gap for containers

Ops receives brittle `podman run` one-liners from developers and struggles to inspect/troubleshoot.

**Our approach:** Ship **httpd in Podman** on port **35443**, managed as `container-fl-httpd.service`. Operators start/stop/status a systemd unit instead of copying long CLI strings.

## High-level architecture

```text
[ Gold build VM ] --manual harden--> [ AWS AMI ]
                                         |
                                         v
                              [ EC2 web instance ]
                               |              |
                          SSH :2222      httpd container :35443
                          (key-only)     (Podman + systemd)
                               |
                          fladmin* + sudo (password)
```

## Technical controls (spec checklist)

| Requirement | Implementation |
|-------------|----------------|
| Manual gold image | Configure VM by hand; `create-image` or import-snapshot |
| AWS deployable | AMI launched in RHDP AWS Blank OPEN / account |
| httpd + index page | Podman httpd; `/opt/fedora-lane/www/index.html` |
| Separate partitions | `/var/log`, `/home`, `/tmp`, `/var/tmp` (< 5 GiB each) |
| SELinux enforcing | `/etc/selinux/config` + runtime Enforcing |
| `/tmp` noexec | fstab mount options |
| httpd port 35443 | publish + `semanage port` `http_port_t` |
| SSH port 2222 | sshd drop-in + `semanage port` `ssh_port_t` |
| Admin users/group/sudo | `fladmins`, sudoers without NOPASSWD |
| No root SSH | `PermitRootLogin no` |
| No SSH passwords | `PasswordAuthentication no` |
| Firewall lockdown | Only 2222/tcp and 35443/tcp |
| Survive reboot | systemd enabled units; verify after reboot |

## Why RHEL (value summary for presentation)

- **Consistency:** Enterprise lifecycle, certified cloud images, one patch stream for the fleet Casey manages.
- **Security:** SELinux, crypto/policy defaults, and a hardening path (OpenSCAP/CIS stretch) for Ren’s audit needs.
- **Operability:** Web Console / session recording story for Alex; container tooling that still feels like Linux services for traditional admins.
- **Business outcome for Anya:** Faster, safer scale-out of the e-commerce web tier without increasing operational risk.

## Recommended next step (closing slide)

Pilot the gold AMI for staging e-commerce web nodes, enable Insights / session recording for production admin access, then expand Image Builder + automation for fleet rebuilds — after the manual gold image proves the standard.
