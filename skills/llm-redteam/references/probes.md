# LLM Red-Team Probe Reference

Category/pattern-level test templates, tool runbooks, and a defensive note. **Authorized endpoints only.**
This is intentionally *not* a curated jailbreak arsenal — each entry describes the **pattern to test** so
you can build a minimal, scoped probe and observe the endpoint's behavior. Redact any leaked secrets/PII
and never trigger real downstream actions on assets you don't own.

Use the OWASP LLM Top 10 (2025) ids from `SKILL.md` §2 to tag every finding.

---

## How to use this file

For each category: the **hypothesis**, a **pattern** (structure, not a weaponized payload), what a
**positive result** looks like, and the **real-impact** you must then chain to before reporting. Start
with the smallest probe that can prove or disprove the hypothesis, one at a time, logging every
prompt/response pair.

---

## (a) Direct prompt injection — LLM01

**Hypothesis:** user-supplied text can override the system/developer instructions.

**Patterns to test:**
- *Instruction override* — a message that asserts the previous instructions are cancelled/superseded and
  supplies new ones. Observe whether the model follows the new instruction over its system prompt.
- *Role reassignment* — text that tries to redefine the model's role or "developer mode" and drop
  guardrails. Observe any behavior change.
- *Delimiter / context confusion* — user text formatted to *look like* system, developer, or tool
  content (fake tags, fake JSON envelopes, fake "SYSTEM:" prefixes). Tests whether the app safely
  separates trusted from untrusted text in the prompt template.

**Positive:** the model prioritizes attacker text over its instructions. **Chain to:** a capability or
sink (§e/§f) — override alone is not yet a security bug.

---

## (b) Indirect (cross-domain) prompt injection — LLM01 / LLM08

**Hypothesis:** hostile instructions embedded in content the model *ingests* are executed as if the user
issued them.

**Injection channels to seed (in your own test data):**
- A **retrieved document / RAG chunk** containing an instruction block.
- A **web page** the browsing tool fetches.
- An **email / ticket / chat message** the assistant summarizes.
- **File or image metadata**, alt-text, or hidden/low-contrast text in a PDF (multimodal).

