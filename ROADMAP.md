# Roadmap

Where the TrinetLayer bug-hunting skills are headed. Items tagged **`help wanted`** are great
contributions — see [CONTRIBUTING.md](CONTRIBUTING.md). This is a living document; open an issue to
propose or claim anything.

## ✅ Shipped

- 9 skills: orchestrator + web / API / source / Android / iOS / EVM / **Solana** / **Move**.
- Shared rulebook: authorization gate, **Map → Prioritize → Probe → Prove → Report**, the 8-rung
  **Trinet Validation Ladder**, impact-first report format.
- **Automation:** `recon.sh` (subfinder→httpx→katana→gau→nuclei, scope-gated, per-tool timeouts) and a
  real **GhostJS `/api/v1`** + dependency-confusion scanner; `recon-runner` subagent.
- **Commands:** `/recon` `/validate` `/report` `/chain` `/remember` `/pickup`.
- Per-skill `references/` payload + PoC libraries. Validate CI (frontmatter + SVG + shellcheck).

## 🔜 Next (planned)

- **Hunt-memory as data, not just notes** — a small helper that persists findings/patterns to
  `${CLAUDE_PLUGIN_DATA}` (JSONL, rotated) so insight from one target informs the next. Builds on
  `/remember` + `/pickup`. `help wanted`
- **Cloud recon** — S3/GCS/Azure bucket enumeration + CDN origin-IP discovery, as a `references/` pack
  and an optional `recon.sh` stage (naabu/smap for non-HTTP services). `help wanted`
- **Token / rug-pull checks** — formalize the EVM/Solana token-safety checklist (mint authority, LP
  lock, blacklist/pause, honeypot, bonding-curve) into a shared `references/token-safety.md`. `help wanted`
- **More report templates** — YesWeHack, Synack, HackenProof formats alongside H1/Bugcrowd/Intigriti/
  Immunefi. `help wanted`
- **Multi-harness** — an `AGENTS.md` so OpenCode / Codex / other harnesses can load the methodology.

## 🧪 Exploring (needs design / discussion)

- **MCP integrations** — first-class Burp / Caido / HackerOne MCP wiring (via `.mcp.json`), so the skills
  can drive a proxy and pull program scope directly. Open an issue with the server you'd use. `help wanted`
- **Autopilot** — a guarded autonomous loop (scope → recon → probe → validate → report) with mandatory
  human checkpoints before anything active or state-changing. Must not weaken the authorization gate.
- **LLM red-team pack** — prompt-injection / jailbreak / data-exfil test corpus for AI-backed endpoints
  (pairs with TrinetLayer's AI-security work).
- **Credential-recon (guardrailed)** — wordlist/OSINT/breach-check methodology with a **hard stop before
  spray** and explicit written-approval gate. Sensitive — design-first.

## Non-goals

- No exploitation of out-of-scope or third-party systems, no mass-targeting, no detection-evasion for
  malicious use. Every feature keeps the responsible-use posture and the shared rulebook intact.
- We stay Claude-Code-native for the skills themselves (a standalone CLI isn't a goal); multi-harness
  support is additive, not a rewrite.
