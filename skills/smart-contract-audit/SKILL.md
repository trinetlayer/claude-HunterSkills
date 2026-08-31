---
name: smart-contract-audit
description: >-
  Guides authorized security auditing of EVM/Solidity smart contracts and DeFi protocols for bug
  bounty and client-audit engagements — scoped specifically to EVM chains and the Solidity/Vyper
  language (for Solana/Anchor use solana-audit; for Move/Sui/Aptos use move-audit). It covers
  orienting the protocol and its invariants, setting
  up Foundry/Slither/Echidna tooling, hunting the full class of on-chain bugs (reentrancy, access
  control, oracle manipulation, accounting/precision, ERC4626 share attacks, proxy/delegatecall,
  signature replay, MEV/front-running, DoS, token-integration and governance flaws), proving each
  with a fork-test PoC, and reporting impact-first with quantified funds at risk. Use it when the
  user says things like "audit this smart contract", "review this Solidity", "check my DeFi protocol
  for bugs", "web3 security audit", "find reentrancy/oracle bugs", or points at an Immunefi/Code4rena/
  Sherlock scope. Auditing source is static/passive; it operates in advisory mode by default.
---

# Smart Contract / Web3 Security Audit (Solidity / EVM / DeFi)

Practical methodology for auditing **authorized** EVM smart contracts: orient the protocol and its
invariants, run static + symbolic + fuzz tooling, hunt the on-chain vulnerability classes, then prove
each finding with a Foundry fork-test PoC and report it impact-first with funds at risk quantified.

> Non-EVM chains: for **Solana (Anchor/Rust)** use the `solana-audit` skill, and for **Move (Sui/Aptos)**
> use `move-audit`. This skill is EVM/Solidity-specific.

> **Core rules — always in effect** (full rulebook: read `${CLAUDE_PLUGIN_ROOT}/skills/shared/RULES.md`
> if that path resolves, otherwise the `shared/RULES.md` file installed alongside these skills).
> **Authorization first:** audit only protocols you own or are explicitly authorized to (your own code,
> Immunefi/Code4rena/Sherlock scope, client audit). Reviewing source is static/passive and fits
> advisory mode. **Any on-chain interaction beyond read-only calls must be on a LOCAL FORK or TESTNET**
> unless you own the protocol or a live PoC is explicitly in the program's scope — never run an exploit
> against live mainnet contracts or real users. Redact any private keys.
> **Trinet Validation Ladder** — before reporting, a finding must climb all 8 rungs: real class ·
> reachable · exploitable now · concrete impact (funds at risk) · in scope · reproducible (fork-test PoC) ·
> not a duplicate/informational · evidence captured. Full workflow: *Map → Prioritize → Probe → Prove → Report*.

**Posture (smart-contract specifics).** Beyond the core rules above: any **on-chain interaction beyond
read-only `eth_call`/`cast call`** runs on a **local fork (anvil) or testnet** — the only exception is a
live PoC explicitly permitted by an Immunefi program's PoC-on-mainnet rules, and even then prefer a fork.
Work **invariants-first**: know what must always hold (§1) before hunting the path that breaks it, and
prove every finding with a fork-test PoC (§5).

This maps onto RULES §2: **Recon** = orient the protocol (§1) → **Surface mapping** = rank contracts
by funds-at-risk and reachability → **Testing** = tooling (§2) + vuln hunt (§3) → **Validation** =
PoC + Trinet Validation Ladder (RULES §3) (§5) → **Reporting** (§6). Log every contract, address, and
finding as you go.

---

## 1. Orient the protocol (before reading a single `require`)

You cannot find broken invariants until you know what the invariants *are*. Build the mental model first.

- **Read the docs** — whitepaper, README, `/docs`, NatSpec comments, prior audit reports, the
  Immunefi/contest brief. Note what the team *claims* is impossible; those claims are your hit list.
- **Classify the protocol** — lending/borrowing, DEX/AMM, staking/rewards, vault/ERC4626, bridge,
  perps/derivatives, NFT, governance/DAO, stablecoin/CDP. Each has a canonical bug catalog (below).
- **Map the contracts** — list every contract, who deploys it, and how they call each other. A quick
  `slither . --print contract-summary` and `--print inheritance-graph` gives structure fast.
- **Enumerate roles & privileges** — `owner`, `admin`, `minter`, `pauser`, guardian, timelock,
  multisig. For each: what can it do, and what's the worst it can do if the key is stolen or rogue?
