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

## If you see these two messages

```text
Unauthorized: Invalid credentials for request.
This system has no repositories available through subscriptions.
```

| Message | Meaning |
|---------|---------|
| `Unauthorized: Invalid credentials` | Wrong Red Hat username/password, wrong activation key, or account cannot register this host |
| `no repositories available through subscriptions` | Host is not entitled to CDN content (not registered correctly, empty/wrong org, or SCA register succeeded but repos never enabled) |

**Fix path below (unregister → register correctly → enable RHEL 10 repos → dnf makecache).**

Most Red Hat accounts now use **Simple Content Access (SCA)**:

- You **register** the system  
- You **do not** need `attach --auto` / pool attach  
- You **must** enable BaseOS + AppStream repos yourself (or via activation key)

---

## Step-by-step fix (on the RHEL 10 builder)

### 0) See what state you are in now

```bash
sudo subscription-manager identity
sudo subscription-manager status
sudo subscription-manager repos --list-enabled | head -50
ls /etc/pki/entitlement/ 2>/dev/null | head
```

- If `identity` fails → not registered (or bad identity)  
- If `repos --list-enabled` is empty / “no repositories” → registered poorly or repos not enabled  

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

### 3) Clean bad registration, then register correctly

If credentials failed or repos are empty, start clean:

```bash
sudo subscription-manager unregister || true
sudo subscription-manager clean
```

#### Path A — Username / password (your Red Hat account)

Use the same login as [access.redhat.com](https://access.redhat.com) / Hybrid Cloud Console.  
**Not** the Linux `root` / `lab-user` password, and **not** the AMI sudo password `RedHat`.

```bash
sudo subscription-manager register --username '<YOUR_RED_HAT_LOGIN>'
# prompts for password — must succeed with NO "Unauthorized"
sudo subscription-manager identity
```

Under SCA, `subscription-manager status` may say **Disabled** or **Registered** — that can be normal. Trust `identity` more than “Overall Status”.

#### Path B — Activation key (best for RHDP / org labs)

Get **Org ID** + **activation key** from:

- Hybrid Cloud Console → Inventory / Activation Keys, or  
- Your RHDP / FASTER lab instructions / mentor  

```bash
sudo subscription-manager register \
  --org '<ORG_ID>' \
  --activationkey '<ACTIVATION_KEY>'
sudo subscription-manager identity
```

Do **not** use a made-up key. Wrong key → `Unauthorized: Invalid credentials`.

#### After register — enable RHEL 10 repos (required when list is empty)

```bash
sudo subscription-manager refresh

# See what the account can offer
sudo subscription-manager repos --list | egrep -i 'rhel-10|baseos|appstream' | head -60

# Enable BaseOS + AppStream (ids must match --list output)
sudo subscription-manager repos \
  --enable=rhel-10-for-x86_64-baseos-rpms \
  --enable=rhel-10-for-x86_64-appstream-rpms

sudo subscription-manager repos --list-enabled
```

If `--enable` says the repo id is invalid, copy the **exact** Repo ID from `repos --list` (names differ slightly by SKU / EUS).

Still “no repositories available”? Then the **Red Hat account has no RHEL subscription content** for this org (evaluation expired, wrong org, or developer account without RHEL). Fix at account level:

1. Log into [console.redhat.com](https://console.redhat.com) / [access.redhat.com](https://access.redhat.com)  
2. Confirm the org has an active **RHEL** subscription  
3. Create/use an activation key that includes RHEL 10 repo sets  
4. Re-run Path B  

For FASTER: ask your **Pod Host / mentor** for the lab activation key / Org ID if your personal account has no RHEL SKU.

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
