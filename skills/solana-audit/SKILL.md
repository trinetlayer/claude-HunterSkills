---
name: solana-audit
description: >-
  Guides authorized security auditing of Solana programs written in Anchor or native Rust for bug
  bounty and client-audit engagements. It covers orienting the program and its account model,
  standing up Anchor/litesvm/Trident/sec3 tooling, hunting the full Sealevel bug catalog (missing
  signer/owner checks, account & type confusion, arbitrary CPI, PDA/bump canonicalization, close/
  revival, integer overflow, rounding, sysvar spoofing, token/mint confusion, and more), proving each
  with a local PoC, and reporting impact-first with funds at risk quantified. Use it when the user says
  things like "audit this Solana program", "review this Anchor code", "check my Solana/SPL program for
  bugs", "Sealevel attack review", "find missing signer/owner checks", or points at an Immunefi Solana
  scope. Auditing source is static/advisory by default; any PoC runs on localnet/testnet/fork only.
---

# Solana / Anchor Program Security Audit (Rust / SPL / Sealevel)

Practical methodology for auditing **authorized** Solana programs: orient the program and its account
model, stand up Anchor/litesvm/fuzz/static tooling, hunt the Sealevel vulnerability classes, then prove
each finding with a local PoC and report it impact-first with funds at risk quantified.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** audit only programs you own or are explicitly authorized to (your own code,
> Immunefi/Code4rena/Sherlock scope, client audit). Reviewing source is static/passive and fits
> advisory mode. **Any on-chain interaction beyond read-only calls must be on a LOCAL validator/testnet
> or a fork** — never run an exploit against live mainnet programs or real users. Redact private keys/seeds.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact (funds at risk) · in scope · reproducible (local PoC) ·
> not a duplicate/informational · evidence captured. Full workflow: *Map → Prioritize → Probe → Prove → Report*.

**Posture (Solana specifics).** Beyond the core rules: any interaction beyond read-only RPC
(`getAccountInfo`, `simulateTransaction`) runs on a **local validator (`solana-test-validator`), litesvm,
or a fork** — never fire a crafted instruction at a live mainnet program. Work **account-model-first**:
Solana has no per-contract storage isolation. A program receives a **list of accounts as UNTRUSTED input
on every instruction** and MUST validate each one (owner, signer, type/discriminator, address). Almost
every Solana bug is *"a check the program should have done but didn't."*

This maps onto RULES §2: **Recon** = orient the program (§1) → **Surface mapping** = rank instructions by
funds-at-risk and reachability → **Testing** = tooling (§2) + vuln hunt (§3) → **Validation** = PoC +
Trinet Validation Ladder (RULES §3) (§4) → **Reporting** (§5). Log every program id, PDA, and finding.

**Deep references (load on demand):**
- `references/checklist.md` — grep-able questions per vuln class + the secure Anchor idiom for each.
- `references/poc-anchor.md` — copy-pasteable Anchor mocha PoC skeleton + a litesvm (Rust/TS) note.
- **Token / rug safety (SPL)** — read-only checklist for vetting an SPL token (mint/freeze/update
  authority revoked, LP/bonding-curve, holder concentration; RugCheck): [references/token-safety.md](references/token-safety.md).

---

## 1. Orient the program (before reading a single constraint)

Build the account/authority model first; you can't spot a missing check until you know what must be checked.

- **Classify the program** — AMM/DEX, lending, staking/rewards, vault, NFT/metadata, governance/DAO,
  stablecoin, escrow, bridge. Each has a canonical bug catalog (§3).
- **Anchor vs native** — Anchor gives you `Account<'info,T>`, `Signer`, `has_one`, `seeds`, `#[account(...)]`
  constraints that do owner/discriminator/signer checks *for you*. Native Rust programs must do all of it
  by hand — assume every check is missing until proven present.
