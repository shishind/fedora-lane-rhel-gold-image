# Image Builder + AWS — copy-paste examples

Copy-paste examples for your AWS account.  
Replace region, bucket, and names with your own values.

| Variable | Example value |
|----------|----------------|
| Blueprint | `./fedora-lane-gold.toml` |
| Distro | **exact** id from `image-builder list` (e.g. `rhel-10.0`, not `rhel-10`) |
| Region | `us-east-2` |
| S3 bucket | `YOUR_S3_BUCKET` |
| AMI name | `fedora-lane-rhel10-gold` |
| Raw file (example) | `rhel-10.0-ami-x86_64.raw` |
| AMI (example) | `ami-xxxxxxxxxxxxxxxxx` |
| Snapshot (example) | `snap-xxxxxxxxxxxxxxxxx` |

**Official Red Hat:**

- [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)  
- [Deploying a RHEL image as an EC2 instance on AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_amazon_web_services/deploying-a-rhel-image-as-an-ec2-instance-on-aws)  
- [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

Commands below match RH’s `image-builder build ami … --aws-*` and `image-builder upload … --to=aws` forms.

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
  --aws-bucket YOUR_S3_BUCKET \
  --aws-ami-name fedora-lane-rhel10-gold
```

When this finishes, open **EC2 → AMIs** in region `us-east-2` and look for `fedora-lane-rhel10-gold`.

---

## 3) Upload an **existing** `.raw` with Image Builder (preferred)

**This one command uploads to S3, creates the snapshot, registers the AMI, then deletes the S3 object.**  
No separate `aws s3 cp` / `import-snapshot` / `register-image` needed.

### Example — upload an existing disk image

```bash
ls -lh ./*ami*.raw ./*.raw rhel-10.0-ami-x86_64.raw 2>/dev/null

sudo image-builder upload \
  rhel-10.0-ami-x86_64.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket YOUR_S3_BUCKET \
  --aws-ami-name fedora-lane-rhel10-gold \
  --arch x86_64
```

What you should see at the end:

```text
AMI registered: ami-…
Snapshot ID: snap-…
Deleted S3 object …
```

When it finishes, note the printed `ami-…` and `snap-…` (use your account region).

Then open **EC2 → AMIs** (Owned by me) and launch with SG ports **2222** and **35443**.

### Glob / dated AMI name

```bash
sudo image-builder upload ./*-ami-*.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket YOUR_S3_BUCKET \
  --aws-ami-name fedora-lane-rhel10-gold-$(date +%Y%m%d) \
  --arch x86_64
```

---

## 4) Azure (same blueprint) — see dedicated guides

```bash
df -h /var   # ≥ 15–20 GiB free
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

# Preferred push (mirrors AWS upload):
# sudo image-builder upload ./*.vhd --to=azure \
#   --azure-tenant … --azure-subscription … \
#   --azure-client-id … --azure-client-secret … \
#   --azure-resource-group … --azure-image-name …
```

Full Azure publish (`image-builder upload --to=azure` or page-blob alternate):  
[15-azure-vhd-upload.md](15-azure-vhd-upload.md) · [16-azure-examples.md](16-azure-examples.md)

---

## 5) Manual path — only if `image-builder upload` is not used

Prefer §3 above. Use this when you uploaded with `aws s3 cp` yourself and must finish import manually.

**CLI** below. Console: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md) Part 5 **5g–5j**.

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
BUCKET=YOUR_S3_BUCKET
S3_KEY=Fedora-Lane-Images/YOUR-DISK.raw

aws s3 cp \
  ./YOUR-DISK.raw \
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
