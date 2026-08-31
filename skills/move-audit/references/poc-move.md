# Move PoC skeletons — `sui move test`, `aptos move test`, Move Prover `spec`

Companion to `../SKILL.md` §5. A Move PoC is a `#[test_only]` module that sets up the target, calls the
vulnerable function with **attacker inputs**, and asserts the unauthorized outcome — or, for a true
invariant, a Prover `spec`. Keep it minimal, deterministic, and runnable on the unit-test VM (no mainnet).

Run:
```bash
sui move test            # Sui   (add -f <filter> to run one test)
aptos move test          # Aptos (--filter <name> to select)
aptos move prove         # Aptos Move Prover (verifies the spec blocks)
```

---

## 1. Sui — `test_scenario` PoC

`test_scenario` gives you per-address transaction contexts so you can model a victim publishing/owning
objects and an attacker calling the target. Assert the attacker gained value or mutated state they must not.

```move
#[test_only]
module proto::exploit_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::test_utils::{assert_eq, destroy};
    use proto::vault::{Self, Vault, AdminCap};

    const ADMIN: address  = @0xA;
    const ATTACKER: address = @0xBAD;

    #[test]
    fun attacker_drains_shared_vault() {
        let mut sc = ts::begin(ADMIN);

        // 1) Admin publishes/initialises the target (mint caps, share the Vault).
        {
            vault::init_for_testing(ts::ctx(&mut sc));   // a #[test_only] init helper in the module
        };

        // 2) Attacker's turn: take the SHARED vault and call the under-protected function.
        ts::next_tx(&mut sc, ATTACKER);
        {
            let mut v = ts::take_shared<Vault>(&sc);
            // The bug: withdraw() mutates a shared object without an auth/cap check.
            let stolen: Coin<SUI> = vault::withdraw(&mut v, 1_000_000, ts::ctx(&mut sc));

            // 3) Assert the unauthorized outcome — attacker holds funds they should not.
            assert_eq(coin::value(&stolen), 1_000_000);

            destroy(stolen);
            ts::return_shared(v);
        };
        ts::end(sc);
    }

    // Assert an intended guard FIRES: expect the abort with the module's error code.
    #[test]
    #[expected_failure(abort_code = proto::vault::E_NOT_AUTHORIZED)]
    fun non_admin_cannot_set_fee() {
        let mut sc = ts::begin(ATTACKER);
        vault::init_for_testing(ts::ctx(&mut sc));
        ts::next_tx(&mut sc, ATTACKER);
        {
            let mut v = ts::take_shared<Vault>(&sc);
            // Should abort E_NOT_AUTHORIZED because ATTACKER holds no AdminCap.
            vault::set_fee(&mut v, 9999, ts::ctx(&mut sc));
            ts::return_shared(v);
        };
        ts::end(sc);
    }
}
```
Notes: expose a `#[test_only] public fun init_for_testing(ctx)` in the target (or call the real `init` with a
test OTW via `test_utils`). Use `ts::take_from_sender<T>` for owned objects and `ts::take_shared<T>` for shared
ones. `destroy` / `return_shared` satisfy the linear-type checker at test end.

---

## 2. Aptos — `signer`-based PoC

Create test signers, publish resources, then call the target as the attacker and assert the illicit result.
The `#[test(...)]` attribute injects named `signer`s.

```move
#[test_only]
module proto::exploit_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin::{Self};
    use aptos_framework::aptos_coin::AptosCoin;
    use proto::vault;

    // Inject signers for the module's admin and an attacker.
    #[test(admin = @proto, attacker = @0xBAD)]
    fun attacker_sets_fee_without_authority(admin: &signer, attacker: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(attacker));

        // 1) Admin initialises the protocol resources.
        vault::init_for_testing(admin);

        // 2) The bug: set_fee checks resource safety but NOT signer identity,
        //    so the attacker (not @proto) can mutate privileged config.
        vault::set_fee(attacker, 9999);

        // 3) Assert the unauthorized state change took effect.
        assert!(vault::current_fee() == 9999, 100);
    }

    // Assert an intended guard FIRES on the fixed code / a griefing abort.
    #[test(attacker = @0xBAD)]
    #[expected_failure(abort_code = proto::vault::E_NOT_AUTHORIZED)]
    fun non_admin_set_fee_aborts(attacker: &signer) {
        account::create_account_for_test(signer::address_of(attacker));
        vault::set_fee(attacker, 9999);   // must abort E_NOT_AUTHORIZED
    }
}
```
Notes: `account::create_account_for_test` registers the address in the test VM. For coin flows use
`coin::register` + a test-mint capability (or `aptos_coin::mint_apt_for_test` in newer frameworks) to fund an
account, then assert balances with `coin::balance<AptosCoin>(addr)`. `#[test_only]` also lets you import
otherwise-`friend`/internal helpers for setup.

---

## 3. Move Prover `spec` note (Aptos `aptos move prove`; Sui Prover analogous)

A single-input test proves the bug exists *once*. A **`spec` block** proves a property for **all** inputs —
use it for invariants ("only the admin address can change the config", "total value is conserved", "this
function never aborts except under condition X"). The Prover (Boogie + Z3) discharges it statically.

```move
module proto::vault {
    struct Config has key { admin: address, fee: u64 }

    public entry fun set_fee(s: &signer, fee: u64) acquires Config {
        assert!(signer::address_of(s) == borrow_global<Config>(@proto).admin, E_NOT_AUTHORIZED);
        borrow_global_mut<Config>(@proto).fee = fee;
    }

    spec set_fee {
        // The function MUST abort unless the caller is the stored admin.
        aborts_if signer::address_of(s) != global<Config>(@proto).admin;
        aborts_if !exists<Config>(@proto);
        // On success, fee is exactly what was passed and nothing else’s admin changed.
        ensures global<Config>(@proto).fee == fee;
        ensures global<Config>(@proto).admin == old(global<Config>(@proto).admin);
    }

    // Module-wide invariant: fee never exceeds a cap, no matter the call sequence.
    spec module {
        invariant [suspendable] forall a: address where exists<Config>(a):
            global<Config>(a).fee <= MAX_FEE;
    }
}
```
Reading the result: if the Prover **cannot** prove an `aborts_if`/`ensures`/`invariant`, it reports a
counterexample — that counterexample often *is* the finding (e.g. a caller who isn't admin yet doesn't hit an
abort ⇒ missing auth check). Use `spec`s to demonstrate an invariant is broken, and to prove a proposed fix
actually restores it. `aptos move prove --filter set_fee` checks one target; the **Sui Prover** (Asymptotic)
applies the same `spec`-block approach to Sui Move and its object model.

**When to use which:** reach for a `#[test_only]` test when the exploit is a concrete sequence (attacker calls
X with input Y and profits); reach for a `spec` when the claim is universal ("no non-admin can ever mutate
config", "value is always conserved"). Strong reports often include both: the test as the smoking gun, the
spec as proof the class is closed after the fix.
