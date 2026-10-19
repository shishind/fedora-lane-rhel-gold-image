# Fix: Image Builder cannot download Red Hat CDN content

## Typical errors

```text
Failed to download metadata for repo ... baseos ... cdn.redhat.com
Cannot download repomd.xml: All mirrors were tried
Unauthorized: Invalid credentials for request.
This system has no repositories available through subscriptions.
```

Or `image-builder build` fails while resolving packages (use exact distro id like `rhel-10.0`).

## What it means

`image-builder` pulls RHEL packages from **Red Hat CDN** using the builder’s **subscription**.  
If the host is not registered or has no repos, the build fails. This is not a TOML syntax problem.

Official install prerequisite: host subscribed with **BaseOS** and **AppStream** enabled  
([Installing RHEL image builder](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index)).

---

## Fix on the RHEL 10 builder

### 1) Network

```bash
ping -c 2 cdn.redhat.com
curl -I --max-time 15 https://cdn.redhat.com/ 2>&1 | head -5
```

### 2) Registration state

```bash
sudo subscription-manager identity
sudo subscription-manager status
sudo subscription-manager repos --list-enabled | head -50
```

### 3) Register (pick one)

Clean bad state if needed:

```bash
sudo subscription-manager unregister || true
sudo subscription-manager clean
```

**Username / password** (Red Hat account — not the Linux sudo password):

```bash
sudo subscription-manager register --username '<YOUR_RED_HAT_LOGIN>'
```

**Activation key** (preferred for organizations):

```bash
sudo subscription-manager register \
  --org '<ORG_ID>' \
  --activationkey '<ACTIVATION_KEY>'
```

Then enable RHEL 10 repos (adjust ids to match `repos --list`):

```bash
sudo subscription-manager refresh
sudo subscription-manager repos --list | egrep -i 'rhel-10|baseos|appstream' | head -40
sudo subscription-manager repos \
  --enable=rhel-10-for-x86_64-baseos-rpms \
  --enable=rhel-10-for-x86_64-appstream-rpms
```

### 4) Prove `dnf` works

```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
```

### 5) Retry Image Builder

```bash
sudo image-builder list-images --filter "distro:rhel-10"
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

---

## Alternatives if portal login fails

1. **Org activation key** from your Red Hat admin  
2. **`rhc connect`** with the same org/key  
3. **Cloud RHEL (RHUI)** builder on AWS where `dnf repolist` already works without classic register  
4. **Developer Subscription** + activation key on a builder you control  

Avoid Rocky/CentOS `.repo` files for RHEL 10 blueprints.

---

## Checklist

| Check | OK when |
|-------|---------|
| `subscription-manager identity` | Shows system / org |
| `dnf repolist` | RHEL 10 BaseOS + AppStream |
| `dnf makecache` | No CDN errors |
| `sudo image-builder build …` | Compose progresses |

Related: [08-rhel10-rebuild.md](08-rhel10-rebuild.md) · [10-create-toml-blueprint.md](10-create-toml-blueprint.md)
