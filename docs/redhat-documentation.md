# Red Hat documentation (official)

Curated links for this Fedora Lane **RHEL 10 gold image** solution.  
Use these in the README and solution overview when citing official Red Hat guidance.

> Prefer **local** Image Builder on a RHEL 10 host. Do **not** use the hosted Image Builder cloud service for this gold-image standard.

---

## 1. Image Builder (build the gold image)

| Topic | Document |
|-------|----------|
| Image Builder overview + output types (`ami`, `vhd`, `qcow2`, …) | [Composing a customized RHEL system image (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index) |
| Install Image Builder (`dnf install image-builder`) | [Installing RHEL image builder](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index) (Chapter 2) |
| Build images with the **`image-builder` CLI** | [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli) |
| Blueprint customizations (users, firewall, filesystems, …) | [Supported image customizations](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/supported-image-customizations) |
| How we create/edit the TOML in this repo | [image-builder/10-create-toml-blueprint.md](../image-builder/10-create-toml-blueprint.md) |
| Build images in Web Console (Cockpit) | [Creating system images using the web console](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-gui) |
| Prepare / upload AMI to AWS (from Image Builder guide) | [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws) |
| Prepare / upload VHD to Microsoft Azure | [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) |
| Single-page book (printable/searchable) | [Composing a customized RHEL system image (html-single)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html-single/composing_a_customized_rhel_system_image/index) |

**Why it matters for Fedora Lane:** defines the **repeatable** gold standard (`distro = "rhel-10.0"` exact id in blueprint) instead of snowflake servers.

---

## 2. Deploy RHEL on AWS (publish + run the AMI)

| Topic | Document |
|-------|----------|
| Deploying RHEL on AWS (book) | [Deploying and managing RHEL on Amazon Web Services (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_amazon_web_services/index) |
| Prepare and upload AMI | [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_amazon_web_services/preparing-and-uploading-ami-images-to-aws) |
| Launch as EC2 instance | [Deploying a RHEL image as an EC2 instance on AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_amazon_web_services/deploying-a-rhel-image-as-an-ec2-instance-on-aws) |
| Single-page book | [Deploying and managing RHEL on AWS (html-single)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html-single/deploying_and_managing_rhel_on_amazon_web_services/index) |

**Why it matters:** S3 → snapshot/AMI → EC2 is how the gold disk becomes a **launchable** web node.

**Related (AWS, not Red Hat):** [VM Import/Export – required `vmimport` role](https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html)

---

## 3. Deploy RHEL on Azure (publish + run the VHD)

| Topic | Document |
|-------|----------|
| Deploying RHEL on Azure (book) | [Deploying and managing RHEL on Microsoft Azure (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/index) |
| Prepare and upload VHD | [Preparing and uploading VHD images to Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/preparing-and-uploading-vhd-images-to-microsoft-azure) |
| Same chapter in Image Builder book | [Preparing and uploading VHD images to Microsoft Azure (composing guide)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-vhd-images-to-microsoft-azure) |
| Build CLI (`image-builder build vhd`) | [Creating system images with the CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-cli) |

Image type in Image Builder: **`vhd`**. Customer steps in this repo: [image-builder/15-azure-vhd-upload.md](../image-builder/15-azure-vhd-upload.md)  
(**Preferred push on RHEL 10:** `az storage blob upload --type page` + `az image create`. `--azure-*` on `image-builder upload` is often not in the RPM yet.)

**Notes vs live RHEL 10 packages (keep our lab guides when RH text differs):**

| Topic | Red Hat chapter says | Use in this lab |
|-------|----------------------|-----------------|
| Azure CLI yum repo | Hand-written `…/yumrepos/…/rhel/10/prod/` | **404** — use [Microsoft Learn RHEL 10 install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux) (`packages-microsoft-prod.rpm`) — [15 Part 1](../image-builder/15-azure-vhd-upload.md) |
| `image-builder build` for VHD | Older positional `build <bp> vhd <key> azure.toml` | Current flags: `build vhd --blueprint … --distro rhel-10.0` (same style as [AMI chapter](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws)) |
| `image-builder upload --to=azure` | Upstream may have `--azure-*` | Many RHEL 10 RPMs: **no** `--azure-*` (`unknown flag: --azure-tenant`) → use `az` page blob |
| Managed image Gen | Text: use `--hyper-v-generation`; example may omit it | Always pass `--hyper-v-generation V2` + `--location` |
| Page blob | `--type page` | Required — preferred publish path |

VHD compose, page-blob upload, and image create still follow **Red Hat** procedure; only install/CLI syntax corrections above.

**Why it matters:** same TOML as AWS → Azure managed image → VM with NSG **2222**/**35443**.

---

## 4. Security controls used in the gold image

| Control in our AMI | Start here |
|--------------------|------------|
| SELinux | [Using SELinux (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_selinux/index) |
| `firewalld` | [Configuring firewalls and packet filters (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_firewalls_and_packet_filters/index) |
| OpenSSH server | [Using secure communications between two systems with OpenSSH](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/securing_networks/using-secure-communications-between-two-systems-with-openssh_securing-networks) |
| OpenSCAP / compliance (stretch) | [Security hardening / OpenSCAP scanning (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/security_hardening/scanning-the-system-for-configuration-compliance-and-vulnerabilities_security-hardening) |

---

## 5. Containers on RHEL (httpd in Podman)

| Topic | Document |
|-------|----------|
| Building / running / managing containers | [Building, running, and managing containers (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/building_running_and_managing_containers/index) |
| Podman systemd integration | See “Running containers as systemd services” in the containers guide above |

**Why it matters:** Challenge 3 — ops manage a **service**, not a fragile `podman run` paste.

---

## 6. Web Console / Session Recording (day-2 demo)

Gold AMI firewall still allows only **2222** and **35443**.  
For GUI operations demos, use a RHEL 10 host with Web Console installed (separate from the locked-down gold AMI firewall).

| Topic | Document |
|-------|----------|
| Managing systems with the RHEL web console | [Managing systems using the RHEL 10 web console](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_systems_using_the_rhel_10_web_console/index) |
| Session recording (search within Security / Recording docs for your minor release) | [Recording sessions (RHEL documentation portal search)](https://docs.redhat.com/en/search/?advanced=true&product=Red%20Hat%20Enterprise%20Linux&q=session%20recording) |

Lab guide in this repo: [07-rhel10-web-console-demo.md](07-rhel10-web-console-demo.md)

---

## Quick map: our repo → Red Hat books

| This repository | Red Hat book |
|-----------------|--------------|
| `image-builder/fedora-lane-gold.toml` | Composing a customized RHEL system image |
| AWS upload / EC2 proof | Deploying and managing RHEL on AWS |
| Azure VHD / VM proof | Deploying and managing RHEL on Microsoft Azure |
| `docs/00-end-to-end-guide.md` | Composing + AWS + Azure books |
| `verify/verify.sh` + hardening | SELinux, firewalls, OpenSSH guides |
| Podman httpd unit | Building, running, and managing containers |
| Optional Cockpit demo | Managing systems using the RHEL 10 web console |
