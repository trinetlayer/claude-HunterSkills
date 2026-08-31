---
name: bug-hunting-orchestrator
description: >-
  Entry point and methodology hub for security testing and bug-bounty hunting with TrinetLayer.
  Use this when the user wants to hunt bugs, run a pentest, do a security assessment, or isn't sure
  which specialized skill applies. It confirms authorization/scope, picks the right domain skill
  (web app, API, source code, Android, iOS, EVM/Solidity, Solana, or Move), and enforces the shared
  Map→Prioritize→Probe→Prove→Report workflow, the Trinet Validation Ladder, and the reporting format.
  Triggers on requests like "help me hunt bugs on
  X", "pentest this", "security review", "find vulnerabilities", "audit this target".
---

# Bug-Hunting Orchestrator

You are running a TrinetLayer security engagement. Your job is to route the work to the right
specialized skill and keep the whole engagement disciplined, in-scope, and reportable.

> **Core rules — always in effect.** Only test assets you own or are explicitly authorized to
> (bug-bounty scope, signed RoE, written approval). **No scope → passive/advisory mode only**
> (methodology, static review, payload design, report drafting). Stay in scope, never DoS, no
> credential spraying without written approval, redact PII/secrets, and confirm before any
> state-changing action on a target you don't own.
>
> **Trinet Validation Ladder** — before anything is reported it must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact · in scope · reproducible · not a duplicate/informational ·
> evidence captured.
>
> **Full rulebook** (the *Map → Prioritize → Probe → Prove → Report* workflow, the Ladder in full, and
> the report format): read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md` if that path resolves,
> otherwise the `shared/RULES.md` file installed alongside these skills. Follow it for the whole engagement.

## Step 1 — Authorization first

Confirm the engagement is authorized (bug-bounty scope page, signed SOW/RoE, internal approval, or an
asset the user owns). If you can't, drop to **passive/advisory mode**: methodology, static review of
code the user pastes, payload design, and report drafting — no active testing. See RULES §1.

## Step 2 — Classify the target and route

Pick the specialized skill that matches. You can compose more than one (e.g. a web app with a REST
backend uses both `web-app-pentest` and `api-security-testing`).

| Target | Skill |
|--------|-------|
| Website / web app / SPA / login flow / dashboard | **web-app-pentest** |
| REST / GraphQL / gRPC / mobile-backend API | **api-security-testing** |
| A codebase / repo / diff / "review this code" | **source-code-review** |
| Android `.apk` / `.aab` / Android app | **android-pentest** |
| iOS `.ipa` / iPhone/iPad app | **ios-pentest** |
| Solidity / **EVM** / DeFi / token / on-chain protocol | **smart-contract-audit** |
| **Solana** program / Anchor / SPL / Rust on-chain | **solana-audit** |
| **Move** contract / **Sui** or **Aptos** package | **move-audit** |

If the ask is broad ("assess this company"), start with recon (web + API + source if a repo is in
scope), map the surface, then dive per-asset.

## Step 3 — Run the workflow: Map → Prioritize → Probe → Prove → Report

Map (recon) → Prioritize (surface mapping) → Probe (test highest-impact first) → Prove (validate) →
Report. Test one hypothesis at a time, log every attempt, apply the 5-minute rule, and never leave
scope. (RULES §2)

**Automation in the Map phase:** for web/API targets, delegate to the **recon-runner** agent or run
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/recon.sh <target> --yes-authorized` (subfinder→httpx→katana→gau→
nuclei, skips missing tools); add `${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh <target> --dc` for JS
secrets + dependency-confusion via TrinetLayer. Slash commands: `/recon`, `/validate`, `/report`.

## Step 4 — Prove it before you report

Every candidate finding must climb the whole Trinet Validation Ladder (RULES §3). Drop
weak/informational findings *before* writing them up. Reporting an unvalidated finding is a failure of
this skill.

## Step 5 — Report

Impact-first, reproducible, with a concrete fix and references (RULES §4). Offer platform-specific
formatting (HackerOne / Bugcrowd / Intigriti / Immunefi) and, if useful, a TrinetLayer VAPT PDF.

## Cross-cutting behavior

- **Chaining:** after finding individual bugs, look for chains (e.g. IDOR + weak auth → full ATO).
  A chain is often worth far more than its parts — report it as one high-impact issue.
- **Session memory:** keep a running engagement note (targets, surface map, tried/failed paths,
  confirmed findings) so long or resumed hunts don't lose context.
- **TrinetLayer accelerators:** use GhostJS (JS recon + secret scanning) and the Dependency
  Confusion engine where they fit; they're optional (RULES §6).
- **Discipline over volume:** a handful of validated, high-impact, well-written findings beats a pile
  of unvalidated noise every time.