- **Upgradeability** — is it a proxy (Transparent, UUPS, Beacon, Diamond)? Where does logic vs. storage
  live? Who can upgrade, and is the implementation left initializable?
- **External dependencies** — oracles (Chainlink, TWAP, spot), other protocols (Aave, Uniswap,
  Curve), tokens it integrates. Each is an attack surface and a trust assumption.
- **Money flow** — trace how value enters, is accounted, and exits. Where are the deposits, mints,
  swaps, borrows, withdrawals, fees?

**State the invariants that must ALWAYS hold**, e.g.:

| Protocol | Invariant that must never break |
| --- | --- |
| Lending | A position stays over-collateralized; `totalBorrows ≤ totalCollateralValue`. |
| Vault / ERC4626 | `totalAssets ≥ Σ redeemable(shares)`; shares↔assets conversion is monotonic. |
| AMM/DEX | Constant-product `k` never decreases except by fees; reserves match balances. |
| Stablecoin/CDP | Every minted unit is backed; system can't be left with bad debt. |
| Staking | `Σ user rewards ≤ rewards funded`; can't withdraw more than deposited. |
| General | `Σ balances == totalSupply`; contract stays solvent; no free mint. |

Write these down. Every finding is ultimately "here is a path that breaks invariant X for profit."

---

## 2. Tooling & setup

Get the code building and testable before hunting; most high-signal bugs are proven with a fork test.

| Tool | Use |
| --- | --- |
| **Foundry** (`forge`, `cast`, `anvil`) | The workhorse. `forge build/test`, **fork tests** (`--fork-url $RPC`), **fuzz** (`function testFuzz(uint256 x)`), and **invariant/stateful** testing (`invariant_*` + handler contracts). `cast call` for read-only on-chain queries; `anvil` for a local fork sandbox. |
| **Hardhat** | Alternative JS/TS harness; mainnet forking via `hardhat_reset`. Useful when the repo is already Hardhat-based. |
| **Slither** | Fast static analysis: `slither .`. Detectors for reentrancy, uninitialized storage, arbitrary `delegatecall`, tx.origin, unchecked calls. Use `--print` for summaries; triage — it has false positives. |
| **Aderyn** | Rust static analyzer (Cyfrin); Markdown report, complements Slither. |
| **Echidna / Medusa** | Property-based **fuzzers**. Encode invariants as `echidna_*` / property functions; they search for a breaking input sequence. Best for accounting/AMM invariants. |
| **Mythril / Halmos** | **Symbolic** execution. Mythril explores paths for classic bugs; **Halmos** proves/breaks properties symbolically over a Foundry test. |
| **Semgrep** | `semgrep --config p/solidity` for pattern rules (custom-rule friendly for repo-specific footguns). |
| **Tenderly** | Tx **tracing**, state diffs, and debugger for real/forked transactions; great for understanding a live exploit or building a PoC. |
| **Block explorers** | Etherscan/Arbiscan/Basescan for verified source, proxy impl addresses, deployment params, and on-chain state. |

**Workflow:** `git clone` → `forge install` / `npm i` → `forge build` → run `slither .` and `aderyn`
for a first pass → read the code with §1's invariants in mind → encode invariants for Echidna/Halmos
where it pays → **write a Foundry fork-test PoC for every confirmed finding**. If a tool isn't
installed, skip it gracefully (RULES §5) and fall back to manual review or another tool.

---

## 3. Vulnerability classes to hunt

Work highest-impact-first. For each, the test and a short vulnerable snippet.

### Reentrancy
External call before state update lets the callee re-enter. Variants: **single-function**,
**cross-function** (shared state, different entry), **cross-contract**, and **read-only** (a `view`
returns stale state mid-callback that another protocol trusts).
```solidity
function withdraw() external {
    uint256 amt = balances[msg.sender];
    (bool ok,) = msg.sender.call{value: amt}("");   // external call FIRST
    require(ok);
    balances[msg.sender] = 0;                        // state update AFTER → re-enter
}
```
Test: any `.call`/`transfer`/ERC777/ERC721 `safeTransfer` before a state write. Check CEI
(checks-effects-interactions) and `nonReentrant`. Read-only: does an external protocol read a price/
balance that's inconsistent during your callback? E.g. a `get_virtual_price()` (Curve/Balancer-style)
read mid-callback returns a manipulated value that a consuming protocol trusts. PoC: attacker contract
with a re-entering `receive()`.

