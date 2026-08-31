---
description: Log a finding, lead, or tested-and-dead path to the engagement's hunt notes.
argument-hint: <what to remember>
allowed-tools: Read, Write, Edit
---

Record this to the engagement's running notes so a long or resumed hunt never loses context:

$ARGUMENTS

Append it to `./hunt-notes.md` (create the file with a header if it doesn't exist). Use one entry per
line/block:

```
## <target>
- [YYYY-MM-DD HH:MM] [confirmed|lead|dead] <class @ location> — <one line> (Ladder: <rung reached>)
```

Classify honestly: **confirmed** (climbed the Trinet Validation Ladder), **lead** (worth testing),
or **dead** (tried, no signal — record it so you don't retest it). Don't duplicate an existing entry;
update it instead. Keep secrets/PII redacted even in notes.
