<div align="center">

<img src="assets/banner.svg" alt="TrinetLayer — Bug-Hunting Skills for Claude Code" width="100%">

<br>

[![Validate](https://github.com/trinetlayer/claude-HunterSkills/actions/workflows/validate.yml/badge.svg)](https://github.com/trinetlayer/claude-HunterSkills/actions/workflows/validate.yml)
[![License](https://img.shields.io/badge/license-MIT-6366F1?style=flat-square)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-9-22D3EE?style=flat-square)](#the-nine-skills)
[![For](https://img.shields.io/badge/for-Claude%20Code-818CF8?style=flat-square)](https://claude.com/claude-code)
![Coverage](https://img.shields.io/badge/coverage-6%20surfaces-0B1220?style=flat-square&labelColor=6366F1)
[![Use](https://img.shields.io/badge/use-authorized%20only-EF4444?style=flat-square)](#authorized-use-only)
![Plugin](https://img.shields.io/badge/plugin-marketplace%20ready-34D399?style=flat-square)

### Turn Claude into a disciplined bug-bounty & pentest co-pilot.

Nine model-invoked [Claude Code](https://claude.com/claude-code) skills — web app, API, source-code
review, Android, iOS, and **EVM · Solana · Move** smart contracts — plus bundled recon automation, tied
together by an orchestrator that keeps every engagement **authorized, in-scope, and reportable**.

<br>

```bash
git clone https://github.com/trinetlayer/claude-HunterSkills.git && cd claude-HunterSkills && ./install.sh
```

<sub>Built by <a href="https://app.trinetlayer.com"><b>TrinetLayer</b></a> — the Attack Surface Lab for bug bounty hunters · <a href="USAGE.md">Usage guide</a> · <a href="#install">Install</a> · <a href="#the-nine-skills">Skills</a></sub>

</div>

---

## Why this exists

Claude is already a strong security reasoner — but out of the box it improvises. It doesn't know your
program's rules, it re-derives methodology from scratch every session, and it will happily write up a
missing-header "finding" that gets your report closed as informational.

These skills fix that. Each one loads a real practitioner's playbook the moment your task matches it:
the recon commands, the payloads that actually land in 2025, the false-positives to never submit, and
a validation ladder every finding has to climb before it reaches a report. You describe the target;
the right skill brings the discipline.

> **This is a force multiplier for methodical, authorized testing — not an autonomous exploit bot.**
> It won't touch anything out of scope, and with no scope it refuses to test at all.

---

## The nine skills

<div align="center">
<img src="assets/surface-map.svg" alt="The orchestrator routes each request to the matching skill" width="92%">
</div>

| | Skill | Reach for it when… | Signature classes |
|---|---|---|---|
| <img src="assets/icons/orchestrator.svg" width="24" alt=""> | **bug-hunting-orchestrator** | You're starting out, or not sure which skill fits | Scope check · routing · methodology |
| <img src="assets/icons/web.svg" width="24" alt=""> | **web-app-pentest** | Testing a website, SPA, dashboard or login flow | IDOR/BOLA · XSS · SSRF (IMDSv2) · SQLi · SSTI · auth & logic · chains |
| <img src="assets/icons/api.svg" width="24" alt=""> | **api-security-testing** | Testing REST / GraphQL / gRPC | OWASP API Top 10 · BOLA/BFLA · JWT · mass assignment · GraphQL DoS |
| <img src="assets/icons/source.svg" width="24" alt=""> | **source-code-review** | Auditing a repo, PR or diff | source→sink SAST · secrets · dependency confusion · CI/CD injection · crypto misuse |
| <img src="assets/icons/android.svg" width="24" alt=""> | **android-pentest** | Testing an Android app / APK | MASVS · exported components · insecure storage · Flutter/RN traffic · pinning bypass |
| <img src="assets/icons/ios.svg" width="24" alt=""> | **ios-pentest** | Testing an iOS app / IPA | Keychain · ATS · URL schemes · WebView bridges · TrollStore · pinning bypass |
| <img src="assets/icons/contract.svg" width="24" alt=""> | **smart-contract-audit** | Auditing **EVM** Solidity / DeFi | reentrancy · oracle manipulation · access control · L2/cross-chain · Foundry PoC |
| <img src="assets/icons/solana.svg" width="24" alt=""> | **solana-audit** | Auditing **Solana** / Anchor (Rust) | missing signer/owner · type-cosplay · arbitrary CPI · PDA bump · sysvar spoof · litesvm PoC |
| <img src="assets/icons/move.svg" width="24" alt=""> | **move-audit** | Auditing **Move** — Sui / Aptos | capability & visibility · owned-vs-shared objects · hot-potato · witness confusion · Move Prover |

**50+ vulnerability classes** across Web2, mobile, and Web3 (EVM · Solana · Move) — each with
how-to-test steps, payload/command-level detail, and a never-submit list. All nine share one rulebook
([`skills/shared/RULES.md`](skills/shared/RULES.md)) — and load payload/PoC libraries from each skill's
`references/` on demand.

---

## Authorized use only

<img src="assets/icons/shield.svg" width="18" align="top" alt="!"> These skills are for security work you're **allowed** to do: your own assets, in-scope bug-bounty
programs, and signed penetration tests. Every skill opens with an **authorization gate** and enforces
the shared rules — no out-of-scope targets, no DoS, no credential spraying without written approval,
minimal handling of real data.

If you can't show authorization, the skills drop to **passive / advisory mode**: methodology, static
review of code you paste, payload design, and report drafting — no active testing. You are responsible
for staying inside the law and your program's rules.

---

## How it works

Claude Code **Skills** are *model-invoked*: Claude reads each skill's short description and pulls in the
full playbook only when your task matches. You don't memorize commands — you describe the goal, and the
matching skill loads its recon steps, checklists, payloads and reporting format on demand.

<div align="center">
<img src="assets/workflow.svg" alt="Map, Prioritize, Probe, Prove, Report — with the eight-rung Trinet Validation Ladder" width="100%">
</div>

### See it in action

<div align="center">
<img src="assets/terminal.svg" alt="A Claude Code session using web-app-pentest to confirm and validate a BOLA finding" width="94%">
</div>

---

## Automation, not just advice

These skills don't only *describe* the work — they can run it. Bundled, scope-gated scripts execute from
the Map phase (pre-approved via `allowed-tools`, so no permission prompt), each skipping any tool you
don't have and timing out rather than hanging.

- **`scripts/recon.sh`** — `subfinder → httpx → katana → gau → nuclei` with per-tool timeouts, writing a
  structured run dir. → `bash scripts/recon.sh <target> --yes-authorized`
- **`scripts/ghostjs-scan.sh`** — a **real** TrinetLayer `/api/v1` GhostJS JS-secret + npm
  dependency-confusion scan. → `TRINETLAYER_API_KEY=gjs_… bash scripts/ghostjs-scan.sh <target> --dc`
- **`recon-runner`** subagent — runs recon and returns a *ranked attack surface*, keeping the noise out
  of your main session.
- **Slash commands** — `/recon <target>`, `/validate` (run a finding up the Trinet Validation Ladder),
  `/report` (impact-first write-up).

Everything recon surfaces is a **lead** — nothing is a finding until it climbs the Validation Ladder.

---

## Set up in one message

New to Claude Code, or want the whole hunting environment (skills **plus** the recommended tooling)
configured for you? Don't wire it up by hand — hand Claude the guide and let it drive.

Paste this into Claude Code:

```text
Read https://trinetlayer.com/blogs/claude-code-setup-for-bug-hunters
and set up my Claude Code bug-hunting environment — install the TrinetLayer
skills and walk me through the rest.
```

Claude reads TrinetLayer's **[Claude Code setup guide for bug hunters](https://trinetlayer.com/blogs/claude-code-setup-for-bug-hunters)**,
installs these skills, and takes you from zero to hunting. Prefer to do it yourself? The manual steps
are right below.

---

## Install

<details open>
<summary><b>Option A — installer script</b> (personal, global — recommended)</summary>

```bash
git clone https://github.com/trinetlayer/claude-HunterSkills.git
cd claude-HunterSkills
./install.sh            # copy into ~/.claude/skills
# or
./install.sh --link     # symlink instead, so `git pull` auto-updates
```
</details>

<details>
<summary><b>Option B — Claude Code plugin marketplace</b></summary>

```
/plugin marketplace add trinetlayer/claude-HunterSkills
/plugin install trinetlayer-bug-hunting@trinetlayer
```
</details>

<details>
<summary><b>Option C — project-scoped</b> (one engagement only)</summary>

```bash
./install.sh --project /path/to/your/engagement   # installs into <project>/.claude/skills
```
</details>

Then start a fresh Claude Code session and just describe the task. To remove everything:
`./install.sh --uninstall`.

---

## Usage in 60 seconds

Lead with your scope — the orchestrator will ask for it if you don't.

```text
"Test app.acme.com for IDOR — it's in scope on their HackerOne program."
"Audit this lending protocol's Solidity for reentrancy and oracle bugs."
"Security-review this pull request for injection and authz gaps."
"Pentest my Android APK — check storage and exported components."
```

| You say… | Skill that loads |
|---|---|
| "Find access-control bugs on this in-scope web app" | web-app-pentest |
| "Test this GraphQL API for BOLA and introspection" | api-security-testing |
| "Audit this IPA's keychain and URL-scheme handling" | ios-pentest |
| "Assess this company — web, API and a repo are in scope" | orchestrator → several |

Full walkthrough, tips, and the two-account trick for access-control bugs → **[USAGE.md](USAGE.md)**.

---

## Under the hood

One rulebook drives all seven skills — [`skills/shared/RULES.md`](skills/shared/RULES.md):

- **Authorization gate** — written scope first, or passive/advisory mode only.
- **Workflow** — *Map → Prioritize → Probe → Prove → Report*, highest-impact classes first.
- **Trinet Validation Ladder** — eight rungs (*real class · reachable · exploitable now · concrete
  impact · in scope · reproducible · not a duplicate · evidence captured*). If a finding can't climb
  all eight, it isn't ready. This is what protects your signal on bounty platforms.
- **Impact-first report format** — with HackerOne / Bugcrowd / Intigriti / Immunefi templates.

---

## TrinetLayer accelerators

Optional — the skills work fully on their own, but they'll lean on TrinetLayer's tooling when it helps:

- **[GhostJS](https://app.trinetlayer.com)** — JavaScript recon + secret scanning (subdomain
  enumeration, source-map/bundle analysis) for the Map phase.
- **Ghost AI** — AI-enhanced analysis of findings.
- **Dependency Confusion** engine — npm dependency-confusion detection during source review & recon.
- **VAPT PDF reports** — export validated findings as a client-ready deliverable.

---

## Ecosystem

Part of the wider TrinetLayer world — *learn → hunt → test → automate → challenge*:

[**App**](https://app.trinetlayer.com) · [**Learn**](https://learn.trinetlayer.com) ·
[**Validator**](https://validator.trinetlayer.com) · [**Blog**](https://trinetlayer.com/blogs) ·
[**Community**](https://trinetlayer.discourse.group)

---

## Contributing

Issues and PRs welcome — new vuln-class coverage, tool/payload updates, platform report templates, and
fixes. Accuracy over volume; keep the responsible-use framing and the shared rulebook intact. See
**[CONTRIBUTING.md](CONTRIBUTING.md)** for the skill format and ground rules,
**[SECURITY.md](SECURITY.md)** for responsible use, and **[CHANGELOG.md](CHANGELOG.md)** for release
history.

## License

[MIT](LICENSE) © 2026 TrinetLayer. Provided for **authorized, lawful** security testing only, with no
warranty. What you point it at is on you.

<div align="center"><sub><code>break. test. learn.</code></sub></div>
