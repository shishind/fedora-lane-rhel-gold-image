# Local Image Builder — easy steps (TOML → AWS AMI + Azure VHD)

You confirmed: **local Image Builder + TOML is OK**.

Mac only edits files. Builds run on a **RHEL** machine (Image Builder does not run on macOS).

```text
[ Mac: edit TOML ]
       ↓
[ RHEL "builder host" with osbuild-composer ]
       ↓
  compose type ami  → upload/register on AWS OPEN
  compose type vhd  → upload on Azure OPEN (stretch)
       ↓
[ Launch VM from that image → verify after reboot ]
```

Lab sudo password (for demo): **`RedHat`**  
SSH key already embedded: your `fedora-lane-lab` public key.

---

## Step 1 — Launch a RHEL builder host (AWS OPEN)

This host **builds** images. It is not the gold web server itself.

Use the same VPC/SG/key you already created (`us-east-2`), or recreate if expired.

```bash
export AWS_DEFAULT_REGION=us-east-2
# reuse your earlier VPC_ID SUBNET_ID SG_ID AMI_ID KEY if still set

aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.xlarge \
  --key-name fedora-lane-builder \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":60,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fedora-lane-image-builder}]' \
  --query 'Instances[0].InstanceId' --output text
```

**Why t3.xlarge + 60 GB?** Image composition needs CPU/RAM/disk.

SSH in as `ec2-user` (or `cloud-user`), then register RHEL if needed (RHDP images usually already work with repos).

---

## Step 2 — Install local Image Builder on that RHEL host

```bash
sudo dnf -y install osbuild-composer composer-cli cockpit-composer \
  genisoimage weldr-client
sudo systemctl enable --now osbuild-composer.socket
sudo usermod -aG weldr "$USER"
getent group weldr
```

**Log out and SSH back in** (so `weldr` group applies).  
Do **not** skip this — otherwise `composer-cli` fails with:

`you do not have permission to access /run/weldr/api.socket`

Quick same-session workaround: `newgrp weldr`

Then:

```bash
id | grep weldr
composer-cli status
composer-cli distros list
composer-cli compose types
```

You should see `ami` and `vhd` (or `vhd` / Azure-related types) in the list.

Full troubleshooting: [09-weldr-permission-fix.md](09-weldr-permission-fix.md)

---

## Step 3 — Copy the TOML from your Mac

**On Mac:**

```bash
export BUILDER_IP=PASTE_BUILDER_PUBLIC_IP

scp -i ~/.ssh/fedora-lane-builder.pem \
  ~/Projects/fedora-lane-rhel-gold-image/image-builder/fedora-lane-gold.toml \
  ec2-user@$BUILDER_IP:~/
```

**On builder host:**

```bash
composer-cli blueprints push ~/fedora-lane-gold.toml
composer-cli blueprints list
composer-cli blueprints show fedora-lane-gold
composer-cli blueprints depsolve fedora-lane-gold
```

If `depsolve` errors on **CDN / repomd.xml / RepoError**, the builder is not
subscribed or cannot reach `cdn.redhat.com` — see
[11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md).  
Other depsolve errors are often package/name issues in the TOML.

---

## Step 4 — Build the AWS image (`ami`)

```bash
composer-cli compose start fedora-lane-gold ami
# prints: Compose started: <UUID>
```

Watch progress:

```bash
watch -n 30 'composer-cli compose status'
```

When status is **FINISHED**:

```bash
COMPOSE_ID=PASTE_UUID
mkdir -p ~/images && cd ~/images
composer-cli compose image "$COMPOSE_ID"
ls -lh
```

You get an AMI-related artifact (often `.raw` or instructions file depending on version). Follow RHEL “upload AMI” for your composer version, **or** use:

```bash
# If composer produced a file usable with AWS import — typical pattern:
# upload to S3 → ec2 import-snapshot / import-image → register AMI
```

**AWS access + Console S3 bucket + CLI upload of `.raw`:**  
[12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)

Example (what we ran on the RHEL 10 builder after creating the bucket in Console):

```bash
aws s3 cp \
  d951ae1c-382e-47f1-9990-f89544935eb8-image.raw \
  s3://fedora-lane-gold-1792315114/Fedora-Lane-Images/
```

Many RHEL versions also support uploading via `composer-cli compose image` + AWS CLI upload scripts in the docs. If your output is `*.ami` or includes upload metadata, use that.

**Simpler RHDP pattern many cohorts use:**  
After compose finishes, follow [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md). If stuck, paste `ls -lh ~/images` and `composer-cli compose status`.

---

## Step 5 — Build Azure image (stretch)

```bash
composer-cli compose start fedora-lane-gold vhd
# wait FINISHED
composer-cli compose image AZURE_COMPOSE_UUID
```

Upload the VHD to Azure OPEN (stretch goal #2).

---

## Step 6 — Launch from your gold AMI and prove

Security group: allow **2222** and **35443** from your IP only.

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$GOLD_IP
```

First boot may take a few minutes (pulls container image). Then:

```bash
getenforce
findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp
sudo ss -tlnp | egrep '2222|35443'
curl -s http://127.0.0.1:35443/
sudo -k; sudo id   # password: RedHat
sudo reboot
# reconnect and re-check
```

---

## Step 7 — Repo docs for Part 1

Keep in GitHub (private + `mflaim-eng`):

- `image-builder/fedora-lane-gold.toml`
- this steps file
- `docs/solution-overview.md` (update to say “local Image Builder + TOML”)
- verify notes / screenshots (no secrets)

---

## Why this meets the brief

| Requirement | How |
|-------------|-----|
| Manual / not **hosted** IB | Local `osbuild-composer` + your TOML |
| AWS or Azure | `ami` + `vhd` from same blueprint |
| Partitions / SELinux / ports / users / firewall / container httpd | TOML + first-boot script |
| Prove on cloud VM | Launch from uploaded image |
| Survive reboot | systemd first-boot + container unit |

---

## Do this next (only Step 1–2)

1. Launch the **image-builder** RHEL EC2 (`t3.xlarge`, 60 GB).  
2. Install `osbuild-composer` / `composer-cli`.  
3. Reply with: builder `PUBLIC_IP` + output of `composer-cli compose types`.

Then we push the TOML and start the `ami` compose together.