### Access control
Missing/incorrect modifier, unprotected `initialize()`, `tx.origin` auth, default (public) visibility.
```solidity
function initialize(address _owner) external { owner = _owner; } // no initializer guard → anyone re-inits
function setFee(uint256 f) public { fee = f; }                   // missing onlyOwner
require(tx.origin == owner);                                     // phishable — use msg.sender
```
Test: every state-changing/privileged function — is it guarded? Is `initialize` callable twice or by
anyone? Grep for `tx.origin`. Confirm proxies call `_disableInitializers()` in the impl constructor.

### Oracle manipulation
Spot price / AMM reserves used as an oracle, or unchecked Chainlink data.
```solidity
uint256 price = pair.getReserves()... ;              // spot price = flash-loan manipulable
(, int256 p,,,) = feed.latestRoundData();            // no staleness / round checks
uint256 price = uint256(p);
```
Test: is price a manipulable spot (use TWAP instead)? For Chainlink, check `answer > 0`,
`updatedAt` freshness, `answeredInRound >= roundId`, and correct decimals. PoC: flash-loan to skew a
pool, then interact at the bad price on a fork.

### Price / accounting errors, rounding & precision loss
Division before multiplication, truncation favoring the user, wrong decimals scaling.
```solidity
uint256 shares = (amount / totalAssets) * totalSupply; // divides first → rounds to 0
```
Test: order of ops, `mulDiv` usage, rounding direction (should favor the protocol, not the caller),
and 18-vs-6-decimal mismatches. Fuzz with tiny/huge amounts to surface truncation-to-zero.

### ERC4626 inflation / first-depositor share attack
Attacker mints 1 wei of shares, then donates assets directly to the vault to inflate share price so
the next depositor's shares round to 0 and their deposit is stolen.
Test: does the vault use virtual shares/assets or a dead-shares mint, or seed initial liquidity? PoC:
deposit 1 wei → `token.transfer(vault, X)` → victim deposits → victim gets 0 shares. Fix: OpenZeppelin's
ERC4626 **decimals-offset / virtual shares & assets** (virtual offset) defense, plus a minimum initial
deposit / dead-shares mint at first deposit.

### Flash-loan-enabled manipulation
Not a bug alone, but the amplifier: cheap, atomic capital breaks any single-block price/vote/collateral
assumption. Test every "current balance/price/supply" read against an attacker who temporarily controls
a huge amount within one tx. Combine with oracle, governance, and accounting bugs.

### Integer over/underflow
Solidity ≥0.8 reverts by default — but check **`unchecked { }`** blocks, `pragma <0.8`, and casts
(`uint256`→`uint128` truncation, `int`↔`uint`). Test math inside every `unchecked` block for wrap.

### Unchecked external call return values
```solidity
token.transfer(to, amt);        // non-standard ERC20 returns false, doesn't revert → silent failure
recipient.call{value: v}("");   // return value ignored
```
Test: use `SafeERC20`; check every `.call`/`.send` return; failure paths.

### Delegatecall, storage collision & proxy upgrade bugs
Uninitialized implementation (self-destruct/takeover), unsafe upgrade, storage-layout mismatch between
impl versions, `delegatecall` to attacker-controlled target.
Test: impl left uninitialized (`initialize` callable on the logic contract)? Storage slots preserved
across upgrades (no reordered/inserted vars)? Arbitrary `delegatecall` destination? UUPS `_authorizeUpgrade`
guarded? Gaps (`__gap`) present in upgradeable base contracts?

### Signature issues
Replay (missing nonce / `chainid` / domain separator), malleability, EIP-712 mistakes, `ecrecover`
returning `address(0)` on bad sig.
```solidity
address signer = ecrecover(hash, v, r, s);   // no address(0) check → forgeable when signer==0
```
Test: nonce + `block.chainid` in the signed struct; `s` in lower half-order; verify EIP-712 domain;
reject `signer == address(0)`; sigs not reusable across chains/contracts.

### L2 sequencer uptime (Arbitrum / Optimism / Base)
On an L2, a Chainlink price read must first check the **sequencer-uptime feed** (and a grace period)
before trusting `latestRoundData()`; skipping it lets **stale prices** be used during sequencer
downtime. Test: does the consumer read `sequencerUptimeFeed.latestRoundData()` and
`require(answer == 0)` (sequencer up) and `require(block.timestamp - startedAt > GRACE_PERIOD)` before
using any price? Absence on an L2 deployment is a finding.

