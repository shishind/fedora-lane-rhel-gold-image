# Publishing this repository

Keep this repository as the source of truth for the Fedora Lane RHEL 10 gold image (blueprint, docs, verify scripts).

## Push to your remote

```bash
cd ~/Projects/fedora-lane-rhel-gold-image
git remote -v
git push -u origin main
```

Use your organization’s Git hosting (GitLab, GitHub, etc.) and grant access to the Fedora Lane / Red Hat stakeholders who need it.

## Before every push

```bash
git status
# Must NOT include: *.pem, .aws/, credentials, .raw disks, passwords
git grep -i 'aws_secret\|BEGIN OPENSSH\|AKIA' || echo "OK: no obvious secrets"
```

Do not commit Access Keys, Secret Keys, session tokens, private SSH keys, or disk images.
