# AWS only — configure access, create S3 bucket (console), upload `.raw` (CLI)

Use this after Image Builder finishes a compose and you have a disk file such as:

```text
d951ae1c-382e-47f1-9990-f89544935eb8-image.raw
```

Goal: put that gold disk into **S3**, then later import it as a snapshot → AMI → EC2.

```text
[ composer-cli compose image ] → .raw on builder
        ↓
[ AWS credentials configured ]
        ↓
[ Console: create S3 bucket (+ optional folder) ]
        ↓
[ CLI: aws s3 cp … .raw → s3://bucket/prefix/ ]
        ↓
[ Next: import-snapshot → register-image → launch ]
```

---

## Part 1 — Install AWS CLI (on the RHEL builder)

If `aws` is already installed, skip install:

```bash
# Official installer (as root or with sudo)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin

hash -r
/usr/local/bin/aws --version
# example: aws-cli/2.38.1 Python/3.14.6 Linux/... exe/x86_64.rhel.10
```

---

## Part 2 — Configure AWS access (credentials)

Use **temporary OPEN / RHDP sandbox** keys from the lab portal.  
**Never** commit keys to git.

### 2a. Get keys from the AWS / RHDP console

1. Open your lab AWS access page (RHDP OPEN / demo portal).  
2. Sign in to the **AWS Console** with the lab account.  
3. Copy (or create) credentials that include:

| Value | Env var |
|-------|---------|
| Access key ID | `AWS_ACCESS_KEY_ID` |
| Secret access key | `AWS_SECRET_ACCESS_KEY` |
| Session token (if temporary) | `AWS_SESSION_TOKEN` |
| Region (e.g. `us-east-2`) | `AWS_DEFAULT_REGION` |

### 2b. Put credentials on the builder

**Option A — environment variables (good for temporary lab keys):**

```bash
export AWS_ACCESS_KEY_ID="AKIA...or ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."          # required for many OPEN/temp keys
export AWS_DEFAULT_REGION="us-east-2"   # use YOUR lab region

aws sts get-caller-identity
```

`get-caller-identity` must print `Account`, `Arn`, `UserId`. If it fails, fix keys/region before creating buckets.

**Option B — `aws configure` (stores under `~/.aws/`):**

```bash
aws configure
# AWS Access Key ID
# AWS Secret Access Key
# Default region name  (e.g. us-east-2)
# Default output format  json

# If you have a session token:
aws configure set aws_session_token "$AWS_SESSION_TOKEN"

aws sts get-caller-identity
```

---

## Part 3 — Create the S3 bucket in the AWS Console

What we did in the lab: create the bucket (and folder) in the **console**, then upload with the **CLI**.

1. In AWS Console, open **S3**.  
2. Click **Create bucket**.  
3. **Bucket name** — globally unique, e.g. `fedora-lane-gold-1792315114`  
   (a timestamp suffix avoids “bucket already exists”).  
4. **AWS Region** — same region you will use for EC2 / import-snapshot (e.g. `us-east-2`).  
5. Leave defaults unless the lab says otherwise → **Create bucket**.  
6. Open the new bucket → **Create folder** (optional but useful), e.g. `Fedora-Lane-Images/`.  
7. Note for CLI:

```text
Bucket:  fedora-lane-gold-1792315114
Prefix:  Fedora-Lane-Images/
URI:     s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/
```

You can also create the bucket with CLI instead of console:

```bash
BUCKET="fedora-lane-gold-$(date +%s)"
aws s3 mb "s3://$BUCKET" --region "$AWS_DEFAULT_REGION"
echo "BUCKET=$BUCKET"
```

---

## Part 4 — Upload the Image Builder `.raw` with CLI

On the builder, go to the directory that has the compose output (often home or where `composer-cli compose image` wrote the file):

```bash
ls -lh *.raw
# example:
# d951ae1c-382e-47f1-9990-f89544935eb8-image.raw   (~12 GiB)
```

Upload into the bucket/folder from the console:

```bash
export AWS_DEFAULT_REGION="us-east-2"   # must match bucket region

/usr/local/bin/aws s3 cp \
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

A 12 GiB upload can take many minutes. Progress looks like:

```text
Completed 808.0 MiB/12.2 GiB (31.8 MiB/s) with 1 file(s) remaining
```

Wait until it finishes with no error. Verify:

```bash
aws s3 ls "s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/"
```

---

## Part 5 — Next (after upload completes)

Turn the S3 object into a snapshot, then an AMI. Needs the **`vmimport`** IAM role (one-time per account). See also [06-rhel9-vsphere-steps.md](06-rhel9-vsphere-steps.md) §5.

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
# wait until Status=completed → copy SnapshotId (snap-...)
```

Then `register-image` with that `snap-...` and launch EC2 (SSH **2222**, httpd **35443**).

---

## Checklist (what we actually did)

- [x] AWS CLI v2 installed on RHEL 10 builder (`/usr/local/bin/aws`)  
- [x] Credentials configured (`aws sts get-caller-identity` works)  
- [x] Logged into AWS Console → created S3 bucket (+ `Fedora-Lane-Images/` folder)  
- [x] `aws s3 cp <uuid>-image.raw s3://<bucket>/Fedora-Lane-Images/`  
- [ ] Wait for upload to 100%  
- [ ] `import-snapshot` → `register-image` → launch + verify  

---

## Related docs

- [05-local-ib-steps.md](05-local-ib-steps.md) — compose AMI/VHD  
- [08-rhel10-rebuild.md](08-rhel10-rebuild.md) — RHEL 10 builder  
- [11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md) — CDN / subscription  
- [docs/02-aws-build-commands.md](../docs/02-aws-build-commands.md) — longer AWS command reference  
