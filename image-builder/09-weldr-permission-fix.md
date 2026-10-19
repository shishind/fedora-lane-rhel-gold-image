# Fix: `composer-cli` cannot access `/run/weldr/api.socket`

## Error you saw

```text
[lab-user@rhel ~]$ composer-cli distros list
ERROR: Types Error: you do not have permission to access /run/weldr/api.socket.
  Check to make sure that you are a member of the weldr group
```

## Why this happens

Local Image Builder talks to `osbuild-composer` through a Unix socket:

```text
/run/weldr/api.socket
```

That socket is owned by the **`weldr`** group. Your login user (`lab-user`) must be in that group **and** your current shell must have refreshed group membership.

Common causes:

1. Packages installed, but `usermod -aG weldr` never run  
2. `usermod` ran, but you **did not log out / SSH again** (old session still has no `weldr`)  
3. `osbuild-composer.socket` is not running yet  

---

## Exact fix (run on the RHEL builder host)

### Step A — Confirm you are on the builder host

```bash
whoami
hostname
cat /etc/os-release | egrep '^(NAME|VERSION_ID)='
```

Expect RHEL **10.x** for the current gold blueprint (`distro = "rhel-10"`).

### Step B — Install Image Builder packages (if not already)

Use **Red Hat** repos only (not Rocky third-party RPMs):

```bash
sudo dnf -y install osbuild-composer weldr-client composer-cli \
  cockpit-composer genisoimage qemu-img
```

### Step C — Start the Weldr / composer socket

```bash
sudo systemctl enable --now osbuild-composer.socket
sudo systemctl status osbuild-composer.socket --no-pager
ls -l /run/weldr/api.socket
```

You should see a socket file. If `ls` says “No such file”, wait a few seconds and re-check status.

### Step D — Add your user to the `weldr` group

```bash
# Replace lab-user if your account name differs
sudo usermod -aG weldr "$USER"
# or explicitly:
# sudo usermod -aG weldr lab-user

# Verify the account has weldr in /etc/group (may still be missing in THIS shell)
getent group weldr
id "$USER"
```

`getent group weldr` should list your username.

### Step E — Refresh the session (required)

Group changes do **not** apply to an already-open SSH session.

**Preferred (cleanest):**

```bash
exit
# SSH back into the builder host
ssh lab-user@<BUILDER_IP>
```

**Same session (quick workaround):**

```bash
newgrp weldr
```

Then verify:

```bash
id
# must show: groups=...(...weldr...)
```

### Step F — Re-run the command that failed

```bash
composer-cli status show
composer-cli distros list
```

You should get a list of distro IDs (look for something like `rhel-10`, `rhel-10.0`, etc.).

Use the **exact** string from that list in `fedora-lane-gold.toml`:

```toml
distro = "rhel-10"    # or rhel-10.0 / whatever distros list printed
```

---

## Still failing? Checklist

| Check | Command | Expect |
|-------|---------|--------|
| Socket exists | `ls -l /run/weldr/api.socket` | file present, group `weldr` |
| Service up | `systemctl is-active osbuild-composer.socket` | `active` |
| You are in weldr **now** | `id \| grep weldr` | prints `weldr` |
| Permissions | `ls -l /run/weldr/api.socket` | your user can access via group |
| SELinux denials (rare) | `sudo ausearch -m AVC -ts recent \| grep weldr` | no recent deny |

If `id` still has no `weldr` after `usermod`, you did not refresh the session — **log out and SSH again**.

If socket is missing:

```bash
sudo systemctl restart osbuild-composer.socket
sudo systemctl status osbuild-composer --no-pager
journalctl -u osbuild-composer -xe --no-pager | tail -50
```

---

## After this works — continue the gold image build

```bash
# On builder: copy TOML if needed, then:
composer-cli blueprints push ~/fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
composer-cli compose start fedora-lane-gold ami
composer-cli compose status
```

Full RHEL 10 rebuild flow: [08-rhel10-rebuild.md](08-rhel10-rebuild.md)  
AWS/Azure compose overview: [05-local-ib-steps.md](05-local-ib-steps.md)
