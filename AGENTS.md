# AGENTS.md — TrinetLayer bug-hunting

Guidance for any agent/harness (Claude Code, OpenCode, Codex, etc.) working in this repo or using these
skills for security testing. In Claude Code the skills load automatically; elsewhere, follow this file.

## Rules (non-negotiable)

Read and follow **[`skills/shared/RULES.md`](skills/shared/RULES.md)**. In short:

- **Authorization first.** Only test assets the user owns or is explicitly authorized to (in-scope
  bounty, signed engagement). No scope → **advisory mode only** (methodology, static review, payload
  design, reporting) — no active testing.
- **Workflow:** Map → Prioritize → Probe → Prove → Report. Highest-impact classes first.
- **Trinet Validation Ladder** (8 rungs) before anything is reported. Kill weak/informational findings.
- Never DoS, never leave scope, no credential spraying without written approval, redact PII/secrets.

## Where things live

- `skills/<name>/SKILL.md` — the per-domain playbook (web, API, source, Android, iOS, EVM, Solana, Move).
  Each links `references/*` payload/PoC libraries (load on demand).
- `scripts/recon.sh` — scope-gated recon pipeline. `scripts/ghostjs-scan.sh` — TrinetLayer `/api/v1` scan.
- Slash commands (Claude Code): `/recon /validate /report /chain /remember /pickup`.

## Using it outside Claude Code

Point your harness at the relevant `skills/<name>/SKILL.md` for the target type, obey `RULES.md`, and run
`scripts/recon.sh <target> --yes-authorized` for the Map phase (it skips any tool you don't have).
