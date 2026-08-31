---
name: api-security-testing
description: >-
  Guides authorized security testing of REST, GraphQL, and gRPC APIs for bug bounty and
  pentest engagements, mapped to the OWASP API Security Top 10 (2023). It covers API surface
  discovery, per-privilege authorization testing (BOLA/BFLA), injection and JWT/OAuth attacks,
  GraphQL-specific abuse, validation of findings, and impact-first reporting. Use it when the
  user says things like "test this API", "REST API pentest", "GraphQL security", "check my
  endpoints for BOLA/BFLA", "API auth testing", or wants to assess an API's authN/authZ,
  rate limiting, input validation, or business logic. Operates in passive/advisory mode until
  authorization is confirmed.
allowed-tools: >-
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/recon.sh *),
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh *)
---

# API Security Testing (REST / GraphQL / gRPC)

Practical methodology for testing APIs on **authorized** targets: map the surface, hammer
authorization and authentication, probe injection and business-logic flaws, then validate and
report impact-first. Works for REST/JSON, GraphQL, and gRPC (protobuf) backends.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** only test assets you own or are explicitly authorized to (bug-bounty scope,
> signed RoE, written approval). **No scope → passive/advisory mode only** (methodology, static review,
> payload design, report drafting). Stay in scope, never DoS, no credential spraying without written
> approval, redact PII/secrets, and confirm before any state-changing action on a target you don't own.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact · in scope · reproducible · not a duplicate/informational ·
> evidence captured. Full workflow: *Map → Prioritize → Probe → Prove → Report*.

This skill maps onto the RULES §2 phases: **Recon** (§1 discovery) → **Surface mapping** (rank
endpoints by impact/reachability and note who *should* reach each) → **Testing** (§2 Top 10, §3
injection/JWT/GraphQL, highest-impact first) → **Validation** (§5) → **Reporting** (§6). Log every
request, target, and result with a timestamp as you go.

## 0. API testing posture (the core-rules block above governs authorization)

- **Use two accounts/roles** (plus an unauth session) for authz testing — BOLA/BFLA are proven by replay.
- **Throttle within the program's rate limits;** automate serially, not in parallel bursts.
- **Use test tenants/accounts** for anything state-changing; prefer idempotent reads to prove a bug.

---

## 1. Discovery & recon (map the API surface)

Enumerate every endpoint, verb, version, and parameter before testing.

