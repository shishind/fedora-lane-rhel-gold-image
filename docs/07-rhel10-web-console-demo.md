# RHEL 10 Web Console demo (RHDP) — Fedora Lane

Use this when your **live demonstration** is Web Console / Cockpit features on **RHEL 10**, as recommended in the Expansion Pack (Junior SA path).

> **Note:** Junior **Consultants** still deliver the **gold image** repo. Junior **SAs** focus on this value demo. If your POD expects both stories, use gold AMI for “standard image” and this RHDP RHEL 10 for Cockpit/Session Recording/containers GUI.

---

## Why RHEL 10 Base (RHDP)?

| Need | RHDP RHEL 10 Base |
|------|-------------------|
| Recommended in Expansion Pack | Yes |
| Web Console already installed | Yes |
| Good for Session Recording + containers GUI | Yes |
| Self-paced RHEL 10 lab included | Yes |

**Do not** use your old RHEL 9.4 gold AMI as the base for *this* Cockpit demo unless mentors say otherwise — order **RHEL 10 Base**.

---

## 1) Order the environment (RHDP)

1. Open [demo.redhat.com](https://demo.redhat.com)  
2. Order: **RHEL 10 Base**  
3. Order form:

| Field | Value |
|-------|--------|
| Activity | Practice/Enablement |
| Purpose | Learning about the product |
| Salesforce ID | not required |
| Everything else | defaults |

4. Wait until Ready (can take up to ~1 hour; often faster).  
5. **Extend lifetime/runtime** before your live call so it does not shut down mid-demo.

---

## 2) Open Web Console

From RHDP service details you typically get:

- Web Console URL (HTTPS, often port **9090**)  
- Username / password (or SSH + set password)

Browser → open Web Console → log in → accept cert if prompted.

**Tell the customer (Fedora Lane):**  
> “Web Console gives Casey’s Linux team one consistent GUI for health, updates, logs, and containers — instead of every region inventing its own scripts.”

---

## 3) Demo map → Fedora Lane challenges

| Challenge | Feature to show | What to say |
|-----------|-----------------|-------------|
| **1. Inconsistent estate / hard to manage** | Web Console overview + **Software Updates** / system health | One consistent management approach for patching and health across the fleet |
| **2. Untraceable admin changes** | **Session Recording** + review in Web Console | See who did what on a server; cut MTTR when checkout breaks after a “helpful” tweak |
| **3. Container skills gap** | **Containers** (Podman) in Web Console | Ops can view/start/stop containers in GUI — not only fragile `podman run` pastes |

Suggested order in the live call (**~5 minutes** for SA demo block):

1. Overview / health / logs (Challenge 1)  
2. Session Recording playback (Challenge 2)  
3. Containers page (Challenge 3)  

Use **tell → show → tell** on each.

---

## 4) Exact click-path (practice this)

### A) Consistent management (Challenge 1)

1. Web Console → **Overview** — CPU, memory, health  
2. **Logs** — show journal without SSH CLI mastery  
3. **Software updates** (or equivalent) — how a standard RHEL node is patched consistently  

**Line:** “Same console experience on every gold RHEL 10 node — Alex’s ops team stops reinventing regional runbooks.”

### B) Session Recording (Challenge 2)

1. Ensure Session Recording is enabled on the demo host (RHDP lab often covers this; follow the RHEL 10 self-paced lab if needed).  
2. Start a recorded session (SSH or console as directed by lab).  
3. Make a small visible change (e.g. edit a test file).  
4. Web Console → **Session Recording** (or Cockpit plugin) → open recording → playback.  

**Line:** “When checkout breaks after an emergency change, Ren and Alex can replay the admin session instead of guessing for four hours.”

### C) Containers via Web Console (Challenge 3)

1. Web Console → **Podman** / **Containers**  
2. Show running containers (or create/start a simple one if lab allows).  
3. Show logs / stop-start from GUI.  

**Line:** “Cameron’s team still ships containers; Casey’s team operates them from the same Web Console — no copy-paste `podman run` disasters.”

---

## 5) 15-minute SA talk track (if this is your whole demo)

| Time | Block |
|------|--------|
| 0–2 min | Opening: Fedora Lane 3 challenges + agenda |
| 2–7 min | Value: RHEL 10 + consistent management story |
| 7–12 min | Live Web Console demos (A→B→C above) |
| 12–15 min | Close: next step (pilot Web Console on gold RHEL 10 web nodes / Insights) |

---

## 6) If you are Junior Consultant (gold image + this demo)

Keep two clear stories:

1. **Build:** Local Image Builder TOML → **RHEL 10** gold AMI (rebuild host on RHEL 10).  
2. **Operate:** RHDP **RHEL 10 Base** Web Console shows how Fedora Lane *manages* that standard (patch, record sessions, containers GUI).

Do **not** mix “we built on 9.4” with “demo is RHEL 10” without saying so — rebuild gold on 10 **or** clearly label demo as “management plane on RHEL 10 Base.”

---

## 7) Timing / RHDP gotchas

- Environments **auto-shut down** — extend before Part 2.  
- Provision **the day before**; rehearse once on camera.  
- Have a backup: screenshots or short local recording if RHDP dies.  
- Never put RHDP passwords in git.

---

## 8) Quick verification before the call

- [ ] RHEL 10 Base Ready  
- [ ] Web Console login works from your laptop  
- [ ] Overview + Logs work  
- [ ] Session Recording playback works  
- [ ] Containers page visible  
- [ ] Lifetime extended past your slot  
- [ ] Opening/closing lines memorized (Fedora Lane challenges)
