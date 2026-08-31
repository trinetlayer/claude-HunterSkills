---
name: credential-recon
description: >-
  Authorized credential-attack RECON for TrinetLayer — passive OSINT, username/email mapping,
  breach-exposure checks, and password-policy discovery that feed a candidate password wordlist for
  an engagement. Use this when the user wants to "build a password wordlist for this engagement",
  "check breach exposure", "map employee emails", or asks for "credential recon" / pre-spray prep on
  an authorized target. It harvests emails, derives username/email patterns, chains holehe→Sherlock,
  runs HIBP/DeHashed exposure lookups, discovers the org's password policy, and assembles a
  lockout-safe candidate list. It STOPS before any actual password spray — submitting a credential to
  a live login needs separate explicit written authorization (endpoints, throttle, lockout-safe
  attempts/window, source IPs) and is deliberately out of scope for this skill's automation.
---

# Credential Recon (OSINT / Wordlist Building)

Passive credential-attack recon — harvest, map, check exposure, discover policy, build the wordlist. Stop there.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** only for engagements you're explicitly authorized on. **No scope →
> passive/advisory mode only.** This skill does OSINT + wordlist building **only**. A live password
> spray/brute is a HARD STOP — it needs separate explicit written authorization (endpoints, throttle,
> lockout-safe attempts/window, source IPs) and is never automated here.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs. Full workflow:
> *Map → Prioritize → Probe → Prove → Report*.

## The line — read before anything else

Two sides. This skill lives entirely on the left.

**SAFE without a sign-off (nothing here touches the target's auth systems):**
harvesting emails · mapping usernames/accounts · breach-exposure lookups · password-policy discovery ·
**building** a candidate wordlist. All passive OSINT against public sources — you never authenticate.

**NEEDS explicit written sign-off — HARD STOP:**
submitting **any** credential to a live login. "One password against many accounts" is a *password
spray*, and it counts. A spray without written permission is an **unauthorized-access offense** and can
**lock out real users**. There is no "just a quick test" exception. If you have not seen the signed
authorization, you do not spray — you hand over the wordlist and stop.

The whole point of this skill is to get you a ready, lockout-safe wordlist **so the spray is a clean,
authorized, separately-approved step** — not to run it.

---

## Quick start

1. **Confirm scope** in writing → else passive/advisory mode only.
2. **Harvest** (§1) — emails, names, username patterns from public sources.
3. **Map accounts** (§1) — email→services (holehe), username→platforms (Sherlock).
4. **Check exposure** (§2) — HIBP / DeHashed for breach-exposed and reused creds.
5. **Discover policy** (§3) — min length, complexity, lockout threshold.
6. **Build the wordlist** (§4) — lockout-safe, segmented per endpoint. **This is the deliverable.**
7. **STOP** (§5). Spray = separate signed authorization. Report exposure findings (§6).

Full command reference: [references/methodology.md](references/methodology.md).

---

## 1. OSINT / harvest + account mapping (passive)

Gather identities from public sources only. Never touch the target's login.

| Task | Tool / technique |
|------|------------------|
| Emails, subdomains, hosts from public sources | `theHarvester -d target.com -b all` |
| Google dorking for exposed addresses | `site:target.com "@target.com"` ; `intext:"@target.com" filetype:xlsx` |
| Name → email pattern derivation | LinkedIn/press → derive `{first}.{last}@target.com`, `{f}{last}@`, verify pattern from any known-good address |
| Email → 120+ services (reset/registration behaviour) | `holehe user@target.com` — tells you where an address is registered |
| Username → platforms | `sherlock jsmith` — finds accounts by handle across sites |

**Chain holehe → Sherlock:** holehe turns an email into a set of services it's registered on; pull the
likely username/handle from those hits and feed it to Sherlock to fan out to more platforms. Together
they build the identity graph (person → emails → usernames → accounts) that seeds both the username list
and the wordlist. All of this reads public signals — it is not authentication.

---

## 2. Breach exposure (passive)

Find already-leaked and reused passwords — a wordlist input **and** a finding in its own right.

| Source | Use | Sensitivity |
|--------|-----|-------------|
| **Have I Been Pwned** | Domain / email breach exposure — which accounts appear in which breaches | Public breach metadata |
| **DeHashed** | Full records (email→password/hash) for **authorized investigations only** | **High** — real plaintext creds; access only under the engagement's authority, redact everywhere |

Use exposure two ways: (1) harvest reused/exposed passwords to prioritise in the candidate list, and
(2) **report exposed corporate credentials as a finding itself** — an exposed live credential is often
higher-impact than anything a spray would yield. Treat every pulled password as toxic: minimum copies,
redacted in notes, deleted once the finding is proven (RULES §1).

---

## 3. Password-policy discovery — shape a *lockout-safe* list

You must know the **lockout threshold** before anyone sprays, or you risk locking out real users. Learn
the policy passively:

- **Active Directory** (if you have a foothold/authorized read): `net accounts` ,
  `Get-ADDefaultDomainPasswordPolicy` — reveals min length, complexity, **lockout threshold + window**.
- **Self-service reset / signup pages** — the client-side validation states the complexity rules.
- **Documented SSO / Azure AD / Entra policy** — tenant password + smart-lockout settings, often in
  admin docs or the sign-in error messages.

Record: min length, complexity classes required, lockout threshold N, and observation window. These set
the ceiling on attempts-per-account-per-window for any later (separately authorized) spray.

---

## 4. Candidate-list building — the deliverable of this skill

Assemble a small, targeted, **lockout-safe** list (quality over size — a huge list guarantees lockouts):

- **Season + year + company mutations** — `Company@2025`, `Autumn2025!`, `Target#2025`.
- **Breach-derived reused passwords** (§2) — highest signal; people reuse.
- **Role-based / context patterns** — vendor defaults, product names, local sports teams, `Welcome1!`.
- **Respect the policy (§3)** — drop candidates that can't satisfy min-length/complexity (wasted attempts
  = wasted lockout budget).

