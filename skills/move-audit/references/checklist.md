# Move Audit Checklist (Sui + Aptos) — per-class, grep-able

Companion to `../SKILL.md` §2. Work top-down; for each class the questions are the ones to answer against
the target, plus `grep`/`rg` seeds. Applies to both chains unless tagged **[Sui]** / **[Aptos]**.

Fast first pass:
```bash
rg -n 'public entry|public\(package\)|public\(friend\)|public fun|entry fun|fun init' .   # every entry point + visibility
rg -n 'struct .*has (copy|drop|store|key)' .                                              # abilities on every struct
rg -n 'Cap\b|AdminCap|OwnerCap|TreasuryCap|UpgradeCap|MintCap|BurnCap' .                   # capabilities
rg -n 'signer::address_of|assert!|abort ' .                                               # auth checks / aborts
rg -n 'borrow_global_mut|borrow_global|move_to|move_from|exists<' .                        # [Aptos] global storage
rg -n 'share_object|public_transfer|transfer::transfer|dynamic_field|dynamic_object_field' . # [Sui] object model
```

---

## 1. Signer / capability authorization
- For **every** `entry`/`public` function that moves value or mutates privileged state: is the caller's
  authority verified? **[Aptos]** `assert!(signer::address_of(s) == @expected, E_...)` or a held cap resource.
  **[Sui]** a capability object parameter (`_: &AdminCap`) or an explicit owner/address check.
- Is a `&signer` accepted but **never actually checked** (present for show)? Grep functions that take `&signer`
  and confirm each uses `signer::address_of`.
- Are admin/owner addresses hardcoded (`@admin`), stored in config, or passed in? If passed in, can an
  attacker pass their own?
- **[Aptos]** Does a function `borrow_global_mut<T>(addr)` where `addr` is caller-controlled, allowing
  mutation of someone else's resource?
- Do "internal" mutations rely only on visibility (not a real check) for safety? Visibility is not authz.

## 2. Capability leakage
- Is any `*Cap` **returned** from a `public` function? `rg -n 'public fun .*: .*Cap'`
- Is a cap stored as a **field of a shared object** (**[Sui]** `share_object` on a struct containing a cap)?
  Anyone with the shared object can borrow the cap.
- Is a privileged cap minted **more than once**, or minted outside `init`/`init_module`?
- **[Sui]** Is an `AdminCap`/`TreasuryCap`/`UpgradeCap` `public_transfer`'d (goes anywhere) vs `transfer`'d to
  a fixed owner? Is it left with the publisher, a shared object, or an attacker-reachable address?
- Can a cap be reconstructed from public data / a forgeable witness (see §5)?

## 3. Visibility over-exposure
- List every `public`, `entry`, `public(package)`/`public(friend)`, `friend` function. For each: is that
  audience intended? Should it be private / `public(package)` instead?
- Is a privileged helper (mint, burn, set-config, withdraw) reachable directly as `public`/`entry`?
- **[Sui]** Does an `entry` fun expose an object mutation that should be gated behind a cap?
- **[Aptos]** `friend` declarations — do they grant a module more access than it should have?

## 4. Sui object model **[Sui]**
- Every function taking `&mut <SharedObject>`: does it verify the caller may mutate it? Shared ≠ authorized.
- `object::owner` / address comparisons correct; no owned-vs-shared confusion.
- `transfer::public_transfer` — can it send a `store` object (value or cap) to an attacker address?
- **Wrapping/unwrapping** — can an attacker unwrap to reach a wrapped privileged object, or wrap to hide one?
- **Dynamic fields** (`dynamic_field` / `dynamic_object_field`) — can an attacker add/remove/overwrite a
  field key that logic trusts? Are field values authenticated?
- `freeze_object` — is anything frozen that later needs mutation (permanent DoS), or NOT frozen that should be?

## 5. Generic type / witness confusion
- Functions generic over `<T>` / `Coin<T>` / `Pool<X,Y>`: is `T` constrained or verified, or can an attacker
  substitute a worthless/wrong type? Look for pools/vaults that don't pin the asset type.
- **One-time-witness (OTW)** **[Sui]** — is the OTW the real module witness (all-caps module name, consumed
  in `init`)? Can it be constructed elsewhere?
- Plain **witness** structs — can an attacker construct the witness that "proves" authorization?
- `phantom T` params — does the logic assume a type identity that phantom doesn't actually enforce at runtime?

## 6. Arithmetic / rounding / abort-DoS
- Division before multiplication (`a / b * c`) → truncation to zero. Does rounding favor the protocol?
- Zero-amount and max-value inputs handled? `rg -n '/|%|<<|>>'` on value math.
- Any `assert!` / implicit abort reachable by an attacker to **block others** (griefing DoS on a shared flow)?
- Decimal/scale mismatches between coins of different `decimals`.
- Note: Move aborts on overflow/underflow — do NOT report EVM-style wrap; DO report abort-DoS and rounding.

## 7. Coin / balance split & merge
- `coin::split` / `balance::split` — amount validated ≤ available? `rg -n 'coin::split|balance::split'`
- `coin::join` / `balance::join` — merging the correct `Coin<T>` type (not a mismatched asset)?
- Zero-amount split/merge handled; does total value stay conserved in the accounting?
- Is the coin's generic type checked against the pool/vault's expected asset before use?

## 8. Oracle / price
- Price timestamp checked for **staleness** before use? Deviation bounds enforced?
- **Spot vs TWAP** — is a flash-manipulable spot/AMM reserve read used for solvency-critical math?
- Single-source dependency; is there a fallback / sanity bound?

## 9. Hot-potato / flash-loan
- The receipt struct has **no abilities** (`rg -n 'struct .*Receipt|struct .*Potato'` then confirm no `has`)?
- Does the `repay`/settlement function validate **amount + fee**, **asset type**, and **correct pool**?
- Can a wrapper **re-grant abilities** (wrap the potato in a `store`/`drop` struct) to escape repayment?
- Can the flash amount be used to manipulate an oracle/vote within the same tx before repay?

## 10. Upgrade / publish policy
- **[Sui]** `UpgradeCap` — who holds it? Transferred to a safe owner or reachable? Policy restricted /
  `package::make_immutable`? `rg -n 'UpgradeCap|make_immutable|upgrade'`
- **[Aptos]** Package `upgrade_policy` — `compatible` (mutable) vs `immutable`? Who owns the controlling
  account / resource account? Mutable + hot key = rug risk.

## 11. Init / one-time-witness
- `init` **[Sui]** / `init_module` **[Aptos]** runs once; privileged caps minted there and **only** there?
- Any post-init path that re-mints `AdminCap`/`TreasuryCap` or re-initializes to seize ownership?
- **[Sui]** OTW un-forgeable (genuine module-name witness passed by the framework in `init`)?

## 12. Cross-cutting
- Every protocol invariant from the docs restated and checked (solvency, conservation, "only admin can X").
- Events emitted for privileged actions (auditability) — absence is informational, not a vuln.
- Test suite present — run it, and consider `move-mutator` to gauge whether it actually catches bugs.
