# Solana / Anchor Audit Checklist

Grep-able questions per vulnerability class, each with a short **vulnerable → secure** Anchor/Rust
snippet. Walk this per instruction handler. Ground truth for idioms: `coral-xyz/sealevel-attacks`
(each class ships `insecure` / `secure` / `recommended` program pairs).

Quick grep starters:
```bash
rg 'AccountInfo<'         # unchecked accounts (no owner/discriminator check)
rg 'is_signer|Signer<'    # signer handling
rg 'create_program_address|find_program_address|bump'   # PDA/bump
rg 'unwrap\(|expect\(|unsafe|\[[0-9a-z_]+\]'            # panic/index risk
rg 'checked_|saturating_|overflow-checks'               # arithmetic safety
rg 'invoke|invoke_signed|CpiContext'                    # CPIs
rg 'init_if_needed|close ='                             # init/close
rg 'remaining_accounts'                                 # unchecked extra accounts
```

---

## 1. Missing signer check
**Ask:** Does every privileged/state-changing instruction require the authority to have *signed*? Is the
authority an `AccountInfo`/`UncheckedAccount` (no signer guarantee) instead of `Signer`?
```rust
// VULNERABLE — authority never proves it signed
pub struct Withdraw<'info> { pub authority: AccountInfo<'info>, /* ... */ }
// SECURE
pub struct Withdraw<'info> {
    pub authority: Signer<'info>,
    #[account(mut, has_one = authority)] pub vault: Account<'info, Vault>,
}
```
Root cause of the Wormhole $320M bridge hack (a spoofed, unverified sysvar/guardian set signer path).

## 2. Missing owner check
**Ask:** Is any account a raw `AccountInfo`/`UncheckedAccount` whose bytes are then trusted? Who owns it?
```rust
// VULNERABLE — attacker passes an account owned by their malicious program
let state = State::try_from_slice(&acct.data.borrow())?;   // owner never checked
// SECURE — Account<T> checks owner == program_id AND the 8-byte discriminator
#[account] pub struct Withdraw<'info> { pub state: Account<'info, State> }
// native fallback:
require_keys_eq!(*acct.owner, crate::ID, MyError::WrongOwner);
```

## 3. Account data matching
**Ask:** Does the program confirm the account's stored `authority`/`owner` field equals the signer?
```rust
// VULNERABLE — any State account accepted, even one the caller doesn't own
// SECURE
#[account(has_one = authority)]         // state.authority == authority.key()
pub state: Account<'info, State>,
// or: #[account(constraint = state.authority == authority.key() @ MyError::Unauthorized)]
```

## 4. Type confusion / type cosplay
**Ask:** Do two account types share a byte layout with no discriminator? Could one be deserialized as another?
```rust
// SECURE — Anchor prepends an 8-byte discriminator per #[account] type; Account<T> enforces it.
// Native: add and check your own tag byte(s) before deserializing.
```

## 5. Account confusion (Sealevel umbrella)
**Ask:** For every account relationship (pool↔vault, user↔position, mint↔token account), is it enforced
by `has_one`, `seeds`, `address`, or `constraint`? Any account that could be substituted for another?

## 6. Arbitrary CPI / missing program-id check
**Ask:** Is the CPI target program taken from instruction accounts and invoked without verifying its id?
```rust
// VULNERABLE — token_program is whatever the caller passed
invoke(&ix, &[from, to, token_program])?;
// SECURE — typed program checks the id for you
pub token_program: Program<'info, Token>,
// or: require_keys_eq!(token_program.key(), spl_token::ID);
```

## 7. PDA seed/bump canonicalization
**Ask:** Is the bump the *canonical* one (from `find_program_address`), stored, and re-checked? Are seed
prefixes unique per account type (no PDA sharing/collision across account kinds)?
```rust
// VULNERABLE — create_program_address accepts ANY valid bump (non-canonical)
let pda = Pubkey::create_program_address(&[b"vault", user.as_ref(), &[bump]], id)?;
// SECURE
#[account(seeds = [b"vault", user.key().as_ref()], bump = vault.bump)]
pub vault: Account<'info, Vault>,   // Anchor derives & checks the canonical bump
```

## 8. Close / revival / re-init
**Ask:** Is an account "closed" only by draining lamports (revivable same tx)? Does `init_if_needed`
silently re-init an existing account's state?
```rust
// VULNERABLE — lamports drained but data intact & account can be re-funded/revived
**acct.lamports.borrow_mut() = 0;
// SECURE — zeroes data, writes the CLOSED discriminator, sends rent to dest
#[account(mut, close = destination)]
pub state: Account<'info, State>,
// If using init_if_needed, guard against re-init overwriting live state.
```

