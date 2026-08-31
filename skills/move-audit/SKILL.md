---
name: move-audit
description: >-
  Guides authorized security auditing of Move smart contracts on Sui and Aptos for bug-bounty and
  client-audit engagements. It covers what Move's resource model guarantees and what it does NOT
  (authorization, logic/invariant, object-ownership, capability, visibility bugs), hunting the Move
  vulnerability classes, running the `move test` / Move Prover tooling, proving each finding with a
  `#[test_only]` PoC or a Prover `spec`, and reporting impact-first with funds at risk quantified.
  Use it when the user says "audit this Move contract", "review this Sui/Aptos Move module", "check my
  Move package for bugs", "Sui object-model security", "capability/visibility review", or points at a
  Move Immunefi scope. Auditing source is static/passive; PoCs run via `move test` / testnet only.
---

# Move Smart-Contract Security Audit (Sui + Aptos)

Practical methodology for auditing **authorized** Move packages on **Sui** and **Aptos**: understand what
the resource model does and does *not* protect, hunt the Move-specific vulnerability classes, then prove
each finding with a `#[test_only]` `move test` PoC (or a Move Prover `spec`) and report it impact-first
with funds at risk quantified.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** audit only packages you own or are explicitly authorized to (your own code,
> Immunefi/Sherlock/C4 scope, client audit). Reviewing source is static/passive and fits advisory mode.
> **Any on-chain interaction beyond read-only must be on a LOCAL/testnet network** — never exploit live
> mainnet packages or real users. Redact private keys/seeds.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact (funds at risk) · in scope · reproducible (local test) ·
> not a duplicate/informational · evidence captured. Full workflow: *Map → Prioritize → Probe → Prove → Report*.

**Posture (Move specifics).** Beyond the core rules: any interaction past reading source / read-only
`sui client` / `aptos move view` runs on a **local validator or testnet** (`sui start` / `aptos node
run-local-testnet`, or the Move unit-test VM). Work **capability- and invariant-first**: know who is
*supposed* to be able to call each `entry`/`public` function and what must always hold, then hunt the
path that breaks it. Prove every finding with a `move test` PoC (§5) or a Prover `spec`.

This maps onto RULES §2: **Recon** = map the package, modules, structs, abilities, capabilities →
**Surface mapping** = rank functions by funds-at-risk and caller reachability → **Testing** = tooling
(§4) + vuln hunt (§2) → **Validation** = PoC + Ladder (RULES §3) (§5) → **Reporting** (§6). Deep, grep-able
per-class questions live in **`references/checklist.md`**; PoC + Prover skeletons in **`references/poc-move.md`** —
open them when you reach that class or that step.

---

## 1. Move's safety model — and what it does NOT protect

State this up front so you target the real surface instead of re-checking what the VM already guarantees.

