---
description: Resume a hunt — read the engagement's notes and suggest the next untested paths.
argument-hint: [target]
allowed-tools: Read, Glob, Grep
---

Resume the engagement$([ -n "$ARGUMENTS" ] && echo " for $ARGUMENTS").

Read `./hunt-notes.md` (and any `./trinet-recon/*/summary.txt` recon output) and reconstruct state:

- **Confirmed findings** so far (ready to report / reported).
- **Open leads** still worth testing.
- **Dead paths** already tried — do **not** retest these.

Then propose the **3–5 highest-value next tests**, skipping anything marked dead, highest-impact first.
If no notes exist yet, say so and start fresh from the Map phase (recon).
