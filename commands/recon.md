---
description: Run TrinetLayer recon on an authorized target and summarize the attack surface.
argument-hint: <target-domain> [--deep]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/recon.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh *), Read, Grep, Glob
---

Recon an **authorized** target: `$ARGUMENTS`

First confirm the target is in scope for the user (own asset / in-scope bounty / signed engagement). If
it isn't clear, ask — do not scan without scope.

Then delegate to the **recon-runner** agent (preferred, keeps output out of context), or run directly:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/recon.sh $1 --yes-authorized --out ./trinet-recon/$1
```

If `TRINETLAYER_API_KEY` is set, also run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh $1 --dc`.

Then read the run directory's `summary.txt` and give a ranked attack surface + 3–5 highest-impact first
tests. Everything is a lead — nothing is a finding until it climbs the Trinet Validation Ladder.
