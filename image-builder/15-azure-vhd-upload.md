# Azure VHD with Image Builder

Same blueprint (`fedora-lane-gold.toml`, `distro = "rhel-10.0"`).  
Image type: **`vhd`**.

**Official Red Hat:**  
[Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) ·  
[Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)

Do **not** commit `.vhd` files to Git.

---

## Image Builder command (Azure)

On current RHEL 10 packages, **`image-builder upload` does not support Azure**.  
`sudo image-builder upload --help` lists clouds such as **aws**, **ibmcloud**, **libvirt**, **openstack** — there are **no** `--azure-*` flags and no `--to=azure`.

For Azure, Image Builder only **builds** the VHD:

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
