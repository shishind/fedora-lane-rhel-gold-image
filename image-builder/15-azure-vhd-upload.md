# Publish the gold disk to Microsoft Azure

Same blueprint (`fedora-lane-gold.toml`, `distro = "rhel-10.0"`) as AWS.  
Image Builder output type: **`vhd`**.

Official Red Hat:

- [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)  
- [Deploying and managing RHEL on Microsoft Azure (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/index)

Do **not** commit storage account keys, `azure.toml` with secrets, or `.vhd` files to Git.

```text
[ image-builder build vhd → .vhd ]
        ↓
[ Azure: resource group + storage account + container ]
        ↓
[ az storage blob upload --type page ]
        ↓
[ az image create (Linux, Gen2) ]
        ↓
[ NSG: TCP 2222 + 35443 from your IP ]
        ↓
[ az vm create → public IP ]
        ↓
[ ssh -p 2222 fladmin1@PUBLIC_IP ]
```

Copy-paste command sheet: [16-azure-examples.md](16-azure-examples.md)

---

## Part 0 — Prerequisites

| Item | Detail |
|------|--------|
| Builder host | RHEL 10 with `image-builder` installed and subscribed |
| Distro id | Exact id from `image-builder list` (e.g. **`rhel-10.0`**, not bare `rhel-10`) |
| Disk space | `/var` needs **≥ 15–20 GiB free** during VHD compose (Red Hat requirement) |
| Azure | Subscription, permission to create resource group, storage, images, VMs |
| SSH key | Private key matching the public key in the blueprint (`fladmin1` / `fladmin2`) |
| Secrets | Never put access keys in the repo |

Confirm distro support for VHD:

```bash
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
# expect: rhel-10.0 type:vhd arch:x86_64
```

---

## Part 1 — Install Azure CLI on the RHEL 10 builder

Skip if `az version` already works.

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft-2025.asc

sudo tee /etc/yum.repos.d/azure-cli.repo >/dev/null <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/packages.microsoft.com/rhel/10/prod/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf install -y azure-cli
az version
```

Sign in (on a headless builder use device code):

```bash
az login --use-device-code
# open the URL in a browser, enter the code, pick the Fedora Lane subscription

az account show --output table
# if wrong subscription:
# az account set --subscription "<subscription-id-or-name>"
```

---

## Part 2 — Create resource group, storage account, container

Pick a region close to your users (example: **`eastus`**). Names must be globally unique for storage accounts (lowercase letters/numbers only).

```bash
export AZ_LOCATION=eastus
export AZ_RG=fedora-lane-gold-rg
export AZ_STORAGE=flgold$(date +%s | tail -c 8)   # e.g. flgold1234567
export AZ_CONTAINER=vhds
export AZ_IMAGE=fedora-lane-rhel10-gold
export AZ_VM=fedora-lane-gold-test

az group create --name "$AZ_RG" --location "$AZ_LOCATION"

az storage account create \
  --name "$AZ_STORAGE" \
  --resource-group "$AZ_RG" \
  --location "$AZ_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true

# Account key (keep private — use env var, do not commit)
export AZ_KEY=$(az storage account keys list \
  --resource-group "$AZ_RG" \
  --account-name "$AZ_STORAGE" \
  --query '[0].value' -o tsv)

az storage container create \
  --account-name "$AZ_STORAGE" \
  --account-key "$AZ_KEY" \
  --name "$AZ_CONTAINER"
```

### Portal equivalent

1. **Resource groups** → **Create** → name `fedora-lane-gold-rg`, region `East US`.  
2. **Storage accounts** → **Create** in that RG (unique name, Standard LRS).  
3. Open the account → **Containers** → **+ Container** → name `vhds`, public access **Private**.  
4. **Access keys** → copy **key1** (only for CLI upload; rotate later).

---

## Part 3 — Build the VHD with Image Builder

```bash
cd /path/to/fedora-lane-rhel-gold-image/image-builder

df -h /var
# ensure 15–20+ GiB free

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd 2>/dev/null
# note the exact filename, e.g. <uuid>-image.vhd
export VHD_FILE=./$(ls -1t ./*.vhd | head -1)
echo "VHD_FILE=$VHD_FILE"
```

### Optional — upload config file for Image Builder (do not commit)

Red Hat documents an `azure.toml` used with some Image Builder upload flows. Create it **only on the builder**, never in Git:

```bash
# LOCAL ONLY — contains secrets
cat > /tmp/azure-upload.toml <<EOF
provider = "azure"

[settings]
storageAccount = "$AZ_STORAGE"
storageAccessKey = "$AZ_KEY"
container = "$AZ_CONTAINER"
EOF
chmod 600 /tmp/azure-upload.toml
```

Prefer the explicit `az storage blob upload` steps below so every stage is visible and auditable. If your `image-builder` build supports passing an Azure upload config, follow the [official VHD chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) for the exact flag layout on your package version (`image-builder --help`).

---

## Part 4 — Upload VHD as a **page** blob

Azure managed images require VHDs as **page** blobs (not block blobs).

```bash
export BLOB_NAME="fedora-lane-rhel10-gold-$(date +%Y%m%d).vhd"

az storage blob upload \
  --account-name "$AZ_STORAGE" \
  --account-key "$AZ_KEY" \
  --container-name "$AZ_CONTAINER" \
  --file "$VHD_FILE" \
  --name "$BLOB_NAME" \
  --type page

# Confirm
az storage blob list \
  --account-name "$AZ_STORAGE" \
  --account-key "$AZ_KEY" \
  --container-name "$AZ_CONTAINER" \
  --output table
```

Blob URL (used when creating the image):

```bash
export VHD_URL="https://${AZ_STORAGE}.blob.core.windows.net/${AZ_CONTAINER}/${BLOB_NAME}"
echo "$VHD_URL"
```

### Portal equivalent

1. Storage account → container `vhds` → **Upload**.  
2. Select the `.vhd` file.  
3. Advanced → Blob type **Page blob**.  
4. Upload (multi‑GB files take time; CLI is more reliable).

---

## Part 5 — Create a managed image from the VHD

Image Builder VHDs are **hybrid** (Gen1 BIOS / Gen2 UEFI). Prefer **Gen2** for new Fedora Lane VMs.

```bash
az image create \
  --resource-group "$AZ_RG" \
  --name "$AZ_IMAGE" \
  --os-type Linux \
  --hyper-v-generation V2 \
  --source "$VHD_URL"

az image show --resource-group "$AZ_RG" --name "$AZ_IMAGE" --output table
```

### Portal equivalent

1. Search **Images** → **+ Create**.  
2. Resource group: `fedora-lane-gold-rg`.  
3. Name: `fedora-lane-rhel10-gold`.  
4. OS type: **Linux**.  
5. VM generation: **Gen 2**.  
6. Storage blob: browse to the uploaded `.vhd`.  
7. Account type: e.g. **Premium SSD** or **Standard SSD**.  
8. **Review + create** → **Create**.

---

## Part 6 — Network security group (ports 2222 and 35443)

The gold image firewall only opens **SSH 2222** and **httpd 35443**. Azure NSG must match.

```bash
export MY_IP=$(curl -s https://ifconfig.me)/32
export AZ_NSG=fedora-lane-gold-nsg

az network nsg create \
  --resource-group "$AZ_RG" \
  --name "$AZ_NSG"

az network nsg rule create \
  --resource-group "$AZ_RG" \
  --nsg-name "$AZ_NSG" \
  --name allow-ssh-2222 \
  --priority 1000 \
  --access Allow --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes "$MY_IP" \
  --destination-port-ranges 2222

az network nsg rule create \
  --resource-group "$AZ_RG" \
  --nsg-name "$AZ_NSG" \
  --name allow-httpd-35443 \
  --priority 1010 \
  --access Allow --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes "$MY_IP" \
  --destination-port-ranges 35443
```

Do **not** open `0.0.0.0/0` for these ports in production demos.

### Portal equivalent

1. **Network security groups** → **Create**.  
2. Add inbound rules: TCP **2222** and **35443**, source = **My IP**.  
3. Attach the NSG to the VM NIC (or subnet) when launching.

---

## Part 7 — Create the VM from the managed image

The gold image already has `fladmin1` / `fladmin2` and their SSH public keys.  
Use `fladmin1` as the Azure admin username and supply the **same** public key that is in the blueprint (Azure still requires an admin identity at create time).

```bash
# Public key that matches ~/.ssh/fedora-lane-lab (must match blueprint)
export SSH_PUB=~/.ssh/fedora-lane-lab.pub

az vm create \
  --resource-group "$AZ_RG" \
  --name "$AZ_VM" \
  --image "$AZ_IMAGE" \
  --size Standard_D2s_v3 \
  --admin-username fladmin1 \
  --ssh-key-values "$SSH_PUB" \
  --nsg "$AZ_NSG" \
  --public-ip-sku Standard \
  --output json

PUBLIC_IP=$(az vm list-ip-addresses \
  --resource-group "$AZ_RG" \
  --name "$AZ_VM" \
  --query '[0].virtualMachine.network.publicIpAddresses[0].ipAddress' -o tsv)
echo "PUBLIC_IP=$PUBLIC_IP"
```

Wait **2–5 minutes** after the VM shows **Running** for first-boot (Podman pull + httpd systemd unit).

### Portal equivalent

1. Open the managed image → **Create VM**.  
2. Size: e.g. **Standard_D2s_v3**.  
3. Administrator account: **SSH public key**, username **`fladmin1`**, paste the blueprint public key.  
4. Networking: assign the NSG that allows **2222** and **35443**.  
5. Public inbound ports: set to **None** (use the custom NSG rules instead of default 22).  
6. Create → note the public IP.

---

## Part 8 — SSH and verify

```bash
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP

# on the VM:
curl -s http://127.0.0.1:35443/
sudo systemctl status container-fl-httpd.service --no-pager
```

From your laptop (if NSG allows your IP on 35443):

```bash
curl -s http://$PUBLIC_IP:35443/
```

Full checklist (same as AWS): [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)

---

## Part 9 — Cleanup (optional)

```bash
# delete VM + disks + NIC + public IP, keep the image for reuse:
az vm delete --resource-group "$AZ_RG" --name "$AZ_VM" --yes --force-deletion true

# or wipe the whole lab resource group:
# az group delete --name "$AZ_RG" --yes --no-wait
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `cannot find image for distro:"rhel-10" type:"vhd"` | Wrong distro id | Use exact id from `image-builder list` (e.g. `rhel-10.0`) |
| No space left on device during build | `/var` too small | Free **15–20+ GiB** on `/var` or enlarge the builder disk |
| Blob upload fails / image create rejects VHD | Uploaded as **block** blob | Re-upload with `--type page` |
| SSH timeout on 22 | Gold image listens on **2222** | Use `-p 2222`; NSG must allow 2222 (not only 22) |
| SSH refused / auth fail | Wrong key or user | Use `fladmin1` + key matching the TOML; wait for cloud-init |
| httpd not answering | First-boot still running | Wait 2–5 min; `systemctl status container-fl-httpd` |
| Portal “Generate new key pair” breaks login | Azure key ≠ blueprint key | Prefer “Use existing public key” = blueprint key |

---

## Related

- Examples sheet: [16-azure-examples.md](16-azure-examples.md)  
- Same blueprint AWS path: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)  
- Build how-to: [08-rhel10-rebuild.md](08-rhel10-rebuild.md)  
- End-to-end (both clouds): [docs/00-end-to-end-guide.md](../docs/00-end-to-end-guide.md)
