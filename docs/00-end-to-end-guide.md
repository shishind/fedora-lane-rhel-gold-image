# End-to-end guide — build once, run on AWS and Azure

This is the full path from blueprint to a verified web node on **AWS** and **Azure**, using the **same** TOML.

| Artifact | Value |
|----------|--------|
| Blueprint | [`image-builder/fedora-lane-gold.toml`](../image-builder/fedora-lane-gold.toml) |
| Distro | **`rhel-10.0`** (exact id from `image-builder list`) |
| Builder | Local **RHEL 10** Image Builder (`image-builder` CLI) — not hosted Image Builder |
| Admins | `fladmin1` / `fladmin2` · SSH port **2222** · keys only |
| Web | Podman httpd · systemd · port **35443** |

```text
                    fedora-lane-gold.toml
                              |
                    image-builder (RHEL 10)
                     /                  \
              type: ami              type: vhd
                  |                      |
             AWS AMI / EC2          Azure image / VM
                  |                      |
         SG 2222+35443            NSG 2222+35443
                  \                      /
                   verify customizations
```

---

## Phase A — Prepare the builder (once)

### A1. RHEL 10 host

```bash
cat /etc/os-release
# VERSION_ID=10.x
```

Host must be subscribed (BaseOS + AppStream) with CDN access.  
If builds fail on repos: [image-builder/11-depsolve-cdn-repo-fix.md](../image-builder/11-depsolve-cdn-repo-fix.md)

### A2. Install Image Builder

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list --filter "distro:rhel-10*"
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
```

You must see lines like:

```text
rhel-10.0 type:ami arch:x86_64
rhel-10.0 type:vhd arch:x86_64
```

Put that **exact** id in the blueprint:

```toml
distro = "rhel-10.0"
```

Troubleshoot wrong id: [image-builder/14-distro-ami-not-found.md](../image-builder/14-distro-ami-not-found.md)

### A3. Blueprint on the builder

```bash
# clone or copy this repo onto the builder
cd /path/to/fedora-lane-rhel-gold-image/image-builder
ls fedora-lane-gold.toml
```

**How the TOML was created, how to create/edit one, and every customization you can use:**  
→ [image-builder/10-create-toml-blueprint.md](../image-builder/10-create-toml-blueprint.md)

### A4. SSH private key on your laptop

The public key for `fladmin1` / `fladmin2` is embedded in the blueprint.  
Keep the matching private key (example name: `~/.ssh/fedora-lane-lab`) **out of Git**.

---

## Phase B — Build the gold disk

### B1. AWS disk (`ami` → usually `.raw`)

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*ami*.raw ./*.raw 2>/dev/null
```

Detail: [image-builder/08-rhel10-rebuild.md](../image-builder/08-rhel10-rebuild.md)  
Examples: [image-builder/13-image-builder-aws-examples.md](../image-builder/13-image-builder-aws-examples.md)

### B2. Azure disk (`vhd`)

Ensure `/var` has **15–20+ GiB** free.

```bash
df -h /var
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
```

Detail: [image-builder/15-azure-vhd-upload.md](../image-builder/15-azure-vhd-upload.md)  
Examples: [image-builder/16-azure-examples.md](../image-builder/16-azure-examples.md)

You can run B1 and B2 from the same blueprint on the same builder (two separate builds).

---

## Phase C — Publish and launch on **AWS**

### C1. Preferred: `image-builder upload` (S3 + snapshot + AMI)

Needs AWS credentials, S3 bucket, and `vmimport` IAM role.  
**One command** uploads the `.raw`, registers the AMI, creates the snapshot, and removes the temp S3 object.

```bash
sudo image-builder upload \
  rhel-10.0-ami-x86_64.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket YOUR_S3_BUCKET \
  --aws-ami-name fedora-lane-rhel10-gold \
  --arch x86_64
# Expect: AMI ami-… and Snapshot snap-…
```

Or build and upload together:

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket YOUR_S3_BUCKET \
  --aws-ami-name fedora-lane-rhel10-gold
```

### C2. Alternate: manual S3 → snapshot → AMI → EC2

Full CLI **and** Console steps (Parts 1–5, including Console 5g–5j):

→ [image-builder/12-aws-access-s3-upload.md](../image-builder/12-aws-access-s3-upload.md)

Short command sheet:

→ [image-builder/13-image-builder-aws-examples.md](../image-builder/13-image-builder-aws-examples.md) §5

### C3. Security group

Allow **your IP** only on:

- TCP **2222** (SSH)  
- TCP **35443** (httpd)

### C4. SSH

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

Wait 2–5 minutes after first boot for Podman/httpd.

---

## Phase D — Publish and launch on **Azure**

### D1. Azure CLI + resource group + service principal

Install `az` with Microsoft’s RHEL 10 method (RH chapter yum URL 404s) — see [15 Part 1](../image-builder/15-azure-vhd-upload.md).  
Official VHD flow: [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)

```bash
az login --use-device-code
# create RG + service principal — see 15 (Preferred) / 16 §2
```

→ [image-builder/15-azure-vhd-upload.md](../image-builder/15-azure-vhd-upload.md)  
→ [image-builder/16-azure-examples.md](../image-builder/16-azure-examples.md) §2

### D2. Preferred: `image-builder upload --to=azure`

```bash
sudo image-builder upload \
  "$VHD_FILE" \
  --to=azure \
  --azure-tenant "$AZ_TENANT" \
  --azure-subscription "$AZ_SUB" \
  --azure-client-id "$AZ_CLIENT_ID" \
  --azure-client-secret "$AZ_CLIENT_SECRET" \
  --azure-resource-group "$AZ_RG" \
  --azure-image-name "$AZ_IMAGE" \
  --arch x86_64
```

Or build + upload together with the same `--azure-*` flags on `image-builder build vhd …`.

### D2b. Alternate: page blob → Gen2 managed image

```bash
az storage blob upload ... --type page
az image create ... --location "$AZ_LOCATION" --os-type Linux --hyper-v-generation V2 --source "$VHD_URL"
```

### D3. NSG + VM

NSG: TCP **2222** and **35443** from your IP.  
VM: username `fladmin1`, SSH public key = blueprint key, size e.g. `Standard_D2s_v3`.

### D4. SSH

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@<PUBLIC_IP>
```

---

## Phase E — Verify (same on AWS and Azure)

On the instance:

→ [08-verify-customizations.md](08-verify-customizations.md)

Quick smoke test:

```bash
cat /etc/redhat-release
getenforce
findmnt /var/log /home /tmp /var/tmp
sudo ss -tlnp | egrep '2222|35443'
curl -s http://127.0.0.1:35443/
sudo firewall-cmd --list-ports
sudo reboot   # then re-check after reboot
```

---

## Phase F — Day-2 (optional)

Web Console / Session Recording demos (gold firewall still only 2222 + 35443):

→ [07-rhel10-web-console-demo.md](07-rhel10-web-console-demo.md)

---

## Official Red Hat books

| Cloud | Book |
|-------|------|
| Build | [Composing a customized RHEL system image](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index) |
| CLI compose | [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli) |
| AWS AMI | [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws) |
| AWS deploy | [Deploying and managing RHEL on Amazon Web Services](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_amazon_web_services/index) |
| Azure VHD | [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) |
| Azure deploy | [Deploying and managing RHEL on Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/index) |

Curated link list + RH vs lab command notes: [redhat-documentation.md](redhat-documentation.md)

---

## Secrets hygiene

Never commit: AWS keys, Azure storage keys, `azure.toml` with secrets, `.pem` / private SSH keys, `.raw` / `.vhd` disks.
