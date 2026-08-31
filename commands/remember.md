---
description: Log a finding, lead, or tested-and-dead path to persistent hunt memory.
argument-hint: <target> <lead|confirmed|dead> <class> <one-line note>
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh *), Read, Write, Edit
---

Record this so a long or resumed hunt (and future hunts on the same target) keep the context:

$ARGUMENTS

Persist it with the memory store (survives across sessions):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh append <target> <lead|confirmed|dead> <class> "<note>"
```

Classify honestly: **confirmed** (climbed the Validation Ladder), **lead** (worth testing), **dead**
(tried, no signal — record it so it isn't retried). If the script isn't available, append to
`./hunt-notes.md` instead. Keep secrets/PII redacted even in notes.
