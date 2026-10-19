# Build the gold image with RHEL 10 Image Builder CLI

Uses the current RHEL 10 tool: **`image-builder`**  
(docs: [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)).

Blueprint:

```toml
distro = "rhel-10"
version = "0.1.2"
```

## 1) Builder host must be RHEL 10

```bash
cat /etc/os-release
# VERSION_ID should be 10.x
```

## 2) Install Image Builder

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list
sudo image-builder list-images --filter "distro:rhel-10"
```

If `dnf install` or the build cannot reach Red Hat content, fix subscription/CDN first:  
[11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)

## 3) Match `distro` in the blueprint

```bash
sudo image-builder list-images --filter "distro:rhel-10"
```

If the filter shows e.g. `rhel-10.0` only, set that exact string in `fedora-lane-gold.toml`:

```toml
distro = "rhel-10"    # or the exact id from list-images
```

## 4) Build (AMI type)

```bash
cd ~/   # or wherever fedora-lane-gold.toml lives
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10 \
  --with-buildlog
```

When finished, note the `.raw` (or similar) artifact in the build output directory.

### Option A — Image Builder uploads to AWS (recommended when AWS is configured)

Prerequisites: AWS credentials on the builder, writable S3 bucket, `vmimport` IAM role  
([AWS AMI chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)).

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10 \
  --aws-region us-east-2 \
  --aws-bucket <YOUR_BUCKET> \
  --aws-ami-name fedora-lane-rhel10-gold
```

Or upload an already-built file:

```bash
sudo image-builder upload ./*-ami-*.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket <YOUR_BUCKET> \
  --aws-ami-name fedora-lane-rhel10-gold
```

### Option B — Manual S3 + import-snapshot

Same as before: Console/CLI bucket, `aws s3 cp`, then import.  
[12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)

## 5) Gold image firewall note

Gold AMI firewall allows only **SSH 2222** and **httpd 35443**.  
Web Console stays closed on the gold image by design.  
Day-2 GUI: [docs/07-rhel10-web-console-demo.md](../docs/07-rhel10-web-console-demo.md)

## 6) Launch and verify

```bash
# After ami-… exists in EC2:
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

Test customizations: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)

```bash
cat /etc/redhat-release
# expect Red Hat Enterprise Linux release 10.x
```
