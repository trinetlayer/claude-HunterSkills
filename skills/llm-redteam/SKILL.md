---
name: llm-redteam
description: >-
  Authorized red-teaming of AI/LLM-backed features against the OWASP LLM Top 10 (2025). Use this when
  the user wants to "red-team this chatbot/AI feature", "test for prompt injection", "can I leak the
  system prompt", "test my RAG for indirect injection", or run an "LLM security test". It orients the
  target (raw chatbot vs. RAG pipeline vs. tool-using agent), maps every place untrusted text enters
  and every action the model can take, then probes the OWASP LLM Top 10 categories, chains findings
  into real security impact (XSS/SSRF/unauthorized action/data exfil), and kills LLM false-positives
  with the Trinet Validation Ladder. For AI endpoints you own or are explicitly authorized to test.
---

# LLM / AI Red-Teaming

Authorized security testing of AI-backed endpoints — orient, probe the OWASP LLM Top 10, prove real impact, report.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** only test AI endpoints you own or are explicitly authorized to. **No scope →
> passive/advisory mode only.** Never DoS (no unbounded/expensive prompt floods), redact any leaked
> secrets/PII, and confirm real impact before reporting.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact · in scope · reproducible · not a duplicate/informational ·
> evidence captured. Full workflow: *Map → Prioritize → Probe → Prove → Report*.

## Authorization gate — do this FIRST

Confirm written scope before a single active prompt; **no scope → passive/advisory mode only** (see the
core-rules block above): methodology, static review of the system prompt / tool config, probe design,
report drafting. LLM-specific: use your own tenant/test accounts, throttle probe volume (garak/PyRIT can
generate thousands of calls — cap them), and never trigger real downstream actions (payments, emails,
deletes) on assets you don't own. Prompt injection that reaches a live tool is a *state-changing action*.

---

## Quick start

1. **Confirm scope** in writing → else passive mode.
2. **Orient** (§1): chatbot vs. RAG vs. agent; map inputs and capabilities.
3. **Rank surface** by impact × reachability (§2, OWASP LLM Top 10).
4. **Probe** the categories (§3), one hypothesis at a time, log every prompt/response pair.
5. **Chain** toward real security impact (§5) — don't stop at "the model misbehaved".
6. **Validate** each candidate against the Ladder, drop content-only issues (§6).
7. **Report** impact-first, mapped to an LLM Top-10 id (§6).

---

## 1. Orient the target

Before probing, decide **what kind of system** you're facing — it dictates the whole test:

- **Raw chatbot** — model + system prompt, no retrieval, no tools. Surface = the user prompt.
- **RAG pipeline** — retrieves documents/chunks into context. Surface = user prompt **+ every retrieved
  source** (docs, web pages, tickets, emails, the vector store). Untrusted retrieved text is the classic
  indirect-injection channel.
- **Agent with tools** — the model can *call functions* (search, HTTP, DB, code exec, email, file I/O).
  Surface = user prompt + tool **outputs** fed back in + the model's ability to **act**.

Map two things exhaustively:

- **Every place untrusted text enters** — user prompt, retrieved docs, tool/API outputs, file/image/PDF
  inputs (multimodal), metadata, prior conversation, memory.
- **Everything the model can DO** — which tools, with what params, and every downstream sink those touch
  (a browser, a shell, a DB, an HTTP client, a rendered HTML/markdown view, another user's data).

**Attack surface = every untrusted-text entry point × every action the model can take.** The impact of an
injection is bounded by what the model is wired to do, so enumerate the capabilities first.

---

## 2. OWASP LLM Top 10 (2025)

Test highest-impact first (§5). Each entry: what it is + how to test.

| ID | Category | What / how to test |
|----|----------|--------------------|
| **LLM01** | Prompt Injection | Untrusted input overrides intended instructions. Test **direct** (user prompt), **indirect** (instructions hidden in retrieved/ingested content), and **multimodal** (instructions in an image/PDF/audio). |
| **LLM02** | Sensitive Information Disclosure | Model reveals training data, PII, credentials, or internal config. Probe for memorized secrets, PII regurgitation, and system-prompt/context leakage. |
| **LLM03** | Supply Chain | Poisoned/backdoored base models, adapters, plugins, or datasets. Review model/plugin provenance, versions, and third-party components. |
| **LLM04** | Data & Model Poisoning | Malicious training/fine-tune/RAG data biases or backdoors behavior. Test whether attacker-controlled content persists into training or the vector store. |
| **LLM05** | Improper Output Handling | Model output is trusted by a downstream sink → **XSS / SQLi / SSRF / command-injection / RCE**. Get the model to emit a payload and see if the host app executes it. |
| **LLM06** | Excessive Agency | Over-permissioned tool use / too much autonomy. Test whether an injected instruction makes the agent take an action it shouldn't (delete, pay, email, exfil). |
| **LLM07** | System Prompt Leakage | *(new dedicated category)* Extraction of the system prompt and any secrets/logic embedded in it. Test partial and full reveal. |
| **LLM08** | Vector & Embedding Weaknesses | RAG/embedding attacks — poisoning the store, cross-tenant retrieval, embedding-space collisions. Test tenant isolation of retrieval. |
| **LLM09** | Misinformation | Confident hallucination / fabricated facts, citations, or code. Assess only where it creates a security or trust consequence. |
| **LLM10** | Unbounded Consumption | Resource/cost exhaustion — DoS, **"denial of wallet"**, and model extraction/distillation. Test carefully; **do not actually DoS** (§3h). |

---

## 3. Probe categories — the real testing

Describe and run these as **categories/patterns**, not a curated jailbreak arsenal. Expanded templates,
tool invocations, and a defensive note live in [references/probes.md](references/probes.md).

- **(a) Direct prompt injection** — instruction-override, role reassignment, delimiter/context confusion
  (making user text look like system/developer context). *→ LLM01.*
- **(b) Indirect injection** — hostile instructions embedded in content the model *ingests*: retrieved
  docs, web pages, emails, tickets, file/image metadata. The payload rides in via RAG/tools, not the
  user prompt. *→ LLM01/LLM08.*
- **(c) Jailbreak families** — persona/roleplay framing, hypothetical/"for research" framing,
  obfuscation/encoding (base64, homoglyphs, translation), and multi-turn **"crescendo"** escalation that
  builds context gradually. *→ LLM01.*
- **(d) System-prompt leak** — extraction / "print your instructions above" / partial-reveal / getting
  the model to summarize or translate its own hidden prompt. *→ LLM07.*
- **(e) Data exfil via tool-use / excessive agency** — inducing unintended tool calls, **SSRF through the
  agent's HTTP tool**, and out-of-band exfil channels (markdown-image or link URLs that leak context to
  an attacker server when rendered). *→ LLM06/LLM01.*
