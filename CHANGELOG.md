# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project uses simple date-stamped versions.

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
