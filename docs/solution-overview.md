# Solution Overview — Fedora Lane RHEL 10 Gold Image

## Purpose

Deliver a **secure, standardized Red Hat Enterprise Linux 10 gold image** for Fedora Lane’s e-commerce **web server** fleet.

The standard is defined as a **local Image Builder blueprint** ([image-builder/fedora-lane-gold.toml](../image-builder/fedora-lane-gold.toml)) with:

```toml
distro = "rhel-10.0"
```

It is composed on a **RHEL 10** builder host (**not** the hosted Image Builder cloud service), published as an **AWS AMI** and/or an **Azure VHD → managed image**, and proven on a live cloud VM.

## Customer challenges addressed

### 1. Inconsistent server environment

Fedora Lane operates ~1,600 Linux servers with mixed distributions (Rocky, Ubuntu, CentOS Stream, Amazon Linux). Drift and incompatible baselines caused a critical patch to fail on 600+ hosts and miss the 30-day remediation window.

**Solution:** One **RHEL 10** AMI with fixed partitions, packages, SELinux, firewall, SSH, and web service. Every new web node boots the same way.

### 2. Untraceable administrative changes / extended outages

Undocumented interactive changes inflated MTTR and hid accountability.

**Solution:** Named accounts in `fladmins`, key-only SSH on port **2222**, root login disabled, password SSH disabled, sudo always requires a password. The AMI is a known-good baseline. **Next phase:** RHEL Session Recording + Web Console for session review.

### 3. Operational skills gap for container workloads

Operations received brittle `podman run` one-liners and struggled to manage containers.

**Solution:** **httpd** runs in **Podman** on port **35443**, managed via **systemd** (`container-fl-httpd.service`). Ops start/stop/status a service instead of pasting long CLI strings.

## High-level architecture

```text
[ TOML blueprint: distro=rhel-10.0 ]
              |
              v
[ Local Image Builder on RHEL 10 host ]
         /                    \
   type: ami                 type: vhd
        |                         |
[ AWS: S3 → snap → AMI ]   [ Azure: page blob → image ]
        |                         |
[ EC2 from AMI ]           [ VM from managed image ]
         \                       /
          SSH :2222  ·  httpd :35443
          (fladmin* + keys · Podman systemd)
```

Step-by-step both clouds: [00-end-to-end-guide.md](00-end-to-end-guide.md)
## Technical controls

| Requirement | How we meet it |
|-------------|----------------|
| RHEL 10 base | `distro = "rhel-10.0"` (exact id) in blueprint; compose on RHEL 10 host |
| Local (not hosted) Image Builder | RHEL 10 `image-builder` CLI on a RHEL builder host |
| AWS deployable | AMI registered and EC2 launched in the target account |
| Azure deployable | VHD uploaded, Gen2 managed image, VM launched |
| Separate filesystems | `/var/log`, `/home`, `/tmp`, `/var/tmp` (< 5 GiB) |
| `/tmp` noexec | fstab + first-boot reinforcement |
| SELinux enforcing | config + runtime |
| SSH 2222 / httpd 35443 | sshd drop-in, SELinux port labels, firewalld |
| Admins + sudo password | `fladmins`, sudoers without NOPASSWD |
| No root / password SSH | sshd hardened |
| Firewall | Only 2222 + 35443 |
| Survive reboot | systemd units enabled; verify after reboot |
| httpd in container | Podman + generated systemd unit |

## Value for stakeholders

| Stakeholder | Outcome |
|-------------|---------|
| Anya (CIO) | Safer scale-out of the digital storefront on a modern RHEL 10 standard |
| Alex (Infra) | Fewer snowflake servers; simpler day-2 operations |
| Ren (Security) | Enforcing SELinux, locked SSH, tight firewall, accountable admins |
| Casey (Linux) | One engineering standard for the web fleet |
| Cameron (Apps) | Containers that ops can run as services |

## Recommended next phase

1. Pilot the RHEL 10 gold AMI on **staging** web nodes.  
2. Enable **Web Console + Session Recording** for production admin access.  
3. Automate rebuilds and add **Red Hat Insights** for fleet visibility.  
4. Keep **AWS** and **Azure** images rebuilt from the same TOML on a schedule.

## Official Red Hat documentation

See [redhat-documentation.md](redhat-documentation.md) for links to:

- *Composing a customized RHEL system image* (RHEL 10 Image Builder)  
- *Deploying and managing RHEL on Amazon Web Services*  
- *Deploying and managing RHEL on Microsoft Azure*  
- SELinux, firewalld, OpenSSH, containers, and Web Console guides
