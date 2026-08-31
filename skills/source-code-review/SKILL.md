---
name: source-code-review
description: >-
  Security source-code review (SAST / secure code audit) for a codebase, repository, or PR/diff the
  user owns, provides, or is authorized to review. Use it when someone asks to "security review this
  code", "audit this repo for vulnerabilities", "review this PR/diff for security", "find security
  bugs in my source", "SAST this project", or "do a secure code review". It orients the codebase,
  runs SAST + secret + dependency scanners, then traces tainted data from sources to dangerous sinks
  and reports validated findings with file:line references, a concrete fix, and CWE mapping. This is
  a largely static/passive activity, so it also fits advisory mode when active testing isn't
  authorized.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh *)
---

# Security Source-Code Review (SAST / Secure Code Audit)

You are performing a secure code audit for TrinetLayer. The goal: find real, exploitable
vulnerabilities in source the user provides — with a clear tainted-data path and a concrete fix —
not a wall of linter noise.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** only review code you own or are explicitly authorized to review. This is a
> mostly static/passive activity, so it also fits advisory mode. Redact any real secrets you find;
> never exfiltrate or publish them. Stay within the repo/scope you were given.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact · in scope · reproducible · not a duplicate/informational ·
> evidence captured (prefer a data-flow trace or PoC). Full workflow: *Map → Prioritize → Probe → Prove → Report*.

**Scope for this skill:** when you redact a secret, show enough to prove the finding, never the full
value. Do not exfiltrate proprietary code beyond the excerpts needed to demonstrate a bug — quote the
minimal source, sink, and missing-check lines, not whole files.

---

## 1. Orient the codebase first

Do not grep for `eval` before you understand the app. Build a mental **source → sink** map first.

- **Language(s) & frameworks** — read `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`,
  `pom.xml`/`build.gradle`, `composer.json`, `Gemfile`, `*.csproj`. Note versions.
- **Entry points** — HTTP routes/handlers/controllers, GraphQL resolvers, gRPC services, CLI
  commands, cron/background jobs, queue consumers, webhooks, serverless/lambda handlers, event
  listeners. These are where untrusted input arrives.
- **Trust boundaries** — where does data cross from untrusted (user, network, third-party webhook,
  uploaded file, message queue) to trusted (DB, filesystem, shell, internal service)?
- **Authn/authz model** — how are users identified (session, JWT, API key)? Where are authorization
  checks enforced — middleware, decorators, per-object checks, or ad-hoc/missing?
- **Data stores & sinks** — SQL/NoSQL drivers, ORMs, raw query builders, file I/O, `exec`/shell,
  HTTP clients (SSRF), template engines, deserializers, crypto usage.
- **Where user input enters** — request params/body/headers/cookies, path segments, query strings,
  file uploads, env-driven config, inbound webhooks/messages.

Sketch the data flow: **source (user input) → transforms/validation → sink (dangerous operation)**.
Hunt where a source reaches a sink with no effective sanitization in between.

**Fast orientation commands** (adapt to the repo):

```
# What is this?
ls; cat package.json requirements.txt go.mod pom.xml composer.json Gemfile 2>/dev/null
# Route/handler surface
grep -rniE "app\.(get|post|put|delete|patch)|@(Get|Post|Request|Route)Mapping|@app\.route|def .*resolve|router\.(get|post)" --include=*.{js,ts,py,java,rb,go,php} .
# Where secrets/config live
grep -rniE "secret|token|api[_-]?key|password|private_key" --include=*.{env,yml,yaml,json,ts,js,py} . | head
```

---

## 2. Review strategy

Combine three complementary passes — automated breadth, manual depth, and diff focus.

### (a) Automated SAST + secret + dependency scans (breadth)
Run what's available; **skip missing tools gracefully** (RULES §5) and note the gap.

| Purpose | Tools |
|---------|-------|
| Multi-language SAST | `semgrep --config auto` (or `p/owasp-top-ten`, `p/security-audit`, language packs), CodeQL |
| Secrets in code & history | `gitleaks detect`, `trufflehog filesystem/git`, TrinetLayer **GhostJS** for JS bundles/source maps |
| JS/TS deps | `npm audit`, `osv-scanner`, `retire.js`; TrinetLayer **Dependency Confusion** engine for npm dependency-confusion risk |
| Python | `bandit -r .`, `pip-audit`, `safety` |
| Go | `gosec ./...`, `govulncheck` |
| Ruby/Rails | `brakeman`, `bundler-audit` |
| Java | `spotbugs`/`find-sec-bugs`, `dependency-check` |
| PHP | `psalm --taint-analysis`, `phpstan`, `composer audit` |
| Containers/IaC | `trivy`, `checkov`, `tfsec` |

