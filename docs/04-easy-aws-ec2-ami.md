# Easy path: AWS EC2 → harden by hand → AMI

For someone new to AWS. One Terminal. Copy/paste each block. Stop if something errors and ask for help.

## English picture (no jargon)

1. Rent a blank Red Hat computer in Amazon’s cloud (**EC2 instance**)
2. Log in and configure it yourself (gold settings)
3. Take a snapshot of that computer (**AMI** = gold image)
4. Start a **new** computer from that snapshot and show it still works

You are **not** using Image Builder. You are configuring by hand.

---

## Before you start (checklist)

- [ ] `aws sts get-caller-identity` works in **this** Terminal
- [ ] You know your region (often `us-east-1` for RHDP — use what RHDP shows)
- [ ] Lab key exists: `~/.ssh/fedora-lane-lab` (we created this earlier)

Set region every time you open a new Terminal:

```bash
export PATH="/opt/homebrew/bin:$PATH"
export AWS_DEFAULT_REGION="us-east-1"   # change if RHDP says otherwise
aws sts get-caller-identity
```

---

# PART A — Create the blank RHEL computer

## A1. Create a login key for the first SSH

**Why:** Amazon puts this key on the new server so you can log in the first time.

```bash
mkdir -p ~/.ssh

# If this says the key already exists, skip to chmod
aws ec2 create-key-pair \
  --key-name fedora-lane-builder \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/fedora-lane-builder.pem

chmod 400 ~/.ssh/fedora-lane-builder.pem
ls -la ~/.ssh/fedora-lane-builder.pem
```

If error `InvalidKeyPair.Duplicate`: key already exists — that’s OK, keep using the existing `.pem`. If you lost the `.pem`, delete the key in AWS Console (EC2 → Key pairs) and run create again.

---

## A2. Find your network (VPC + subnet)

**Why:** Every server must sit in a network. We use the account’s default one.

```bash
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
echo "VPC_ID=$VPC_ID"

SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[0].SubnetId' --output text)
echo "SUBNET_ID=$SUBNET_ID"
```

Both must look like `vpc-...` and `subnet-...`. If `None`, say so — RHDP sometimes has no “default” VPC and we pick another.

---

## A3. Firewall rules (Security Group)

**Why:** Amazon blocks all ports unless you allow them. We allow:

- **22** — first login only  
- **2222** — SSH after we harden  
- **35443** — website (httpd)

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
echo "MY_IP=$MY_IP"

SG_ID=$(aws ec2 create-security-group \
  --group-name fedora-lane-builder-sg \
  --description "Fedora Lane builder" \
  --vpc-id "$VPC_ID" \
  --query GroupId --output text)
echo "SG_ID=$SG_ID"

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 2222 --cidr "$MY_IP"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 35443 --cidr "$MY_IP"
```

If error `InvalidGroup.Duplicate`:

```bash
SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=fedora-lane-builder-sg \
  --query 'SecurityGroups[0].GroupId' --output text)
echo "SG_ID=$SG_ID"
```

---

## A4. Pick a blank RHEL 9 image

**Why:** Starting OS only. You will add all gold settings yourself.

```bash
AMI_ID=$(aws ec2 describe-images \
  --owners 309956199498 \
  --filters "Name=name,Values=RHEL-9.*x86_64*" "Name=state,Values=available" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
  --output text)
echo "AMI_ID=$AMI_ID"
```

Must look like `ami-...`. If empty/`None`, stop and tell me.

---

## A5. Start the server

**Why:** This is your builder machine.

```bash
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

echo "Waiting until running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "PUBLIC_IP=$PUBLIC_IP"
```

Save these three lines in a note:

```text
INSTANCE_ID=...
PUBLIC_IP=...
SG_ID=...
```

---

## A6. Log in (first time)

Wait ~1 minute after “running”, then:

```bash
ssh -o StrictHostKeyChecking=accept-new \
  -i ~/.ssh/fedora-lane-builder.pem \
  ec2-user@$PUBLIC_IP
```

If `Permission denied`, try:

```bash
ssh -i ~/.ssh/fedora-lane-builder.pem cloud-user@$PUBLIC_IP
```

Success = you see a Linux prompt. Check:

```bash
cat /etc/redhat-release
```

Leave this SSH window open. Open a **second** Terminal on your Mac for copy commands.

---

## A7. Copy project scripts onto the server

**On your Mac** (second Terminal — not inside SSH):

```bash
export PATH="/opt/homebrew/bin:$PATH"
# set PUBLIC_IP again if needed
PUBLIC_IP="PASTE_THE_IP_HERE"

scp -i ~/.ssh/fedora-lane-builder.pem -r \
  ~/Projects/fedora-lane-rhel-gold-image \
  ec2-user@$PUBLIC_IP:~/
```

(Use `cloud-user` instead of `ec2-user` if that’s how you logged in.)

---

# PART B — Harden by hand (on the server)

Do these **inside SSH** on the EC2. We’ll go one block at a time when you’re logged in.

Order:

1. Update packages  
2. Extra disk for `/var/log` `/home` `/tmp` `/var/tmp` + `/tmp` noexec  
3. SELinux enforcing  
4. Run `scripts/10-users-ssh-firewall.sh` (admins, SSH 2222, firewall)  
5. Run `scripts/20-httpd-container.sh` (httpd container :35443)  
6. `sudo bash verify/verify.sh`  
7. Reboot and verify again  

*(Detailed commands for Part B are given live step-by-step so nothing breaks mid-way.)*

---

# PART C — Make the AMI (gold image)

**On your Mac** (after hardening + reboot test OK):

```bash
# Stop for a clean image
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

GOLD_AMI=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "fedora-lane-rhel-gold-$(date +%Y%m%d)" \
  --description "Fedora Lane manual gold image" \
  --query ImageId --output text)

echo "GOLD_AMI=$GOLD_AMI"
aws ec2 wait image-available --image-ids "$GOLD_AMI"
echo "AMI ready"
```

**Why stop first?** Cleaner disk snapshot.

---

# PART D — Prove it on a NEW server

```bash
TEST_ID=$(aws ec2 run-instances \
  --image-id "$GOLD_AMI" \
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

# Login with the LAB key on port 2222 (after hardening)
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$TEST_IP
```

On the test server:

```bash
sudo bash ~/fedora-lane-rhel-gold-image/verify/verify.sh
curl -s http://127.0.0.1:35443/
```

From Mac browser or Terminal: `curl http://TEST_IP:35443/`

---

# PART E — Save money when done

```bash
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" "$TEST_ID"
# or terminate when finished forever
```

---

## Tiny AWS dictionary

| Word | Meaning |
|------|---------|
| EC2 | A virtual server |
| AMI | Saved image you can launch more servers from (= your gold image) |
| Security Group | Cloud firewall |
| VPC / Subnet | Network the server lives in |
| Key pair | SSH key Amazon installs for first login |
