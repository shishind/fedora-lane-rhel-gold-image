# Image Builder + Azure — Image Builder commands only

| Variable | Example |
|----------|---------|
| Blueprint | `./fedora-lane-gold.toml` |
| Distro | `rhel-10.0` |
| Upload config | `/tmp/azure.toml` (do not commit) |
| Image key / name | `fedora-lane-rhel10-gold` |

Official: [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)

Narrative: [15-azure-vhd-upload.md](15-azure-vhd-upload.md)

---

## Setup (Image Builder)

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
df -h /var
sudo image-builder build --help
sudo image-builder upload --help
```

---

## Build VHD only

```bash
cd /path/to/fedora-lane-rhel-gold-image/image-builder

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
```

---

## Upload with Image Builder (`azure.toml`)

```bash
# LOCAL ONLY — replace with your Azure storage values; never commit
cat > /tmp/azure.toml <<EOF
provider = "azure"

[settings]
storageAccount = "YOUR_STORAGE_ACCOUNT"
storageAccessKey = "YOUR_STORAGE_ACCESS_KEY"
container = "YOUR_CONTAINER"
EOF
chmod 600 /tmp/azure.toml
```

**Red Hat Image Builder upload command:**

```bash
sudo image-builder build ./fedora-lane-gold.toml vhd fedora-lane-rhel10-gold /tmp/azure.toml
```

---

## Upload with Image Builder (`upload --to=azure`) — only if flags exist

```bash
sudo image-builder upload --help   # must list --azure-tenant / --to=azure

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

If you see `unknown flag: --azure-tenant`, use the **`azure.toml`** command above instead.
