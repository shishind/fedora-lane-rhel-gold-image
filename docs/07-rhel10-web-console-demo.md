# RHEL 10 Web Console — day-2 operations (Fedora Lane)

Optional follow-on to the gold AMI: show how operations manage RHEL 10 with the **Web Console** (Cockpit), including overview, logs, containers, and session recording.

The **gold AMI** keeps firewall open only for **2222** and **35443**. Use a separate RHEL 10 management host (or temporarily open Cockpit on a non-gold lab node) for this GUI story.

## Why Web Console

| Need | Web Console |
|------|-------------|
| Consistent day-2 UI for Linux ops | Overview, services, networking, logs |
| Container skills gap | Containers page for Podman workloads |
| Untraceable changes | Session Recording for admin review |

## Demo outline

1. Log in to Web Console on a RHEL 10 host.  
2. **Overview** — health, updates story for a standard RHEL 10 node.  
3. **Logs** — find recent admin or service events.  
4. **Containers** — show Podman-managed workloads (aligns with gold httpd service model).  
5. **Session Recording** — play back an admin session (if enabled on that host).

## Tie-back to the gold image

1. **Build:** Local Image Builder TOML → **RHEL 10** gold AMI.  
2. **Operate:** Web Console is how Fedora Lane *manages* that standard at scale.

## Verification before a stakeholder walkthrough

- [ ] RHEL 10 host ready  
- [ ] Web Console login works from the operator workstation  
- [ ] Overview + Logs work  
- [ ] Session Recording playback works (if in scope)  
- [ ] Containers page visible  

Never commit Web Console or cloud passwords to git.
