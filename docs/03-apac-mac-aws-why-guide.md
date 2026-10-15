# APAC Junior Consultant Guide — Mac + AWS (with WHY)

**Your geo:** APAC  
**Part 1 due:** ~**19 Oct** (recording + repo + docs in the Google form; topic = Server/Cloud OS TDP)  
**Part 2 live:** **22 Oct** (PODs 1, 3, 5) or **23 Oct** (PODs 2, 4, 6) — check your calendar title `Server/Cloud OS TDP Practice Activity Part 2`

This guide assumes:

- You work on a **Mac**
- You have **AWS access** (RHDP AWS Blank OPEN **or** a company/lab AWS account)
- You will build a **manual RHEL gold image** (no hosted Image Builder), turn it into an **AMI**, launch EC2, and **prove** the specs

---

## Big picture — what are we building and why?

Fedora Lane’s e-commerce web servers are inconsistent, hard to audit, and awkward for containers. You build **one hardened RHEL “gold” AMI** so every new web server boots the same way.

| Customer challenge | What your AMI proves |
|--------------------|----------------------|
| Mixed OS + config drift | One RHEL standard image |
| Undocumented admin changes / long outages | Hardened identity + known-good baseline |
| Ops can’t manage containers | httpd in Podman as a systemd service |

**Why build on EC2 from a Mac (recommended)?**  
Macs don’t run RHEL natively like a server. The reliable FASTER path is:

1. From your Mac → launch a **RHEL EC2 builder**
2. SSH in → harden it **by hand** (the “manual gold image”)
3. Create an **AMI** from that instance
4. Launch a **new** EC2 from the AMI and re-verify (proves the gold image, not just one snowflake VM)

That satisfies “manual, not hosted Image Builder” while using AWS access you already have.

```text
[ Mac ] --AWS CLI/Console--> [ EC2 builder: harden RHEL ]
                                    |
                              create-image (AMI)
                                    |
                              [ EC2 test from AMI ] --> demo + verify.sh
```

---

## Phase A — Mac setup (tools)

### A1. Install Homebrew tools

**Why:** Your Mac needs AWS CLI to create/launch AMIs, and GitHub CLI (`gh`) to create a **private** repo and invite `mflaim-eng`.

```bash
# Install Homebrew if missing: https://brew.sh
brew install awscli gh git

aws --version
gh --version
git --version
```

### A2. Configure AWS credentials

**Why:** Commands like `run-instances` and `create-image` need an identity. Prefer temporary RHDP/OPEN credentials; **never commit them**.

```bash
# Option 1: interactive
aws configure
# Access Key, Secret, region (e.g. ap-southeast-1 or us-east-1), output=json

# Option 2: env vars from RHDP (example names — use what the portal gives you)
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."   # if temporary
export AWS_DEFAULT_REGION="ap-southeast-1"

aws sts get-caller-identity   # must succeed
```

**Why `get-caller-identity` first?**  
Fails fast if keys/region are wrong before you spend time launching VMs.

### A3. SSH key for Fedora Lane admins

**Why:** Spec disables SSH password login. Without a public key on the instance, you lock yourself out.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/fedora-lane-lab -C "fedora-lane-apac" -N ""
cat ~/.ssh/fedora-lane-lab.pub
```

Also create (or reuse) an **AWS key pair** for the *first* builder login (AWS injects it for `ec2-user` / `cloud-user`):

```bash
aws ec2 create-key-pair \
  --key-name fedora-lane-builder \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/fedora-lane-builder.pem
chmod 400 ~/.ssh/fedora-lane-builder.pem
```

**Why two keys?**  
- `fedora-lane-builder.pem` → get into the fresh RHEL AMI as the default cloud user  
- `fedora-lane-lab` → baked into `fladmin1`/`fladmin2` for the hardened SSH :2222 path you’ll demo

### A4. GitHub login + private repo

**Why:** Expansion pack requires a private repo (prefer GitHub), share with `mflaim-eng`, submit the link in Part 1.

```bash
cd ~/Projects/fedora-lane-rhel-gold-image
gh auth login   # GitHub.com → HTTPS or SSH → login in browser

# Create PRIVATE remote and push (after first local commit)
gh repo create fedora-lane-rhel-gold-image --private --source=. --remote=origin --push

