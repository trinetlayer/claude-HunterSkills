<!-- Keep PRs focused — one class/fix per PR is easiest to review. -->

## What changed
<!-- Which skill(s) / file(s), and what you added or fixed. -->

## Why it's correct
<!-- The reference that backs it: CWE / OWASP / SWC / MASVS / advisory / write-up.
     If it's a payload/command, note where you confirmed it still works. -->

## Checklist
- [ ] Keeps the responsible-use framing and `skills/shared/RULES.md` intact
- [ ] Matches the existing style (tight "how to test" + real payload/command)
- [ ] Frontmatter valid (`name:` matches folder, `description:` present) if a skill changed
- [ ] `xmllint --noout assets/*.svg` passes if any SVG changed
- [ ] No secrets, no unauthorized-attack-only content