## 9. Integer overflow / underflow
**Ask:** Is `overflow-checks = true` set for release? Any bare `+ - *` on balances/amounts?
```toml
# Cargo.toml
[profile.release]
overflow-checks = true
```
```rust
// VULNERABLE (release wraps): self.balance -= amount;
// SECURE:
self.balance = self.balance.checked_sub(amount).ok_or(MyError::Underflow)?;
```

## 10. Missing has_one / constraint
**Ask:** Every relationship the logic assumes — is it actually enforced on the accounts struct?
```rust
#[account(mut, has_one = owner, has_one = mint)]
pub position: Account<'info, Position>,
```

## 11. Duplicate mutable accounts
**Ask:** Can the same account be passed for two params so a transfer/credit double-counts?
```rust
#[account(constraint = account_a.key() != account_b.key() @ MyError::DuplicateAccount)]
```

## 12. Rounding / precision
**Ask:** Division before multiplication? Does rounding favor the user? Enough intermediate width (`u128`)?
```rust
// VULNERABLE — divides first, truncates to 0
let shares = amount / total_assets * total_supply;
// SECURE — mul before div, u128 intermediate, floor on the protocol-safe side
let shares = (amount as u128 * total_supply as u128 / total_assets as u128) as u64;
```

## 13. Sysvar spoofing
**Ask:** Are `Clock`/`Rent`/instructions sysvars read from a caller-passed `AccountInfo`?
```rust
// VULNERABLE — clock is an arbitrary account with forged timestamp
// SECURE
pub clock: Sysvar<'info, Clock>,        // or: let clock = Clock::get()?;
// native: require_keys_eq!(clock_acct.key(), sysvar::clock::ID);
```

## 14. Missing rent-exemption
**Ask:** Are new accounts created rent-exempt? Anchor `init` enforces it; native must check.
```rust
#[account(init, payer = payer, space = 8 + State::LEN)]  // Anchor enforces rent-exempt
pub state: Account<'info, State>,
// native: require!(Rent::get()?.is_exempt(acct.lamports(), acct.data_len()), MyError::NotRentExempt);
```

## 15. Arbitrary token account / mint confusion
**Ask:** Are SPL token accounts/mints from input constrained by mint, owner/authority, and address?
```rust
#[account(mut, token::mint = expected_mint, token::authority = pool_authority)]
pub vault: Account<'info, TokenAccount>,
#[account(address = expected_mint_pubkey)]
pub mint: Account<'info, Mint>,
```

## 16. Stale state after CPI
**Ask:** Is a deserialized account read *after* a CPI mutated it, without reloading?
```rust
token::transfer(cpi_ctx, amount)?;      // CPI changes the token account on-chain
ctx.accounts.vault.reload()?;           // SECURE — refresh before reading .amount
let bal = ctx.accounts.vault.amount;
```

## 17. remaining_accounts unvalidated
**Ask:** Does the handler iterate `ctx.remaining_accounts` and use them without per-account checks?
```rust
for acct in ctx.remaining_accounts {
    require_keys_eq!(*acct.owner, expected_program, MyError::WrongOwner);   // check EACH
    // verify key / signer / discriminator as needed before use
}
```

## 18. Insecure init / authority transfer
**Ask:** Can anyone call `initialize` (front-run to seize ownership)? Is authority transfer one-step?
```rust
// SECURE init — gate to a PDA or known deployer; SECURE transfer — two step:
// propose_authority(new) -> stores pending; accept_authority() -> require signer == pending.
```

## 19. Rust panics / unsafe (DoS)
**Ask:** Any `unwrap()`/`expect()`/direct index/`div`/`unsafe` on attacker-influenced data?
```rust
// VULNERABLE: let x = list[i]; let y = a / b; let v = opt.unwrap();
// SECURE:
let x = list.get(i).ok_or(MyError::OutOfBounds)?;
let y = a.checked_div(b).ok_or(MyError::DivByZero)?;
let v = opt.ok_or(MyError::Missing)?;
```

---

## Wrap-up per finding
Run it up the **Trinet Validation Ladder** (RULES §3): real class · reachable · exploitable now ·
concrete impact (funds at risk) · in scope · reproducible (local PoC) · not a duplicate/informational ·
evidence captured. Then write it up impact-first (SKILL §5) with a green local PoC (`poc-anchor.md`).