# Give reviewer access
gh repo invite mflaim-eng --permission pull
# If invite fails, add collaborator in GitHub UI: Settings → Collaborators
```

---

## Phase B — Launch the builder EC2

### B1. Pick a RHEL AMI

**Why:** You need a clean Red Hat base. Marketplace/RHEL AMIs are fine as the *starting* OS; **you** apply the gold configuration manually.

```bash
# Example: find RHEL 9 in your region (IDs change by region/account)
aws ec2 describe-images \
  --owners 309956199498 \
  --filters "Name=name,Values=RHEL-9*" "Name=architecture,Values=x86_64" \
  --query 'sort_by(Images,&CreationDate)[-5].[ImageId,Name]' \
  --output table
```

Note an `ami-...` ID. If RHDP already documents a RHEL AMI, use that.

### B2. Security group for the builder

**Why (builder phase):** You need SSH **22** open *initially* so you can log in and change SSH to 2222. After hardening, demo SG will only allow 2222 + 35443.

```bash
# Use your default VPC or a known VPC — list them:
aws ec2 describe-vpcs --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock,Default:IsDefault}' --output table

VPC_ID=vpc-xxxxxxxx   # replace
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

SG_ID=$(aws ec2 create-security-group \
  --group-name fedora-lane-builder-sg \
  --description "Builder SSH during gold image prep" \
  --vpc-id "$VPC_ID" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr "$MY_IP"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 2222 --cidr "$MY_IP"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 35443 --cidr "$MY_IP"

echo "SG_ID=$SG_ID"
```

**Why open 22 and 2222?**  
You’ll switch sshd to 2222 mid-build. Keeping both open during build avoids locking yourself out. On the **final demo** instance, prefer only 2222 + 35443.

### B3. Launch builder

```bash
AMI_ID=ami-xxxxxxxx
SUBNET_ID=subnet-xxxxxxxx   # from describe-subnets in your VPC

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.large \
  --key-name fedora-lane-builder \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":40,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fedora-lane-gold-builder}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "INSTANCE_ID=$INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "PUBLIC_IP=$PUBLIC_IP"
```

**Why t3.large + 40 GiB?**  
You need room for separate partitions / LVs and package installs. Smaller disks make the partition story painful.

### B4. First SSH

RHEL cloud images often use `ec2-user` or `cloud-user`:

```bash
ssh -i ~/.ssh/fedora-lane-builder.pem ec2-user@$PUBLIC_IP
# if that fails:
ssh -i ~/.ssh/fedora-lane-builder.pem cloud-user@$PUBLIC_IP
```

Copy this repo’s scripts up (from Mac, new terminal):

```bash
scp -i ~/.ssh/fedora-lane-builder.pem -r \
  ~/Projects/fedora-lane-rhel-gold-image \
  ec2-user@$PUBLIC_IP:~/
```

---

## Phase C — Harden the builder (the gold configuration)

Work **on the EC2** as `ec2-user`/`cloud-user` with `sudo`.  
Full command detail also lives in `docs/02-aws-build-commands.md`. Below is the APAC learning path with **why**.

### C1. Update the OS

```bash
sudo dnf -y update
```

**Why:** Gold images should start from patched packages. Shipping known CVEs undermines Ren Tanaka’s security story.

### C2. Separate partitions: `/var/log`, `/home`, `/tmp`, `/var/tmp`

**Why (ops reliability):** Spec says keep these off the root filesystem so logs/temp don’t fill `/` and take down the node. Each filesystem **&lt; 5 GiB** for this lab.

On a cloud AMI you usually already have one root disk. Practical approaches:

1. **Attach a second EBS volume**, partition it, mount the four directories (cleanest on AWS), **or**
2. Use **LVM** if free space exists in the volume group, **or**
3. Rebuild with custom partitioning from an ISO (harder on Mac/AWS)

**Recommended for Mac+AWS:** attach a second 12–16 GiB EBS, create 4 partitions, mount them.

From **Mac**:

```bash
VOL_ID=$(aws ec2 create-volume \
  --availability-zone $(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text) \
  --size 16 --volume-type gp3 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=fedora-lane-data}]' \
  --query VolumeId --output text)

aws ec2 wait volume-available --volume-ids "$VOL_ID"
aws ec2 attach-volume --volume-id "$VOL_ID" --instance-id "$INSTANCE_ID" --device /dev/sdf
```

**On EC2** (device may appear as `/dev/nvme1n1`):

```bash
lsblk
# Pick the NEW 16G disk, e.g. /dev/nvme1n1

