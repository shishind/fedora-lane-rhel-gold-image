# Image Builder + Azure — copy-paste examples

Same Fedora Lane blueprint as AWS. Replace names/region if yours differ.

| Variable | Example value |
|----------|----------------|
| Blueprint | `./fedora-lane-gold.toml` |
| Distro | **exact** id (e.g. `rhel-10.0`) |
| Location | `eastus` |
| Resource group | `fedora-lane-gold-rg` |
| Image name | `fedora-lane-rhel10-gold` |
| Tenant / subscription / SP | from `az account show` + `az ad sp create-for-rbac` |
| Storage account | unique lowercase name (manual path only) |
| Container | `vhds` (manual path only) |
| VM name | `fedora-lane-gold-test` |
| SSH | `fladmin1` on port **2222** |

Full narrative: [15-azure-vhd-upload.md](15-azure-vhd-upload.md)

**Official Red Hat:**

- [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)  
- [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)  
- [Deploying and managing RHEL on Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/index)

**Azure CLI on RHEL 10:** [Install the Azure CLI on Linux](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux)  
(do **not** use the 404 yum baseurl still printed in some RH Azure chapters — see [15 § Part 1](15-azure-vhd-upload.md))

---

## 0) One-time setup on the RHEL 10 builder

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"

# Azure CLI — Microsoft RHEL 10 method (see 15-azure-vhd-upload.md Part 1)
sudo rm -f /etc/yum.repos.d/azure-cli.repo
sudo rpm --import https://packages.microsoft.com/keys/microsoft-2025.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/10/packages-microsoft-prod.rpm
sudo dnf install -y azure-cli
az version

az login --use-device-code
az account show --output table