- **Map PDAs & seeds** — for each PDA: what seeds, is the **bump** canonical and stored, are seed prefixes
  unique per account type (no PDA sharing/collision)?
- **Enumerate authorities & privileged instructions** — admin/upgrade authority, mint authority, pool
  authority, fee setter. For each: what can it do, and what's the worst if the key is rogue or the
  instruction is callable by anyone?
- **Map CPIs** — which instructions call into other programs (SPL Token, Metaplex, another vault)? Is the
  target **program id verified**, or taken from input?
- **State the invariants** that must ALWAYS hold:

| Program | Invariant that must never break |
| --- | --- |
| AMM/DEX | Constant product / reserves match vault balances; no value minted for free. |
| Lending | Positions stay over-collateralized; can't withdraw more than deposited. |
| Vault | `vault_balance ≥ Σ redeemable(shares)`; shares↔assets monotonic. |
| Staking | `Σ user rewards ≤ rewards funded`; withdraw ≤ deposited. |
| Token/mint | `Σ balances == supply`; only the true mint authority mints. |
| General | Only signer/owner can act on their account; authority transfers are two-step. |

Every finding is ultimately "here is an unvalidated account/path that breaks invariant X for profit."

---

## 2. Tooling & setup

Get the program building and testable first; most high-signal bugs are proven with a local PoC.

| Tool | Use |
| --- | --- |
| **Anchor test framework** | `anchor test` — TS/mocha tests against `solana-test-validator`; the primary PoC harness for Anchor programs. |
| **`cargo test-sbf`** | Compiles the SBF program and runs Rust integration tests against it. |
| **`solana-program-test` / BanksClient** | In-process Rust test runtime; fast, no validator, good for native programs. |
| **litesvm** | Fast **in-process SVM** (Rust + TS/`litesvm` npm) — millisecond tests, ideal for tight PoC loops. |
| **Trident** (Ackee) | Coverage-guided **fuzzer** for Anchor/native; generates & mutates instruction sequences to break invariants. |
| **sec3 X-Ray** | **Static analyzer** (50+ Solana bug classes: missing signer/owner, unchecked PDA, overflow). Triage — has false positives. |
| **Neodyme poc-framework** | Rust helpers for building exploit PoCs (sign, send, clone accounts) against a local/fork bank. |
| **`cargo-audit`** | Flags vulnerable Rust crate deps (RustSec advisories). |
| **`solana-security-txt`** | Check the program embeds a `security.txt` (contact, policy) — its absence is an informational note. |
| **`coral-xyz/sealevel-attacks`** | The **canonical corpus**: each attack as `insecure` / `secure` / `recommended` program pairs. Your ground truth for idioms. |

**Workflow:** `git clone` → `anchor build` / `cargo build-sbf` → run **sec3 X-Ray** and `cargo-audit` for a
first pass → read the code with §1's model in mind, walking `references/checklist.md` per instruction →
encode invariants for **Trident** where it pays → **write a local PoC (Anchor mocha or litesvm) for every
confirmed finding** (§4). If a tool isn't installed, skip it gracefully (RULES §5) and fall back to manual
review against the sealevel-attacks pairs.

---

## 3. Vulnerability classes to hunt

Work highest-impact-first. Each row: what it is / how it happens → the **Anchor fix**. Snippets and
grep-able questions per class live in `references/checklist.md`; secure-vs-insecure pairs in
`coral-xyz/sealevel-attacks`.

### The Sealevel catalog

