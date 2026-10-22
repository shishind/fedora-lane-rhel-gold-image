# Build the gold image with RHEL 10 Image Builder CLI

Uses the current RHEL 10 tool: **`image-builder`**  
(docs: [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)).

Blueprint:

```toml
distro = "rhel-10.0"   # exact id from: image-builder list --filter "distro:rhel-10*"
version = "0.1.3"
```

## 1) Builder host must be RHEL 10

```bash
cat /etc/os-release
# VERSION_ID should be 10.x
```

## 2) Install Image Builder

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list --filter "distro:rhel-10*"
```

If `dnf install` or the build cannot reach Red Hat content, fix subscription/CDN first:  
[11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)

## 3) Match `distro` in the blueprint (critical)

```bash
sudo image-builder list --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"
```

You need a line like `rhel-10.0 type:ami arch:x86_64`.  
**Do not** use bare `rhel-10` — that causes `cannot find image for: distro:"rhel-10" type:"ami"`.

```toml
distro = "rhel-10.0"    # use the EXACT id from the list
```

Troubleshoot: [14-distro-ami-not-found.md](14-distro-ami-not-found.md)

## 4) Build (AMI type)

```bash
cd ~/   # or wherever fedora-lane-gold.toml lives
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

When finished, note the `.raw` (or similar) artifact in the build output directory.

### Option A — `image-builder upload` to AWS (recommended)

Prerequisites: AWS credentials on the builder, writable S3 bucket, `vmimport` IAM role  
([AWS AMI chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)).

**One upload command does: S3 → snapshot → AMI → delete temp S3 object.**

Proven (existing `.raw`):

```bash
sudo image-builder upload \
  rhel-10.0-ami-x86_64.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold \
  --arch x86_64
# → AMI registered: ami-0cad9f5491acdddf9
# → Snapshot ID: snap-01ea4b3df978de401
```

**Build + upload in one step:**

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

Full narrative + sample log: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)  
Copy-paste sheet: [13-image-builder-aws-examples.md](13-image-builder-aws-examples.md)

### Option B — Manual S3 + import-snapshot

Only if Option A is unavailable. Console/CLI: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md) (Part 5).
## 5) Build Azure VHD (same blueprint)

```bash
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
df -h /var   # need 15–20+ GiB free

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
```

Publish to Azure (page blob → Gen2 image → NSG → VM):

- Detailed: [15-azure-vhd-upload.md](15-azure-vhd-upload.md)  
- Examples: [16-azure-examples.md](16-azure-examples.md)  
- Official: [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)

## 6) Gold image firewall note

Gold image firewall allows only **SSH 2222** and **httpd 35443** (AWS SG and Azure NSG must match).  
Web Console stays closed on the gold image by design.  
Day-2 GUI: [docs/07-rhel10-web-console-demo.md](../docs/07-rhel10-web-console-demo.md)

## 7) Launch and verify

```bash
# AWS EC2 or Azure VM — same SSH:
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

Test customizations: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)

```bash
cat /etc/redhat-release
# expect Red Hat Enterprise Linux release 10.x
```

End-to-end both clouds: [docs/00-end-to-end-guide.md](../docs/00-end-to-end-guide.md)
