---
description: Correlate individual findings into higher-impact bug chains.
argument-hint: [paste findings, or leave blank to use ./hunt-notes.md]
allowed-tools: Read
---

Look at the findings below (or read `./hunt-notes.md` if none are pasted):

$ARGUMENTS

Find **chains** — where combining bugs yields impact greater than the sum of the parts. Classic shapes:

- IDOR/info-leak exposing a reset token + weak reset flow → **account takeover**
- SSRF + cloud metadata (IMDSv2/GCP/Azure) → **credential theft → cloud pivot**
- Open redirect + OAuth `redirect_uri` → **auth-code/token theft → ATO**
- Self-XSS + login-CSRF/cookie-fixation → **stored XSS on a victim**
- Subdomain takeover + cookie scope → **session/CSRF-token theft**

For each chain you find, give: the **component bugs**, the **combined attack path** (step by step), and
the **elevated severity/impact**. Report the chain as a single high-impact finding — it's usually worth
far more than its parts. Only include chains where each link is real (climbs the Validation Ladder).