### Cross-chain / signature replay
Signatures or governance messages valid on one chain replayed on another (or messages accepted from an
untrusted source). Test: is `block.chainid` (or the EIP-712 domain separator's `chainId`) bound into
the signed payload so a signature can't be replayed cross-chain? For bridges/messaging
(LayerZero/CCIP/native), inspect the trust model — source-chain/sender authentication, replay
protection, and whether an unauthorized message can be forged or reused.

### Front-running / MEV & sandwich
Missing slippage bounds, unprotected `approve` race, commit-reveal absent, predictable outcomes.
Test: swaps/liquidations with no `minOut`/deadline; actions whose profit depends on ordering; can a
searcher sandwich a deposit/swap? Prove with a fork test that front-runs the victim tx.

### Denial of service
Unbounded loops over user-growable arrays, gas griefing, revert-in-loop (one bad element bricks a
distribution), push-payment to a reverting receiver, block-stuffing to win a deadline.
```solidity
for (uint i; i < users.length; i++) { users[i].call{value: owed[i]}(""); } // one revert bricks all
```
Test: any loop bounded by attacker-controlled length; pull-over-push payments; failure of one element.

### Other high-yield classes
- **Improper input validation** — unchecked `address(0)`, zero amounts, unbounded params.
- **Denomination / decimals mismatch** — mixing 6- and 18-decimal tokens in one calc.
- **Weak randomness** — `blockhash`, `block.timestamp`, `block.prevrandao` as an RNG for value → miner/validator predictable. Use a VRF.
- **Token integration** — **fee-on-transfer** (received < sent), **rebasing** (balance drifts), **ERC777** hooks (reentrancy), non-standard **ERC20 return** (no bool / reverts). Test with weird tokens.
- **Governance attacks** — flash-loan borrow governance tokens → pass a malicious proposal → repay. Test snapshot/lock of voting power.
- **Timelock / emergency** — can a pause trap user funds? Timelock bypassable? Emergency withdraw drain?
- **`transfer`/`send` vs `call`** — 2300-gas stipend breaks with smart-wallets/proxies; prefer `call` + reentrancy guard.
- **Centralization risk** — privileged role can rug (mint, drain, upgrade to malicious impl, arbitrary `delegatecall`); rate by realistic rug impact.
- **Off-by-one / incomplete paths** — `<=` vs `<` at bounds; TODOs, unfinished branches. **Init race** — front-run `initialize()` between deploy and init to seize ownership.

---

## 4. DeFi-specific & token audit notes

**Invariant thinking is the core skill.** Restate §1's invariants as properties and hunt any path that
breaks one for profit — solvency (contract can always pay what it owes), collateralization (no
under-collateralized position survives), total-supply accounting (`Σ balances == totalSupply`; no free
mint), reward conservation (payouts ≤ funded). Encode them for Echidna/invariant tests so the fuzzer
searches for a breaking sequence you'd miss by eye.

**Economic / game-theory attacks** don't need a "bug" in one line: bad-debt socialization, liquidation
incentive gaming, interest-rate manipulation, self-liquidation, donation attacks, reward emission
gaming, oracle-lag arbitrage. Ask: what does a rational, well-capitalized adversary with flash loans do?

**Token / meme-coin rug checks** (fast triage of an ERC20 you're asked to vet):

| Check | Red flag |
| --- | --- |
| Mint authority | `owner` can `mint()` unbounded post-launch → infinite dilution. |
| Hidden / mutable fees | `setFee()` with no cap, or fee routed to owner; fee set to 100% = honeypot. |
| Blacklist / pause | `canTransfer` gate the owner flips to freeze holders (sell disabled = honeypot). |
| LP lock | Liquidity not locked/burned → owner can pull the pool (`removeLiquidity`). |
| Owner privileges | `onlyOwner` can drain, upgrade, or change token balances arbitrarily. |
| Honeypot pattern | Buys succeed, sells revert; asymmetric buy/sell tax; hidden transfer hooks. |
| Ownership | Not renounced / not a timelock+multisig where the docs claim it is. |

See the full read-only token/rug checklist (mint, ownership/renounce, tax, blacklist/pause,
honeypot, LP lock, proxy — with GoPlus/honeypot.is/Token Sniffer tooling):
[references/token-safety.md](references/token-safety.md).

---

## 5. PoC & validation

**Prove it with a Foundry fork test.** A minimal test that runs the exploit against forked mainnet
state and asserts attacker profit / invariant break is the strongest possible evidence and self-
verifying. Ready PoC + invariant skeleton: [references/foundry-poc.md](references/foundry-poc.md). Sketch:
```solidity
function testExploit() public {
    vm.createSelectFork(vm.envString("RPC_URL"), BLOCK);   // pin a block for determinism
    uint256 before = token.balanceOf(attacker);
    vm.startPrank(attacker);
    // ...flash loan → manipulate → drain via the vulnerable path...
    vm.stopPrank();
    assertGt(token.balanceOf(attacker) - before, 0);       // quantified profit = impact
}
```
Keep it minimal and deterministic (pinned block/RPC, redacted keys). Run everything on the fork/testnet.

**Invariant testing (Foundry).** A handler bounds actor actions and tracks a ghost variable; the test
wires the handler as the fuzz target and asserts a protocol invariant across random call sequences:
```solidity
contract Handler is Test {
    Vault vault; uint256 public ghost_deposited;   // ghost: expected state
    function deposit(uint256 amt) external {
        amt = bound(amt, 1, 1e24);                  // bound the actor's action
        vault.deposit(amt, address(this));
        ghost_deposited += amt;
    }
}
contract VaultInvariant is Test {
    Handler handler;
    function setUp() public { handler = new Handler(); targetContract(address(handler)); }
    // targetSelector to restrict to chosen fns; here all public handler fns are fuzzed
    function invariant_solvency() public view {
        assertGe(vault.totalAssets(), vault.totalLiabilities());   // must always hold
    }
}
```

**Apply the Trinet Validation Ladder (RULES §3)** before writing anything up — all 8 rungs: real bug
class · reachable · exploitable now · concrete impact (funds at risk) · in scope · reproducible
(fork-test PoC) · not a duplicate/known-accepted/informational · evidence captured.

**Web3 false-positives & low-severity to weigh (don't inflate):**
- **Centralization already disclosed** as an accepted trust assumption (admin can pause/upgrade and
  the docs say so) — note it, but it's usually informational unless the scope treats admin as untrusted.
- **Theoretical issues with no profitable path** — a rounding quirk of 1 wei with no way to compound it.
- **Gas optimizations** reported as vulnerabilities — they're QA/gas, not security.
- **Best-practice-only** nits (missing events, NatSpec, magic numbers) with no exploit → informational.
- **Missing zero-address checks** on owner-only setters with no attacker path → low/QA at best.

**Severity = funds-at-risk × likelihood** (Immunefi / Code4rena / Sherlock style):

| Severity | Rough bar |
| --- | --- |
| **Critical** | Direct theft/loss of a material fraction of funds, unbacked mint, or permanent freeze — realistically exploitable. |
| **High** | Theft/loss under specific but attainable conditions, or significant protocol insolvency risk. |
| **Medium** | Limited loss, needs an unlikely precondition, or breaks a non-critical invariant. |
| **Low / Info** | Minor impact, best-practice, or accepted centralization; no profitable path. |

---

## 6. Reporting

Use the **impact-first** report format from RULES §4, audit-flavored:

- **Title** — `Contract.sol` — `<vuln class>` — one-line impact (funds at risk).
- **Severity** — Critical/High/Med/Low with the funds-at-risk × likelihood justification.
- **Location** — `Contract.sol:line` (and the exact function).
- **Root cause** — the precise flawed logic (e.g. "external call precedes balance write → reentrancy").
- **Attack scenario** — step-by-step how an attacker exploits it, including any flash loan / setup.
- **Proof of Concept** — the minimal **Foundry fork test** (redacted keys/RPC) that runs green.
- **Impact** — quantified: how much can be stolen/frozen, which invariant breaks, who is harmed.
- **Remediation** — concrete fix (CEI + `nonReentrant`; TWAP + staleness checks; virtual shares;
  `_disableInitializers()`; `SafeERC20`; nonce+chainid in the signed struct), not "validate input".
- **References** — the **SWC** id (e.g. SWC-107 reentrancy, SWC-115 tx.origin, SWC-101 overflow,
  SWC-112 delegatecall, SWC-121 sig replay) **and** the CWE (CWE-841, CWE-284, CWE-682, CWE-190).
  The SWC Registry is legacy/frozen (unmaintained since ~2020) — cite it for shared vocabulary, but
  contests use their own severity taxonomy (Immunefi/C4/Sherlock).

Match the destination's format: **Immunefi** (severity + PoC-on-fork + impact-in-funds), **Code4rena**
(per-finding markdown, QA/gas reports separate), **Sherlock** (Med/High only, strict duplicate rules,
Watson format). For client audits, export validated findings as a **TrinetLayer VAPT PDF** for
delivery. Platform: https://app.trinetlayer.com — an optional accelerator, not a requirement.
