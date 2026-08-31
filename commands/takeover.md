---
description: Check in-scope subdomains for dangling-DNS / subdomain takeover.
argument-hint: <domain, or a subs list file>
allowed-tools: Bash, Read, Grep
---

Subdomain-takeover check for: `$ARGUMENTS` (authorized scope only).

Resolve CNAMEs (`dnsx -cname` / `dig`), flag dangling records pointing at unclaimed services
(S3/GitHub Pages/Heroku/Fastly/Azure/etc.), and confirm the fingerprint before claiming anything. Run
`nuclei -tags takeover` on the live list if available. Only report a takeover you can actually
demonstrate control of — serve a benign marker, never host real content. Climb the Validation Ladder.
