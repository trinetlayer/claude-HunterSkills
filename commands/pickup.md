---
description: Resume a hunt — read persistent hunt memory and suggest the next untested paths.
argument-hint: [target]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh *), Read, Glob, Grep
---

Resume the engagement$([ -n "$ARGUMENTS" ] && echo " for $ARGUMENTS").

Pull prior state from hunt memory (and any `./trinet-recon/*/summary.txt`):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh query <target>     # or: memory.sh list
```

Reconstruct: **confirmed findings**, **open leads**, and **dead paths** (do NOT retest these). Then
propose the **3–5 highest-value next tests**, skipping dead paths, highest-impact first. If there's no
memory yet, say so and start fresh from the Map phase (also check `./hunt-notes.md`).
