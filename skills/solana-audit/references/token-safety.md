# Solana / SPL Token Safety Checklist (read-only analysis)

Read-only triage for an SPL token you're **authorized** to vet. This is **analysis, not
exploitation**: inspect on-chain authorities and holder state to decide whether a token is a
rug/scam risk to **REPORT**. All the authorities below are readable on-chain — you never send a
transaction to check them.

> Baseline safety expectation: **mint, freeze, and update authority should ALL be revoked**.
> Any one still active is a lever the creator can pull against holders.

---

## The checklist

### Mint authority
Should be **revoked (null)**. If the mint authority is still set, the creator can mint unlimited
new supply at any time and dilute every holder to zero. This is the single most important flag.

### Freeze authority
Should be **revoked**. If active, the creator can **freeze holder token accounts** — a frozen
account cannot transfer, so holders can't sell. This is a common rug mechanism: let people buy,
then freeze them out.

### Update / metadata mutability
Metadata update authority should be **revoked / metadata immutable**. Mutable metadata lets the
creator swap the token's **name, logo, or links** after launch — a bait-and-switch used for
phishing (e.g. relabel a worthless token as a trusted brand, or repoint the site link).

### Update authority (program / token)
Confirm **who can change the token / its metadata** and that it has been handed off or renounced.
An active update authority in the wrong hands undermines every "immutable" claim.

### LP / bonding curve
For **pump.fun-style** launches, check the **bonding-curve stage** vs. whether liquidity has
**migrated to a real LP** (e.g. Raydium). After migration, check the **LP status** (locked/burned)
and **top-holder concentration** — a migrated pool with concentrated holders can still be dumped.

### Holder distribution
Look at **concentration in a few wallets** and the **dev-wallet percentage**. A handful of
wallets (or the deployer) holding a large share means a single dump can rug the token regardless
of authority state.

---

## Tools

| Tool | Role |
| --- | --- |
| **RugCheck (rugcheck.xyz)** | 20+ checks; the **"authority controls"** section verifies mint/freeze/update are revoked. Revocation of **all three** is the baseline safety expectation. Also surfaces LP and holder concentration. |
| **Helius** (RPC/DAS) | Authorities are readable on-chain — query mint account (`mintAuthority`, `freezeAuthority`) and metadata (`updateAuthority`, `isMutable`) directly. |
| **Solscan / SolanaFM** | Inspect holder distribution, top holders, and authority fields in a browser. |

**Workflow:** run RugCheck for the authority + LP + holder summary → confirm mint / freeze /
update authorities directly on-chain (Helius) → review holder concentration on Solscan/SolanaFM.
Read-only analysis; report a failing token as a rug risk, do not exploit it.
