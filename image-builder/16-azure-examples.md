# Image Builder + Azure — Image Builder commands only

| Variable | Example |
|----------|---------|
| Blueprint | `./fedora-lane-gold.toml` |
| Distro | `rhel-10.0` |

Official: [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)

Narrative: [15-azure-vhd-upload.md](15-azure-vhd-upload.md)

---

## Confirm: no Azure on `image-builder upload`

```bash
sudo image-builder upload --help
# Expect: --to, --aws-*, --ibmcloud-*, --libvirt-*, --openstack-*
# No --azure-* on RHEL 10 packages used in this lab
```

---

## Build VHD (only Image Builder step for Azure)

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
df -h /var

cd /path/to/fedora-lane-rhel-gold-image/image-builder

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
```

After the `.vhd` exists, Azure publish steps are in Red Hat’s VHD chapter (not `image-builder upload` on this RPM).