| # | Class | What / how | Secure Anchor idiom |
| --- | --- | --- | --- |
| 1 | **Missing signer check** | Privileged action doesn't verify the authority actually signed (`AccountInfo` never checks `is_signer`). Root cause of the **Wormhole $320M** hack. | Use `Signer<'info>` (or `require!(acct.is_signer)`). `has_one = authority` + `authority: Signer`. |
| 2 | **Missing owner check** | Attacker passes a look-alike account owned by *their* malicious program; program reads its bytes as trusted state. | `Account<'info,T>` checks owner==program **and** discriminator; native: `require_keys_eq!(acct.owner, expected)`. |
| 3 | **Account data matching** | Program never checks an account's *contents* (e.g. its `authority` field) match the caller. | `#[account(has_one = authority)]` or `constraint = state.authority == signer.key()`. |
| 4 | **Type confusion / type cosplay** | Two account types share a byte layout; program deserializes one as the other. | Anchor's 8-byte **discriminator** (auto for `#[account]`); enforce via `Account<'info,T>`. |
| 5 | **Account confusion (Sealevel)** | Umbrella: any two accounts swapped/substituted because a relationship wasn't enforced. | Constrain every relationship (`has_one`, `seeds`, `address`, `constraint`). See sealevel-attacks. |
| 6 | **Arbitrary CPI / missing program-id** | Callee program taken from instruction input, not verified → attacker points it at a malicious program. | Typed `Program<'info, Token>` (checks id), or `require_keys_eq!(callee.key(), expected_id)`. |
| 7 | **PDA seed/bump canonicalization** | Non-canonical bump via `create_program_address`, or shared/colliding seeds let one PDA impersonate another. | Store & enforce the **canonical bump**; `#[account(seeds=[...], bump)]`; unique seed prefixes per type. |
| 8 | **Close / revival / re-init** | Account "closed" only by draining lamports can be revived in the same tx; `init_if_needed` re-inits state. | `#[account(close = dest)]` (zeroes data + sets closed discriminator); guard `init` vs `init_if_needed`. |
| 9 | **Integer overflow/underflow** | Release builds **wrap silently**; a debit underflows to a huge balance. | `overflow-checks = true` in `Cargo.toml`; `checked_add/sub/mul` / `saturating_*`. |
| 10 | **Missing has_one / constraint** | Relationships between accounts (pool↔vault, user↔position) not enforced. | `has_one`, `constraint = ...` on the accounts struct. |
| 11 | **Duplicate mutable accounts** | Same account passed for two params; program credits/debits it twice. | `#[account(constraint = a.key() != b.key())]`. |
| 12 | **Rounding / precision** | Div-before-mul truncates to 0; rounding favors the user. | Mul-before-div; floor on the **protocol-safe** side; `u128` intermediates. |
| 13 | **Sysvar spoofing** | `Clock`/`Rent` read from a caller-passed account holding forged data. | `Sysvar<'info, Clock>` / `Clock::get()`; or check the account address is the real sysvar id. |
| 14 | **Missing rent-exemption** | New account under-funded → purged by runtime, data lost / re-creatable. | `#[account(init, payer, space)]` (Anchor enforces rent); or check `Rent::is_exempt`. |
| 15 | **Arbitrary token account / mint confusion** | Program trusts an SPL token account/mint from input without constraining its `mint`/`owner`/address. | Constrain `token_account.mint == expected_mint`, `.owner == expected_authority`, vault by `address`/PDA. |
| 16 | **Stale state after CPI** | A deserialized copy is used after a CPI mutates the on-chain account → stale value. | `ctx.accounts.foo.reload()?` after the CPI before reading. |
| 17 | **`remaining_accounts` unvalidated** | Extra accounts bypass Anchor's derive-macro checks entirely. | Manually validate **each** (owner, signer, key, discriminator) before use. |
| 18 | **Insecure init / authority** | `initialize` callable by anyone (front-run to seize), or one-step authority transfer. | Gate init (PDA/known authority); **two-step** authority transfer (propose → accept). |
| 19 | **Rust panics / unsafe** | `unwrap()`, out-of-bounds index, div-by-zero, `unsafe` → instruction panics = **DoS**. | `ok_or(err)?`, `checked_*`, `.get(i)`; avoid `unwrap`/`unsafe` on attacker-influenced data. |

Read `references/checklist.md` for the vulnerable-vs-secure snippet and grep questions behind each row.

