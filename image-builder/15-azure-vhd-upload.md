# Azure VHD with Image Builder

Same blueprint (`fedora-lane-gold.toml`, `distro = "rhel-10.0"`).  
Image type: **`vhd`**.

**Official Red Hat:**  
[Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) ·  
[Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

Do **not** commit `.vhd` files to Git.

---

## Which version can `upload --to=azure`?

| Where | Typical `image-builder` RPM | `upload --to=azure` / `--azure-*` |
|-------|----------------------------|-----------------------------------|
| **RHEL 10** AppStream (this lab) | ~31–**77.x** | **No** — your `upload --help` matches this |
| **CentOS Stream 10** AppStream | up to ~**77.0.0** | **No** |
| **Fedora 43/44** (updates) | ~**85.x** | **Yes** (service principal flags; documented upstream by v86) |
| **Fedora 45** testing / **Rawhide** | **87.0.0+** | **Yes** + can reuse `az login` (no SP required) |
| Upstream [osbuild/image-builder](https://github.com/osbuild/image-builder/releases) | **≥ 86** (SP), **≥ 87** (CLI creds, 2026-10-14) | **Yes** |

Check on the builder:

```bash
rpm -q image-builder
image-builder version
sudo image-builder upload --help | grep -i azure || echo "no Azure upload on this RPM"
```

RHEL 10 docs still describe build **`vhd`** then publish with Azure tooling / `azure.toml` flow — not `upload --to=azure`:  
[Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure).

On current RHEL 10 packages, Image Builder only **builds** the VHD:

```bash
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
df -h /var   # need ≥ 15–20 GiB free

cd /path/to/fedora-lane-rhel-gold-image/image-builder

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog

ls -lh ./*.vhd
```

Publishing that `.vhd` into Azure (storage, managed image, VM) is outside `image-builder upload` on this RPM — follow the [Red Hat Azure VHD chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) after the build.

Copy-paste: [16-azure-examples.md](16-azure-examples.md)

---

## Related

- AWS upload (supported by `image-builder upload --to=aws`): [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)  
- Official RH index: [docs/redhat-documentation.md](../docs/redhat-documentation.md)