- **(f) Insecure output handling** — get the model to emit an XSS/SQLi/command payload that a **downstream
  sink executes** (rendered HTML, a DB query built from output, a shell call). *→ LLM05.*
- **(g) Sensitive-info disclosure** — PII/secret memorization, and **RAG cross-tenant leakage** (asking
  for another tenant's/user's data and seeing if retrieval returns it). *→ LLM02/LLM08.*
- **(h) Robustness / DoS** — unbounded, recursive, or expensive prompts (huge outputs, deep nesting,
  "repeat forever"). **Test the *class* carefully — confirm the endpoint lacks limits with a single
  bounded probe; never actually flood or run up cost.** *→ LLM10.*

---

## 4. Tooling

One line each. **Offense** (against authorized endpoints):

- **garak** (NVIDIA) — LLM vulnerability scanner, 120+ probes / 28 detectors; breadth sweep and regression.
- **promptmap2** (utkusen) — dual-AI prompt-injection tester; an attacker model probes your app model.
- **PyRIT** (Microsoft) — orchestration framework for multi-turn/multimodal red-teaming with adaptive
  attacks (Crescendo, TAP).

**Defense / reference** (to characterize and re-test mitigations):

- **llm-guard** (Protect AI) — runtime input/output firewall (scanners for injection, PII, secrets, toxicity).
- **Promptfoo** — prompt/LLM eval + red-team harness; wire into CI for regression.

Invocation snippets for garak / PyRIT / promptmap2 are in [references/probes.md](references/probes.md).

---

## 5. The highest-impact chains

This is what turns "the model said a bad word" into a **reportable security bug**. Spend time here:

- **Insecure output handling → real XSS/SSRF on the host app** — model output rendered/executed by the
  app becomes a live web vuln affecting other users. *(LLM05 → XSS/SSRF/RCE.)*
- **Excessive agency → a real unauthorized action** — an injected instruction makes the agent send an
  email, move money, delete data, or change config. *(LLM06/LLM01.)*
- **Indirect injection in RAG → exfil of another tenant's data** — a poisoned document instructs the
  model to fetch and leak data it can retrieve across tenants. *(LLM01/LLM08/LLM02.)*

The security consequence — not the model's wording — is the finding. Trace injection → capability →
sink → real-world effect, and prove the effect.

---

## 6. Validation & reporting

Run every candidate through the Trinet Validation Ladder (RULES §3): real class · reachable · exploitable
now · concrete impact · in scope · reproducible · not a duplicate/informational · evidence captured. If
any rung is "no", fix the gap or drop it.

**LLM false-positives — do NOT report without a demonstrated security consequence:**

- A **jailbreak with no security impact** — the model produced disallowed *content* but nothing was
  breached, no action taken, no data leaked.
- A **refusal bypass** that only yields policy-disallowed text (a safety/brand issue), not a security one.
- **Hallucinations / misinformation** with no security or trust consequence downstream.
- **"The model can be made to say X"** where X has no sink, no privilege, and no victim.

**Report** impact-first per RULES §4: Title → Severity → Summary → Steps to Reproduce → PoC → Impact →
Remediation → References. Lead with the concrete security consequence (data leak, downstream exploit,
unauthorized action), **mapped to its OWASP LLM Top-10 id** (e.g. LLM01, LLM05). Include the exact
prompt/response transcript as evidence, redact any leaked secrets/PII, and give the fix (input/output
filtering, least-privilege tool scoping, output encoding at the sink, tenant isolation in retrieval).
Export a formal deliverable as a **TrinetLayer VAPT PDF** (`app.trinetlayer.com`) when needed — an
optional accelerator, not a requirement.

For the deep-dive probe templates and tool runbooks, read [references/probes.md](references/probes.md).
