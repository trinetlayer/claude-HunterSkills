# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project uses simple date-stamped versions.

## [1.1.0] — 2026-09-01

Turns the pack from pure methodology into a working tool.

### Added
- **Automation** — bundled `scripts/recon.sh` (scope-gated subfinder→httpx→katana→gau→nuclei, per-tool
  timeouts, skips missing tools) and `scripts/ghostjs-scan.sh` (real TrinetLayer `/api/v1` GhostJS +
  dependency-confusion scan). A **`recon-runner`** subagent and **`/recon` · `/validate` · `/report`**
  slash commands.
- **Two new audit skills** — **`solana-audit`** (Anchor/Rust: Sealevel classes — missing signer/owner,
  type-cosplay, arbitrary CPI, PDA bump/seed, close/revival, sysvar spoofing…; Trident/sec3 X-Ray/
  litesvm PoC) and **`move-audit`** (Sui + Aptos: capability/visibility/object-model/hot-potato;
  `move test` + Move Prover). Orchestrator now routes to them; `smart-contract-audit` scoped to EVM.
- **Payload & PoC reference files** (`references/`, progressive disclosure): web payload library,
  GraphQL & JWT packs, Foundry PoC + invariant skeleton, Android/iOS Frida hooks, a custom Semgrep rule.
- CI now runs **shellcheck** and validates agents/commands frontmatter.
- **Hunt memory & chaining:** `/chain` (correlate findings into higher-impact chains), `/remember`
  and `/pickup` (a lightweight per-engagement notes file so long/resumed hunts keep context).
- **Community:** `ADOPTERS.md` (+ "Used by"), `ROADMAP.md` (with `help wanted` items), `AGENTS.md`
  (multi-harness), a false-positive issue template, and a professional Contributing flow in the README.

### Changed
- `web-app-pentest` / `api-security-testing` / `source-code-review` wire the recon + GhostJS scripts
  into their Map phase (pre-approved via `allowed-tools`). 9 skills total.

## [1.0.0] — 2026-09-01

First public release.

### Added
- **Seven Claude Code skills** covering the full bug-hunting surface:
  `bug-hunting-orchestrator`, `web-app-pentest`, `api-security-testing`, `source-code-review`,
  `android-pentest`, `ios-pentest`, `smart-contract-audit`.
- **Shared rulebook** (`skills/shared/RULES.md`): the authorization gate, the
  **Map → Prioritize → Probe → Prove → Report** workflow, the **Trinet Validation Ladder** (8 rungs),
  and an impact-first report format with HackerOne / Bugcrowd / Intigriti / Immunefi templates.
- ~36 vulnerability classes across Web2, mobile, and Web3, each with how-to-test steps,
  payload/command-level detail, and a never-submit / false-positive list.
- 2025-era coverage: AWS **IMDSv2** + GCP/Azure metadata SSRF, client-side path traversal &
  prototype pollution, GraphQL `GET`-CSRF & directive DoS, CI/CD-as-code (GitHub Actions) injection,
  **Flutter/React-Native** traffic interception, **TrollStore** + Android-14 APEX CA store,
  L2/cross-chain (sequencer-uptime) and Foundry invariant testing.
- Install paths: `install.sh` (copy/symlink/project/uninstall) and a Claude Code **plugin marketplace**
  manifest (`.claude-plugin/`).
- Branded, image-rich README with four self-contained SVG diagrams (hero banner, attack-surface map,
  workflow + Validation Ladder, and a terminal demo).
- Project scaffolding: `CONTRIBUTING.md`, `SECURITY.md`, issue/PR templates, and a validation CI.

[1.0.0]: https://github.com/trinetlayer/claude-HunterSkills/releases/tag/v1.0.0
