# Local RHEL Image Builder (RHEL 10 CLI)

Fedora Lane’s gold image is built with **local** RHEL Image Builder on a RHEL 10 host — package `image-builder`, command `image-builder`.

Official docs:

- [Composing a customized RHEL system image (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index)
- [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)
- [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)
- [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure)
- [Deploying and managing RHEL on Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/index)
- Azure CLI install on RHEL 10 (Microsoft Learn — RH chapter yum URL 404s): [Install Azure CLI on Linux](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux)

Do **not** use the hosted Image Builder service on console.redhat.com for this standard.

**End-to-end (AWS + Azure):** [docs/00-end-to-end-guide.md](../docs/00-end-to-end-guide.md)

> **Note:** Older guides used `composer-cli` + `osbuild-composer` (Weldr). On RHEL 10, use the current **`image-builder`** CLI below. The blueprint TOML format stays the same.

## Blueprint

`fedora-lane-gold.toml` — packages, mounts, users, firewall, SSH, first-boot Podman httpd.

**Create / customize the TOML** (how this file was built, step-by-step create guide, full customization catalog for your team):  
→ [10-create-toml-blueprint.md](10-create-toml-blueprint.md)

## Install (RHEL 10 builder)

Host must be subscribed (BaseOS + AppStream) and able to reach Red Hat CDN.

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list --filter "distro:rhel-10*"
# expect lines like: rhel-10.0 type:ami arch:x86_64
```

Run builds as **root** (`sudo`), per Red Hat documentation.

CDN / subscription problems: [11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)

## Build the gold image

```bash
cd /path/to/image-builder   # directory with fedora-lane-gold.toml

# Confirm exact distro id (e.g. rhel-10.0 — NOT bare rhel-10)
sudo image-builder list --filter "type:ami" --filter "distro:rhel-10*"

# Build AWS disk image (ami type). Output is typically a .raw under the working directory.
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

**Build + upload to AWS in one command (example):**

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --aws-region us-east-2 \
  --aws-bucket YOUR_S3_BUCKET \
  --aws-ami-name fedora-lane-rhel10-gold
```

**Upload an existing `.raw` (preferred — creates snapshot + AMI):**

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

Full example sheet: [13-image-builder-aws-examples.md](13-image-builder-aws-examples.md)  
Narrative + alternate manual path: [12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)
## Build + publish to Azure (`vhd`)

Confirm VHD support and free space on `/var` (**≥ 15–20 GiB**):

```bash
sudo image-builder list --filter "type:vhd" --filter "distro:rhel-10*"
df -h /var

sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --with-buildlog
```

**Preferred — upload existing `.vhd` (creates managed image):**

```bash
sudo image-builder upload \
  ./*.vhd \
  --to=azure \
  --azure-tenant "$AZ_TENANT" \
  --azure-subscription "$AZ_SUB" \
  --azure-client-id "$AZ_CLIENT_ID" \
  --azure-client-secret "$AZ_CLIENT_SECRET" \
  --azure-resource-group fedora-lane-gold-rg \
  --azure-image-name fedora-lane-rhel10-gold \
  --arch x86_64
```

**Build + upload to Azure in one command:**

```bash
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10.0 \
  --azure-tenant "$AZ_TENANT" \
  --azure-subscription "$AZ_SUB" \
  --azure-client-id "$AZ_CLIENT_ID" \
  --azure-client-secret "$AZ_CLIENT_SECRET" \
  --azure-resource-group fedora-lane-gold-rg \
  --azure-image-name fedora-lane-rhel10-gold
```

Needs a resource group + Azure service principal (see [15](15-azure-vhd-upload.md)).  
Alternate: page-blob `az` upload → Gen2 image. Then NSG **2222**/**35443** → VM → SSH.

**Detailed Azure guide:** [15-azure-vhd-upload.md](15-azure-vhd-upload.md)  
**Azure examples:** [16-azure-examples.md](16-azure-examples.md)

## Full rebuild guide

[08-rhel10-rebuild.md](08-rhel10-rebuild.md)

## Spec coverage

| Requirement | In TOML / first-boot |
|-------------|----------------------|
| Separate `/var/log` `/home` `/tmp` `/var/tmp` | `customizations.filesystem` |
| SELinux enforcing | first-boot script |
| `/tmp` noexec | first-boot fstab |
| SSH 2222, no root, no password | sshd drop-in |
| httpd container :35443 | first-boot Podman + systemd |
| fladmins + sudo password | users + sudoers.d |
| Firewall only SSH+httpd | firewall + first-boot |
| Survive reboot | systemd units enabled |
| AWS + Azure | `ami` and `vhd` image types |

Verify after launch: [docs/08-verify-customizations.md](../docs/08-verify-customizations.md)
