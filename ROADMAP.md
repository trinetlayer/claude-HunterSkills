# Roadmap

Where the TrinetLayer bug-hunting skills are headed. Items tagged **`help wanted`** are great
contributions — see [CONTRIBUTING.md](CONTRIBUTING.md). This is a living document; open an issue to
propose or claim anything.

## ✅ Shipped

- **12 skills:** orchestrator + web / API / source / Android / iOS / EVM / **Solana** / **Move** /
  **cloud** / **LLM red-team** / **credential-recon**.
- Shared rulebook: authorization gate, **Map → Prioritize → Probe → Prove → Report**, the 8-rung
  **Trinet Validation Ladder**, impact-first report format.
- **Automation:** `recon.sh` (subfinder→httpx→katana→gau→nuclei + optional naabu/takeover, scope-gated,
  per-tool timeouts), a real **GhostJS `/api/v1`** + dependency-confusion scanner, and the `recon-runner`
  subagent.
- **Autopilot** — guarded human-on-the-loop hunt-loop (`/autopilot`) with mandatory checkpoints.
- **Persistent hunt-memory** — `scripts/memory.sh` (JSONL, rotated) backing `/remember` `/pickup` `/chain`.
- **MCP integrations guide** — Burp / Caido / HackerOne / ProjectDiscovery (`mcp/`).
- **Token/rug references** — EVM + Solana token-safety checklists.
- **Commands:** `/recon` `/recon-rank` `/validate` `/report` `/chain` `/remember` `/pickup` `/autopilot`
  `/cloud-recon` `/llm-redteam` `/takeover` `/jwt-scan`.
- Per-skill `references/` payload + PoC libraries. Validate CI (frontmatter + SVG + shellcheck + JSON).

## 🔜 Next (planned)

- **Hunt-memory intelligence** — pattern-mining across the JSONL store (which classes hit on which stacks)
  to auto-prioritize the next hunt. `help wanted`
- **More report templates** — YesWeHack, Synack, HackenProof formats alongside H1/Bugcrowd/Intigriti/
  Immunefi. `help wanted`
- **Deeper MCP** — a first-party helper that auto-detects installed Burp/Caido and writes the MCP config.
  `help wanted`
- **Multi-harness** — extend `AGENTS.md` coverage for OpenCode / Codex / other harnesses.

## Non-goals

- No exploitation of out-of-scope or third-party systems, no mass-targeting, no detection-evasion for
  malicious use. Every feature keeps the responsible-use posture and the shared rulebook intact.
- We stay Claude-Code-native for the skills themselves (a standalone CLI isn't a goal); multi-harness
  support is additive, not a rewrite.
