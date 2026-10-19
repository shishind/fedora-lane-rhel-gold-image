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

## 4) Azure (same blueprint) — see dedicated guides

```bash
df -h /var   # ≥ 15–20 GiB free
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

Full Azure publish (page blob → image → NSG → VM):  
[15-azure-vhd-upload.md](15-azure-vhd-upload.md) · [16-azure-examples.md](16-azure-examples.md)

---

## 5) Manual path — S3 → snapshot → AMI → launch

Use this when you already uploaded the `.raw` with `aws s3 cp` (not `image-builder upload`).

**CLI** commands are below. For the same flow in the **AWS Console** (Import snapshot → Create image → Security group → Launch), use [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md) Part 5 sections **5g–5j**.

```text
aws s3 cp .raw → S3
        ↓
aws ec2 import-snapshot  →  snap-…
        ↓
aws ec2 register-image   →  ami-…
        ↓
aws ec2 run-instances    →  PUBLIC_IP
        ↓
ssh -p 2222 fladmin1@PUBLIC_IP
```

### 5a) Upload `.raw` (if not done)

```bash
export AWS_DEFAULT_REGION=us-east-2
BUCKET=fedora-lane-gold-1792315114
S3_KEY=Fedora-Lane-Images/d951ae1c-382e-47f1-9990-f89544935eb8-image.raw

aws s3 cp \
  ./d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  "s3://${BUCKET}/Fedora-Lane-Images/"

aws s3 ls "s3://${BUCKET}/Fedora-Lane-Images/"
```

### 5b) Import snapshot

```bash
cat > /tmp/containers.json <<EOF
{
  "Description": "Fedora Lane RHEL 10 gold",
  "Format": "raw",
  "UserBucket": {
    "S3Bucket": "$BUCKET",
    "S3Key": "$S3_KEY"
  }
}
EOF

aws ec2 import-snapshot \
  --description "Fedora Lane RHEL 10 gold" \
  --disk-container file:///tmp/containers.json

# wait until completed
aws ec2 describe-import-snapshot-tasks --output table

SNAP_ID=$(aws ec2 describe-import-snapshot-tasks \
  --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId' --output text)
echo "SNAP_ID=$SNAP_ID"
```

### 5c) Create AMI from snapshot

```bash
AMI_ID=$(aws ec2 register-image \
  --name "fedora-lane-rhel10-gold-$(date +%Y%m%d)" \
  --description "Fedora Lane RHEL 10 gold web image" \
  --architecture x86_64 \
  --virtualization-type hvm \
  --ena-support \
  --root-device-name /dev/sda1 \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=${SNAP_ID},DeleteOnTermination=true,VolumeType=gp3}" \
  --query ImageId --output text)
echo "AMI_ID=$AMI_ID"
```

### 5d) Security group + launch

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[0].SubnetId' --output text)

SG_ID=$(aws ec2 create-security-group \
  --group-name fedora-lane-gold-sg \
  --description "Fedora Lane gold 2222+35443" \
  --vpc-id "$VPC_ID" --query GroupId --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters Name=group-name,Values=fedora-lane-gold-sg \
    --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 2222 --cidr "$MY_IP" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 35443 --cidr "$MY_IP" 2>/dev/null || true

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.medium \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fedora-lane-gold-test}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "PUBLIC_IP=$PUBLIC_IP"
```

### 5e) SSH (wait 2–5 min for first-boot)

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP
curl -s http://127.0.0.1:35443/
```

Full detail + troubleshooting: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)  
Verify customizations: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)
