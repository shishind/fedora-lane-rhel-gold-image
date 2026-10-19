# Fix: `cannot find image for: distro:"rhel-10" type:"ami"`

## Error

```text
error: cannot find image for: distro:"rhel-10" type:"ami" arch:"x86_64"
```

And this may print nothing:

```bash
sudo image-builder list-images --filter "distro:rhel-10"
```

## Cause

Image Builder does **not** use the short name `rhel-10`.  
It needs the **exact** distro id, for example:

- `rhel-10.0`
- `rhel-10.1`
- `rhel-10.2`

That id must appear in `image-builder list` together with `type:ami` and `arch:x86_64`.

---

## Fix — list, then set distro exactly

### 1) List what this host can build

```bash
sudo image-builder list | egrep -i 'rhel-10|ami' | head -50

# or filtered:
sudo image-builder list --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "arch:x86_64"
```

Example line you want to see:

```text
rhel-10.0 type:ami arch:x86_64
```

(or `rhel-10.2 type:ami arch:x86_64`, etc.)

### 2) Put that **exact** string in the blueprint

Edit `fedora-lane-gold.toml`:

```toml
distro = "rhel-10.0"    # MUST match the list line — change if yours is rhel-10.2
```

### 3) Build with the same id

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

Or omit `--distro` and let Image Builder use the **host** version (often easiest on a RHEL 10.x builder):

```bash
# Temporarily comment out distro= in the TOML, or set it to the host’s exact id
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --with-buildlog
```

### 4) AWS upload example (after distro is correct)

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

---

## If `list` shows no `rhel-10*` at all

1. Confirm the builder is RHEL 10: `cat /etc/redhat-release`  
2. Fix subscription / CDN: [11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)  
3. Reinstall packages: `sudo dnf reinstall -y image-builder`

---

## Related

- [13-image-builder-aws-examples.md](13-image-builder-aws-examples.md)  
- [08-rhel10-rebuild.md](08-rhel10-rebuild.md)  
