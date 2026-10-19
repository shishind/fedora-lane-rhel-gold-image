# Image Builder + AWS — copy-paste examples

All examples use the Fedora Lane blueprint and sample AWS values from this project.  
Replace region / bucket / AMI name if yours differ.

| Variable | Example value |
|----------|----------------|
| Blueprint | `./fedora-lane-gold.toml` |
| Distro | **exact** id from `image-builder list` (e.g. `rhel-10.0`, not `rhel-10`) |
| Region | `us-east-2` |
| S3 bucket | `fedora-lane-gold-1792315114` |
| AMI name | `fedora-lane-rhel10-gold` |
| Raw file (sample) | `d951ae1c-382e-47f1-9990-f89544935eb8-image.raw` |

Official: [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)

---

## 0) One-time setup on the RHEL 10 builder

```bash
# Image Builder
sudo dnf install -y image-builder cockpit-image-builder

# MUST see a line like: rhel-10.0 type:ami arch:x86_64
sudo image-builder list --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"

# Put that exact distro id in fedora-lane-gold.toml (distro = "rhel-10.0")
# If error "cannot find image for distro:rhel-10 type:ami" → 14-distro-ami-not-found.md

# AWS CLI identity (must succeed before upload)
export AWS_DEFAULT_REGION=us-east-2
aws sts get-caller-identity
```

Need an S3 bucket + `vmimport` role (see AWS doc chapter linked above).

---

## 1) Build only (local `.raw`, no AWS yet)

```bash
cd ~
# or: cd /path/to/fedora-lane-rhel-gold-image/image-builder

sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*ami*.raw ./*.raw 2>/dev/null
```

---

## 2) Build **and** upload to AWS in one command

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

When this finishes, open **EC2 → AMIs** in region `us-east-2` and look for `fedora-lane-rhel10-gold`.

---

## 3) Upload an **existing** `.raw` with Image Builder

Use this if you already built locally (or used `aws s3 cp` earlier and still have the file on disk).

```bash
# List what you have
ls -lh ./*ami*.raw ./*.raw 2>/dev/null

# Example with a known filename from a previous compose:
sudo image-builder upload \
  ./d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold

# Or glob if the name matches the usual pattern:
sudo image-builder upload ./*-ami-*.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold-$(date +%Y%m%d)
```

---

## 4) Azure stretch (same blueprint)

```bash
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

---

## 5) Manual path (if you are not using `image-builder upload`)

```bash
# Upload raw to the folder created in Console
aws s3 cp \
  ./d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/

aws s3 ls s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/
```

Then `import-snapshot` / `register-image` — full steps: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)

---

## 6) After the AMI exists — launch check

```bash
# From your laptop (SG must allow your IP on 2222)
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
curl -s http://127.0.0.1:35443/
```

Verification commands: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)
