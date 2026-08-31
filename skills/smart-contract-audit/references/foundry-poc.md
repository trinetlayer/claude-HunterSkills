# Foundry PoC & invariant skeletons

Ready-to-adapt Foundry tests for proving an EVM/Solidity finding. Two skeletons:
1. A **fork-test exploit PoC** — run the attack against pinned mainnet state, assert attacker profit.
2. A **stateful invariant test** — a bounded handler + ghost variable + `targetContract` that fuzzes
   call sequences and asserts a protocol invariant never breaks.

Run with:
```bash
export RPC_URL=https://eth-mainnet.example/<key>       # an archive/full node for the pinned block
forge test --match-contract ExploitPoC -vvvv            # exploit PoC, full traces
forge test --match-contract VaultInvariant -vv          # invariant run
```
Invariant runs are configured in `foundry.toml`:
```toml
[invariant]
runs = 256
depth = 64
fail_on_revert = false     # set true once your handler never reverts on its own bounded inputs
```

---

## 1. Fork-test exploit PoC

A minimal, deterministic test that forks real state at a pinned block, runs the exploit as the
attacker, and asserts quantified profit. Green test = self-verifying evidence.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

// Minimal interfaces for the target + tokens (declare only what the PoC calls).
interface IVulnerable {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function priceOf(address token) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

contract ExploitPoC is Test {
    // --- Pinned target + token addresses (fill in the real ones) ---
    IVulnerable constant TARGET = IVulnerable(0x0000000000000000000000000000000000000000);
    IERC20 constant USDC        = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    uint256 constant FORK_BLOCK = 19_000_000;   // pin for determinism
    address attacker = makeAddr("attacker");

    function setUp() public {
        // Fork mainnet at a fixed block so the PoC is reproducible.
        vm.createSelectFork(vm.envString("RPC_URL"), FORK_BLOCK);

        // Fund the attacker with the capital the exploit needs (e.g. flash-loan proceeds).
        deal(address(USDC), attacker, 1_000_000e6);
    }

    function test_Exploit() public {
        uint256 balBefore = USDC.balanceOf(attacker);

        vm.startPrank(attacker);
        // ---- exploit steps ----
        // 1. (optional) take a flash loan to amplify capital
        // 2. manipulate the vulnerable state (skew a spot-price pool, inflate shares, re-enter, ...)
        // 3. interact with TARGET at the bad state to extract value
        USDC.approve(address(TARGET), type(uint256).max);
        TARGET.deposit(1_000_000e6);
        // ... trigger the bug ...
        TARGET.withdraw(/* more than deposited, or drained funds */ 0);
        vm.stopPrank();

        uint256 balAfter = USDC.balanceOf(attacker);
        uint256 profit = balAfter - balBefore;

        console2.log("attacker profit (USDC):", profit);
        assertGt(profit, 0, "no profit => exploit did not work");   // quantified impact = the finding
    }
}
```

Notes:
- `vm.createSelectFork(url, block)` creates and selects the fork in one call; pin the block for
  determinism. Use an archive/full RPC that has that block's state.
- `deal(token, to, amount)` sets an ERC20 balance directly (no need to source real tokens). `deal(addr, wei)` sets ETH.
- `makeAddr("name")` derives a labeled address; `vm.startPrank`/`vm.stopPrank` set `msg.sender` for
  the enclosed calls (`vm.prank` for a single call).
- Keep it minimal and deterministic; redact any real keys/RPC in the writeup.

---

## 2. Stateful invariant test (handler + ghost + targetContract)

The fuzzer calls random sequences of the **handler's** functions; after each sequence Foundry checks
every `invariant_*` function. The handler **bounds** each actor action and tracks a **ghost variable**
(expected off-chain state) so the invariant can compare real vs. expected.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

// ---- Handler: the only contract the fuzzer is allowed to call ----
contract Handler is Test {
    Vault public vault;
    MockERC20 public asset;

    uint256 public ghost_totalDeposited;   // ghost: sum of successful deposits
    uint256 public ghost_totalWithdrawn;   // ghost: sum of successful withdrawals

    address[] internal actors;
    address internal currentActor;

    constructor(Vault _vault, MockERC20 _asset) {
        vault = _vault;
        asset = _asset;
        for (uint256 i; i < 4; i++) actors.push(makeAddr(string.concat("actor", vm.toString(i))));
    }

    // Pick an actor for this call, deterministically from the fuzzed seed.
    modifier useActor(uint256 seed) {
        currentActor = actors[seed % actors.length];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function deposit(uint256 seed, uint256 amount) external useActor(seed) {
        amount = bound(amount, 1, 1e24);                 // bound the action to a sane range
        asset.mint(currentActor, amount);
        asset.approve(address(vault), amount);
        vault.deposit(amount, currentActor);
        ghost_totalDeposited += amount;                  // track expected state
    }

    function withdraw(uint256 seed, uint256 shares) external useActor(seed) {
        uint256 maxShares = vault.balanceOf(currentActor);
        if (maxShares == 0) return;
        shares = bound(shares, 1, maxShares);
        uint256 assets = vault.redeem(shares, currentActor, currentActor);
        ghost_totalWithdrawn += assets;
    }
}

// ---- Invariant test: wires the handler as the fuzz target ----
contract VaultInvariant is Test {
    Vault vault;
    MockERC20 asset;
    Handler handler;

    function setUp() public {
        asset = new MockERC20("Mock", "MCK", 18);
        vault = new Vault(address(asset));
        handler = new Handler(vault, asset);

        // Fuzz ONLY the handler (not the raw vault) so every action is bounded/valid.
        targetContract(address(handler));

        // Optionally restrict to specific handler functions:
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.withdraw.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // Solvency: the vault always holds at least what depositors can redeem.
    function invariant_solvency() public view {
        assertGe(
            asset.balanceOf(address(vault)),
            handler.ghost_totalDeposited() - handler.ghost_totalWithdrawn(),
            "vault holds less than net deposits => insolvent"
        );
    }

    // Accounting: total shares back no more assets than exist.
    function invariant_sharesBackedByAssets() public view {
        assertGe(vault.totalAssets(), vault.convertToAssets(vault.totalSupply()));
    }
}
```

Key pieces:
- **Handler** — the actor. Every fuzzed function `bound()`s its inputs and (usually) `prank`s as one
  of a small set of actors, so the fuzzer explores realistic sequences instead of reverting garbage.
- **Ghost variables** (`ghost_*`) — the expected state the handler maintains, used by invariants as
  the source of truth to compare against on-chain state.
- **`targetContract(addr)`** — restricts fuzzing to the handler. Without it Foundry fuzzes every
  deployed contract, hitting unbounded reverts.
- **`targetSelector(FuzzSelector{...})`** — narrows to chosen handler functions (omit to fuzz all
  public handler functions).
- **`invariant_*`** — asserted after every call sequence. Name them for the property (`invariant_solvency`).
  Set `fail_on_revert = false` in `[invariant]` while the handler may still revert; tighten to `true`
  once it never does, so a handler revert becomes a signal.

Encode §1's stated invariants (solvency, collateralization, `Σ balances == totalSupply`, reward
conservation) as `invariant_*` functions — the fuzzer searches for the breaking sequence you'd miss by eye.
