# Local RHEL Image Builder (RHEL 10 CLI)

Fedora Lane’s gold image is built with **local** RHEL Image Builder on a RHEL 10 host — package `image-builder`, command `image-builder`.

Official docs:

- [Composing a customized RHEL system image (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index)
- [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli)
- [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)

Do **not** use the hosted Image Builder service on console.redhat.com for this standard.

> **Note:** Older guides used `composer-cli` + `osbuild-composer` (Weldr). On RHEL 10, use the current **`image-builder`** CLI below. The blueprint TOML format stays the same.

## Blueprint

`fedora-lane-gold.toml` — packages, mounts, users, firewall, SSH, first-boot Podman httpd.

How the file is structured: [10-create-toml-blueprint.md](10-create-toml-blueprint.md)

## Install (RHEL 10 builder)

Host must be subscribed (BaseOS + AppStream) and able to reach Red Hat CDN.

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder list
sudo image-builder list-images --filter "distro:rhel-10"
```

Run builds as **root** (`sudo`), per Red Hat documentation.

CDN / subscription problems: [11-depsolve-cdn-repo-fix.md](11-depsolve-cdn-repo-fix.md)

## Build the gold image

```bash
cd /path/to/image-builder   # directory with fedora-lane-gold.toml

# Confirm distro id matches blueprint (distro = "rhel-10")
sudo image-builder list-images --filter "distro:rhel-10"

# Build AWS disk image (ami type). Output is typically a .raw under the working directory.
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10 \
  --with-buildlog
```

Optional: build and register in AWS in one flow (needs AWS credentials, S3 bucket, `vmimport` role):

```bash
sudo image-builder build ami \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10 \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

Or build locally, then upload an existing `.raw`:

```bash
sudo image-builder upload ./rhel-10*-ami-*.raw \
  --to=aws \
  --aws-region us-east-2 \
  --aws-bucket fedora-lane-gold-1792315114 \
  --aws-ami-name fedora-lane-rhel10-gold
```

Manual S3 + `import-snapshot` path (what we also documented):  
[12-aws-access-s3-upload.md](12-aws-access-s3-upload.md)

Azure stretch:

```bash
sudo image-builder build vhd \
  --blueprint ./fedora-lane-gold.toml \
  --distro rhel-10
```

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
