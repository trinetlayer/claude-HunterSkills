---
description: Run a candidate finding up the Trinet Validation Ladder before you report it.
argument-hint: <paste the finding / describe it>
---

Put this candidate finding through the **Trinet Validation Ladder**. Finding:

$ARGUMENTS

Judge it against all **8 rungs** — for each, say PASS/FAIL/UNKNOWN with one line of reasoning:

1. **Real class** — maps to a concrete, named vulnerability (not "could be").
2. **Reachable** — the vulnerable path is reachable by the attacker role being modelled.
3. **Exploitable now** — works against the live target today, not "if X were also true".
4. **Impact** — concrete attacker outcome (data / funds / accounts / integrity / availability).
5. **In scope** — asset and issue type are both in scope and reportable.
6. **Reproducible** — clean, minimal, deterministic steps from a known state.
7. **Not a duplicate / non-informational** — not already reported; not on the never-submit list
   (self-XSS, missing headers w/o exploit, best-practice-only, rate-limit-only, …).
8. **Evidence captured** — request/response, PoC, screenshot, or tx trace in hand.

Verdict: **READY** only if every rung holds. Otherwise say exactly which rung fails and what to gather
or prove to close the gap — or that it should be dropped.
