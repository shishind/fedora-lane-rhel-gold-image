# Technical Build Guide — RHEL Gold Image → AWS AMI

> Do **not** use the hosted Image Builder service. Build manually, then import/register as an AMI.  
> Never commit AWS keys or private SSH keys.

Assumptions:

- Builder host: RHEL 9 or RHEL 10 (EC2 or on-prem)
- Target: **AWS**
- You have `sudo` and Red Hat repository access on the builder

Replace placeholders:

- `YOUR_PUBKEY` — your SSH public key
- `REGION` — e.g. `us-east-1`
- `BUCKET` — your S3 bucket name

---

## 0) Prep on your laptop

```bash
# Optional: generate an admin keypair for fladmins
ssh-keygen -t ed25519 -f ~/.ssh/fedora-lane-lab -C "fedora-lane-lab" -N ""

# Show public key (paste into admin authorized_keys / blueprint)
cat ~/.ssh/fedora-lane-lab.pub
```

Install AWS CLI where you will run import commands (builder host or operator workstation).

```bash
aws --version
aws sts get-caller-identity   # proves creds work — do not save output in git
```

---

## 1) Install OS and create partitions

### Option A — during interactive Anaconda install

Create custom partitioning with separate filesystems (each **under 5 GiB** for this scenario):

| Mount     | Suggested size | FS   |
|-----------|----------------|------|
| `/`       | 15–20 GiB      | xfs  |
| `/boot`   | 1 GiB          | xfs  |
| `/var/log`| 2 GiB          | xfs  |
| `/home`   | 2 GiB          | xfs  |
| `/tmp`    | 2 GiB          | xfs  |
| `/var/tmp`| 2 GiB          | xfs  |
| `swap`    | 2 GiB          | swap |

### Option B — after minimal install (LVM example)

```bash
# Inspect disks
lsblk
sudo vgs
sudo lvs

# Example: grow VG / create LVs (adjust disk/VG names to match YOUR system)
# WARNING: destructive if wrong — verify names first

sudo lvcreate -L 2G -n var_log   YOUR_VG
sudo lvcreate -L 2G -n home      YOUR_VG
sudo lvcreate -L 2G -n tmp       YOUR_VG
sudo lvcreate -L 2G -n var_tmp   YOUR_VG

sudo mkfs.xfs /dev/YOUR_VG/var_log
sudo mkfs.xfs /dev/YOUR_VG/home
sudo mkfs.xfs /dev/YOUR_VG/tmp
sudo mkfs.xfs /dev/YOUR_VG/var_tmp

# Temporary mount to migrate data if directories already have content
sudo mkdir -p /mnt/{var_log,home,tmp,var_tmp}
sudo mount /dev/YOUR_VG/var_log /mnt/var_log
sudo mount /dev/YOUR_VG/home    /mnt/home
sudo mount /dev/YOUR_VG/tmp     /mnt/tmp
sudo mount /dev/YOUR_VG/var_tmp /mnt/var_tmp

sudo rsync -aHAX /var/log/ /mnt/var_log/
sudo rsync -aHAX /home/    /mnt/home/
# /tmp and /var/tmp can stay empty

sudo umount /mnt/{var_log,home,tmp,var_tmp}
```

Add to `/etc/fstab` (use UUIDs from `blkid`):

```bash
sudo blkid /dev/YOUR_VG/var_log
sudo blkid /dev/YOUR_VG/home
sudo blkid /dev/YOUR_VG/tmp
sudo blkid /dev/YOUR_VG/var_tmp
```

Example `/etc/fstab` lines:

```fstab
UUID=xxxx  /var/log  xfs  defaults        0 0
UUID=yyyy  /home     xfs  defaults        0 0
UUID=zzzz  /tmp      xfs  defaults,nodev,nosuid,noexec  0 0
UUID=wwww  /var/tmp  xfs  defaults,nodev,nosuid         0 0
```

```bash
sudo mount -a
findmnt /var/log /home /tmp /var/tmp
```

---

## 2) Base update + SELinux enforcing

```bash
sudo dnf -y update
sudo setenforce 1
getenforce   # must show Enforcing

sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
grep ^SELINUX= /etc/selinux/config
```

---

## 3) `/tmp` non-executable

Ensure fstab has `noexec` on `/tmp`, then:

```bash
sudo mount -o remount /tmp
findmnt -no OPTIONS /tmp | tr ',' '\n' | grep noexec
# must print: noexec
```

---

## 4) Fedora Lane admin users + sudo (password required)

