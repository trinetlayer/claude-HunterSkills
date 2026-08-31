# Usage & Examples

A quick tour of how to drive the TrinetLayer skills from Claude Code once they're installed.

## The golden rule

Start every engagement by telling Claude what you're authorized to test. The orchestrator will ask
for scope if you don't provide it. Examples of good openers:

> "I'm testing `app.example.com` — it's in scope on their HackerOne program (URL below). Help me hunt."
>
> "Here's a signed pentest RoE for `10.0.0.0/24`. Let's start recon."
>
> "Review this repo I own for security issues." *(then point Claude at the code)*

If you can't show scope, say so — Claude will stay in **advisory mode** (methodology, static review,
payload design, report drafting) and won't run active tests.

## Example prompts per skill

| You say… | Skill that loads |
|----------|------------------|
| "Help me find IDOR and auth bugs on this in-scope web app." | web-app-pentest |
| "Test this GraphQL API for BOLA and introspection issues." | api-security-testing |
| "Security-review this pull request for injection and authz gaps." | source-code-review |
| "Pentest my Android APK — check storage and exported components." | android-pentest |
| "Audit this iOS build's keychain usage and URL-scheme handling." | ios-pentest |
| "Audit this lending protocol's Solidity for reentrancy and oracle bugs." | smart-contract-audit |
| "Assess this company — I have web, API, and a repo in scope." | orchestrator → multiple |

## A typical flow

1. **Scope** — you paste the program scope / RoE / repo. Claude confirms boundaries.
2. **Recon** — Claude maps the surface (subdomains, endpoints, params, tech, or contracts/roles).
3. **Testing** — highest-impact classes first, one hypothesis at a time, every attempt logged.
4. **Validation** — each candidate climbs the Trinet Validation Ladder; weak/informational findings are dropped.
5. **Chaining** — Claude looks for bug chains worth more than the sum of parts.
6. **Report** — impact-first write-up with steps, PoC, impact, fix, and references — formatted for
   your target platform, optionally exported as a TrinetLayer VAPT PDF.

## Tips

- **Bring your tools.** The skills reference real tools (subfinder, httpx, nuclei, ffuf, semgrep,
  Frida, objection, Foundry, Slither, …). Install the ones you use; missing tools are skipped, not
  fatal.
- **Two accounts beat one.** For access-control bugs (IDOR/BOLA/BFLA), give Claude two test accounts
  so it can prove cross-tenant access.
- **Keep a running note.** Ask Claude to maintain an engagement note so long/resumed hunts keep
  context (targets, surface map, tried/failed paths, confirmed findings).
- **Validate before you submit.** The whole point of the Ladder is to protect your signal/reputation
  on bounty platforms — let it drop the weak stuff before it reaches a report.

## Combine with TrinetLayer

- Run [**GhostJS**](https://app.trinetlayer.com) first for JS recon + secret scanning, then feed the
  discovered endpoints/subdomains back into the web/API skills.
- Use the **Dependency Confusion** engine during source-code review.
- Export validated findings as a **VAPT PDF** for client-ready deliverables.
