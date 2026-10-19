# Local Image Builder on RHEL 9 (vSphere) — step by step

Build host = your **vSphere RHEL 9** machine.  
Mac = edit files / git only.  
Cloud = upload `ami` / `vhd` and demo.

Lab sudo password (in blueprint): `RedHat`  
SSH key already in TOML: your `fedora-lane-lab` public key.

---

## 0) Check the RHEL 9 VM

On the vSphere RHEL 9 box:

```bash
cat /etc/redhat-release
# expect: Red Hat Enterprise Linux release 9.x

free -h
df -h /
# aim for: 8GB+ RAM, 40GB+ free disk

subscription-manager status
sudo dnf repolist
```

If `dnf` cannot see BaseOS/AppStream, fix subscription first (RHSM / activation key). Image Builder needs repos.

---

## 1) Install Image Builder (RHEL 9)

```bash
sudo dnf -y install osbuild-composer composer-cli cockpit-composer \
  genisoimage weldr-client qemu-img

sudo systemctl enable --now osbuild-composer.socket
sudo systemctl status osbuild-composer.socket --no-pager

sudo usermod -aG weldr $USER
```

**Log out completely and SSH/console back in**, then:

```bash
id | grep weldr
composer-cli status
composer-cli compose types
```

Confirm you see at least:

- `ami` (AWS)
- `vhd` (Azure) — name may appear as `vhd` on RHEL 9

---

## 2) Copy the blueprint from your Mac

**On Mac:**

```bash
scp ~/Projects/fedora-lane-rhel-gold-image/image-builder/fedora-lane-gold.toml \
  YOURUSER@VSPHERE_RHEL_IP:~/
```

**On RHEL 9:**

```bash
ls -l ~/fedora-lane-gold.toml
```

---

## 3) Push and validate the TOML

```bash
composer-cli blueprints push ~/fedora-lane-gold.toml
composer-cli blueprints list
composer-cli blueprints show fedora-lane-gold
composer-cli blueprints depsolve fedora-lane-gold
```

- `depsolve` must succeed before compose.  
- If it fails, paste the error (usually package/name or TOML syntax).

To change the blueprint later: edit TOML → bump `version` (e.g. `0.0.3`) → `push` again.

---

## 4) Compose AWS image (`ami`)

```bash
composer-cli compose start fedora-lane-gold ami
# note the UUID printed
```

Watch:

```bash
composer-cli compose status
# or:
watch -n 20 composer-cli compose status
```

When **FINISHED**:

```bash
COMPOSE_ID=PASTE-UUID-HERE
mkdir -p ~/images && cd ~/images
composer-cli compose image "$COMPOSE_ID"
ls -lh
```

You typically get a large image file (often `.raw` or similar depending on version/plugins). Keep the filename for upload.

If status is **FAILED**:

```bash
composer-cli compose log "$COMPOSE_ID" | tail -100
```

---

## 5) Upload AMI to AWS (OPEN env)

On a machine with AWS CLI + working OPEN credentials (Mac or the RHEL 9 host):

```bash
export AWS_DEFAULT_REGION=us-east-2   # or your RHDP region
aws sts get-caller-identity
```

### Typical RHEL 9 flow: raw → S3 → snapshot → register AMI

```bash
# 1) bucket (name must be globally unique)
BUCKET="fedora-lane-gold-$(date +%s)"
aws s3 mb "s3://$BUCKET" --region "$AWS_DEFAULT_REGION"

# 2) upload the composed file (adjust filename from ls)
IMAGE_FILE=~/images/YOUR-COMPOSE-FILE.raw
aws s3 cp "$IMAGE_FILE" "s3://$BUCKET/fedora-lane-gold.raw"
```

`containers.json`:

```bash
cat > /tmp/containers.json <<EOF
{
  "Description": "Fedora Lane RHEL gold",
  "Format": "raw",
  "UserBucket": {
    "S3Bucket": "$BUCKET",
    "S3Key": "fedora-lane-gold.raw"
  }
}
EOF
```

```bash
aws ec2 import-snapshot \
  --description "Fedora Lane gold" \
  --disk-container file:///tmp/containers.json

# wait until completed — note SnapshotId
aws ec2 describe-import-snapshot-tasks
```

```bash
SNAP_ID=snap-PASTE
aws ec2 register-image \
  --name "fedora-lane-rhel-gold-$(date +%Y%m%d)" \
  --architecture x86_64 \
  --virtualization-type hvm \
  --ena-support \
  --root-device-name /dev/sda1 \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=$SNAP_ID,DeleteOnTermination=true,VolumeType=gp3}"
```

Note the returned `ami-...`.

> If your compose output format is not `raw`, change `"Format"` (e.g. `vmdk`) to match.  
> If register fails on root device name, try `/dev/xvda`.

---

## 6) Launch gold VM on AWS and prove

Reuse your security group that allows **2222** and **35443** from your IP.

```bash
# launch from GOLD_AMI, note PUBLIC_IP
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP
```

First boot runs `fedora-lane-firstboot.service` (SELinux ports + Podman httpd). Wait 2–5 minutes, then:

```bash
getenforce
findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp
curl -s http://127.0.0.1:35443/
sudo ss -tlnp | egrep '2222|35443'
sudo -k; sudo id    # password: RedHat
sudo reboot
```

After reboot, re-check curl and mounts.

Optional: copy `verify/verify.sh` to the instance and run it.

---

## 7) Azure stretch (same blueprint)

On RHEL 9 builder:

```bash
composer-cli compose start fedora-lane-gold vhd
# wait FINISHED
composer-cli compose image AZURE-UUID
```

Upload the VHD to Azure Blank OPEN and create a VM from it (stretch goal #2).

---

## Quick command cheat sheet

```bash
composer-cli blueprints push ~/fedora-lane-gold.toml
composer-cli blueprints depsolve fedora-lane-gold
composer-cli compose start fedora-lane-gold ami
composer-cli compose status
composer-cli compose image <UUID>
composer-cli compose log <UUID>
```

---

## Do now

1. On vSphere RHEL 9 → finish **Step 1** (install + `composer-cli compose types`)  
2. **Step 2–3** (copy + push + depsolve)  
3. Paste back:
   - `cat /etc/redhat-release`
   - `composer-cli compose types` (short list)
   - result of `depsolve` (OK or error text)
