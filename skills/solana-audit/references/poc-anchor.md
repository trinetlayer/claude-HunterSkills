# Solana PoC Skeletons — Anchor mocha (+ litesvm note)

A finding isn't proven until a **local** test constructs the malicious instruction and asserts the
unauthorized state change. Everything here runs on `solana-test-validator`, litesvm, or a fork —
**never mainnet**. Redact real keypairs/seeds; generate throwaway keypairs in the test.

---

## A. Anchor TS / mocha skeleton

`tests/exploit.ts` — run with `anchor test` (spins up a local validator and deploys the program).

```ts
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import {
  TOKEN_PROGRAM_ID, createMint, createAccount,
  mintTo, getAccount,
} from "@solana/spl-token";
import { Keypair, SystemProgram, PublicKey } from "@solana/web3.js";
import { assert } from "chai";
import { Vault } from "../target/types/vault";   // generated IDL types

describe("vault — missing owner/signer check", () => {
  const provider = anchor.AnchorProvider.env();   // uses local validator + wallet
  anchor.setProvider(provider);
  const program = anchor.workspace.Vault as Program<Vault>;
  const connection = provider.connection;

  // actors
  const admin = (provider.wallet as anchor.Wallet).payer;
  const attacker = Keypair.generate();

  let mint: PublicKey;
  let vaultAta: PublicKey;
  let attackerAta: PublicKey;

  before(async () => {
    // fund the attacker so it can pay fees
    const sig = await connection.requestAirdrop(attacker.publicKey, 2e9);
    await connection.confirmTransaction(sig);

    mint = await createMint(connection, admin, admin.publicKey, null, 6);
    vaultAta = await createAccount(connection, admin, mint, /* owner PDA */ admin.publicKey);
    attackerAta = await createAccount(connection, attacker, mint, attacker.publicKey);
    await mintTo(connection, admin, mint, vaultAta, admin, 1_000_000); // seed the vault
  });

  it("drains the vault via the vulnerable instruction", async () => {
    const before = (await getAccount(connection, attackerAta)).amount;

    // Construct the MALICIOUS instruction: e.g. pass a look-alike `state`
    // account, or omit the true signer, whatever the bug allows.
    await program.methods
      .withdraw(new anchor.BN(1_000_000))
      .accounts({
        // fakeState / substituted mint / wrong authority goes here:
        authority: attacker.publicKey,
        vault: vaultAta,
        destination: attackerAta,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .signers([attacker])
      .rpc();

    const after = (await getAccount(connection, attackerAta)).amount;
    // Impact assertion: attacker gained funds they had no right to.
    assert.ok(after > before, "attacker balance should have increased");
    assert.equal(after - before, 1_000_000n);
  });

  it("secure build: the same call must FAIL", async () => {
    // After the fix, assert the malicious call reverts with the expected error.
    try {
      await program.methods.withdraw(new anchor.BN(1))
        .accounts({ authority: attacker.publicKey, vault: vaultAta,
                    destination: attackerAta, tokenProgram: TOKEN_PROGRAM_ID })
        .signers([attacker]).rpc();
      assert.fail("expected the instruction to revert");
    } catch (e: any) {
      assert.match(e.toString(), /Unauthorized|ConstraintHasOne|owner/i);
    }
  });
});
```

**Notes**
- `anchor.AnchorProvider.env()` reads `ANCHOR_PROVIDER_URL` / `ANCHOR_WALLET`; `anchor test` sets these
  to a local validator. To fork mainnet state, run `solana-test-validator --url mainnet-beta
  --clone <PROGRAM_ID> --clone <ACCOUNT> ...` and point the provider at `http://127.0.0.1:8899`.
- Keep it deterministic: generate keypairs in-test, airdrop locally, assert an exact delta.
- The "secure build must fail" test doubles as a **fix-verification** regression test.

---

## B. litesvm (fast, in-process — no validator)

litesvm runs the SVM in-process for millisecond PoC loops. Good when you don't need a full validator.

**TypeScript (`litesvm` npm):**
```ts
import { LiteSVM } from "litesvm";
import { Keypair, Transaction, TransactionInstruction, PublicKey } from "@solana/web3.js";

const svm = new LiteSVM();
const programId = PublicKey.unique();
svm.addProgramFromFile(programId, "target/deploy/vault.so");   // load the built program

const attacker = new Keypair();
svm.airdrop(attacker.publicKey, 1_000_000_000n);

// build the malicious instruction (accounts/data crafted to trigger the bug)
const ix = new TransactionInstruction({ programId, keys: [ /* ... */ ], data: Buffer.from([/* ... */]) });
const tx = new Transaction().add(ix);
tx.recentBlockhash = svm.latestBlockhash();
tx.sign(attacker);
const res = svm.sendTransaction(tx);
// inspect res / read account state, then assert the unauthorized change
```

**Rust (`litesvm` crate):**
```rust
use litesvm::LiteSVM;
use solana_sdk::{signature::Keypair, signer::Signer, transaction::Transaction};

let mut svm = LiteSVM::new();
svm.add_program_from_file(program_id, "target/deploy/vault.so").unwrap();
let attacker = Keypair::new();
svm.airdrop(&attacker.pubkey(), 1_000_000_000).unwrap();
// let ix = /* craft malicious instruction */;
// let tx = Transaction::new_signed_with_payer(&[ix], Some(&attacker.pubkey()), &[&attacker], svm.latest_blockhash());
// let res = svm.send_transaction(tx);
// assert!(/* unauthorized state change observed */);
```

**Alternatives:** `solana-program-test` + `BanksClient` (Rust, in-process) for native programs;
**Neodyme poc-framework** for cloning live accounts into a local bank and scripting the exploit;
`cargo test-sbf` to run Rust integration tests against the compiled SBF binary.

---

## Checklist before you attach a PoC to a report
- [ ] Runs green on a **local** validator / litesvm / fork (never mainnet).
- [ ] Constructs the *malicious* instruction, not just a happy path.
- [ ] Asserts a **concrete unauthorized state change** (attacker balance up / victim drained / invariant broken).
- [ ] Deterministic: throwaway keypairs, local airdrop, exact delta asserted.
- [ ] Redacted — no real private keys or seeds committed.
- [ ] Paired "secure build must fail" test to verify the remediation.