sudo parted /dev/nvme1n1 --script mklabel gpt \
  mkpart varlog 1MiB 4097MiB \
  mkpart home 4097MiB 8193MiB \
  mkpart tmp 8193MiB 12289MiB \
  mkpart vartmp 12289MiB 16384MiB

sudo mkfs.xfs /dev/nvme1n1p1
sudo mkfs.xfs /dev/nvme1n1p2
sudo mkfs.xfs /dev/nvme1n1p3
sudo mkfs.xfs /dev/nvme1n1p4

# Migrate existing data then remount (example for /var/log)
sudo mkdir -p /mnt/varlog
sudo mount /dev/nvme1n1p1 /mnt/varlog
sudo rsync -aHAX /var/log/ /mnt/varlog/
sudo umount /mnt/varlog
# Repeat pattern for /home, /tmp, /var/tmp (tmp dirs can be empty)

# Use UUIDs in fstab
sudo blkid /dev/nvme1n1p{1,2,3,4}
```

`/etc/fstab` example (**why noexec on /tmp:** stop attackers/admins executing binaries from world-writable temp — compliance control):

```fstab
UUID=...  /var/log  xfs  defaults,nofail               0 0
UUID=...  /home     xfs  defaults,nofail               0 0
UUID=...  /tmp      xfs  defaults,nodev,nosuid,noexec,nofail  0 0
UUID=...  /var/tmp  xfs  defaults,nodev,nosuid,nofail  0 0
```

```bash
sudo mount -a
findmnt /var/log /home /tmp /var/tmp
findmnt -no OPTIONS /tmp | tr ',' '\n' | grep noexec
```

**Why `nofail`?**  
If the data volume is missing on a bad launch, the instance can still boot so you can fix it (lab convenience). For production you’d be stricter.

### C3. SELinux enforcing

```bash
sudo setenforce 1
getenforce
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
```

**Why:** Fedora Lane needs mandatory access control for PCI-ish posture. Enforcing SELinux is an explicit Expansion Pack requirement and a strong Ren Tanaka talking point.

### C4. Admin users + sudo with password

```bash
export PUBKEY="$(cat ~/fedora-lane-rhel-gold-image/../.ssh/fedora-lane-lab.pub 2>/dev/null || true)"
# Easier: paste from Mac:
# export PUBKEY='ssh-ed25519 AAAA... fedora-lane-apac'

cd ~/fedora-lane-rhel-gold-image
sudo -E bash scripts/10-users-ssh-firewall.sh
sudo passwd fladmin1
sudo passwd fladmin2
```

**Why named admins + group `fladmins`?**  
Accountability (Challenge 2). Shared root logins are what caused untraceable changes.

**Why sudo must ask for a password?**  
Stops silent privilege escalation if a session is left unlocked; matches “no passwordless sudo” spec.

**Why put your pubkey on fladmin* before disabling password SSH?**  
Otherwise you cannot log in after `PasswordAuthentication no`.

### C5. SSH port 2222 + harden

The script already writes sshd drop-in and SELinux port labels. Understand **why**:

| Setting | Why |
|---------|-----|
| `Port 2222` | Non-standard port (spec) + forces SELinux/firewall skill |
| `semanage port -a -t ssh_port_t -p tcp 2222` | SELinux blocks sshd on unlabeled ports even if firewall allows |
| `PermitRootLogin no` | Direct root is a compliance/risk anti-pattern |
| `PasswordAuthentication no` | Stops password guessing; keys only |

**Critical test before closing your session:**

```bash
# From Mac
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP
```

### C6. Firewall only 2222 + 35443

**Why:** Least privilege network exposure. Spec: only SSH and httpd ports reachable.

After you’re stable on 2222, you can remove port 22 from the **AWS security group** for the final demo instance (builder may keep 22 until AMI is done).

### C7. httpd in a container on 35443

```bash
sudo bash scripts/20-httpd-container.sh
curl -s http://127.0.0.1:35443/
```

**Why container?**  
Maps to Challenge 3 — ops should run a **service**, not paste `podman run`.

**Why port 35443 + SELinux `http_port_t`?**  
Non-default port proves you can adjust policy (same class of skill as production custom ports).

**Why systemd unit?**  
Survives reboot (spec item 7) and is familiar to classic Linux admins on Casey’s team.

### C8. Verify on builder + reboot

```bash
sudo bash verify/verify.sh
sudo reboot
# wait, then SSH on 2222 again and re-run verify
```

**Why reboot test before AMI?**  
If it fails here, every instance from the AMI will fail. Fix once on the builder.

### C9. Light cloud clean-up before AMI (optional but good)

```bash
sudo dnf clean all
sudo cloud-init clean --logs || true
# Do NOT delete fladmin authorized_keys
history -c
```

**Why:** Reduce unique builder noise in the gold image. Don’t remove your admin keys or you’ll brick the AMI.

---

## Phase D — Create AMI and prove on a fresh instance

### D1. Create image from builder

**From Mac:**

```bash
# Prefer stopping first for a clean disk snapshot
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