**What Move guarantees for you (don't waste time re-proving these):**
- **Linear / resource types + abilities** (`copy`, `drop`, `store`, `key`) — a struct without `copy`
  can't be duplicated; without `drop` it can't be silently discarded (must be consumed/stored/returned);
  without `store` it can't be put in another struct or global storage; `key` makes it a top-level object
  (Sui) / global resource (Aptos). This prevents value **duplication and accidental loss** at the type level.
- **No dynamic dispatch** — a module calls only functions it imports at compile time, so there is **no
  classic reentrancy** (no untrusted callback re-enters mid-state-change).
- **On-chain bytecode verifier** — every published module is re-verified for type/resource/reference
  safety; you cannot publish bytecode that violates the ability rules.

**What Move does NOT protect (this is your attack surface):**
- **Authorization** — the VM guarantees a `Coin` can't be forged, NOT that the *right* caller is moving it.
- **Logic / invariant errors** — wrong accounting, broken protocol invariants, ordering mistakes.
- **Rounding / precision & abort-DoS** — arithmetic aborts on overflow (safer), but truncation, zero-amount
  edges, and deliberate griefing aborts remain.
- **Visibility mistakes** — a privileged helper accidentally `public`/`entry`/`public(package)`.
- **Object-ownership bugs (Sui)** — shared objects are mutable by *anyone*; wrong owner checks.
- **Capability misuse** — an `AdminCap` leaked, over-broad, or checkable-by-holder-only with no scope.

Bottom line: Move removes a whole EVM bug family (reentrancy, silent value loss, integer wrap) and hands
you a language where **authorization, capabilities, visibility, and the object/global-storage model** are
where the money is lost.

---

## 2. Vulnerability classes to hunt

Highest-impact first. Each: what it is / how to spot it, and the fix. Grep-able questions in
`references/checklist.md`.

### Weak or absent signer / capability checks
The #1 Move bug. Move guarantees resource safety, **not** authz. For **every** `entry`/`public` function
that moves value or mutates privileged state, ask: does it verify the caller's authority — the `signer`'s
address (Aptos) or a required **capability object** (Sui)?
```move
// VULN (Aptos): anyone can call — no check that `admin` is the real admin
public entry fun set_fee(admin: &signer, fee: u64) acquires Config {
    borrow_global_mut<Config>(@proto).fee = fee;   // signer identity never checked
}
// FIXED: bind authority to a known address (or gate on an AdminCap resource the signer must hold)
public entry fun set_fee(admin: &signer, fee: u64) acquires Config {
    assert!(signer::address_of(admin) == @admin, E_NOT_AUTHORIZED);
    borrow_global_mut<Config>(@proto).fee = fee;
}
```
On Sui the pattern is a capability parameter: `public fun set_fee(_: &AdminCap, cfg: &mut Config, fee: u64)` —
holding the `AdminCap` *is* the authorization, so the leak question (below) becomes critical.

### Capability leakage
A capability that authorizes is only as safe as its reachability. Bug if an `AdminCap`/`OwnerCap`/`TreasuryCap`
is **returned** from a public function, **stored inside a shared object** (anyone with the shared object can
borrow it), transferred to the wrong address, or mintable more than once.
```move
// VULN (Sui): AdminCap handed out / reachable
public fun get_admin(cfg: &Config): AdminCap { cfg.cap }        // returns the cap → attacker holds authority
// also VULN: storing an AdminCap as a field of a *shared* object → any tx can borrow it
```
Fix: mint privileged caps exactly once in `init`, `transfer::transfer` them to the deployer (owned, not
shared), never return them from public functions, never embed them in shared state.

### Visibility over-exposure
`public`, `entry`, `friend` / `public(friend)`, and `public(package)` decide who can call. A privileged or
internal helper accidentally exposed is a direct break. Check every `public`/`entry` function: is it *meant*
to be callable by the world? Should it be `public(package)` (Sui 2024) / `friend` / private instead? An
`entry` function is directly invokable in a transaction — confirm each one is intended as a user entry point.

### Sui owned-vs-shared object bugs
Sui's core surface. **Shared objects are mutable by any transaction** → they need explicit in-function auth;
**owned objects** are gated by ownership at the protocol layer. Check:
- Any function taking `&mut SharedObject` must verify the caller's right to mutate it — sharing is NOT authz.
- `object::owner` / address checks correct; no confusion between owned and shared.
- Unsafe `transfer::public_transfer` (sends a `store`-having object anywhere — can leak value/caps).
- Object **wrapping/unwrapping** and **dynamic fields** (`dynamic_field` / `dynamic_object_field`): can an
  attacker add/remove/overwrite a field, or unwrap to reach a wrapped privileged object?

### Generic type / witness confusion
Functions generic over `<T>` (e.g. `Coin<T>`, a pool `Pool<X, Y>`) that don't **constrain or verify T** let
an attacker substitute the wrong type — mixing pools, depositing a worthless coin to withdraw a valuable one.
Also **one-time-witness (OTW)** and **witness** patterns: an OTW must be un-forgeable (only produced in `init`
of its own module); a plain witness struct that can be constructed by an attacker forges "proof of X". Check
phantom-type params (`phantom T`) actually pin identity where the logic assumes it.

### Arithmetic precision / rounding / abort-DoS
Move **aborts on overflow/underflow** (safer than EVM wrap) — but rounding direction, truncation (`/` then
`*`), zero-amount edges, and **griefing aborts** remain. A function that aborts on an attacker-suppliable
input can brick a shared flow (DoS). Check rounding favors the protocol, not the caller; zero and max inputs;
any `assert!`/implicit abort reachable by an attacker to block others.

### Unchecked coin / balance split & merge
`coin::split` / `coin::join`, `balance::split` / `balance::join` with unvalidated amounts, wrong generic
type, or zero edges → value created, lost, or wrong-asset accounting.
```move
// VULN: split by an unchecked user amount; and no check that the coin type matches the pool asset
let part = coin::split(&mut user_coin, amount, ctx);   // amount unvalidated vs balance / expectations
```
Check: amount ≤ available; correct `Coin<T>` type vs the pool/vault's expected asset; zero-amount handling;
that split/merge conserves total value in the accounting.

### Oracle / price
Same class as EVM but Move-flavored: **staleness** (timestamp freshness), **deviation** bounds, **spot-vs-TWAP**
(a spot AMM read is manipulable), and **single-source** reliance. Check the price feed's timestamp and round
are validated before use, and that a flash-swappable spot price isn't trusted for solvency-critical math.

### Hot-potato / flash-loan misuse
A **hot potato** is a struct with **no abilities** (no `copy`, `drop`, `store`, `key`) — it can't be stored,
copied, or dropped, so the transaction is *forced* to consume it before it ends (e.g. call `repay`). This
enforces flash-loan repayment. Bugs:
- The settlement / `repay` function **under-validates** the amount, fee, asset type, or pool — attacker
  repays less, wrong asset, or to the wrong pool while the potato is consumed.
- A wrapper **re-grants abilities** (wraps the potato in a `store`/`drop` struct) so it can be dropped or
  stored, escaping mandatory repayment.
```move
// The receipt MUST have no abilities so it cannot be dropped/stored:
struct FlashReceipt { amount: u64, fee: u64 }          // no `has` clause → hot potato
// VULN repay: doesn't check the returned coin covers amount+fee, or accepts any Coin<T>
```

### Upgrade / publish policy
- **Sui `UpgradeCap`** — who holds it, is it `transfer`ed to a safe owner or left reachable, is the upgrade
  policy restricted (compatible/additive/immutable via `package::make_immutable` / restrict)? A leaked
  `UpgradeCap` lets an attacker publish malicious logic.
- **Aptos module upgrade policy** — is the package `upgrade_policy` mutable (`compatible`) or `immutable`?
  Who owns the account/resource-account that controls upgrades? A mutable package under a hot key is a rug risk.

### Init / one-time-witness
`init` (Sui) / `init_module` (Aptos) runs **once** at publish. Confirm privileged caps are minted there and
only there, the OTW (Sui) is the real module-name witness (un-forgeable), and no post-init path re-mints an
`AdminCap`/`TreasuryCap` or re-runs initialization to seize ownership.

---

## 3. Sui Move vs Aptos Move

Both are Move, so the language-level classes (logic/arithmetic/capability/visibility/generic-witness) apply to
both. The *platform* model differs — and that's where each chain's bugs cluster.

| Dimension | **Sui Move** | **Aptos Move** |
| --- | --- | --- |
| Core model | **Object-centric**: `Object<T>` values with a `UID`; state lives in objects. | **Account/resource-centric** (Diem lineage): state lives in **global storage** under account addresses. |
| Ownership | **owned / shared / immutable** objects; shared = anyone can mutate (needs in-fn auth). | Resources stored under an account; the account's **`signer`** is the authority. |
| Storage ops | `transfer::transfer` / `public_transfer` / `share_object` / `freeze_object`; dynamic fields. | `move_to`, `borrow_global` / `borrow_global_mut`, `move_from`, `exists<T>`. |
| Composition | Programmable Transaction Blocks (**PTBs**) chain calls & pass objects between them. | Entry functions; **resource accounts** for programmatic signers. |
| Auth primitive | **Capability objects** (hold the object = authority) + object ownership. | **`signer`** (address identity) + capability resources. |
| Upgrades | **`UpgradeCap`** + package upgrade policy. | Package **`upgrade_policy`** (compatible / immutable) on the owning account. |
| Bug cluster | **Object model**: owned-vs-shared, `public_transfer`, wrapping, dynamic fields, cap-in-shared. | **Signer authority + global storage**: missing `signer` checks, wrong `borrow_global`, `exists` races. |

**Net:** on **Sui** look hardest at the object model (who can touch a shared object, where caps live, transfer/
wrap/dynamic-field abuse); on **Aptos** look hardest at signer authority and global-storage access
(`borrow_global_mut` under the wrong authority, missing `signer::address_of` checks). Both share the language
classes above.

---

## 4. Tooling & setup

Get the package building and its tests running before hunting; most Move findings are proven with a unit test.

| Tool | Use |
| --- | --- |
| **`sui move test` / `aptos move test`** | Move unit-test VM. `#[test]`, `#[test_only]` (test-only modules/imports/helpers), `#[expected_failure(abort_code = ...)]` for asserting intended aborts. Sui adds `test_scenario` for multi-tx / object flows. The primary PoC harness. |
| **`sui move build` / `aptos move compile`** | Compile + run the bytecode verifier; surfaces ability/visibility/type errors fast. |
| **Move Prover** (`aptos move prove`) | **Formal verification.** Write `spec` blocks with `aborts_if`, `ensures`, and `invariant`; the Prover (Boogie + Z3) proves them for *all* inputs — the strongest evidence an invariant holds or is broken. Best for accounting/authz invariants. |
| **Sui Prover** (Asymptotic) | Prover tooling for Sui Move `spec`s (Sui's object model), analogous to the Aptos Prover. |
| **move-mutator / move-spec-test** | Mutation testing — checks your test/spec suite actually catches injected bugs; good for gauging coverage of a target's own tests. |
| **move-analyzer** | LSP for reading large packages (go-to-def, references) — navigate call graphs and find every caller of a privileged function. |
| **Local network** | `sui start` (local) / `aptos node run-local-testnet`, or public **testnet/devnet**, for any live PoC beyond the unit-test VM. Never mainnet. |

**Workflow:** clone → `sui move build` / `aptos move compile` → run existing tests (`… test`) → read the code
with §1's guarantees/gaps and §2's classes in mind, mapping capabilities and every `entry`/`public` caller →
encode key invariants as Prover `spec`s where it pays → **write a `#[test_only]` PoC for every confirmed
finding** (`references/poc-move.md`). If a tool isn't installed, skip it gracefully (RULES §5) and fall back
to manual review or another tool.

---

## 5. PoC & validation

**Prove it with a `#[test_only]` `move test`.** The standard Move PoC is a test-only module that sets up the
target, invokes the vulnerable function with **attacker inputs**, and asserts the unauthorized outcome:
- **Sui** — use `test_scenario`: create tx contexts for victim and attacker addresses, publish/init the target,
  transfer objects, then have the attacker call the target function and assert they gained value / mutated
  state they shouldn't. (`sui::test_utils::destroy` / `assert_eq` for teardown and checks.)
- **Aptos** — create `signer`s (`account::create_account_for_test` / `#[test(attacker = @0xBAD)]`), publish
  resources with `move_to`, then call the target as the attacker and assert the illicit result.
- For **intended aborts** (proving a *guard* fires, or that a griefing input reverts) use
  `#[expected_failure(abort_code = E_...)]`.
- For **invariants** (something that must hold over *all* inputs, e.g. "total value conserved", "only admin
  mutates config"), encode it as a **Prover `spec`** (`aborts_if` / `invariant` / `ensures`) instead of a
  single-input test — see the spec note in `references/poc-move.md`.

Full skeletons for both chains + the Prover `spec` note: **`references/poc-move.md`**.

**Apply the Trinet Validation Ladder (RULES §3)** before writing anything up — all 8 rungs: real bug class ·
reachable · exploitable now · concrete impact (funds at risk) · in scope · reproducible (`move test` PoC or
Prover spec) · not a duplicate/known-accepted/informational · evidence captured.

**Move false-positives & low-severity to weigh (don't inflate):**
- **Guaranteed-by-the-VM "bugs"** — claiming reentrancy or integer wrap where Move already prevents it. Know §1.
- **Centralization already disclosed** — admin can upgrade/pause and the docs say so → usually informational
  unless the scope treats admin as untrusted.
- **Aborts with no attacker leverage** — a revert on a self-inflicted bad input, not a griefing DoS on others.
- **Theoretical rounding of 1 unit** with no way to compound it → low/QA.
- **Best-practice-only nits** (missing events, naming, no `#[view]`) with no exploit → informational.

**Severity = funds-at-risk × likelihood** (Immunefi / C4 / Sherlock style):

| Severity | Rough bar |
| --- | --- |
| **Critical** | Direct theft/loss of a material fraction of funds, unbacked mint, leaked `AdminCap`/`UpgradeCap`, or permanent freeze — realistically exploitable. |
| **High** | Theft/loss under specific but attainable conditions, or significant protocol insolvency risk. |
| **Medium** | Limited loss, needs an unlikely precondition, or breaks a non-critical invariant. |
| **Low / Info** | Minor impact, best-practice, or accepted centralization; no profitable path. |

---

## 6. Reporting

Use the **impact-first** report format from RULES §4, Move-flavored:

- **Title** — `module::function` — `<vuln class>` — one-line impact (funds at risk).
- **Severity** — Critical/High/Med/Low with the funds-at-risk × likelihood justification.
- **Location** — `path/module.move` — the exact `module::function` (and struct/ability if relevant).
- **Root cause** — the precise flaw (e.g. "`entry fun set_fee` never checks `signer::address_of` against
  the admin", or "`AdminCap` stored as a field of a shared `Config` → any tx borrows it").
- **Attack scenario** — step-by-step: what the attacker calls, with which inputs / caps, on Sui (PTB / object
  flow) or Aptos (signer / resource flow).
- **Proof of Concept** — the minimal **`#[test_only]` `move test`** (or Prover `spec`) that runs and proves it.
- **Impact** — quantified: how much can be stolen/frozen, which invariant breaks, who is harmed.
- **Remediation** — concrete fix (add the `signer`/cap check; make the cap owned not shared; tighten
  visibility to `public(package)`; validate the coin type/amount in `repay`; restrict the upgrade policy),
  not "validate input".
- **References** — the **Move Book** (abilities, hot-potato / no-abilities pattern, one-time-witness),
  **Sui docs** (object model, `transfer`, dynamic fields, `UpgradeCap`) or **Aptos docs** (global storage,
  `signer`, resource accounts, upgrade policy), and the relevant **CWE** (CWE-284 authz, CWE-682 accounting,
  CWE-841 workflow) for shared vocabulary.

Match the destination's format: **Immunefi** (severity + `move test` PoC + impact-in-funds), **Code4rena**
(per-finding markdown, QA/gas separate), **Sherlock** (Med/High only, strict duplicate rules). For client
audits, export validated findings as a **TrinetLayer VAPT PDF** for delivery. Platform:
https://app.trinetlayer.com — an optional accelerator, not a requirement.
