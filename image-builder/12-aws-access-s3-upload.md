# Publish the gold disk to AWS

After RHEL **Image Builder** (`image-builder`) produces an `ami`-type disk (often `.raw`), publish it to AWS as an **AMI**.

Official: [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)

Do **not** store Access Keys, Secret Keys, or session tokens in this Git repository.

## Preferred — Image Builder uploads for you

With AWS credentials configured on the builder, an S3 bucket, and the `vmimport` role.

**Example A — build and upload together:**

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

**Example B — upload a file you already composed:**

```bash
sudo image-builder upload \
  ./d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

**Example C — glob pattern if the name matches `*-ami-*.raw`:**

```bash
sudo image-builder upload ./*-ami-*.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

More examples: [13-image-builder-aws-examples.md](13-image-builder-aws-examples.md)

---

## Alternate — Console S3 + `aws s3 cp` + import-snapshot

Example compose output:

```text
d951ae1c-382e-47f1-9990-f89544935eb8-image.raw
```

```text
[ image-builder build ami → .raw ]
        ↓
[ Configure AWS credentials on the builder ]
        ↓
[ AWS Console: create S3 bucket (+ folder) ]
        ↓
[ CLI: aws s3 cp .raw → s3://bucket/prefix/ ]
        ↓
[ import-snapshot → register AMI → launch EC2 ]
```

---

## Part 1 — Install AWS CLI (on the RHEL builder host)

Skip if `aws --version` already works.

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin

hash -r
/usr/local/bin/aws --version
```

---

## Part 2 — Configure AWS access (credentials)

The builder host needs an IAM identity that can use **S3** (and later **EC2** import). Use credentials from your organization’s AWS account (IAM user access keys, or temporary credentials from your cloud team / identity provider).

### 2a. Obtain credentials

1. Sign in to the **AWS Management Console** for the Fedora Lane (or project) AWS account.  
2. Create or retrieve IAM credentials with permission to write to S3 in the target region.  
3. You need:

| Value | Environment variable |
|-------|----------------------|
| Access key ID | `AWS_ACCESS_KEY_ID` |
| Secret access key | `AWS_SECRET_ACCESS_KEY` |
| Session token (if using temporary credentials) | `AWS_SESSION_TOKEN` |
| Region (e.g. `us-east-2`) | `AWS_DEFAULT_REGION` |

### 2b. Apply credentials on the builder

**Option A — environment variables** (fits temporary credentials well):

```bash
export AWS_ACCESS_KEY_ID="AKIA...or ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."            # only if your credentials include a token
export AWS_DEFAULT_REGION="us-east-2"     # region where the bucket and AMI will live

aws sts get-caller-identity
```

**Option B — shared config file:**

```bash
aws configure
# Access Key ID / Secret Access Key / region / output = json

# If you have a session token:
aws configure set aws_session_token "$AWS_SESSION_TOKEN"

aws sts get-caller-identity
```

`get-caller-identity` must return `Account`, `Arn`, and `UserId` before you create buckets or upload.

---

## Part 3 — Create the S3 bucket in the AWS Console

Create storage in the **console**, then upload the large `.raw` with the **CLI**.

1. Open **S3** in the AWS Console.  
2. **Create bucket**.  
3. **Bucket name** — globally unique, for example `fedora-lane-gold-1792315114`.  
4. **AWS Region** — same region you will use for EC2 / snapshot import.  
5. Create the bucket (defaults are fine unless your security team requires specific encryption or blocking settings).  
6. Open the bucket → **Create folder**, for example `Fedora-Lane-Images/`.  
7. Record:

```text
Bucket:  fedora-lane-gold-1792315114
Prefix:  Fedora-Lane-Images/
URI:     s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/
```

CLI alternative:

```bash
BUCKET="fedora-lane-gold-$(date +%s)"
aws s3 mb "s3://$BUCKET" --region "$AWS_DEFAULT_REGION"
echo "BUCKET=$BUCKET"
```

---

## Part 4 — Upload the `.raw` with the AWS CLI

On the builder, in the directory that contains the compose output:

```bash
ls -lh *.raw
```

Upload into the bucket and folder:

```bash
export AWS_DEFAULT_REGION="us-east-2"   # must match the bucket region

aws s3 cp \
  d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/
```

Or with variables:

```bash
BUCKET="fedora-lane-gold-1792315114"
PREFIX="Fedora-Lane-Images"
IMAGE_FILE="d951ae1c-382e-47f1-9990-f89544935eb8-image.raw"

aws s3 cp "$IMAGE_FILE" "s3://${BUCKET}/${PREFIX}/"
```

Large images (about 12 GiB) take several minutes. Wait until the command exits successfully, then verify:

```bash
aws s3 ls "s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/"
```

---

## Part 5 — After `.raw` is in S3: snapshot → AMI → launch

S3 only stores the file. EC2 needs an **AMI**. Flow:

```text
S3 .raw  →  import-snapshot (snap-…)  →  register-image (ami-…)  →  run-instances  →  SSH :2222
```

Needs the account **`vmimport`** IAM role (one-time). If import fails with a role error, create `vmimport` per the [AWS AMI chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws).

Set examples (adjust names if yours differ):

```bash
export AWS_DEFAULT_REGION=us-east-2
BUCKET="fedora-lane-gold-1792315114"
S3_KEY="Fedora-Lane-Images/d951ae1c-382e-47f1-9990-f89544935eb8-image.raw"
aws sts get-caller-identity
```

### 5a) Import snapshot from S3

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
```

Watch until **completed** (can take 10–30+ minutes for a ~12 GiB image):

```bash
aws ec2 describe-import-snapshot-tasks \
  --query 'ImportSnapshotTasks[].{Status:SnapshotTaskDetail.Status,Progress:SnapshotTaskDetail.Progress,Snap:SnapshotTaskDetail.SnapshotId,Msg:SnapshotTaskDetail.StatusMessage}' \
  --output table

# when Status=completed, copy SnapshotId:
SNAP_ID=$(aws ec2 describe-import-snapshot-tasks \
  --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId' \
  --output text)
echo "SNAP_ID=$SNAP_ID"
# expect: snap-...
```

### 5b) Register AMI from the snapshot

```bash
AMI_NAME="fedora-lane-rhel10-gold-$(date +%Y%m%d)"

AMI_ID=$(aws ec2 register-image \
  --name "$AMI_NAME" \
  --description "Fedora Lane RHEL 10 gold web image" \
  --architecture x86_64 \
  --virtualization-type hvm \
  --ena-support \
  --boot-mode uefi-preferred \
  --root-device-name /dev/sda1 \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=${SNAP_ID},DeleteOnTermination=true,VolumeType=gp3}" \
  --query 'ImageId' \
  --output text)

echo "AMI_ID=$AMI_ID"
# expect: ami-...
```

If register fails on root device name, retry with `/dev/xvda` instead of `/dev/sda1`.  
If `--boot-mode` is rejected by older CLI, omit that flag.

### 5c) Security group (ports 2222 + 35443 for your IP)

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
echo "MY_IP=$MY_IP"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
echo "VPC_ID=$VPC_ID"

SG_ID=$(aws ec2 create-security-group \
  --group-name fedora-lane-gold-sg \
  --description "Fedora Lane gold SSH 2222 + httpd 35443" \
  --vpc-id "$VPC_ID" \
  --query GroupId --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters Name=group-name,Values=fedora-lane-gold-sg \
    --query 'SecurityGroups[0].GroupId' --output text)
echo "SG_ID=$SG_ID"

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 2222 --cidr "$MY_IP" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 35443 --cidr "$MY_IP" 2>/dev/null || true
```

If your IP changes later, add a new rule for the new `/32` or SSH will time out.

### 5d) Key pair for first boot (optional)

Gold image already has `fladmin1`/`fladmin2` SSH keys. You still need a subnet and instance type.  
If the account has no default key pair and you want one for console recovery, create it separately; day-2 login uses `fedora-lane-lab`.

### 5e) Launch EC2 from the AMI

```bash
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[0].SubnetId' --output text)
echo "SUBNET_ID=$SUBNET_ID"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.medium \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fedora-lane-gold-test}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
echo "INSTANCE_ID=$INSTANCE_ID"

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "PUBLIC_IP=$PUBLIC_IP"
```

Wait **2–5 minutes** for first-boot (Podman pull + httpd).

### 5f) SSH and verify

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP

# on the instance:
cat /etc/redhat-release
getenforce
curl -s http://127.0.0.1:35443/
sudo firewall-cmd --list-ports
```

From your laptop (SG must allow 35443):

```bash
curl -s http://$PUBLIC_IP:35443/
```

Full check list: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)

---

## Checklist

- [ ] AWS CLI installed on the RHEL builder  
- [ ] Credentials configured (`aws sts get-caller-identity` succeeds)  
- [ ] S3 bucket (+ folder) created; `.raw` uploaded  
- [ ] `import-snapshot` completed → `snap-…`  
- [ ] `register-image` → `ami-…`  
- [ ] Security group allows **your IP** on **2222** and **35443**  
- [ ] EC2 launched; SSH as `fladmin1` on port 2222  
- [ ] Customizations verified  

---

## Related docs

- [13-image-builder-aws-examples.md](13-image-builder-aws-examples.md) — build/upload examples  
- [05-local-ib-steps.md](05-local-ib-steps.md) — compose flow  
- [08-rhel10-rebuild.md](08-rhel10-rebuild.md) — RHEL 10 builder  
- [docs/08-verify-customizations.md](../docs/08-verify-customizations.md) — post-launch tests  
- [docs/solution-overview.md](../docs/solution-overview.md) — architecture for Fedora Lane  