AMI_NEW=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "fedora-lane-rhel-gold-$(date +%Y%m%d)" \
  --description "Fedora Lane e-commerce web gold image (manual)" \
  --query ImageId --output text)

echo "AMI_NEW=$AMI_NEW"
aws ec2 wait image-available --image-ids "$AMI_NEW"
```

**Why this is allowed:** You configured everything manually. `create-image` only packages that work. Hosted Image Builder *service* is what the brief forbids.

**Why stop first?**  
Consistent filesystem state; fewer “half-written” surprises.

### D2. Launch test instance from AMI

Create a **demo SG** with only 2222 + 35443 from your IP (best practice for the live call).

```bash
TEST_ID=$(aws ec2 run-instances \
  --image-id "$AMI_NEW" \
  --instance-type t3.medium \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fedora-lane-gold-test}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$TEST_ID"
TEST_IP=$(aws ec2 describe-instances --instance-ids "$TEST_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "TEST_IP=$TEST_IP"

ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$TEST_IP
sudo bash verify/verify.sh
curl -s http://$TEST_IP:35443/
```

**Why a second instance?**  
Graders/SMEs care that the **AMI** carries the config. Proving only on the builder is weaker.

### D3. Negative tests (great for live demo)

```bash
ssh -p 22 fladmin1@$TEST_IP          # should fail
ssh -p 2222 root@$TEST_IP            # should fail
# password SSH should fail too
```

---

## Phase E — Docs, recording, live call (APAC)

### E1. Finish repo docs

Already in this project:

- `docs/01-what-we-are-solving.md` — challenges → value  
- `docs/solution-overview.md` — client-facing overview  
- `docs/02-aws-build-commands.md` — deep commands  
- This file — Mac/APAC path with why  

Update `README.md` with your real AMI ID region notes (no secrets).

### E2. Part 1 (due ~19 Oct)

1. Practice in RHSH → get recording link  
2. Google form → select **Server/Cloud OS TDP**  
3. Submit recording + **private GitHub URL** + docs  

### E3. Part 2 (~22/23 Oct)

15 minutes: opening → live walkthrough on test EC2 → value → next step.  
SMEs play **Casey Novak** / **Alex Lee**.

### E4. Follow-up email (&lt; 2 days)

To SMEs; CC Pod Host, Manager, `faster@redhat.com`.

### E5. Cost hygiene

```bash
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" "$TEST_ID"
# or terminate when fully done; delete unused volumes
```

**Why:** RHDP/AWS lab spend; Expansion Pack says shut environments down.

---

## Presentation cheat-sheet (say the “why” out loud)

1. **Partitions** — “Logs and temp can’t fill root and kill checkout.”  
2. **SELinux + firewall + odd ports** — “Same security baseline on every web node; audit-friendly.”  
3. **SSH keys / no root / sudo password** — “We know which admin acted; no anonymous root.”  
4. **Podman httpd + systemd** — “Ops manages a service, not a fragile developer one-liner.”  
5. **AMI → new instance** — “This is a repeatable gold standard for Alex’s fleet, not a one-off VM.”

---

## Stretch (if time before 19 Oct)

```bash
sudo dnf -y install openscap-scanner scap-security-guide
# eval CIS profile — see docs/02 — document report in docs/scap-report.html
```

**Why:** Shows Ren Tanaka you can prove hardening against a known benchmark.

---

## If something breaks

| Symptom | Likely cause |
|---------|----------------|
| SSH dies after port change | Forgot `semanage port` for 2222 |
| Locked out | Disabled passwords before adding pubkey |
| curl :35443 fails externally | SG or firewalld missing 35443 |
| Container gone after reboot | systemd unit not enabled |
| AMI instance missing mounts | Second EBS not in AMI / wrong fstab device names — prefer UUID + include volume in AMI or bake mounts on root LV |

Use AWS console **EC2 → Serial console** / screenshot if SSH fails after hardening.
