# Rebuild gold image on RHEL 10

The blueprint now sets:

```toml
distro = "rhel-10"
version = "0.1.1"
```

Your previous AMI was composed on **RHEL 9.4** — rebuild on a **RHEL 10** Image Builder host.

## 1) Builder host must be RHEL 10

```bash
cat /etc/os-release
# VERSION_ID should be 10.x
```

Install Image Builder from **Red Hat** repos (not Rocky):

```bash
sudo dnf -y install osbuild-composer weldr-client composer-cli \
  cockpit-composer genisoimage qemu-img
sudo systemctl enable --now osbuild-composer.socket
sudo usermod -aG weldr "$USER"
getent group weldr    # your user must appear here
```

**Required:** log out of SSH and connect again (or run `newgrp weldr`).  
Group membership does **not** apply to the current shell until you refresh.

```bash
id | grep weldr       # must show weldr
composer-cli status show
composer-cli distros list
```

If you see `you do not have permission to access /run/weldr/api.socket`, follow the full fix:  
**[09-weldr-permission-fix.md](09-weldr-permission-fix.md)**

## 2) Match `distro` exactly

```bash
composer-cli distros list
```

If the list shows e.g. `rhel-10.0` or `rhel-100` instead of `rhel-10`, edit `fedora-lane-gold.toml`:

```toml
distro = "rhel-10.0"   # use the EXACT string from distros list
```

## 3) Subscription / CDN must work (before depsolve)

Image Builder downloads RHEL packages from `cdn.redhat.com`. If depsolve fails with
`Cannot download repomd.xml` / `RepoError`, fix registration first:

**[11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)**

Quick check:

```bash
sudo subscription-manager status
sudo dnf makecache
sudo dnf repolist
```

## 4) Push + compose

```bash
composer-cli blueprints push ~/fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
composer-cli compose start fedora-lane-gold ami
composer-cli compose status
```

When FINISHED → `composer-cli compose image UUID` → upload to AWS → new AMI → launch → verify.

## 5) Gold image firewall note (Cockpit)

Gold image firewall rule: **only SSH (2222) and httpd (35443)** on the network.

So the gold AMI keeps **Cockpit/Web Console closed** in firewall (by design).

For **Web Console / Session Recording / containers GUI**, use a separate RHEL 10 management host (`docs/07-rhel10-web-console-demo.md`).

## 6) Verify base OS on the new EC2

```bash
cat /etc/redhat-release
# expect Red Hat Enterprise Linux release 10.x
```
