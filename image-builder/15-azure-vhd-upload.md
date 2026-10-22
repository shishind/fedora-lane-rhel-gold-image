# Publish the gold disk to Microsoft Azure (Image Builder)

Same blueprint (`fedora-lane-gold.toml`, `distro = "rhel-10.0"`).  
Image type: **`vhd`**.

**Official Red Hat:**  
[Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) ·  
[Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

Do **not** commit `azure.toml` (secrets) or `.vhd` files to Git.

Confirm VHD support and free space (`/var` ≥ **15–20 GiB**):

```bash
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
df -h /var
```

---

## 1) Build the VHD (local)

```bash
cd /path/to/fedora-lane-rhel-gold-image/image-builder

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
```

---

## 2) Upload with Image Builder (`azure.toml`)

Red Hat’s Image Builder Azure upload uses an **`azure.toml`** upload config  
([same VHD chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)).  
Create it **only on the builder** (storage account + key + container must already exist in Azure):

```bash
# LOCAL ONLY — never commit
cat > /tmp/azure.toml <<EOF
provider = "azure"

[settings]
storageAccount = "YOUR_STORAGE_ACCOUNT"
storageAccessKey = "YOUR_STORAGE_ACCESS_KEY"
container = "YOUR_CONTAINER"
EOF
chmod 600 /tmp/azure.toml
```

**Red Hat documented build + upload form:**

```bash
sudo image-builder build ./fedora-lane-gold.toml vhd fedora-lane-rhel10-gold /tmp/azure.toml
```

On current RHEL 10 packages the flagged form is preferred for compose; confirm how your RPM accepts the upload file:

```bash
sudo image-builder build --help
sudo image-builder upload --help
```

**If `upload --help` lists `--to=azure` / `--azure-*`**, you can push an existing `.vhd` with Image Builder:

```bash
export VHD_FILE=./$(ls -1t ./*.vhd | head -1)

sudo image-builder upload \
  "$VHD_FILE" \
  --to=azure \
  --azure-tenant "$AZ_TENANT" \
  --azure-subscription "$AZ_SUB" \
  --azure-client-id "$AZ_CLIENT_ID" \
  --azure-client-secret "$AZ_CLIENT_SECRET" \
  --azure-resource-group "$AZ_RG" \
  --azure-image-name fedora-lane-rhel10-gold \
  --arch x86_64
```

Many RHEL 10 RPMs do **not** include `--azure-*` yet (`unknown flag: --azure-tenant`). In that case use the **`azure.toml`** build command above (Red Hat), not `upload --to=azure`.

Copy-paste sheet: [16-azure-examples.md](16-azure-examples.md)

---

## Related

- Examples: [16-azure-examples.md](16-azure-examples.md)  
- AWS Image Builder upload: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)  
- Official RH index: [docs/redhat-documentation.md](../docs/redhat-documentation.md)
