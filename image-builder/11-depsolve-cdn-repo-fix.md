# Fix: `depsolve` fails downloading Red Hat CDN (`repomd.xml`)

## Error you saw

```text
composer-cli blueprints depsolve fedora-lane-gold
ERROR: BlueprintsError: fedora-lane-gold: running osbuild-depsolve-dnf failed:
DNF error occurred: RepoError: There was a problem reading a repository:
Failed to download metadata for repo '...' [baseos:
https://cdn.redhat.com/content/dist/rhel10/10/x86_64/baseos/os]:
Cannot download repomd.xml: All mirrors were tried
```

## What it means

`depsolve` asks Image Builder to resolve every package in the blueprint against **Red Hat CDN** (`cdn.redhat.com`).

That download uses the builder host’s **subscription / RHSM certificates**. If the host is not registered, not entitled, or cannot reach the CDN, depsolve fails — even if `composer-cli distros list` already works.

This is **not** a TOML syntax problem.

---

## Step-by-step fix (on the RHEL 10 builder)

### 1) Confirm OS and network

```bash
cat /etc/redhat-release
# expect: Red Hat Enterprise Linux release 10.x

ping -c 2 cdn.redhat.com
curl -I --max-time 15 https://cdn.redhat.com/ 2>&1 | head -5
```

If DNS/ping/curl fail, fix lab network / proxy / firewall first.

### 2) Check subscription status

```bash
sudo subscription-manager status
sudo subscription-manager identity
sudo subscription-manager list --available --all | head -40
sudo subscription-manager list --consumed
```

Healthy builder usually shows **Current** / registered identity and at least one consumed subscription that covers RHEL.

### 3) Register if needed (pick one path)

**A — Interactive username/password (common on lab VMs):**

```bash
sudo subscription-manager register --username <RHN_OR_OFFLINE_USER> --auto-attach
```

**B — Activation key (preferred in org / RHDP when provided):**

```bash
sudo subscription-manager register \
  --org <ORG_ID> \
  --activationkey <ACTIVATION_KEY>
sudo subscription-manager attach --auto
```

**C — Already registered but no repos:**

```bash
sudo subscription-manager refresh
sudo subscription-manager attach --auto
sudo subscription-manager repos --list | egrep -i 'rhel-10|baseos|appstream' | head -40
```

Enable BaseOS + AppStream for RHEL 10 if they are disabled (repo ids vary slightly by release):

```bash
# List exact ids first, then enable — examples:
sudo subscription-manager repos --list-enabled | head -50

# Typical pattern (adjust ids to match --list output):
sudo subscription-manager repos \
  --enable=rhel-10-for-x86_64-baseos-rpms \
  --enable=rhel-10-for-x86_64-appstream-rpms
```

If your `repos --list` shows different names (for example with `eus` or `e4s`), enable the matching **baseos** and **appstream** for `x86_64`.

### 4) Prove normal `dnf` can use Red Hat repos

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
sudo dnf -y install --setopt=tsflags=test bash
```

If **host** `dnf` cannot refresh `cdn.redhat.com`, Image Builder depsolve cannot either. Fix subscription/network before going further.

### 5) Restart Image Builder services

After fixing RHSM, restart so workers pick up new certs/repos:

```bash
sudo systemctl restart osbuild-composer.socket osbuild-composer
sudo systemctl status osbuild-composer.socket --no-pager
```

If you fixed subscription while logged in as `root`, still ensure your normal user is in `weldr` (see [09-weldr-permission-fix.md](09-weldr-permission-fix.md)). Running as `root` often works for the socket, but lab guidance prefers `lab-user` + `weldr`.

### 6) Re-run depsolve

```bash
composer-cli blueprints push ~/fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
```

Success looks like package lists / no `RepoError`. Then:

```bash
composer-cli compose start fedora-lane-gold ami
composer-cli compose status
```

---

## RHDP / lab-specific notes

| Situation | What to do |
|-----------|------------|
| RHDP VM already registered | Skip register; run `subscription-manager status` + `dnf makecache` |
| “Simple Content Access” org | Attach may be automatic; still need valid identity + network to CDN |
| Proxy required | Configure `/etc/rhsm/rhsm.conf` proxy settings; retry `dnf makecache` |
| Clock wrong | `timedatectl`; bad time breaks TLS to CDN |
| Still failing after register | `sudo journalctl -u rhsmcertd -u osbuild-composer -xe --no-pager \| tail -80` |

**Do not** add unofficial Rocky/CentOS `.repo` files to fix this — Image Builder for `distro = "rhel-10"` must use Red Hat content.

---

## Quick checklist

| Check | OK when |
|-------|---------|
| `subscription-manager status` | Registered / entitled |
| `dnf repolist` | Shows RHEL 10 BaseOS + AppStream |
| `dnf makecache` | Completes without CDN errors |
| `curl -I https://cdn.redhat.com/` | Reachable (not timeout) |
| `systemctl restart osbuild-composer` | After RHSM fix |
| `composer-cli blueprints depsolve ...` | No `RepoError` |

---

## Related docs

- [08-rhel10-rebuild.md](08-rhel10-rebuild.md) — full rebuild flow  
- [09-weldr-permission-fix.md](09-weldr-permission-fix.md) — socket permission  
- [10-create-toml-blueprint.md](10-create-toml-blueprint.md) — TOML contents  
