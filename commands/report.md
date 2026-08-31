---
description: Turn validated findings/notes into an impact-first report (H1/Bugcrowd/Intigriti/Immunefi).
argument-hint: <notes about the validated finding> [platform]
---

Draft an **impact-first** report from these notes:

$ARGUMENTS

First confirm the finding has cleared the Trinet Validation Ladder; if it clearly hasn't, say so and
run `/validate` first instead of writing it up.

Produce this structure (redact PII/secrets/tokens in every request/response and screenshot):

```
Title:        <asset> — <vuln class> — <one-line impact>
Severity:     <CVSS or program scale> + short justification
Summary:      2–3 sentences: what, where, why it matters.
Steps to Reproduce:
  1. …  (numbered, copy-pasteable, from a clean state)
Proof of Concept:  <request/response, payload, PoC code, tx hash — redacted>
Impact:       Concrete attacker outcome. If it chains, state the combined impact.
Remediation:  Specific, actionable fix (not "sanitize input").
References:   CWE / OWASP / SWC / MASVS / advisory.
```

If a target platform is named (HackerOne / Bugcrowd / Intigriti / Immunefi), reorder to that platform's
fields but keep the same content. Lead with impact; make triage effortless.
