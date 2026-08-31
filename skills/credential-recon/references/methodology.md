# Credential Recon — Passive OSINT & Wordlist Reference

Command reference for the **passive** phases of `credential-recon`: harvest → map → exposure → policy →
wordlist. Everything here reads public sources or authorized reads — **nothing authenticates to the
target**. The one thing this file does **not** contain is spray automation, by design (see the STOP box
at the end).

> **Before any of this:** confirm written authorization. **No scope → passive/advisory mode only.**
> Every credential you touch is toxic — minimum copies, redact in notes, delete once a finding is proven.

---

## 1. Email / host harvesting

```bash
# theHarvester — emails, subdomains, hosts from public search engines & sources
theHarvester -d target.com -b all
theHarvester -d target.com -b bing,duckduckgo,crtsh,hunter -l 500 -f harvest.json

# Extract just the @target.com addresses from output for the identity list
grep -Eio '[a-z0-9._%+-]+@target\.com' harvest.* | sort -u > emails.txt
```

### Google / search dorks (run in a browser; passive)
```
site:target.com "@target.com"
intext:"@target.com" filetype:xlsx OR filetype:csv OR filetype:pdf
site:linkedin.com/in "target company"
"@target.com" -site:target.com          # addresses leaked on third-party sites
site:github.com "target.com" password    # exposed creds in code (verify, redact)
```

### Name → email pattern derivation
Collect employee names (LinkedIn, press releases, conference talks) and derive the org's address format
from any one known-good address. Common formats:
```
{first}.{last}@target.com      jane.smith@target.com
{f}{last}@target.com           jsmith@target.com
{first}{l}@target.com          janes@target.com
{last}{f}@target.com           smithj@target.com
```
Confirm the pattern against a single verified address before expanding the whole roster. Deriving a
pattern is arithmetic on public names — it is not verification against the target's mail server.

---

## 2. Username / account mapping — chain holehe → Sherlock

```bash
# holehe — email -> 120+ sites, via each site's password-reset / registration behaviour.
# Tells you WHERE an address is registered (no login attempt against the target).
holehe user@target.com
holehe --only-used user@target.com          # show only sites where it's registered
cat emails.txt | while read e; do holehe --only-used "$e"; done

# Sherlock — username/handle -> accounts across platforms.
sherlock jsmith
sherlock jsmith janesmith --print-found --timeout 10
```

**The chain:** holehe turns `user@target.com` into a list of registered services → read the likely
handle/username from those accounts → feed the handle to Sherlock to fan out to more platforms. Result:
a person → emails → usernames → accounts graph that seeds both the username list and the wordlist
(people bake handles, pet names, and years into passwords).

---

## 3. Breach exposure lookups

```bash
# Have I Been Pwned (API key required) — breach exposure for a domain or address.
curl -s -H "hibp-api-key: $HIBP_API_KEY" \
  "https://haveibeenpwned.com/api/v3/breachedaccount/user@target.com?truncateResponse=false"

# Domain-wide view is via the HIBP domain-search dashboard (verified domain owner) — passive.
```

**DeHashed** — full records (email → password/hash). **Authorized investigations only**; this returns
real plaintext credentials. Query via the DeHashed web UI or API under the engagement's authority, and
**redact everything** in your notes. Use exposure results two ways:
1. Reused/exposed passwords → prioritise them in the candidate list (§5).
2. An exposed **live** corporate credential is a finding on its own — often higher impact than a spray.

Treat pulled passwords as toxic waste: fewest copies, redacted, deleted once proven (RULES §1).

---

## 4. Password-policy discovery (shape a lockout-safe list)

Know the **lockout threshold** before anyone sprays.

```cmd
:: Active Directory (authorized read / foothold)
net accounts                              :: min length, lockout threshold, lockout window
```
```powershell
Get-ADDefaultDomainPasswordPolicy         # MinPasswordLength, Complexity, LockoutThreshold, LockoutObservationWindow
Get-ADFineGrainedPasswordPolicy -Filter * # PSOs that override the default for some groups
```

- **Self-service reset / signup pages** — client-side validation states the complexity rules (min
  length, required classes). Read the page; don't submit against real accounts.
- **SSO / Azure AD / Entra** — tenant password policy + **smart lockout** (threshold + duration);
  documented in admin portals and sometimes revealed in sign-in error text.

Record: `min_length`, `complexity_classes`, `lockout_threshold N`, `observation_window`. These cap the
attempts-per-account-per-window for any later (separately authorized) spray.

---

## 5. Wordlist mutation patterns (the deliverable)

Keep it **small and targeted** — a bloated list guarantees lockouts. Drop anything the policy (§4) would
reject.

```
# Season + year + company (respect min length / complexity)
Company@2025      Company2025!     Company#2025
Spring2025!       Summer2025!      Autumn2025!      Winter2025!
Target@2025       Target#2025

# Common base + policy topper
Welcome1!   Password1!   Changeme1!   Qwerty123!   <VendorDefault>1!

# Breach-derived (highest signal — from §3, reused as-is or +1/! toppers)
<leaked_pw>      <leaked_pw>1     <leaked_pw>!

# Context / role-based
<ProductName>1!  <LocalSportsTeam>2025!  <OfficeCity>2025!
```

### Segment per endpoint (separate files — each has its own lockout behaviour)
```
wordlist-owa.txt        # Outlook Web Access
wordlist-vpn.txt        # VPN portal
wordlist-sso.txt        # SSO / IdP
wordlist-entra.txt      # Azure AD / Entra
policy-notes.md         # lockout_threshold, safe attempts/window, MFA state per endpoint
```

Deliverable = the segmented lists **plus** `policy-notes.md`. Hand this to the authorized spray activity.
Nothing in this file fires a single credential at a login.

---

```
##############################################################################
#                                                                            #
#   ⛔  STOP — A PASSWORD SPRAY NEEDS SEPARATE WRITTEN AUTHORIZATION  ⛔       #
#                                                                            #
#   Everything above is passive OSINT + wordlist building. Submitting even   #
#   ONE credential to a live login (one password across many accounts = a    #
#   spray) is unauthorized access without a signed RoE and can lock out      #
#   real users.                                                              #
#                                                                            #
#   The RoE must specify: allowed endpoints · throttle window ·              #
#   lockout-safe attempts-per-account-per-window (< threshold from §4) ·     #
#   allowed source IPs · blackout / rollback plan.                           #
#                                                                            #
#   This reference contains NO spray automation on purpose. Do not add it.   #
#   The spray is a separate, authorized activity — this skill ends at the    #
#   wordlist.                                                                 #
#                                                                            #
##############################################################################
```