| Source | How to pull it |
| --- | --- |
| Swagger/OpenAPI | Try `/swagger.json`, `/openapi.json`, `/v3/api-docs`, `/swagger-ui`, `/redoc`. Import into Postman/Insomnia to auto-build a request collection. |
| GraphQL | Send an introspection query (`__schema`); if disabled, use **clairvoyance**/**graphql-cop** to infer types via field suggestions. Check `/graphql`, `/graphiql`, `/api/graphql`, `/v1/graphql`. |
| gRPC | `grpcurl -plaintext host:port list` for server reflection; if reflection is off, obtain `.proto` files or reverse them from the client. |
| JS-derived endpoints | Grep bundles/source maps for paths, hostnames, keys. **TrinetLayer GhostJS** pulls endpoints + secrets (~152 detections) out of JS, plus subdomains and source-map/bundle analysis. |
| Mobile app traffic | Proxy the app through Burp/Caido (cert pinning bypass if needed) to capture undocumented endpoints. |
| SOAP/WSDL | Fetch `?wsdl`; import into SoapUI to enumerate operations. |
| Path/verb brute force | **ffuf** for paths, **kiterunner** (`kr scan`) for API route/verb patterns from its wordlists. |
| Hidden params | **arjun** to discover unlinked query/body params on known endpoints. |
| API versions | Enumerate `/v1`, `/v2`, `/api/v3`, `/beta`, `/internal` — old versions often lack fixes (feeds API9). |

Tools: Postman/Insomnia (collections), Burp Suite/Caido (intercept + Repeater/Intruder), ffuf,
kiterunner, arjun, clairvoyance / graphql-cop, grpcurl. Record base URL, auth scheme, and every
`{method, path, params, roles-that-should-access}` for phase 2 surface mapping.

**Automated recon:** run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/recon.sh <target> --yes-authorized`
(chains subfinder→httpx→katana→gau→nuclei, skips missing tools, throttled), or delegate to the
**recon-runner** agent to keep output out of context. For JS secrets + npm dependency-confusion via
TrinetLayer, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh <target> --dc` (needs
`TRINETLAYER_API_KEY`; skips gracefully without it).

---

## 2. OWASP API Security Top 10 (2023) — test checklist

Test each. You need **≥ two accounts** (and ideally an unauthenticated session) to prove most authz bugs.

| # | Risk | How to test | Example |
| --- | --- | --- | --- |
| **API1** | **BOLA / IDOR** (object-level authz) | Log in as user A, capture a request with an object ID, replay it as user B (or unauth). Swap numeric IDs, UUIDs, slugs, filenames. Reverse "opaque" refs (base64/hex/unsalted-hash/predictable-UUIDv1) and enumerate; hit **export/report/PDF** and **batch/array** (`ids[]=`, `{"user_ids":[…]}`) routes that skip the UI's per-object check; try the ID in cookies, GraphQL node IDs, and WebSocket subscribe frames. See [references/idor.md](references/idor.md). | `GET /api/orders/1043` as B returns A's order; `GET /api/reports/export?account_id=1044` pulls another tenant. |
| **API2** | **Broken authentication** | Test token expiry/revocation, weak JWT (see §3), credential-stuffing protection, password-reset token entropy, missing auth on some routes. Attack **OTP/MFA/reset** flows: code not bound to user/session, reuse/no-invalidation, verify-endpoint rate-limit bypass, race on verify, OTP leaked in response, drop/null/type-confuse the code — full catalog in [references/auth-bypass.md](references/auth-bypass.md). | Expired/`alg:none` JWT still accepted; reset token predictable; OTP minted for A verifies B (ATO). |
| **API3** | **Broken object property level authz** (mass assignment + excessive data exposure) | Add fields the client never sends (`"role":"admin"`, `"isVerified":true`) to create/update bodies. Diff full API response vs. what the UI renders for leaked fields. | `PATCH /users/me` with `"balance":99999`; response includes `password_hash`, internal flags. |
| **API4** | **Unrestricted resource consumption** | Probe for missing rate limits, unbounded `limit`/`page` params, large uploads, expensive queries. Prove the *gap*, don't actually exhaust. | No lockout after N failed logins; `?limit=1000000` honored. |
| **API5** | **BFLA** (function-level authz) | As a low-priv user, call admin/privileged endpoints and try alternate verbs. Switch `GET`→`PUT`/`DELETE`, add `X-HTTP-Method-Override`; guess admin routes from patterns and probe `internal.`/`admin.` subdomains reusing the same IDs. | Regular user hits `DELETE /api/admin/users/5` successfully. |
| **API6** | **Unrestricted access to sensitive business flows** | Find flows worth automating (signup, checkout, coupon, invites) and test whether anti-automation controls exist. | Script redeems one-per-user coupon 500× via API. |
| **API7** | **SSRF** | Any param taking a URL/host/file (webhooks, image fetch, import-from-URL, PDF render). Point at `169.254.169.254`, internal hosts, `file://`. Use blind/OOB (Collaborator) when no response echoes. | `POST /fetch {"url":"http://169.254.169.254/latest/meta-data/"}` returns cloud creds. |
| **API8** | **Security misconfiguration** | Check verbose stack traces, permissive CORS, missing TLS, default creds, unsafe HTTP methods (TRACE), content-type handling, missing security headers *where it enables an exploit*. | CORS reflects `Origin` with `Allow-Credentials: true`. |
| **API9** | **Improper inventory management** | Hunt shadow/zombie APIs: old versions, staging/`internal` hosts, deprecated endpoints still live, undocumented routes from JS/mobile. | `/api/v1/users` (deprecated, unpatched) still serves data. |
| **API10** | **Unsafe consumption of 3rd-party APIs** | Where the target trusts an upstream/integration, test whether attacker-influenced upstream data is validated (redirects followed blindly, injected data trusted). | Webhook from a spoofable third party alters account state. |

---

## 3. Injection & other attack classes

**Injection (via JSON body, query, headers, path):**
- **SQLi** — `'`, `" OR 1=1--`, time-based `;WAITFOR DELAY` in string fields and numeric contexts.
- **NoSQLi** — operator injection in JSON: `{"user":{"$ne":null},"pass":{"$ne":null}}`, `{"$gt":""}`.
- **Command injection** — `; id`, `$(id)`, `|whoami` in fields feeding shell/OS calls.
- **SSTI** — `${7*7}`, `{{7*7}}`, `<%= 7*7 %>` where input hits a template engine.
- **XXE** — XML/SOAP or `Content-Type: application/xml` endpoints; external entity → file read/SSRF.
- **Mass assignment** — see API3; inject `role`, `isAdmin`, `verified`, `account_id`, `price`.

**JWT attacks:** `alg:none` (strip signature); weak/guessable HMAC secret (crack with hashcat mode 16500);
**RS256→HS256** algorithm confusion (sign with the public key as HMAC secret); `kid` injection (path
traversal / SQLi in `kid`); `jku`/`x5u` pointing at attacker-hosted keys; expired/`nbf` bypass; claim
tampering (`sub`, `scope`, `admin`). For copy-pasteable JWT attacks and tooling, see
[references/jwt.md](references/jwt.md).

**OAuth/token issues:** redirect_uri manipulation, `state`/PKCE missing (CSRF), token leakage in
Referer/logs, scope escalation, implicit-flow token theft, refresh-token reuse.

**OTP / MFA / password-reset bypass:** on the verify endpoint — code not bound to user+session
(A's code verifies B → ATO), reuse / no-invalidation (after success, logout, or password change),
verify-endpoint rate-limit bypass (per-IP header rotation, casing/padding, `/v2` + mobile surface),
race on verify (parallel requests beat the "used" flag), OTP leaked in response body/headers, and
request-shape tricks (drop the field, `null`/empty, array/object type confusion, skip the step). Also
brute-forceable backup/recovery codes. Full catalog: [references/auth-bypass.md](references/auth-bypass.md).

**Other classes:**
- **Rate-limit / enumeration** — username/email enumeration via response or timing diffs; test if limits
  reset per-IP/header and can be bypassed (`X-Forwarded-For`/`X-Real-IP` rotation, code casing/padding,
  `/v1`↔`/v2` and mobile endpoints) — prove the gap, don't flood. On OTP/reset verify this re-enables
  brute force; see [references/auth-bypass.md](references/auth-bypass.md).
- **Verb tampering** — `GET` vs `POST` vs `PUT` vs `HEAD` vs arbitrary verbs on the same route.
- **Content-type confusion** — swap `application/json` ↔ `x-www-form-urlencoded` ↔ `xml` to dodge
  filters/parsers or trigger XXE.
- **CORS on APIs** — reflected/`null`/wildcard `Origin` with `Allow-Credentials: true` → cross-origin reads.
- **HTTP request smuggling** on API gateways/proxies — CL.TE / TE.CL desync to bypass front-end authz.

**gRPC-specific:** enumerate methods via server reflection (`grpcurl list` / `describe`); call
sensitive methods across privilege levels (BOLA/BFLA apply to unary and streaming RPCs alike); tamper
protobuf fields (`grpcurl -d '{...}'`) to inject IDs, extra fields (mass assignment), and injection
payloads; check whether metadata (auth tokens in gRPC headers) is validated per-method; test
transcoding gateways (gRPC-JSON/`grpc-gateway`) as a REST surface; watch for missing TLS on `-plaintext`.

**GraphQL-specific:** (copy-pasteable queries in [references/graphql.md](references/graphql.md))
| Issue | Test |
| --- | --- |
| Introspection exposed | `__schema` query returns full schema in prod. |
| Batching / aliasing abuse | Send many aliased queries in one request to brute-force or bypass rate limits (e.g. 100 aliased `login`). |
| DoS via deep/nested queries | Deeply nested/recursive relations — flag the *possibility*; do not actually run a query-of-death. |
| Field suggestion leakage | Typo'd fields return "Did you mean…" — reconstruct a hidden schema. |
| Authz bypass | Reach the same object via a different query path/edge that skips the authz check; mutations lacking checks. |
| GET-based CSRF | GraphQL endpoint accepts queries (and sometimes mutations) over `GET` with query params → CSRF-able; test `?query={...}` and mutation-over-GET, no CSRF token / SameSite. |
| Directive-overloading DoS | Abuse repeated `@skip`/`@include` directives (and field/alias duplication) to blow up query cost; combine with deep nesting and aliasing/batching for amplification. |

---

## 4. Testing technique notes

- **Two-account replay.** Keep A and B (and unauth) sessions in Burp/Postman. For every ID-bearing or
  privileged request, replay across sessions and diff — this is how BOLA/BFLA get proven.
- **Tamper JWTs** in Repeater / jwt_tool: flip `alg`, edit claims, try key-confusion, re-sign.
- **Fuzz JSON structure**, not just values: add fields, nest objects, send arrays where scalars expected,
  wrap values (`{"$ne":...}`), send nulls/oversized types. Type confusion breaks weak validators.
- **Test undocumented verbs & routes** from kiterunner/arjun output and JS-derived paths.
- **Diff responses** — status, length, timing, and body fields — to catch enumeration and silent authz gaps.
- **Automate within limits.** Serial, throttled, single-account for anti-automation checks. Never parallel
  floods; honor program rate limits. Use OOB (Collaborator/interactsh) for blind SSRF/injection.

**Quick starting checklist for a new API target:**

1. Grab the spec (OpenAPI/GraphQL introspection/gRPC reflection) or reconstruct it (GhostJS, mobile proxy).
2. Import into Postman/Burp; set up A / B / unauth sessions with their tokens.
3. Sweep every ID-bearing GET across sessions (BOLA) before touching writes.
4. Enumerate admin/privileged routes and replay as low-priv (BFLA); try alternate verbs.
5. On each write endpoint, add unexpected fields (mass assignment) and diff responses for over-exposure.
6. Point every URL/host param at internal metadata (SSRF); fuzz string params for injection.
7. Inspect the auth token — JWT/OAuth weaknesses (§3) — and old API versions (API9).

---

## 5. Validation (climb the Trinet Validation Ladder (RULES §3) before writing anything up)

Apply the Trinet Validation Ladder (RULES §3) — all 8 rungs: real class · reachable · exploitable now ·
concrete impact · in scope · reproducible · not a duplicate/informational · evidence captured.

**Do NOT report these API false-positives (no impact = no bug):**
- Verbose errors / stack traces with **no** exploitable data or follow-on.
- Data that is **documented public** (intentionally open endpoints, public profiles).
- **Missing security headers** with no demonstrated exploit.
- **Rate-limit-only** observations with no sensitive flow behind them.
- **"Self-only" IDOR** — accessing your *own* data by ID is not a bug; you must reach *another* tenant's.
- Introspection enabled where the schema is already public / intended.

If it doesn't climb all 8 rungs, fix the gap or drop it. Apply the RULES §2 5-minute rule per path.

---

## 6. Reporting

Use the **impact-first** report format from RULES §4: Title · Severity · Summary · Steps to Reproduce ·
Proof of Concept (request/response, redacted) · Impact · Remediation · References.

- Lead with attacker outcome ("any user reads any other user's orders"), then the minimal repro.
- Include the exact request/response pair (tokens/PII redacted) and both account contexts for authz bugs.
- **References:** cite the OWASP API risk (e.g. *API1:2023 BOLA*) **and** the CWE — e.g. CWE-639
  (IDOR/BOLA), CWE-285 (BFLA), CWE-915 (mass assignment), CWE-201 (excessive data exposure), CWE-918
  (SSRF), CWE-89 (SQLi), CWE-943 (NoSQLi), CWE-77/78 (command injection), CWE-1336 (SSTI),
  CWE-611 (XXE), CWE-347 (JWT signature), CWE-770 (unrestricted resource consumption), CWE-287
  (broken authentication), CWE-640 (weak password recovery), CWE-307 (no brute-force protection / OTP),
  CWE-362 (race). Chain related
  findings so triage sees the full blast radius (e.g. BOLA + excessive data exposure = full-tenant read).
- State severity on the program's scale with a one-line justification; give a specific, actionable fix
  (e.g. "enforce object-level authz server-side keyed to the session, not the client-supplied ID"),
  never just "sanitize input".
- Export validated findings as a **TrinetLayer VAPT PDF** for delivery; GhostJS output can seed the recon
  appendix. Platform: https://app.trinetlayer.com (optional accelerator, not a requirement).
