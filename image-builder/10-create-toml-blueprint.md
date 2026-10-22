# Creating and customizing the Image Builder TOML blueprint

This guide is for Fedora Lane engineers who will **own and evolve** the gold image.

| Topic | Section |
|-------|---------|
| How `fedora-lane-gold.toml` was created | [How we built this blueprint](#how-we-built-this-blueprint) |
| Create your own / edit ours | [How to create or change a blueprint](#how-to-create-or-change-a-blueprint) |
| What you can customize | [Customization catalog (what you can do)](#customization-catalog-what-you-can-do) |
| What this gold image uses today | [Fedora Lane mapping](#fedora-lane-requirement--toml-field) |

**Working file:** [`fedora-lane-gold.toml`](fedora-lane-gold.toml)

**Official Red Hat docs:**

- [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)  
- [Supported image customizations (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/supported-image-customizations)  
- [Blueprint format](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/rhel-image-builder-blueprint-format)

Never put AWS/Azure keys or **private** SSH keys in the TOML or in Git.

---

## How we built this blueprint

High-level path used for Fedora Lane:

```text
1. List exact distro id on RHEL 10 builder   →  rhel-10.0
2. Create TOML header (name, version, distro)
3. Add packages (podman, firewalld, ssh, sudo, …)
4. Add filesystem mounts (/var/log, /home, /tmp, /var/tmp)
5. Add group + users (password HASH + SSH public key)
6. Set hostname, services, firewall ports
7. Bake config files (sshd drop-in, sudoers, index.html)
8. Bake first-boot script (SELinux, noexec, Podman httpd + systemd)
9. Compose: image-builder build ami|vhd --blueprint … --distro rhel-10.0
10. Publish to AWS (or Azure) and verify on a fresh VM
```

### Why some things are in the TOML vs first-boot

| In the TOML at compose time | In first-boot script (runs once on first boot) |
|-----------------------------|-----------------------------------------------|
| Packages, users, groups, mounts | SELinux enforcing + port labels (`semanage`) |
| Firewall ports list | `/tmp` noexec fstab rewrite |
| sshd drop-in, sudoers, hostname | Podman pull + `generate systemd` for httpd |
| Static `index.html` | Enable `container-fl-httpd.service` |

Image Builder writes the disk image; first-boot finishes runtime steps that need a live system (SELinux ports, container pull, systemd unit generation).

---

## How to create or change a blueprint

### Prerequisites

| Item | Why | How |
|------|-----|-----|
| RHEL 10 builder | Local Image Builder | EC2 or on-prem RHEL 10 |
| `image-builder` CLI | Compose from TOML | `sudo dnf install -y image-builder` |
| Exact `distro` id | Must match builder | `sudo image-builder list --filter "distro:rhel-10*"` |
| SSH **public** key | Key-only admin login | `cat ~/.ssh/yourkey.pub` |
| Password **hash** | Sudo password | `openssl passwd -6 'YourPassword'` |

### Step 1 — Confirm distro id

```bash
sudo image-builder list --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"
```

Use the **exact** id (example: `rhel-10.0`). Bare `rhel-10` fails the build.

```toml
distro = "rhel-10.0"
```

### Step 2 — Create the file (or copy ours)

```bash
cd /path/to/fedora-lane-rhel-gold-image/image-builder
cp fedora-lane-gold.toml my-gold.toml   # safest: start from ours
# or create empty and build up:
# nano my-gold.toml
```

Minimum header:

```toml
name = "fedora-lane-gold"
description = "Fedora Lane e-commerce web gold image (RHEL 10)"
version = "0.1.3"
distro = "rhel-10.0"
modules = []
groups = []
```

Bump `version` every time you change the blueprint.

### Step 3 — Add packages

```toml
[[packages]]
name = "podman"
version = "*"
```

Repeat `[[packages]]` for each RPM. Use `*` for latest from subscribed repos, or pin a version string if you need reproducibility.

**Packages in the Fedora Lane gold image today:**

| Package | Purpose |
|---------|---------|
| `httpd` | Web stack available on the host |
| `podman` | Run httpd in a container |
| `container-selinux` | SELinux for containers |
| `policycoreutils-python-utils` | `semanage` for custom ports |
| `firewalld` | Host firewall |
| `openssh-server` | SSH |
| `sudo` | Privileged admin with password |
| `openscap-scanner` / `scap-security-guide` | Stretch: OpenSCAP / CIS |

### Step 4 — Filesystems

```toml
[[customizations.filesystem]]
mountpoint = "/var/log"
minsize = "2 GiB"
```

Fedora Lane uses 2 GiB each for `/var/log`, `/home`, `/tmp`, `/var/tmp` (under 5 GiB each for this standard).  
`/tmp` **noexec** is applied in the first-boot script.

### Step 5 — Groups and users (password + SSH key)

**Group:**

```toml
[[customizations.group]]
name = "fladmins"
```

**Password — always a hash, not plain text:**

```bash
openssl passwd -6 'RedHat'
# paste the full $6$... string:
```

```toml
password = "$6$salt$hash..."
```

**SSH public key** (one line from `.pub` file):

```toml
[[customizations.user]]
name = "fladmin1"
description = "Fedora Lane administrator"
groups = ["fladmins", "wheel"]
key = "ssh-ed25519 AAAA... comment"
password = "$6$...."
```

**Sudo with password** (no `NOPASSWD`):

```toml
[[customizations.files]]
path = "/etc/sudoers.d/fladmins"
mode = "0440"
data = """
%fladmins ALL=(ALL) ALL
"""
```

### Step 6 — Hostname, services, firewall

```toml
[customizations]
hostname = "fl-web-gold"

[customizations.services]
enabled = ["firewalld", "sshd", "fedora-lane-firstboot.service"]

[customizations.firewall]
ports = ["2222:tcp", "35443:tcp"]

[customizations.firewall.services]
enabled = []
disabled = ["ssh", "http", "https", "cockpit"]
```

### Step 7 — Config files and directories

Create parent dirs before nested files:

```toml
[[customizations.directories]]
path = "/opt/fedora-lane/www"
mode = "0755"
ensure_parents = true

[[customizations.files]]
path = "/etc/ssh/sshd_config.d/99-fedora-lane.conf"
data = """
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
"""
```

### Step 8 — First-boot (optional but used here)

Bake a script + oneshot systemd unit so the first boot:

- Sets SELinux enforcing and port labels  
- Remounts `/tmp` with `noexec`  
- Starts firewalld with only 2222 + 35443  
- Pulls httpd container and enables `container-fl-httpd.service`  

See the full script in [`fedora-lane-gold.toml`](fedora-lane-gold.toml) (`fedora-lane-firstboot.sh`).

### Step 9 — Build

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

AWS / Azure publish: [08-rhel10-rebuild.md](08-rhel10-rebuild.md) · [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md) · [15-azure-vhd-upload.md](15-azure-vhd-upload.md)

### Step 10 — Change something later

1. Edit the TOML.  
2. Bump `version`.  
3. Rebuild and publish a **new** AMI/image (existing VMs keep the old disk).  
4. For password only on a **running** VM: `sudo passwd fladmin1` (does not change the AMI).

---

## Customization catalog (what you can do)

These are the main blueprint customizations Image Builder supports on RHEL 10.  
**Used in Fedora Lane gold** = already in `fedora-lane-gold.toml`.  
**Available for you** = you can add them when you extend the standard.

### A. Identity and access

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Extra users | `[[customizations.user]]` | Yes (`fladmin1/2`) | Add app users, set `home`, `shell`, `uid`, `gid`, `expiredate` |
| Extra groups | `[[customizations.group]]` | Yes (`fladmins`) | Create groups; optional `gid` |
| SSH key on user | `key =` on user **or** `[[customizations.sshkey]]` | Yes | Rotate keys; add keys for existing users |
| Password | `password =` (prefer `$6$` hash) | Yes | Lab/sudo password; rotate hash and rebuild |

Example — add another admin:

```toml
[[customizations.user]]
name = "fladmin3"
groups = ["fladmins", "wheel"]
key = "ssh-ed25519 AAAA... fladmin3"
password = "$6$...."
```

### B. Packages and content

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Individual packages | `[[packages]]` | Yes | Add monitoring agents, tools, app deps |
| Package groups | `[[groups]]` | No | Install comps groups (e.g. `@server-product`) |
| Containers at build | container embedding (see RH Ch 5.4) | No (we pull at first-boot) | Prefetch images into the disk if your IB version supports it |

Example — add a package:

```toml
[[packages]]
name = "rsyslog"
version = "*"
```

### C. Storage and layout

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Extra mount points | `[[customizations.filesystem]]` | Yes | Add `/var/lib/containers`, larger `/var/log`, etc. Keep sizes sensible for your AMI |
| Partition mode | `[customizations]` / disk options | Default | `auto-lvm` vs raw — see RH “partition mode” |
| LVM names | `[[customizations.disk.partitions]]` | No | Name VGs/LVs for standards |

Example — larger log volume:

```toml
[[customizations.filesystem]]
mountpoint = "/var/log"
minsize = "4 GiB"
```

### D. Network and firewall

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Open ports | `[customizations.firewall] ports = [...]` | Yes (`2222`, `35443`) | Add app ports (`8080:tcp`), ranges (`30000-32767:tcp`) |
| firewalld services | `[customizations.firewall.services]` | Yes (disable ssh/http/https/cockpit) | `enabled = ["ntp"]`, `disabled = ["telnet"]` |

Example — also open metrics:

```toml
[customizations.firewall]
ports = ["2222:tcp", "35443:tcp", "9100:tcp"]
```

List firewalld service names on a RHEL host: `firewall-cmd --get-services`.

### E. Services and boot behavior

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Enable/disable units | `[customizations.services]` | Yes | Enable `chronyd`, disable unused daemons |
| Hostname | `[customizations] hostname =` | Yes (`fl-web-gold`) | Set a fleet naming pattern |

```toml
[customizations.services]
enabled = ["sshd", "firewalld", "chronyd"]
disabled = ["postfix"]
```

### F. Files and directories

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Create/replace files | `[[customizations.files]]` | Yes | Drop-ins for sshd, sudoers, sysctl, banners, app config |
| Create directories | `[[customizations.directories]]` | Yes | Ensure parents exist before nested files |

Prefer drop-in files under `/etc/...d/` instead of rewriting whole configs.

### G. Locale, time, kernel

| Customization | TOML | Used here? | What you can do |
|---------------|------|------------|-----------------|
| Timezone / NTP | `[customizations.timezone]` | No | e.g. `timezone = "UTC"`, NTP servers |
| Locale / keyboard | `[customizations.locale]` | No | `languages`, `keyboard` |
| Kernel arguments | `[customizations.kernel]` | No | Append `args` (e.g. audit, hugepages) |
| Real-time kernel | kernel customization + packages | No | Specialized latency workloads |

Example — timezone:

```toml
[customizations.timezone]
timezone = "UTC"
```

### H. Installer / ISO only (usually not for AMI/VHD)

| Customization | When it applies |
|---------------|-----------------|
| `[customizations.installer]` / Kickstart | `image-installer` ISO builds — not required for AWS AMI / Azure VHD gold images |

### I. Patterns beyond the TOML (first-boot / day-2)

You can also extend the **first-boot script** (or cloud-init later) for:

| Need | Approach |
|------|----------|
| Containerized apps as systemd units | Same pattern as `container-fl-httpd` |
| Register to Insights / RHSM extras | First-boot or bootstrap playbook |
| OpenSCAP CIS remediation | Stretch: `oscap` + `scap-security-guide` (packages already listed) |
| Extra SSH users per environment | Separate blueprints (`staging` vs `prod`) or inject keys at launch |

---

## Fedora Lane requirement → TOML field

| Requirement | Where |
|-------------|--------|
| RHEL 10 base | `distro = "rhel-10.0"` |
| Local IB (not hosted) | Build with `image-builder` on RHEL 10 |
| Separate mounts &lt; 5 GiB | `[[customizations.filesystem]]` |
| SELinux enforcing | first-boot script |
| `/tmp` noexec | first-boot fstab rewrite |
| SSH 2222, no root, no password SSH | `99-fedora-lane.conf` |
| Admins + sudo **with** password | user `password=` + sudoers without NOPASSWD |
| SSH key login | user `key=` |
| Firewall only SSH + httpd | firewall ports 2222 + 35443 |
| httpd container :35443 | first-boot Podman + systemd |
| Survive reboot | enabled services + first-boot flag |

---

## Minimal example (start small)

If you want a **tiny** blueprint to learn the format, then grow it:

```toml
name = "fl-minimal"
description = "Learning blueprint"
version = "0.0.1"
distro = "rhel-10.0"
modules = []
groups = []

[[packages]]
name = "vim-enhanced"
version = "*"

[customizations]
hostname = "fl-minimal"

[[customizations.user]]
name = "fladmin1"
groups = ["wheel"]
key = "ssh-ed25519 AAAA... your-key"
password = "$6$...."
```

Then add mounts, firewall, and first-boot as you harden toward the full [`fedora-lane-gold.toml`](fedora-lane-gold.toml).

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [`fedora-lane-gold.toml`](fedora-lane-gold.toml) | Production gold blueprint |
| [08-rhel10-rebuild.md](08-rhel10-rebuild.md) | Build AMI / VHD |
| [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md) | Publish to AWS |
| [15-azure-vhd-upload.md](15-azure-vhd-upload.md) | Publish to Azure |
| [../docs/08-verify-customizations.md](../docs/08-verify-customizations.md) | Prove customizations after launch |
| [../docs/00-end-to-end-guide.md](../docs/00-end-to-end-guide.md) | Full AWS + Azure path |