---

## 4. PoC & validation

**Prove it with a local PoC.** Write a minimal **Anchor TS/mocha** test (or Rust **litesvm** /
`solana-program-test`) that constructs the *malicious* instruction — the wrong account, the missing
signer, the substituted mint — and **asserts the unauthorized state change** (attacker balance up, victim
drained, invariant broken). A green test that steals funds on a local validator is the strongest evidence
and is self-verifying. Skeleton and imports: `references/poc-anchor.md`.

```ts
it("drains vault via missing owner check", async () => {
  // fund attacker's fake state account owned by a malicious program, pass it in
  await program.methods.withdraw(amount)
    .accounts({ state: fakeState.publicKey, vault, authority: attacker.publicKey })
    .signers([attacker]).rpc();
  const after = await getAccount(connection, attackerAta);
  assert.ok(after.amount > before.amount);   // unauthorized gain = impact
});
```

**Apply the Trinet Validation Ladder (RULES §3)** before writing anything up — all 8 rungs: real bug
class · reachable · exploitable now · concrete impact (funds at risk) · in scope · reproducible (local
PoC) · not a duplicate/known-accepted/informational · evidence captured.

**Common low-value / false-positives to weigh (don't inflate):**
- **Centralization noted-as-accepted** — admin/upgrade authority can rug and the docs say so → usually
  informational unless the scope treats the admin as untrusted.
- **Theoretical with no profitable path** — a missing check on an account no attacker can reach, or a
  1-lamport rounding quirk with no way to compound it.
- **Compute-unit / gas nits** — CU optimizations reported as security → QA, not a vulnerability.
- **Missing `security.txt` / events / zero-address-style** checks with no attacker path → informational.

**Severity = funds-at-risk × likelihood** (Immunefi / Code4rena / Sherlock style):

| Severity | Rough bar |
| --- | --- |
| **Critical** | Direct theft/loss of a material fraction of funds, unbacked mint, or permanent freeze — realistically exploitable. |
| **High** | Theft/loss under specific but attainable conditions, or significant insolvency risk. |
| **Medium** | Limited loss, needs an unlikely precondition, or breaks a non-critical invariant. |
| **Low / Info** | Minor impact, best-practice, or accepted centralization; no profitable path. |

---

## 5. Reporting

Use the **impact-first** report format from RULES §4, Solana-flavored:

- **Title** — `program::instruction` — `<vuln class>` — one-line impact (funds at risk).
- **Severity** — Critical/High/Med/Low with the funds-at-risk × likelihood justification.
- **Location** — program name, instruction handler, and the accounts-struct line (file:line).
- **Root cause** — the precise missing check (e.g. "`state` is `AccountInfo`, so its owner is never
  verified → attacker supplies a malicious-program-owned look-alike").
- **Attack scenario** — step-by-step: which account is forged/substituted, what the attacker signs, the
  unauthorized state change.
- **Proof of Concept** — the minimal **local PoC** (Anchor mocha or litesvm; redacted keys) that runs green.
- **Impact** — quantified: how much can be stolen/frozen, which invariant breaks, who is harmed.
- **Remediation** — the concrete Anchor idiom (`Signer<'info>`, `Account<'info,T>`, `has_one`,
  `seeds`+`bump`, `close = dest`, `checked_*`, `overflow-checks`), not "validate input".
- **References** — the matching `coral-xyz/sealevel-attacks` example, Anchor docs
  (account constraints), and the CWE (e.g. CWE-284 access control, CWE-190 overflow, CWE-843 type confusion).

Match the destination's format: **Immunefi** (severity + local PoC + impact-in-funds), **Code4rena** /
**Sherlock** (per-finding markdown, Med/High for Sherlock, strict duplicate rules). For client audits,
export validated findings as a **TrinetLayer VAPT PDF** for delivery. Platform:
https://app.trinetlayer.com — an optional accelerator, not a requirement.
