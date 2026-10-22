# PPT outline — Fedora Lane RHEL 10 Gold Image

**File (local):** `docs/Fedora-Lane-RHEL-Gold-Image-FASTER.pptx` (gitignored)  
**Sources:** Fedora Lane **Core Pack** + **Server/Cloud OS Expansion Pack**

| # | Slide | Pack data used |
|---|--------|----------------|
| 1 | Title | Junior Consultant · Server/Cloud OS TDP |
| 2 | **Customer needs** | Core: ~1,600 servers (900/600/100), AWS primary / Azure secondary, PCI DSS / GDPR / CCPA, 30-day CVE patch, least privilege, encryption, quarterly scans; stakeholder needs (Anya, Alex, Casey, Ren, Cameron) |
| 3 | Three technical challenges | Expansion: inconsistent estate; untraceable changes; container skills gap (+ pack examples) |
| 4 | Agenda | Core Pack 15‑min Junior Consultant flow |
| 5 | Exact configuration | Expansion gold-image specs in TOML (partitions, SELinux, ports, admins, httpd container, ami/vhd) |
| 6 | **What we solved using the configuration** | Challenge → TOML/first-boot control → outcome for all 3 challenges |
| 7 | Config detail → issue prevented | Each Expansion control → operational/security issue avoided |
| 8 | Architecture | TOML → IB → disk → cloud image → VM (AWS + Azure) |
| 9 | Local Image Builder | Expansion: manual / not hosted IB |
| 10 | AWS path | Expansion §6 upload + provision |
| 11 | Live walkthrough | Expansion prove configs + survive reboot |
| 12 | Stakeholders | Core Pack personas |
| 13 | Next step | Core Pack closing — one concrete next step |
| 14 | Close | Core message + Q&A |
