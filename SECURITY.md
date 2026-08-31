# Security & Responsible Use

## What this project is

These are **methodology skills** for Claude Code — playbooks, checklists, and payloads for **authorized**
security testing. They contain no exploits against any specific live system, no malware, and no
targeting of real third parties. Every skill is authorization-gated and drops to passive/advisory mode
when scope can't be shown (see [`skills/shared/RULES.md`](skills/shared/RULES.md)).

## Acceptable use

Use these skills only for work you are allowed to do:

- assets you own,
- targets explicitly in scope on a bug-bounty program, or
- engagements covered by a signed penetration-test agreement / rules of engagement.

Do **not** use them for unauthorized access, testing out-of-scope systems, denial of service, credential
spraying without written approval, or any activity that breaks the law or a program's rules. What you
point these skills at is your responsibility.

## Reporting a problem with this repo

If you find a security problem in the repository itself — for example a malicious payload that could
harm the *operator* running it, a supply-chain issue, or unsafe instructions — please report it
privately rather than opening a public issue:

- Use **GitHub → Security → Report a vulnerability** (private advisory) on this repo, or
- Email the maintainers via the contact on <https://app.trinetlayer.com>.

Please include the file, the concern, and a minimal description of the impact. We aim to acknowledge
within a few days.

## What to report elsewhere

Vulnerabilities you discover in **someone else's** product while *using* these skills belong to **that
product's** disclosure program (HackerOne / Bugcrowd / Intigriti / Immunefi / the vendor's
security.txt) — not here.
