# Contributing

Thanks for helping make these skills sharper. The whole value of this repo is **accuracy + discipline**
— a payload that actually lands in 2025, a false-positive that saves someone a closed report. Small,
correct contributions beat big vague ones.

## Ways to contribute

- **New coverage** — a vuln class, technique, tool, or bypass that a domain skill is missing.
- **Freshness fixes** — a payload/command/flag that went stale (e.g. a cloud metadata endpoint, an OS
  change that breaks a recipe).
- **Report templates** — platform-specific formats (HackerOne / Bugcrowd / Intigriti / Immunefi …).
- **Docs** — clearer wording, examples, fixes in `README.md` / `USAGE.md`.

## Ground rules (non-negotiable)

1. **Keep the responsible-use framing.** Every skill stays authorization-gated and drops to
   passive/advisory mode without scope. Don't add anything whose only purpose is unauthorized attack,
   mass exploitation, or detection evasion for malicious use.
2. **Keep the shared rulebook intact.** Don't weaken `skills/shared/RULES.md` (the authorization gate,
   the Trinet Validation Ladder, the report format). Skills reference it — don't fork it.
3. **Accuracy over volume.** If you add a payload or command, it must be correct and current. Cite the
   CWE / OWASP / SWC / MASVS reference where one applies.
4. **Tight, practical entries.** Match the existing style: a one-line "how to test" + a real
   payload/command. No essays, no filler.

## Adding or editing a skill

Each skill is one folder under `skills/` with a single `SKILL.md`:

```
skills/<skill-name>/SKILL.md
```

`SKILL.md` starts with YAML frontmatter — `name` (must match the folder) and a `description` that says
**what it does and when to use it**, with natural trigger phrases (this is what makes Claude load it):

```markdown
---
name: web-app-pentest
description: >-
  Web application penetration testing … Use this when the user wants to test a website,
  "find XSS/SSRF/IDOR", "assess this login flow" …
---

# Web Application Pentest
...
```

The body should open with the shared **core-rules block** (copy it from any existing skill) so the
authorization gate and the Ladder survive plugin-mode loading, then the skill's own methodology.

## Before you open a PR

- Run the same checks CI runs:
  ```bash
  xmllint --noout assets/*.svg          # SVGs well-formed
  # each skills/*/SKILL.md has name: + description: frontmatter and references RULES.md
  ```
- If you have the Claude Code CLI: `claude plugin validate .` should pass.
- Keep the diff focused — one class/fix per PR is easiest to review.

## PRs & issues

Use the issue templates (new coverage vs. bug/staleness). PRs should say **what** changed and **why it's
correct** (link the reference). By contributing you agree your work is licensed under this repo's
[MIT license](LICENSE).
