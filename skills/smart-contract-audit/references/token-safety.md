# EVM Token Safety / Rug-Pull Checklist (read-only analysis)

Read-only triage for an ERC20 token you're **authorized** to vet (client audit, your own
token, or an in-scope program). This is **analysis, not exploitation**: you inspect verified
source and on-chain state to decide whether a token is a rug/scam risk to **REPORT**. A token
failing these checks is something you flag, never something you exploit against holders.

> Never trust a single scanner. Every automated flag below is a lead to confirm against
> **verified source on Etherscan** (and the actual on-chain state / storage slots). Scanners
> miss obfuscated logic and produce false positives both ways.

---

## The checklist

### Mint authority / supply
Can supply be inflated after launch? Look for an owner-only `mint()`, an uncapped
`totalSupply`, or any path that increases balances without a matching burn/deposit. Unbounded
mint = infinite dilution of every holder.
- GoPlus: `is_mintable`.

### Ownership / renounce
Is `owner` renounced (set to `0x0`)? **But a renounced owner is not proof of safety** — confirm
no other privileged roles (minter, pauser, fee-setter, `AccessControl` roles) and no
proxy-admin still control the contract. Cosmetic renounce (renounce `owner` while a role or the
proxy admin retains full power) is a common scam pattern.
- GoPlus: `owner_address`, `can_take_back_ownership`.

### Hidden fees / tax
What are the buy/sell tax percentages? Can the owner **raise the tax toward ~100%** to make
sells effectively impossible (a "soft honeypot")? Check for fees routed to the owner and for a
`setFee`/`setTax` with no hard cap.
- GoPlus: `buy_tax`, `sell_tax`, `slippage_modifiable`.

### Blacklist / whitelist / pause
Are there functions that block specific holders from selling, gate transfers to a whitelist, or
halt all trading? An owner-flippable blacklist/pause lets the deployer freeze holders after they
buy (sell disabled = honeypot).
- GoPlus: `is_blacklisted`, `transfer_pausable`, `is_anti_whale`.

### Honeypot (can't sell)
The definitive test: **simulate a buy followed by a sell** to confirm the exit actually works.
Honeypots let buys succeed and make sells revert (or apply asymmetric/hidden transfer hooks).
- honeypot.is trading simulation; Token Sniffer heuristics.

### LP lock / burn
Is liquidity **locked** (Unicrypt / Team.Finance) or is the LP **burned**? Check the lock
duration and the **percentage** of LP locked — a short lock or a small locked fraction means the
deployer can still pull the pool (`removeLiquidity`).
- GoPlus: `lp_holders` (lock/burn status of LP token holders).

### Proxy / upgradeability
Is the token behind a proxy (EIP-1967, UUPS, Transparent)? **Who is the proxy admin?** An
upgradeable token voids any "renounce" claim — the admin can swap in malicious logic (add a
blacklist, raise tax, mint) at any time. Verify the admin slot on-chain, don't take the source at
face value.
- GoPlus: `is_proxy`; then read the EIP-1967 admin/implementation slots on-chain.

---

## Tools

| Tool | Role |
| --- | --- |
| **GoPlus Security API** | Fast contract-level flags (`is_mintable`, `owner_address`, `buy_tax`/`sell_tax`, `is_blacklisted`, `transfer_pausable`, `is_proxy`, `lp_holders`, …). First pass. |
| **honeypot.is** | Sell **simulation** — the ground truth on whether a holder can actually exit. |
| **Token Sniffer** | Heuristic score + contract-similarity to known scams. |
| **Etherscan** (Arbiscan/Basescan) | Verified source, proxy implementation address, deployment params, on-chain state and storage slots. The place you confirm every scanner flag. |

**Workflow:** run GoPlus for the flags → simulate buy+sell on honeypot.is → cross-check the
Token Sniffer score → **confirm each flag against verified source + on-chain state on Etherscan**
before concluding. Frame the output as read-only analysis; report a failing token as a rug/scam
risk, do not exploit it.