**Segment by endpoint** — keep separate lists per target so the (future, authorized) spray can be
throttled independently: **OWA · VPN · SSO · Azure AD / Entra**. Each has its own lockout behaviour.

Deliverable = segmented wordlist + the policy notes (lockout threshold, safe attempts/window). Nothing
here is fired at a login.

---

## 5. The spray — OUT OF SCOPE HERE (guardrail)

> ## ⛔ HARD STOP — DO NOT SPRAY FROM THIS SKILL
> The actual password spray is a **separate, authorized activity**. It requires a **signed RoE** that
> spells out: **allowed endpoints**, **throttle window**, **lockout-safe attempts-per-account-per-window**,
> **allowed source IPs**, and a **blackout / rollback plan**. Until that document exists, the answer is
> no.
>
> **Do not generate or run spray automation in this skill.** No spray scripts, no "loop the wordlist
> against the login", no credential-stuffing tooling — not even as an example. If the user asks to
> spray: (1) require the written authorization first, (2) confirm the agreed thresholds match the
> discovered lockout policy (§3), and (3) direct the execution to the separate authorized activity —
> this skill's job ends at handing over the wordlist.

---

## 6. Validation & reporting

Report the two things this skill *does* produce as findings, each climbing the Trinet Validation Ladder
(RULES §3): real class · reachable · exploitable now · concrete impact · in scope · reproducible · not a
duplicate/informational · evidence captured.

- **Exposed credentials** (breach hits, §2) — name the accounts, the breach, and whether the credential
  is likely still valid; **redact the actual passwords/hashes** in every note, screenshot, and report.
- **Password-policy weaknesses** (§3) — no/high lockout threshold, weak min-length/complexity, no MFA on
  a sprayable endpoint — the conditions that make a future spray dangerous.

Write impact-first (RULES §4): Title → Severity → Summary → Steps → Evidence (redacted) → Impact →
Remediation → References (CWE-521 weak password requirements, CWE-307 improper restriction of auth
attempts, OWASP). The wordlist itself is an engagement artifact, not a public report — handle it as
sensitive and hand it to the authorized spray activity, not into the report body.