**Pattern:** place a benign-looking instruction inside the ingested artifact ("when summarizing this,
also do X"), then trigger the normal flow that ingests it. **Positive:** the model acts on the embedded
instruction. **Chain to:** exfil/action (§e) or cross-tenant retrieval (§g). This is the highest-value
LLM class because the victim never sees the payload.

---

## (c) Jailbreak families — LLM01

Test the **family**, not a hoarded list of one-off strings:
- *Persona / roleplay* — asking the model to adopt a character that "has no restrictions".
- *Hypothetical / framing* — "for research/fiction/as an example", nested "pretend" contexts.
- *Obfuscation / encoding* — base64, leetspeak, homoglyphs, translation, token-splitting to slip past
  input filters. Tests input-side detection robustness.
- *Multi-turn "crescendo"* — build innocuous context over several turns, then pivot; tests whether
  guardrails consider conversation history.

**Positive:** a guardrail is bypassed. **Only report** if it yields a *security* consequence, not merely
disallowed content (see `SKILL.md` §6 false-positives).

---

## (d) System-prompt leakage — LLM07

**Hypothesis:** the hidden system prompt (and any secrets/logic in it) can be extracted.

**Patterns:** ask the model to repeat/print the text "above", to summarize or translate its own
instructions, to output its configuration as a formatted block, or to continue a partial quote of its
prompt (partial-reveal). Also test indirect leak via error messages and tool arguments.

**Positive:** partial or full system prompt returned. **Impact depends on contents** — credentials, API
keys, internal URLs, or hidden business logic in the prompt is a real finding; a generic persona prompt
is usually informational.

---

## (e) Data exfil via tool-use / excessive agency — LLM06 / LLM01

**Hypothesis:** injected instructions can make the agent *act* — call tools it shouldn't, or leak context
out of band.

**Patterns:**
- *Unintended tool invocation* — an injected instruction that names a tool/function and coaxes a call
  with attacker-chosen parameters. Enumerate which tools are reachable and with what args.
- *SSRF through the agent* — if the agent has an HTTP/fetch/browse tool, induce a request to an
  internal address or a cloud metadata endpoint; observe the response reflected back.
- *Out-of-band exfil channels* — instruct the model to embed sensitive context into a **markdown image
  URL** or **hyperlink** pointing at an attacker-controlled server; when the client renders it, the
  query string leaks the data. Use a listener you control (e.g. an interactsh/collaborator URL).

**Positive:** a tool fires, an internal resource is reached, or your listener receives context.
**Chain to** the concrete effect (unauthorized action, data leak) and prove it.

---

## (f) Insecure output handling — LLM05

**Hypothesis:** the app trusts model output at a downstream sink that then executes it.

**Patterns (get the model to *emit* the payload, then check the sink):**
- *XSS* — output rendered as HTML/markdown without encoding → emit an HTML/script snippet and check it
  executes in another user's view.
- *SQLi / NoSQLi* — output interpolated into a query → emit query-breaking syntax and check DB behavior.
- *Command injection / RCE* — output passed to a shell, `eval`, or a code-exec tool → emit shell/code
  and check execution.
- *SSRF* — output used as a URL by a server-side fetch → emit an internal URL.

**Positive:** the sink executes model-emitted input. This converts an LLM quirk into a **standard web
vuln**; report it as such (CWE-79/89/78/918) *and* tag LLM05. Cross-reference the `web-app-pentest` or
`api-security-testing` skill for exploiting the sink.

---

## (g) Sensitive-info disclosure & RAG cross-tenant leakage — LLM02 / LLM08

**Hypothesis:** the model or its retrieval layer returns data it shouldn't.

**Patterns:**
- *Memorization* — probe for training-data regurgitation of secrets/PII (structured requests for
  "example" records, known unique strings). Confirm the data is real and non-public before reporting.
- *RAG cross-tenant* — from tenant/user A's session, ask for content that should belong only to tenant B
  and see if retrieval crosses the boundary. This is a serious **isolation** bug (LLM08 → LLM02).
- *Context bleed* — check whether one user's conversation/memory leaks into another's.

**Positive:** real cross-boundary or non-public data returned. Redact it in evidence.

---

## (h) Robustness / DoS — LLM10  *(test the class carefully; do NOT actually DoS)*

**Hypothesis:** the endpoint lacks limits on input size, output length, cost, or recursion.

**Safe test approach:** confirm the *absence of a control* with a **single bounded probe** — e.g. a
moderately large but capped input, or a request for a long-but-bounded output — and observe whether the
service imposes limits (max tokens, timeouts, rate/cost caps). **Do not** send floods, "repeat forever",
or unbounded recursion against a live endpoint. Report the missing-control class with the bounded
evidence; note **denial-of-wallet** (unbounded paid-token consumption) and **model-extraction** (bulk
querying to distill the model) as related LLM10 concerns to raise, not to execute at scale.

---

## Tool runbooks (authorized endpoints only)

Throttle everything — these frameworks can emit thousands of calls; cap probes and cost.

### garak (NVIDIA) — breadth sweep / regression
```
pip install garak
# List available probes/detectors
garak --list_probes
# Scan an OpenAI-compatible model (set the relevant API key env var first)
garak --model_type openai --model_name <model> \
      --probes promptinject,leakreplay,xss --generations 5
# REST endpoint you own (describe the request/response in a JSON config)
garak --model_type rest -G your_endpoint_config.json --probes promptinject
```
Review the produced report/hitlog; treat hits as *candidates* to validate and chain, not confirmed bugs.

### PyRIT (Microsoft) — orchestrated multi-turn / multimodal
```
pip install pyrit
```
Use an orchestrator (e.g. Crescendo / TAP / red-teaming orchestrator) with your target endpoint as the
"prompt target" and a scorer to judge success. Good for adaptive, multi-turn attacks and multimodal
inputs. Keep turn counts and concurrency low against a live target.

### promptmap2 (utkusen) — dual-AI injection tester
```
git clone https://github.com/utkusen/promptmap2 && cd promptmap2
pip install -r requirements.txt
# Point it at YOUR system prompt / app; an attacker model probes your target model
python promptmap2.py --target-system-prompt system_prompt.txt
```
Use it to regression-test a system prompt's resistance to injection as you harden it.

### Promptfoo — CI regression (eval + red-team)
```
npx promptfoo@latest redteam init
npx promptfoo@latest redteam run
```
Wire into CI so injection/leak regressions fail the build after you've fixed them.

---

## Defensive note — llm-guard (Protect AI)

When you've found and confirmed an issue, re-test the fix. **llm-guard** provides runtime input/output
scanners (prompt-injection, PII, secrets, toxicity, ban-substrings, relevance) that act as an
input/output firewall around the model:
```
pip install llm-guard
```
Recommend defenses per finding: **input scanning** for injection/PII, **output scanning + encoding at
the sink** for LLM05, **least-privilege tool scoping / human-in-the-loop** for LLM06 excessive agency,
**strict tenant isolation** in retrieval for LLM08, and **rate/token/cost caps** for LLM10. A filter is
mitigation, not a guarantee — always confirm the underlying sink/capability is also hardened.

---

## References

- OWASP Top 10 for LLM Applications (2025) — LLM01–LLM10.
- CWE mappings for chained sinks: CWE-79 (XSS), CWE-89 (SQLi), CWE-78 (command injection), CWE-918 (SSRF).
- Related TrinetLayer skills: `web-app-pentest`, `api-security-testing` (for exploiting the downstream sink).