```bash
sudo groupadd fladmins

# Create admins (set passwords interactively — needed for sudo prompts)
sudo useradd -m -G fladmins -s /bin/bash fladmin1
sudo useradd -m -G fladmins -s /bin/bash fladmin2
sudo passwd fladmin1
sudo passwd fladmin2

# SSH keys (password SSH will be disabled later)
sudo mkdir -p /home/fladmin1/.ssh /home/fladmin2/.ssh
echo 'YOUR_PUBKEY' | sudo tee /home/fladmin1/.ssh/authorized_keys >/dev/null
echo 'YOUR_PUBKEY' | sudo tee /home/fladmin2/.ssh/authorized_keys >/dev/null
sudo chmod 700 /home/fladmin{1,2}/.ssh
sudo chmod 600 /home/fladmin{1,2}/.ssh/authorized_keys
sudo chown -R fladmin1:fladmin1 /home/fladmin1/.ssh
sudo chown -R fladmin2:fladmin2 /home/fladmin2/.ssh
```

Sudoers drop-in (**no NOPASSWD**):

```bash
echo '%fladmins ALL=(ALL) ALL' | sudo tee /etc/sudoers.d/fladmins
sudo chmod 440 /etc/sudoers.d/fladmins
sudo visudo -cf /etc/sudoers.d/fladmins
```

Verify as `fladmin1`:

```bash
su - fladmin1
sudo -k
sudo id    # must prompt for password
```

---

## 5) SSH on port 2222 + harden

```bash
sudo dnf -y install policycoreutils-python-utils

# SELinux: label TCP 2222 as ssh
sudo semanage port -a -t ssh_port_t -p tcp 2222 2>/dev/null || \
  sudo semanage port -m -t ssh_port_t -p tcp 2222

sudo semanage port -l | grep ssh
```

Create drop-in config:

```bash
sudo tee /etc/ssh/sshd_config.d/99-fedora-lane.conf >/dev/null <<'EOF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
EOF

sudo sshd -t
sudo systemctl restart sshd
sudo systemctl enable sshd
```

**Keep your current session open.** Test from another terminal:

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@BUILDER_IP
```

Only after that works, you may close port 22 in firewall (next section).

---

## 6) firewalld — only SSH 2222 and httpd 35443

```bash
sudo dnf -y install firewalld
sudo systemctl enable --now firewalld

sudo firewall-cmd --permanent --remove-service=ssh 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --permanent --add-port=35443/tcp

# Remove extras if present
sudo firewall-cmd --permanent --remove-service=cockpit 2>/dev/null || true
sudo firewall-cmd --permanent --remove-service=http 2>/dev/null || true
sudo firewall-cmd --permanent --remove-service=https 2>/dev/null || true

sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

---

## 7) httpd in a Podman container on port 35443

```bash
sudo dnf -y install podman container-selinux

# SELinux: allow http on 35443
sudo semanage port -a -t http_port_t -p tcp 35443 2>/dev/null || \
  sudo semanage port -m -t http_port_t -p tcp 35443

sudo mkdir -p /opt/fedora-lane/www
echo '<html><body><h1>Fedora Lane e-commerce web — httpd OK</h1></body></html>' | \
  sudo tee /opt/fedora-lane/www/index.html

# Pull and run (UBI httpd preferred when available; docker.io httpd works for lab)
sudo podman pull registry.access.redhat.com/ubi9/httpd-24 || \
  sudo podman pull docker.io/library/httpd:2.4
```

If using **UBI httpd**:

```bash
sudo podman run -d --name fl-httpd \
  --restart=always \
  -p 35443:8080 \
  -v /opt/fedora-lane/www:/var/www/html:Z \
  registry.access.redhat.com/ubi9/httpd-24
```

If using **docker.io httpd** (port 80 inside container):

```bash
sudo podman run -d --name fl-httpd \
  --restart=always \
  -p 35443:80 \
  -v /opt/fedora-lane/www:/usr/local/apache2/htdocs:Z \
  docker.io/library/httpd:2.4
```

Generate systemd unit so it survives reboot:

```bash
cd /tmp
sudo podman generate systemd --new --name fl-httpd --files
sudo cp /tmp/container-fl-httpd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now container-fl-httpd.service

curl -sI http://127.0.0.1:35443/ | head
curl -s http://127.0.0.1:35443/
```

> Note: with `--new`, Podman recreates the container from the unit on each start. Ensure the unit embeds the same `podman run` flags (ports, volume). Re-generate after you finalize the run command.

---

## 8) Cloud-prep packages (important for AWS boot)

