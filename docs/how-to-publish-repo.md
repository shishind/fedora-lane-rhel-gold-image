# How to publish this Git repository (FASTER)

Follow these steps so you and reviewers (and later the “customer” narrative) share one source of truth.

## 1) Local repo (already initialized)

```bash
cd ~/Projects/fedora-lane-rhel-gold-image
git status
git log --oneline -5
```

## 2) Preferred: Consulting GitLab (Core Pack)

1. Open your cohort’s sub-group under the **FASTER** group on Consulting GitLab.  
2. Create a **private** project, e.g. `fedora-lane-rhel-gold-image`.  
3. Copy the HTTPS or SSH clone URL.  
4. Push:

```bash
cd ~/Projects/fedora-lane-rhel-gold-image
git remote remove origin 2>/dev/null || true
git remote add origin <PASTE_GITLAB_URL>
git branch -M main
git push -u origin main
```

5. In GitLab → **Members** — add your manager/mentor as needed.  
6. Submit the **GitLab project URL** in your Part 1 form.

## 3) Alternate: private GitHub (Expansion Pack)

```bash
gh auth login
gh repo create fedora-lane-rhel-gold-image --private --source=. --remote=origin --push
gh api repos/$(gh api user -q .login)/fedora-lane-rhel-gold-image/collaborators/mflaim-eng \
  -X PUT -f permission=pull
```

## 4) Safety check before every push

```bash
git status
# Must NOT include: *.pem, .aws/, credentials, .raw disks, passwords
git grep -i 'aws_secret\|BEGIN OPENSSH\|AKIA' || echo "OK: no obvious secrets"
```

Install **rh-pre-commit** as required by the Expansion Pack.
