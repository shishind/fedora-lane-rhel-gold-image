# How we created `fedora-lane-gold.toml`

This doc explains **how to write the Image Builder blueprint**, what each block does, and **exactly how the admin password and SSH key were passed**.

Working file in this repo:

`image-builder/fedora-lane-gold.toml`

---

## What you need before writing the TOML

| Item | Why | How we got it |
|------|-----|----------------|
| RHEL 10 builder host | Image Builder only runs on RHEL | EC2 / on-prem RHEL 10 |
| `image-builder` package / CLI | Compose from TOML | `dnf install image-builder` — see [08-rhel10-rebuild.md](08-rhel10-rebuild.md) |
| Exact `distro` id | Blueprint must match builder | `sudo image-builder list-images --filter "distro:rhel-10"` |
| SSH **public** key | Key-only login for fladmins | Admin workstation `.pub` key |
| Password **hash** (not plain text) | Sudo password for fladmins | `openssl passwd -6` (see below) |
| Security / layout requirements | What to encode | Partitions, SELinux, ports, firewall, container httpd |

**Never put** AWS keys or private SSH keys (`.pem` / `id_ed25519`) in the TOML or git.

Official blueprint + CLI: [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

---

## Step 1 — Confirm the distro id

On the builder:

```bash
sudo image-builder list-images --filter "distro:rhel-10"
```

Copy the **exact** distro string (examples: `rhel-10`, `rhel-10.0`). Put it here:

```toml
distro = "rhel-10"
```

If you use the wrong string, the build fails with a distro error.

---

## Step 2 — Create the file skeleton

On your Mac (or builder):

```bash
cd ~/Projects/fedora-lane-rhel-gold-image/image-builder
# start from our file, or create empty:
# nano fedora-lane-gold.toml
```

Minimum header:

```toml
name = "fedora-lane-gold"
description = "Fedora Lane e-commerce web gold image (RHEL 10)"
version = "0.1.1"
distro = "rhel-10"
modules = []
groups = []
```

- `name` — blueprint name (`fedora-lane-gold`)
- `version` — bump when you change the blueprint (we use `0.1.2`)
- `distro` — must match Step 1

---

## Step 3 — Add packages

Each package is a TOML table:

```toml
[[packages]]
name = "podman"
version = "*"
```

**What we included and why:**

| Package | Why |
|---------|-----|
| `httpd` | Web stack present (container preferred; package available) |
| `podman` | Run httpd in a container |
| `container-selinux` | SELinux policy for containers |
| `policycoreutils-python-utils` | `semanage` for custom SSH/httpd ports |
| `firewalld` | Host firewall |
| `openssh-server` | SSH daemon |
| `sudo` | Admin privilege with password |
| `openscap-scanner` / `scap-security-guide` | Stretch hardening / OpenSCAP |

---

## Step 4 — Separate filesystems (&lt; 5 GiB)

Requirement: `/var/log`, `/home`, `/tmp`, `/var/tmp` as separate mounts under 5 GiB.

```toml
[[customizations.filesystem]]
mountpoint = "/var/log"
minsize = "2 GiB"

[[customizations.filesystem]]
mountpoint = "/home"
minsize = "2 GiB"

[[customizations.filesystem]]
mountpoint = "/tmp"
minsize = "2 GiB"

[[customizations.filesystem]]
mountpoint = "/var/tmp"
minsize = "2 GiB"
```

`/tmp` **noexec** is applied in the first-boot script (fstab rewrite), not only in this block.

---

## Step 5 — Admin group + users (password + SSH key)

### 5a. Create the group

```toml
[[customizations.group]]
name = "fladmins"
```

### 5b. How the **password** is passed (important)

Image Builder does **not** accept a plain-text password in the blueprint for production-style hashes.

You must put a **SHA-512 crypt hash** in the `password = "..."` field.

**Generate the hash** (on Mac or RHEL):

```bash
# Lab password we use: RedHat
openssl passwd -6 'RedHat'
```

Example output (yours will differ because salt is random):

```text
$6$/V1FLi5PQGlFGbWT$gULz/71IRt9h8Hsli5QFLDhriu0JxnOXV2JCnwqnv4VEmwBPyFVmT5mpA6onQReAwvStA/Je4jztNYGGbIscH0
```

Meaning of the hash:

| Part | Meaning |
|------|---------|
| `$6$` | SHA-512 crypt |
| middle segment | salt |
| last segment | hashed password |

Paste the **entire** `$6$...` string into TOML:

```toml
password = "$6$/V1FLi5PQGlFGbWT$gULz/71IRt9h8Hsli5QFLDhriu0JxnOXV2JCnwqnv4VEmwBPyFVmT5mpA6onQReAwvStA/Je4jztNYGGbIscH0"
```

**Do not** write:

```toml
password = "RedHat"    # WRONG — plain text is not what we use
```

Document the cleartext only in a **comment** for the lab (already in our file):

```toml
# Lab sudo password for fladmin1/fladmin2: RedHat
```

That password is for **sudo** (and local console login if enabled). SSH password login is **disabled** in sshd config — you still need the SSH key to log in remotely.

### 5c. How the **SSH public key** is passed

1. On your Mac, show the public key:

```bash
cat ~/.ssh/fedora-lane-lab.pub
# or:
cat ~/.ssh/id_ed25519.pub
```

2. Copy the **one line** that starts with `ssh-ed25519` or `ssh-rsa`.

3. Put it in the `key = "..."` field (whole line, in quotes):

```toml
[[customizations.user]]
name = "fladmin1"
description = "Fedora Lane administrator"
groups = ["fladmins", "wheel"]
key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... fedora-lane-apac"
password = "$6$...."
```

Same for `fladmin2`.

- `groups = ["fladmins", "wheel"]` — admin group + classic wheel for sudo
- Image Builder installs the key into the user’s `authorized_keys` at compose time

### 5d. Sudo with password (not passwordless)

```toml
[[customizations.files]]
path = "/etc/sudoers.d/fladmins"
mode = "0440"
data = """
%fladmins ALL=(ALL) ALL
"""
```

Note: **no** `NOPASSWD`. So after SSH key login, `sudo` still asks for the password (`RedHat`).

---

## Step 6 — Hostname, services, firewall

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

Only custom ports **2222** (SSH) and **35443** (httpd container) are opened. Default ssh/http/https/cockpit services are disabled on the firewall.

---

## Step 7 — SSH hardening file baked into the image

```toml
[[customizations.files]]
path = "/etc/ssh/sshd_config.d/99-fedora-lane.conf"
data = """
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
"""
```

| Setting | Effect |
|---------|--------|
| `Port 2222` | Non-default SSH |
| `PermitRootLogin no` | No root SSH |
| `PasswordAuthentication no` | Keys only over SSH |
| `PubkeyAuthentication yes` | Uses the `key =` from users |

---

## Step 8 — Directories + web content

Parent directories must exist before nested files (compose can fail otherwise):

```toml
[[customizations.directories]]
path = "/opt/fedora-lane"
mode = "0755"
ensure_parents = true

[[customizations.directories]]
path = "/opt/fedora-lane/www"
mode = "0755"
ensure_parents = true

[[customizations.files]]
path = "/opt/fedora-lane/www/index.html"
data = """
<html><body><h1>Fedora Lane e-commerce web — httpd OK</h1></body></html>
"""
```

Also a fallback under `/var/www/html/index.html` for safety.

---

## Step 9 — First-boot script (runtime hardening + Podman httpd)

Some controls are easier **after** first boot (SELinux ports, Podman pull, systemd generate). We bake:

1. `/usr/local/sbin/fedora-lane-firstboot.sh` — runs once  
2. `/etc/systemd/system/fedora-lane-firstboot.service` — oneshot, enabled  

What the script does:

- SELinux → enforcing  
- `/tmp` → `noexec` in fstab + remount  
- `semanage port` for 2222 (`ssh_port_t`) and 35443 (`http_port_t`)  
- firewalld: open 2222 + 35443 only  
- Pull UBI httpd, run as `fl-httpd` on host port **35443**  
- `podman generate systemd` → enable `container-fl-httpd.service`  
- Touch `/var/lib/fedora-lane-firstboot.done` so it does not re-run  

That is how “httpd in a container, managed as a service” is delivered.

---

## Step 10 — Build from the TOML (RHEL 10 `image-builder` CLI)

```bash
# Copy TOML to builder if edited on Mac
scp image-builder/fedora-lane-gold.toml user@BUILDER:~/

# On builder
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10 \
  --with-buildlog
```

Publish to AWS with Image Builder upload flags, or manual S3 path:  
[05-local-ib-steps.md](05-local-ib-steps.md) · [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)

---

## Quick map: requirement → TOML field

| Requirement | Where in our TOML |
|-------------|-------------------|
| RHEL 10 base | `distro = "rhel-10"` |
| Local IB (not hosted) | `image-builder build` on RHEL 10 host |
| Separate mounts &lt; 5 GiB | `[[customizations.filesystem]]` |
| SELinux enforcing | first-boot script |
| `/tmp` noexec | first-boot fstab rewrite |
| SSH 2222, no root, no password SSH | `99-fedora-lane.conf` |
| Admins + sudo **with** password | users `password=` hash + sudoers **without** NOPASSWD |
| SSH key login | user `key=` public key line |
| Firewall only SSH + httpd | firewall ports 2222 + 35443 |
| httpd container :35443 | first-boot Podman + systemd |
| Survive reboot | enabled services + first-boot flag |

---

## Changing the password later

1. Generate a new hash: `openssl passwd -6 'NewPassword'`  
2. Replace both `password =` lines for fladmin1 and fladmin2  
3. Update the comment `# Lab sudo password ...`  
4. Bump `version`  
5. Re-push blueprint and **recompose** (existing AMI keeps the old hash until rebuild)  

On a **running** EC2 (without rebuild):

```bash
sudo passwd fladmin1
sudo passwd fladmin2
```

---

## Related docs

- [fedora-lane-gold.toml](fedora-lane-gold.toml) — the actual blueprint  
- [08-rhel10-rebuild.md](08-rhel10-rebuild.md) — RHEL 10 `image-builder` flow  
- [05-local-ib-steps.md](05-local-ib-steps.md) — AMI / VHD build flow  
- [09-weldr-permission-fix.md](09-weldr-permission-fix.md) — legacy `composer-cli` only  
