# Custom Semgrep rules for repo-specific sinks

`semgrep --config auto` finds the generic sinks. It does **not** know about *this* project's own
dangerous wrappers — the internal `db.raw()`, the home-grown `render()`, the `httpGet()` helper that
skips SSRF checks. A ten-line custom rule turns the SAST pass from breadth-only into targeted depth:
you tell Semgrep the exact sink your codebase invented, and it finds every call site.

Write a custom rule when:
- The project wraps a dangerous primitive in its own function (`Database.raw`, `unsafeHTML`, `sh`).
- A generic rule is too noisy and you want to match only the tainted shape.
- You want taint tracking from a framework's request object to a project-specific sink.

Run any rule file with:

```bash
semgrep --config ./rule.yaml .            # one rule file over the repo
semgrep --config ./rules/ .               # a directory of rule files
semgrep --config ./rule.yaml --config p/security-audit .   # stack custom + registry packs
semgrep --config ./rule.yaml --sarif -o out.sarif .        # machine-readable output
```

---

## 1. Simple `pattern` rule — catch a project's own dangerous wrapper

Example: the app forbids raw SQL everywhere except an internal `db.raw(...)` escape hatch. Flag every
call so each can be reviewed for concatenated/interpolated input.

```yaml
# rule.yaml
rules:
  - id: project-db-raw-called
    languages: [javascript, typescript]
    severity: WARNING
    message: >-
      db.raw() executes an unparameterized query. Confirm the argument is a constant
      string with bound parameters, never concatenated/interpolated user input (CWE-89).
    metadata:
      cwe: "CWE-89: Improper Neutralization of Special Elements used in an SQL Command"
      owasp: "A03:2021 - Injection"
    patterns:
      - pattern: db.raw($X)
      # narrow to the dangerous shape: only flag when $X is built, not a bare literal
      - pattern-not: db.raw("...")
```

Key operators inside `patterns:` (implicit AND):
- `pattern:` — the code shape to match. `$X`, `$Y` are metavariables (match any expression); `...`
  matches any sequence of args/statements.
- `pattern-not:` — subtract a safe shape (here, a plain string literal) to cut false positives.
- `pattern-inside:` / `pattern-not-inside:` — scope to (or exclude) a surrounding block.
- `metavariable-pattern` / `metavariable-regex` — constrain what a metavariable may be.

A **`pattern-sinks`-style** variant that lists several project sinks in one rule via `pattern-either`:

```yaml
rules:
  - id: project-html-sinks
    languages: [javascript, typescript]
    severity: ERROR
    message: "User input reaching a raw-HTML sink → XSS (CWE-79). Escape or sanitize first."
    metadata: { cwe: "CWE-79", owasp: "A03:2021 - Injection" }
    patterns:
      - pattern-either:
          - pattern: render($X)              # project's own unescaped template render
          - pattern: $EL.innerHTML = $X
          - pattern: unsafeHTML($X)
      - pattern-not: render("...")
```

### Python example — a home-grown shell wrapper

```yaml
rules:
  - id: project-sh-command-injection
    languages: [python]
    severity: ERROR
    message: "sh() runs a shell command; interpolated input → command injection (CWE-78)."
    metadata: { cwe: "CWE-78", owasp: "A03:2021 - Injection" }
    patterns:
      - pattern: sh(f"...{$X}...")            # f-string with an interpolated value
```

---

## 2. Taint-mode rule — track a source through to a project sink

`mode: taint` follows data flow: anything matching `pattern-sources` that reaches `pattern-sinks`
(without passing through a `pattern-sanitizers`) is reported. This is what finds the real bug —
untrusted request data flowing into the wrapper — instead of every call site.

```yaml
# taint-rule.yaml
rules:
  - id: req-into-db-raw-taint
    mode: taint
    languages: [javascript, typescript]
    severity: ERROR
    message: >-
      Request-controlled data flows into db.raw() without parameterization → SQL injection (CWE-89).
      Use bound parameters: db.raw("... WHERE id = ?", [id]).
    metadata:
      cwe: "CWE-89"
      owasp: "A03:2021 - Injection"
    pattern-sources:
      - pattern: req.params
      - pattern: req.query
      - pattern: req.body
      - patterns:
          - pattern: $REQ.$PROP
          - metavariable-regex:
              metavariable: $REQ
              regex: ^(req|request|ctx)$
    pattern-sanitizers:
      - pattern: parseInt(...)
      - pattern: escapeSql(...)
      - pattern: db.escape(...)
    pattern-sinks:
      - pattern: db.raw($SINK)
      - pattern: db.query($SINK)
```

How the four source/sink/sanitizer sections work:
- `pattern-sources` — where untrusted data originates. List every request accessor the framework
  exposes (Express `req.*`, Flask `request.*`, etc.).
- `pattern-sinks` — the dangerous operation. Point these at the **project's own** wrappers, not just
  the generic driver call — that's the whole reason to hand-write the rule.
- `pattern-sanitizers` — anything that renders the data safe. A path through one of these is **not**
  reported. Getting these right is what kills false positives (parameterization, integer coercion,
  an allow-list validator).
- `pattern-propagators` (optional) — functions that carry taint through (e.g. `$Y = wrap($X)`), for
  when data is laundered through a helper before hitting the sink.

Run it exactly like a search rule:

```bash
semgrep --config ./taint-rule.yaml --sarif -o taint.sarif .
```

---

## Tips

- Prototype patterns fast at <https://semgrep.dev/playground> against a pasted snippet, then save the
  YAML into the repo.
- `semgrep --validate --config ./rule.yaml` checks rule syntax before you run it.
- Keep custom rules in a `./semgrep/` dir in the repo and run `semgrep --config ./semgrep/ .` so the
  whole targeted rule set runs in one pass alongside the registry packs.
- Every hit is still a **lead, not a finding** — trace the tainted path and confirm reachability
  before it climbs the Trinet Validation Ladder.
