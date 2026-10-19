# Local Image Builder — RHEL 10 CLI → AWS AMI (+ Azure stretch)

Mac only edits files. Builds run on a **RHEL 10** machine with the **`image-builder`** CLI.

```text
[ Mac: edit TOML ]
       ↓
[ RHEL 10 builder: image-builder ]
       ↓
  build type ami  → AWS AMI
  build type vhd  → Azure (stretch)
       ↓
[ Launch VM from that image → verify after reboot ]
```

Admin sudo password (demo): **`RedHat`**  
SSH key in blueprint: `~/.ssh/fedora-lane-lab.pub` (comment `fedora-lane-apac`).

Official: [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

---

## Step 1 — RHEL 10 builder host

Use a RHEL 10 VM/EC2 with enough disk (about **60 GiB** free recommended for composes).

```bash
cat /etc/os-release   # VERSION_ID=10.x
```

---

## Step 2 — Install Image Builder

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list
sudo image-builder list --filter "distro:rhel-10*"
```

Subscription/CDN issues: [11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)

---

## Step 3 — Copy the TOML to the builder

**On Mac:**

```bash
export BUILDER_IP=PASTE_BUILDER_PUBLIC_IP
scp -i ~/.ssh/<builder-key>.pem \
  ~/Projects/fedora-lane-rhel-gold-image/image-builder/fedora-lane-gold.toml \
  cloud-user@$BUILDER_IP:~/
```

**On builder:**

```bash
ls -l ~/fedora-lane-gold.toml
```

---

## Step 4 — Build AWS image (`ami`)

```bash
cd ~
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

Find the output `.raw` (name varies by release), for example:

```bash
ls -lh ./*ami*.raw ./*.raw 2>/dev/null
```

### Publish to AWS

**Preferred (Image Builder upload)** — [AWS AMI chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)

```bash
# Build + upload (example)
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold

# Or upload an existing raw (example)
sudo image-builder upload \
  ./d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

All examples: [13-image-builder-aws-examples.md](13-image-builder-aws-examples.md)

**Or** manual Console S3 + CLI `aws s3 cp` + import-snapshot:  
[12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)

---

## Step 5 — Azure (`vhd`) — full publish path

```bash
df -h /var   # ≥ 15–20 GiB free
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

Then: storage account → **page** blob upload → Gen2 managed image → NSG **2222**/**35443** → VM.

- Detailed (CLI + Portal): [15-azure-vhd-upload.md](15-azure-vhd-upload.md)  
- Examples: [16-azure-examples.md](16-azure-examples.md)

---

## Step 6 — Launch and verify

**AWS** security group or **Azure** NSG: your IP on **2222** and **35443**.

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

Commands: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)  
Both clouds end-to-end: [docs/00-end-to-end-guide.md](../docs/00-end-to-end-guide.md)

```bash
cat /etc/redhat-release
getenforce
findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp
sudo ss -tlnp | egrep '2222|35443'
curl -s http://127.0.0.1:35443/
sudo firewall-cmd --list-ports
sudo reboot   # then re-check
```

---

## Why this meets Fedora Lane requirements

| Requirement | How |
|-------------|-----|
| Local Image Builder (not hosted) | `image-builder` on RHEL 10 |
| AWS or Azure | `ami` + `vhd` |
| Partitions / SELinux / ports / users / firewall / container httpd | TOML + first-boot |
| Prove on cloud VM | Launch from AMI |
| Survive reboot | systemd units |

More detail: [08-rhel10-rebuild.md](08-rhel10-rebuild.md) · [10-create-toml-blueprint.md](10-create-toml-blueprint.md)
