<div align="center">

# 🛡️ TrinetLayer Bug-Hunting Skills for Claude Code

**Turn Claude into a disciplined bug-bounty & pentest co-pilot.**

Six specialized [Claude Code](https://claude.com/claude-code) skills — web app, API, source-code
review, Android, iOS, and smart-contract security testing — plus an orchestrator that keeps every
engagement authorized, in-scope, and reportable.

Built by [**TrinetLayer**](https://app.trinetlayer.com) · the attack-surface lab for bug bounty hunters.

</div>

---

## ⚠️ Authorized testing only

These skills are for **authorized security work**: your own assets, in-scope bug-bounty programs, and
signed penetration-test engagements. Every skill opens with an **authorization gate** and enforces
a shared rulebook — no out-of-scope testing, no DoS, no credential spraying without written approval,
and minimal handling of real data. If authorization can't be shown, the skills drop to **passive /
advisory mode** (methodology, static review of code you provide, payload design, report drafting).
You are responsible for staying within the law and your program's rules.

---

## What's inside

| Skill | Use it when you're… |
|-------|---------------------|
| 🧭 **bug-hunting-orchestrator** | Starting an engagement, or not sure which skill fits — it confirms scope and routes. |
| 🌐 **web-app-pentest** | Testing a website / web app — XSS, SSRF, IDOR, SQLi, auth & business-logic flaws, chains. |
| 🔌 **api-security-testing** | Testing REST / GraphQL / gRPC — OWASP API Top 10, BOLA/BFLA, JWT, mass assignment. |
| 🔎 **source-code-review** | Auditing a repo / PR / diff — source→sink SAST, secrets, dependency confusion, crypto misuse. |
| 🤖 **android-pentest** | Testing an Android app / APK — MASVS classes, exported components, storage, pinning bypass. |
| 🍎 **ios-pentest** | Testing an iOS app / IPA — keychain, ATS, URL schemes, WebView bridges, pinning bypass. |
| ⛓️ **smart-contract-audit** | Auditing Solidity / DeFi — reentrancy, oracle manipulation, access control, PoC in Foundry. |

Every skill shares one rulebook — [`skills/shared/RULES.md`](skills/shared/RULES.md) — covering the
authorization gate, the **5-phase workflow** (recon → surface mapping → testing → validation →
reporting), a **7-point validation gate** that kills weak findings before you submit, and an
**impact-first report format** with HackerOne / Bugcrowd / Intigriti / Immunefi templates.

---

## Install

### Option A — installer script (personal, global)

```bash
git clone https://github.com/TrinetLayer/trinetlayer-skills.git
cd trinetlayer-skills
./install.sh          # copy into ~/.claude/skills
# or
./install.sh --link   # symlink instead, so `git pull` auto-updates
```

### Option B — Claude Code plugin marketplace

```
/plugin marketplace add TrinetLayer/trinetlayer-skills
/plugin install trinetlayer-bug-hunting@trinetlayer
```

### Option C — project-scoped

```bash
./install.sh --project /path/to/your/engagement   # installs into <project>/.claude/skills
```

Then start a new Claude Code session and just describe the task —
*"help me hunt bugs on this authorized target"*, *"audit this Solidity contract"*, *"security-review
this repo"* — and the orchestrator routes to the right skill.

To remove: `./install.sh --uninstall`.

---

## How it works

Claude Code **Skills** are model-invoked: Claude reads each skill's description and pulls in the full
instructions only when your task matches. So you don't memorize commands — you describe what you want,
and the matching skill loads its methodology, checklists, tool commands, and payloads on demand.

```
You: "help me pentest this in-scope web app"
      │
      ▼
bug-hunting-orchestrator  ──▶ confirms scope ──▶ routes to web-app-pentest (+ api-security-testing)
      │
      ▼
5-phase workflow ─▶ 7-point validation gate ─▶ impact-first report
```

## TrinetLayer accelerators (optional)

The skills can lean on [TrinetLayer](https://app.trinetlayer.com)'s own tooling where it helps:

- **GhostJS** — JavaScript recon + secret scanning (~152 detections, subdomain enumeration).
- **Dependency Confusion** engine — npm dependency-confusion detection during code review & recon.
- **REST API** (`/api/v1`, Pro) — automate scans from a workflow.
- **VAPT PDF reports** — export validated findings.

These are optional accelerators, never requirements — the skills work fully on their own.

---

## Contributing

Issues and PRs welcome — new vuln-class coverage, tool updates, platform report templates, and
fixes. Keep the responsible-use framing and the shared rulebook intact.

## License

[MIT](LICENSE) © 2026 TrinetLayer. Provided for authorized, lawful security testing only; no warranty.
