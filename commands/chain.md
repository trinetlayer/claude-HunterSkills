---
description: Correlate individual findings into higher-impact bug chains.
argument-hint: [paste findings, or leave blank to use hunt memory]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh *), Read
---

Look at the findings below — or pull them from memory with
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh query <target>` (or read `./hunt-notes.md`):

$ARGUMENTS

Find **chains** where combining bugs yields impact greater than the parts:

- IDOR/info-leak exposing a reset token + weak reset → **account takeover**
- SSRF + cloud metadata (IMDSv2/GCP/Azure) → **credential theft → cloud pivot**
- Open redirect + OAuth `redirect_uri` → **auth-code/token theft → ATO**
- Self-XSS + login-CSRF/cookie-fixation → **stored XSS on a victim**
- Subdomain takeover + cookie scope → **session/CSRF-token theft**

For each chain: the **component bugs**, the **combined attack path** (step by step), and the **elevated
severity**. Report the chain as one high-impact finding. Only chains where each link climbs the Ladder.
