# Publish the gold disk to AWS

After RHEL **Image Builder** (`image-builder`) produces an `ami`-type disk (often `.raw`), publish it to AWS as an **AMI**.

Official: [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)

Do **not** store Access Keys, Secret Keys, or session tokens in this Git repository.

## Preferred — Image Builder uploads for you

With AWS credentials configured on the builder, an S3 bucket, and the `vmimport` role:

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

Or upload an existing raw file:

```bash
sudo image-builder upload ./*-ami-*.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

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

## Part 5 — Import snapshot and register the AMI

The S3 object is storage only. EC2 boots from an **AMI**. Import needs the account **`vmimport`** IAM role (one-time setup per account).

```bash
BUCKET="fedora-lane-gold-1792315114"
S3_KEY="Fedora-Lane-Images/d951ae1c-382e-47f1-9990-f89544935eb8-image.raw"

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
  --description "Fedora Lane gold" \
  --disk-container file:///tmp/containers.json

aws ec2 describe-import-snapshot-tasks
# wait until Status=completed → note SnapshotId (snap-...)
```

Register the AMI from that snapshot, launch an EC2 web node, then verify SSH on **2222** and httpd on **35443**.  
Allow your admin IP in the security group for those ports.

**Prove every customization** with simple commands:  
[docs/08-verify-customizations.md](../docs/08-verify-customizations.md)

More detail: [06-rhel9-vsphere-steps.md](06-rhel9-vsphere-steps.md) (AWS upload section).

---

## Checklist

- [ ] AWS CLI installed on the RHEL builder  
- [ ] Credentials configured (`aws sts get-caller-identity` succeeds)  
- [ ] S3 bucket (+ folder) created in the Console  
- [ ] `.raw` uploaded with `aws s3 cp`  
- [ ] Snapshot imported and AMI registered  
- [ ] Test EC2 launched; SG allows your IP on 2222 + 35443  
- [ ] Customizations checked with commands in [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)  

---

## Related docs

- [05-local-ib-steps.md](05-local-ib-steps.md) — compose flow  
- [08-rhel10-rebuild.md](08-rhel10-rebuild.md) — RHEL 10 builder  
- [docs/08-verify-customizations.md](../docs/08-verify-customizations.md) — post-launch tests  
- [docs/solution-overview.md](../docs/solution-overview.md) — architecture for Fedora Lane  