df -h /var   # Red Hat: ≥ 15–20 GiB free for VHD compose
```

---

## 1) Build VHD only (local file)

```bash
cd /path/to/fedora-lane-rhel-gold-image/image-builder

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
export VHD_FILE=./$(ls -1t ./*.vhd | head -1)
```

---

## 2) Preferred — `image-builder upload` to Azure (managed image)

Needs an existing resource group + service principal (Contributor on that RG).  
Same pattern as AWS `image-builder upload --to=aws`.

```bash
export AZ_LOCATION=eastus
export AZ_RG=fedora-lane-gold-rg
export AZ_IMAGE=fedora-lane-rhel10-gold

az group create --name "$AZ_RG" --location "$AZ_LOCATION"

export AZ_SUB=$(az account show --query id -o tsv)
export AZ_TENANT=$(az account show --query tenantId -o tsv)

# one-time: create SP (save appId + password; do not commit)
az ad sp create-for-rbac \
  --name "fedora-lane-image-builder" \
  --role Contributor \
  --scopes "/subscriptions/${AZ_SUB}/resourceGroups/${AZ_RG}"

export AZ_CLIENT_ID="<appId>"
export AZ_CLIENT_SECRET="<password>"

# Upload existing .vhd → managed image in $AZ_RG
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

**Build + upload in one command:**

```bash
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --azure-tenant "$AZ_TENANT" \
  --azure-subscription "$AZ_SUB" \
  --azure-client-id "$AZ_CLIENT_ID" \
  --azure-client-secret "$AZ_CLIENT_SECRET" \
  --azure-resource-group "$AZ_RG" \
  --azure-image-name "$AZ_IMAGE" \
  --with-buildlog
```

Then skip §3 and go to §4 (NSG + VM). Confirm flags on your host: `sudo image-builder upload --help`.

---

## 3) Alternate — create storage + page-blob upload (`az`)

Use only if §2 is unavailable.

```bash
export AZ_LOCATION=eastus
export AZ_RG=fedora-lane-gold-rg
export AZ_STORAGE=flgold$(date +%s | tail -c 8)
export AZ_CONTAINER=vhds

az group create --name "$AZ_RG" --location "$AZ_LOCATION"

az storage account create \
  --name "$AZ_STORAGE" \
  --resource-group "$AZ_RG" \
  --location "$AZ_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2

export AZ_KEY=$(az storage account keys list \
  --resource-group "$AZ_RG" \
  --account-name "$AZ_STORAGE" \
  --query '[0].value' -o tsv)

az storage container create \
  --account-name "$AZ_STORAGE" \
  --account-key "$AZ_KEY" \
  --name "$AZ_CONTAINER"

echo "STORAGE=$AZ_STORAGE KEY length=${#AZ_KEY}"
```

### Upload VHD as page blob → create Gen2 image

```bash
export BLOB_NAME="fedora-lane-rhel10-gold-$(date +%Y%m%d).vhd"
export AZ_IMAGE=fedora-lane-rhel10-gold

az storage blob upload \
  --account-name "$AZ_STORAGE" \
  --account-key "$AZ_KEY" \
  --container-name "$AZ_CONTAINER" \
  --file "$VHD_FILE" \
  --name "$BLOB_NAME" \
  --type page

export VHD_URL="https://${AZ_STORAGE}.blob.core.windows.net/${AZ_CONTAINER}/${BLOB_NAME}"

az image create \
  --resource-group "$AZ_RG" \
  --name "$AZ_IMAGE" \
  --location "$AZ_LOCATION" \
  --os-type Linux \
  --hyper-v-generation V2 \
  --source "$VHD_URL"
```

---

## 4) NSG + VM + SSH (after preferred or alternate image create)

```bash
export MY_IP=$(curl -s https://ifconfig.me)/32
export AZ_NSG=fedora-lane-gold-nsg
export AZ_VM=fedora-lane-gold-test
export SSH_PUB=~/.ssh/fedora-lane-lab.pub

az network nsg create --resource-group "$AZ_RG" --name "$AZ_NSG"

az network nsg rule create --resource-group "$AZ_RG" --nsg-name "$AZ_NSG" \
  --name allow-ssh-2222 --priority 1000 --access Allow --protocol Tcp \
  --direction Inbound --source-address-prefixes "$MY_IP" \
  --destination-port-ranges 2222

az network nsg rule create --resource-group "$AZ_RG" --nsg-name "$AZ_NSG" \
  --name allow-httpd-35443 --priority 1010 --access Allow --protocol Tcp \
  --direction Inbound --source-address-prefixes "$MY_IP" \
  --destination-port-ranges 35443

az vm create \
  --resource-group "$AZ_RG" \
  --name "$AZ_VM" \
  --image "$AZ_IMAGE" \
  --size Standard_D2s_v3 \
  --admin-username fladmin1 \
  --ssh-key-values "$SSH_PUB" \
  --nsg "$AZ_NSG" \
  --public-ip-sku Standard

PUBLIC_IP=$(az vm list-ip-addresses -g "$AZ_RG" -n "$AZ_VM" \
  --query '[0].virtualMachine.network.publicIpAddresses[0].ipAddress' -o tsv)
echo "PUBLIC_IP=$PUBLIC_IP"

# wait 2–5 minutes for first-boot, then:
ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@$PUBLIC_IP
```

Verify: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)

---

## 5) Portal-only path (summary)

1. Build `.vhd` on the RHEL 10 builder (section 1).  
2. Azure Portal: create RG → Storage account → container → upload VHD as **page blob**.  
3. **Images** → Create → Linux, **Gen 2**, point at the blob.  
4. **Create VM** from the image; username `fladmin1`; existing SSH public key from the blueprint.  
5. NSG inbound: **2222** and **35443** from your IP (not default 22).  
6. SSH: `ssh -i ~/.ssh/fedora-lane-lab -p 2222 fladmin1@PUBLIC_IP`

Step-by-step Portal notes: [15-azure-vhd-upload.md](15-azure-vhd-upload.md) Parts 2, 4–7.
