# Legacy note: `composer-cli` / Weldr socket

This project’s **current** path on RHEL 10 is the **`image-builder`** CLI:

```bash
sudo dnf install -y image-builder cockpit-image-builder
sudo image-builder build ami --blueprint ./fedora-lane-gold.toml --distro rhel-10
```

See [08-rhel10-rebuild.md](08-rhel10-rebuild.md) and [README.md](README.md).

---

## If you still use old `composer-cli`

Older Image Builder stacks used `osbuild-composer` + `composer-cli` and required membership in the **`weldr`** group to access `/run/weldr/api.socket`.

```text
ERROR: you do not have permission to access /run/weldr/api.socket
```

Fix (legacy only):

```bash
sudo systemctl enable --now osbuild-composer.socket
sudo usermod -aG weldr "$USER"
# log out / SSH again, or: newgrp weldr
id | grep weldr
composer-cli status show
```

Prefer migrating to **`image-builder`** on RHEL 10 instead of staying on `composer-cli`.
