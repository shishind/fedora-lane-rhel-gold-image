# Red Hat documentation (official)

Curated links for this Fedora Lane **RHEL 10 gold image** solution.  
Use these in the README, solution overview, and live presentation (“per Red Hat documentation…”).

> **Note for FASTER:** Prefer **local** Image Builder on a RHEL 10 host. Do **not** use the hosted Image Builder cloud service for this practice activity.

---

## 1. Image Builder (build the gold image)

| Topic | Document |
|-------|----------|
| Image Builder overview + output types (`ami`, `vhd`, `qcow2`, …) | [Composing a customized RHEL system image (RHEL 10)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/index) |
| Install Image Builder + Cockpit plugin | [Installing RHEL image builder](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/installing-rhel-image-builder) |
| Build images with the CLI | [Creating system images using the RHEL image builder CLI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-image-builder-cli) |
| Build images in Web Console (Cockpit) | [Creating system images using the web console](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-system-images-with-gui) |
| Prepare / upload AMI to AWS (from Image Builder guide) | [Preparing and uploading AMI images to AWS](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/preparing-and-uploading-ami-images-to-aws) |
| Single-page book (printable/searchable) | [Composing a customized RHEL system image (html-single)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html-single/composing_a_customized_rhel_system_image/index) |

**Why it matters for Fedora Lane:** defines the **repeatable** gold standard (`distro = "rhel-10"` blueprint) instead of snowflake servers.

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

## 3. Azure stretch goal

| Topic | Document |
|-------|----------|
| Deploying RHEL on Azure (RHEL 10) | [Deploying and managing RHEL on Microsoft Azure](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/deploying_and_managing_rhel_on_microsoft_azure/index) |

Image type in Image Builder: `vhd` (see output formats table in the composing guide above).

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

Gold AMI firewall still allows only **2222** and **35443** (Expansion Pack).  
For GUI demos, use RHDP **RHEL 10 Base** (Web Console preinstalled).

| Topic | Document |
|-------|----------|
| Managing systems with the RHEL web console | [Managing systems using the RHEL 10 web console](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_systems_using_the_rhel_10_web_console/index) |
| Session recording (search within Security / Recording docs for your minor release) | [Recording sessions (RHEL documentation portal search)](https://docs.redhat.com/en/search/?advanced=true&product=Red%20Hat%20Enterprise%20Linux&q=session%20recording) |

Lab guide in this repo: [07-rhel10-web-console-demo.md](07-rhel10-web-console-demo.md)

---

## 7. How to cite these in the presentation

Example lines:

- “Per Red Hat’s *Composing a customized RHEL system image* guide, we define a RHEL 10 blueprint and build locally.”  
- “Per *Deploying RHEL on AWS*, we publish the disk as an AMI and launch EC2 for proof.”  
- “Containers follow *Building, running, and managing containers* — httpd as a systemd-managed Podman service.”

---

## Quick map: our repo → Red Hat books

| This repository | Red Hat book |
|-----------------|--------------|
| `image-builder/fedora-lane-gold.toml` | Composing a customized RHEL system image |
| AWS upload / EC2 proof | Deploying and managing RHEL on AWS |
| `verify/verify.sh` + hardening | SELinux, firewalls, OpenSSH guides |
| Podman httpd unit | Building, running, and managing containers |
| Optional Cockpit demo | Managing systems using the RHEL 10 web console |