```bash
sudo dnf -y install cloud-init cloud-utils-growpart gdisk

# Ensure DHCP networking (NetworkManager)
sudo nmcli -t -f NAME,DEVICE,TYPE con show
# Prefer a single DHCP ethernet connection for eth0/ens5

# Add AWS-friendly drivers into initramfs (critical before export)
sudo dracut -f --add-drivers "nvme xen-netfront xen-blkfront ena"

# Clean machine-specific bits carefully
sudo cloud-init clean --logs || true
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Remove builder SSH host keys (regenerated on first boot by cloud-init/ssh)
sudo rm -f /etc/ssh/ssh_host_*

# Clear history / temp (do not delete your admin authorized_keys)
history -c
sudo rm -rf /tmp/* /var/tmp/*
sudo dnf clean all
```

Power off when ready to snapshot/export:

```bash
sudo sync
sudo poweroff
```

---

## 9) Export disk and import as AWS AMI

Exact export depends on where you built:

### If builder is KVM/qcow2 on a host you control

```bash
# Convert qcow2 → raw
qemu-img convert -f qcow2 -O raw fedora-lane-gold.qcow2 fedora-lane-gold.raw

# Upload
aws s3 mb s3://BUCKET --region REGION
aws s3 cp fedora-lane-gold.raw s3://BUCKET/fedora-lane-gold.raw
```

`containers.json`:

```json
{
  "Description": "Fedora Lane RHEL gold image",
  "Format": "raw",
  "UserBucket": {
    "S3Bucket": "BUCKET",
    "S3Key": "fedora-lane-gold.raw"
  }
}
```

Import snapshot + register AMI:

```bash
aws ec2 import-snapshot \
  --region REGION \
  --description "Fedora Lane RHEL gold" \
  --disk-container file://containers.json

# Wait until status completed, note SnapshotId
aws ec2 describe-import-snapshot-tasks --region REGION

aws ec2 register-image \
  --region REGION \
  --name "fedora-lane-rhel-gold-$(date +%Y%m%d)" \
  --architecture x86_64 \
  --virtualization-type hvm \
  --ena-support \
  --root-device-name /dev/sda1 \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=snap-XXXXXXXX,DeleteOnTermination=true,VolumeType=gp3}"
```

> Root device name may be `/dev/xvda` or `/dev/sda1` depending on image layout — match what AWS docs / import result expect. Adjust if the instance fails to boot.

### Alternative: `aws ec2 import-image`

```bash
aws ec2 import-image \
  --region REGION \
  --description "Fedora Lane RHEL gold" \
  --license-type BYOL \
  --disk-containers file://containers.json

aws ec2 describe-import-image-tasks --region REGION
```

### If building inside EC2 already

You can skip file import and **create an AMI from the stopped builder instance**:

```bash
# On AWS console or CLI — after all hardening, STOP the instance
INSTANCE_ID=i-xxxxxxxx

aws ec2 create-image \
  --region REGION \
  --instance-id "$INSTANCE_ID" \
  --name "fedora-lane-rhel-gold-$(date +%Y%m%d)" \
  --description "Fedora Lane e-commerce web gold image" \
  --no-reboot
```

A valid manual path: configure the instance by hand, then `create-image`. Avoid the **hosted** Image Builder cloud service — creating an AMI from a configured VM is fine.

---

## 10) Launch from AMI and prove requirements

Security group:

- Inbound TCP **2222** from your IP
- Inbound TCP **35443** from your IP
- No other inbound

```bash
AMI_ID=ami-xxxxxxxx
SG_ID=sg-xxxxxxxx
SUBNET_ID=subnet-xxxxxxxx
KEY_NAME=your-existing-key   # optional if keys baked into image

aws ec2 run-instances \
  --region REGION \
  --image-id "$AMI_ID" \
  --instance-type t3.medium \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fedora-lane-gold-test}]'
```

Connect and verify:

```bash
PUBLIC_IP=x.x.x.x
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP

# On the instance:
curl -s http://127.0.0.1:35443/
getenforce
findmnt /tmp
sudo ss -tlnp | egrep '2222|35443'
sudo firewall-cmd --list-all

# Prove reboot persistence
sudo reboot
# reconnect after ~60s and re-check curl + services
```

From your laptop:

```bash
curl -sI http://$PUBLIC_IP:35443/
ssh -p 22 fladmin1@$PUBLIC_IP     # should FAIL
ssh -p 2222 root@$PUBLIC_IP       # should FAIL
```

---

## 11) Stretch — OpenSCAP (optional)

```bash
sudo dnf -y install openscap-scanner scap-security-guide

oscap info /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml | less
# Pick a profile, e.g. cis

sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results /tmp/scap-results.xml \
  --report /tmp/scap-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Remediations are powerful — apply carefully, then re-test SSH/httpd
```

Copy the HTML report out for your repo **docs/** (no secrets).