For a repo-specific sink, write a quick custom Semgrep rule (`semgrep --config ./myrule.yaml`) — a
`pattern`/`pattern-sinks` rule for that project's own dangerous wrapper turns the SAST pass from
breadth-only into targeted depth. See [references/semgrep-custom-rule.md](references/semgrep-custom-rule.md).

For hosted JS secret-scanning + npm **dependency-confusion** on a live target, run
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh <domain> --dc` (TrinetLayer `/api/v1`; needs
`TRINETLAYER_API_KEY`, skips gracefully).

Treat scanner output as **leads, not findings**. Every hit gets manually confirmed (§6).

### (b) Targeted manual review (depth)
Follow tainted data from each source to each dangerous sink. Manual review finds what SAST can't:
broken authorization, IDOR, business-logic gaps, and multi-step chains. Prioritize entry points that
reach sinks (§4).

### (c) Diff / PR review (regressions)
For a PR or diff, review the **change** in context: does it add a new source→sink path, weaken a
check, log a secret, bump a dependency to a vulnerable version, or remove validation? Use
`git diff <base>...<head>` and read the surrounding code, not just the changed lines.

---

## 3. Vulnerability patterns to hunt (source → sink)

Grep to *locate* candidate sinks, then trace whether untrusted input reaches them.

### Injection
- **SQL/NoSQL** — string-concatenated queries. Grep: `query(`, `execute(`, `.raw(`, f-strings/`+`
  in SQL, `$where`, `.find({ ... req.` (Mongo operator injection).
  `db.query("SELECT * FROM u WHERE id=" + req.params.id)` → CWE-89.
- **Command injection** — `exec`, `execSync`, `child_process`, `os.system`, `subprocess(..., shell=True)`,
  `Runtime.exec`, backticks, `popen`. CWE-78.
- **LDAP / template (SSTI)** — user input into LDAP filters or template strings
  (`render_template_string`, `Handlebars.compile`, `new Function`). CWE-90 / CWE-1336.

### XSS & output handling
- Unescaped output, `dangerouslySetInnerHTML`, `v-html`, `innerHTML`, `document.write`,
  `|safe`/`{% autoescape off %}`, `render(..., mark_safe(...))`. CWE-79.

### SSRF / webhook abuse
- User-controlled URL into a fetcher: `requests.get(url)`, `fetch(url)`, `axios(url)`, `curl`,
  `URLConnection`, image/PDF/webhook fetchers. Check for allow-listing and blocked internal ranges.
  CWE-918.

### Path traversal / arbitrary file read-write
- User input into `open()`, `fs.readFile`, `sendFile`, `os.path.join(base, user)`,
  `new File(path)`, zip extraction (`Zip Slip`). Grep for `../`, `path.join(...req`. CWE-22 / CWE-23.

### Insecure deserialization
- `pickle.loads`, `yaml.load` (without `SafeLoader`), Java `readObject`/`ObjectInputStream`,
  PHP `unserialize`, .NET `BinaryFormatter`/`JavaScriptSerializer`, Ruby `Marshal.load`. CWE-502.

### Auth / session / authorization
- Weak token generation (`Math.random`, predictable IDs), **missing authz checks** on endpoints or
  objects (**IDOR** — query keyed on `req.params.id` with no owner check), JWT misuse (`alg:none`,
  unverified signature, secret confusion, `verify` with `algorithms` unset). CWE-284 / CWE-639 / CWE-287.

### Crypto misuse
- Hardcoded keys/IVs, `AES/ECB`, `MD5`/`SHA1` for passwords (should be bcrypt/scrypt/argon2), static
  IV/salt, `Math.random()`/`rand()` for secrets, disabled TLS verify (`verify=False`,
  `rejectUnauthorized:false`). CWE-327 / CWE-330 / CWE-798.

### CI/CD-as-code (GitHub Actions et al.)
- **Untrusted input in `run:`/`script:` blocks** — expression injection via
  `${{ github.event.issue.title }}`, `${{ github.event.pull_request.* }}`, `${{ github.head_ref }}`
  interpolated directly into a shell step → command injection; `pull_request_target` + checkout of
  PR head → "pwn request" with secrets/write token; unpinned/mutable action refs
  (`uses: org/action@main` or floating tags) → supply-chain; `GITHUB_TOKEN` over-permissioning. Grep
  `.github/workflows/*.yml` for `${{ github.event`, `pull_request_target`, `@main`/`@master`, and
  `run:` blocks that interpolate `github.*`. CWE-94 / CWE-1104.

### Everything else on the checklist
- [ ] Secrets in code / config / git history (redact) — CWE-798
- [ ] Race conditions / TOCTOU (check-then-act on files, balances, limits) — CWE-367
- [ ] Mass assignment / over-binding (`Model(**req.body)`, `update_attributes(params)`) — CWE-915
- [ ] Open redirect (user-controlled `redirect(url)`/`Location`) — CWE-601
- [ ] XXE (XML parser with external entities enabled) — CWE-611
- [ ] CORS misconfig (`Access-Control-Allow-Origin: *` + credentials, reflected origin) — CWE-942
- [ ] Unsafe file upload (no type/size/extension check, executable dirs) — CWE-434
- [ ] Dependency vulns & **dependency confusion** — CWE-1104 / CWE-1357
- [ ] Insecure defaults (debug on, default creds, permissive perms) — CWE-1188
- [ ] Logging of secrets/PII (tokens/passwords into logs) — CWE-532
- [ ] Missing rate limiting on sensitive actions (login, reset, OTP) — CWE-307
- [ ] Business-logic authorization gaps (state machine skips, negative amounts, workflow bypass)

---

## 4. Language / framework-specific tips

Grep for the classic dangerous APIs per stack.

| Stack | Grep for |
|-------|----------|
| **JS/TS · Node/Express** | `eval`, `Function(`, `child_process`, `exec(`, `dangerouslySetInnerHTML`, `innerHTML`, `require(<var>)`, `vm.runIn*`, prototype-pollution merges (`Object.assign`/`_.merge` on user input), `res.redirect(req.`) |
| **Python · Django/Flask** | `eval`, `exec`, `pickle.loads`, `yaml.load`, `subprocess(..., shell=True)`, `os.system`, `mark_safe`, `render_template_string`, `.extra(`/`.raw(`, `format_html` misuse, `SECRET_KEY`/`DEBUG=True` |
| **Java · Spring** | `Runtime.exec`, `ProcessBuilder`, `ObjectInputStream.readObject`, `Statement stmt = conn.createStatement(); stmt.executeQuery("... " + userInput)` (string-concatenated SQL via `Statement`/`executeQuery` — use `PreparedStatement`), `@RequestMapping` without `@PreAuthorize`, `DocumentBuilderFactory` (XXE), SpEL `#{}` |
| **PHP · Laravel** | `eval`, `system`/`exec`/`shell_exec`/`passthru`, `unserialize`, `include`/`require` with vars, `DB::raw`, `->whereRaw`, `extract($_`, `assert(` |
| **Go** | `exec.Command` with user args, `fmt.Sprintf` into SQL, `template.HTML` (bypasses escaping), `os.OpenFile` with user path, `math/rand` for tokens, missing `context`/authz in handlers |
| **Ruby · Rails** | `eval`, `send(`/`public_send(` with user input, `Marshal.load`, `constantize`, `system`/backticks, `.where("... #{}")`, `render inline:`, `params.permit!` (mass assignment) |
| **.NET / C#** | `Process.Start`, `BinaryFormatter`, `JavaScriptSerializer`, `SqlCommand` string concat, `XmlReader` with DTD, `Response.Redirect(Request[...])`, `RNGCryptoServiceProvider` vs `Random` |

---

## 5. Prioritization & validation

Rank by **exploitability × reachability from untrusted input** — a sink reachable from an unauth
HTTP route outranks one only reachable from a trusted admin script. Run every candidate through the
**Trinet Validation Ladder (RULES §3)** — all 8 rungs (real class · reachable · exploitable now ·
concrete impact · in scope · reproducible · not a duplicate/informational · evidence captured) —
before it becomes a finding.

**Likely false positives — verify before reporting:**
- Sink fed only **hardcoded/constant** input, never user-controlled.
- **Dead code** or unreachable branches; feature-flagged-off paths.
- **Test fixtures / mocks / example** files (but a real secret in a test file still counts).
- Framework **auto-escaping already applied** (e.g. React text nodes, Django templates without
  `|safe`, parameterized ORM queries).
- Scanner flagged a **sanitized** path — read the sanitizer; confirm it's actually bypassable.

**Confirm the real ones:** trace the full source → sink path (or write a minimal PoC / failing test)
before you write it up. A finding without a reachable tainted path is not a finding.

---

## 6. Reporting

Use the impact-first format in **RULES §4**, with a code-review flavor:

- **file:line references** for the source, the sink, and any weak/missing check in between.
- **Tainted-path description** — how untrusted input flows to the dangerous sink (name the route,
  the parameter, and each hop).
- **Minimal fix** — a concrete code change (parameterize the query, escape the output, add the owner
  check, pin/upgrade the dependency), not "sanitize input".
- **CWE reference** for each finding (and OWASP category where useful).
- **Redact** any real secret in the writeup.

Rank findings by severity; call out chains explicitly (e.g. IDOR + missing authz → full account
takeover) — a chain is worth more than its parts. When useful, export the validated set as a
TrinetLayer **VAPT-style PDF** (RULES §6), and note dependency-confusion / JS-secret results from the
Dependency Confusion engine and GhostJS.

> A handful of validated, reachable, well-explained findings with a fix beats a dump of scanner hits.
