# Agent report: Solidity/EVM Token-Standard Reference Research for CIP-0112 Reference Implementation

(Verbatim agent deliverable, 2026-08-26. Sections: 1 OZ ERC-20 adoptability, 2 extension catalogue, 3 pitfalls, 4 CIP-0086, 5 non-translating concepts.)

**Framing note:** every EVM pattern carries the implicit authorization assumption "the caller is msg.sender, authenticated by transaction signature, acting against globally visible shared state." Canton has none of that.

## 1. What made OpenZeppelin's ERC-20 THE adoptable reference

Cited at OpenZeppelin Contracts v5.7.0, commit cab19933c33c2ad1d4c7a84864a3601dddfd16f3 (2026-07-29).

### 1.1 Single internal choke point: _update
- ERC20.sol: `_update(from, to, value) internal virtual` is the ONLY function through which every mint (from==0), burn (to==0), and transfer flows. "All customizations to transfers, mints, and burns should be done by overriding this function."
- Replaced v4.x dual hooks _beforeTokenTransfer/_afterTokenTransfer in v5.0 (issue #3535, PR #3838): one override point instead of two hooks from three entry points; two hooks caused ordering/double-invocation bugs.
- _transfer is deliberately NOT the extension point — only enforces non-zero-address checks then delegates to _update, so extensions can't bypass invariants.
- Daml translation: funnel every supply-affecting change through one auditable internal function = the documented extension seam. Authorization at entry point (choice controllers), invariants at the choke point.

### 1.2 Core vs extensions, extension-by-inheritance
- Core ERC20.sol minimal and standard-exact; extensions in contracts/token/ERC20/extensions/, each one small file overriding _update or _approve, composed via C3-linearized multiple inheritance.
- OZ ships NO ERC20Mintable: minting is internal _mint; issuer wires access control (Ownable/AccessControl) themselves, usually via Contracts Wizard. Who may mint is a policy decision OZ refuses to default.

### 1.3 Docs/testing/versioning discipline (the adoption moat)
- Versioned docs site + NatSpec API reference + guides + explicit warnings ("decimals is only used for display purposes").
- Shared behavior suites (shouldBehaveLikeERC20) reused by downstream forks; Foundry fuzzing; Certora formal verification specs in-repo since v5.
- Strict semver; breaking changes at majors only (v5: removed hooks, removed increaseAllowance/decreaseAllowance, custom errors); every major audited; CHANGELOG + migration guides.
- Wizard as onboarding — arguably the biggest driver of "OZ as default."
- Missing analogues to copy: reusable behavior test suites consumers run against adaptations; scaffolding/wizard story.

## 2. Extension catalogue and composition

| Extension | What | Hook | Authorization assumption |
|---|---|---|---|
| ERC20Burnable | holder/spender burns | _burn/_spendAllowance | msg.sender holder or allowance |
| ERC20Capped | max supply on mint | _update | none (pure invariant) |
| ERC20Pausable | blocks movement | _update + whenNotPaused | external pauser role |
| ERC20Permit (EIP-2612) | gasless approvals | permit() → _approve | EIP-712 signature |
| ERC20Votes | checkpointed voting | _update moves units | delegation by msg.sender |
| ERC20FlashMint (ERC-3156) | flash loans | flashLoan around _mint/_burn | single-EVM-tx atomicity (no Canton analogue) |
| ERC20Wrapper | wrap 1:1 | deposit/withdraw | transferFrom allowance |
| ERC1363 | transfer-and-call | wraps + callback | recipient hook |
| ERC4626 | vault shares | separate standard | share math over global balances |
| ERC20TemporaryApproval (ERC-7674) | one-tx approvals | transient storage | single-tx |
| ERC20Bridgeable (ERC-7802), ERC20Crosschain (ERC-7786) | cross-chain mint/burn | restricted | trusted bridge role |

Composition: multiple inheritance, one _update override calling super._update chains all parents. One override point makes N extensions stack.

Most-used (qualitative — Wizard toggles, flagship deployments; no census):
1. AccessControl/Ownable-gated minting + ERC20Burnable
2. ERC20Permit (near-default since ~2021; USDC v2, DAI)
3. ERC20Pausable + non-OZ blocklist — stablecoin/RWA compliance cluster (USDC/USDT: pause + blacklist + upgradeability)
4. ERC20Capped
5. ERC20Votes (governance only)
6. ERC4626 (vault product class)
7. FlashMint, ERC1363, TemporaryApproval — rare.

Daml translation: high-value = compliance cluster (pausable, role-gated mint/burn, cap, blocklist/freeze) + supply reporting — all invariant-style guards on the single update path. Permit/FlashMint/TemporaryApproval/Votes-checkpointing are EVM-model artifacts.

## 3. Battle-tested pitfalls (canonical: d-xo/weird-erc20)

1. **Approve front-running race**: approve(N)→approve(M) lets front-running spender spend N+M. USDT "approve 0 first" breaks integrators; OZ increaseAllowance/decreaseAllowance REMOVED in v5 (issue #4583, PR #4585; $24M increaseAllowance phishing cited). Root cause: allowance = shared mutable state, two writers, no ordering. Canton lesson: allowance as discrete contract per grant (consume-and-replace = archive+create) — race-free by construction.
2. **Missing return values** (USDT, BNB, OMG) → SafeERC20 wrappers. Lesson: result contract must be type-system-enforced — Daml interfaces give this free.
3. **Fee-on-transfer/rebasing**: STA fee drained ~$500k from Balancer. Lesson: if issuer hooks permitted on update path, document loudly that debit≠credit breaks integrators; prefer fees as explicit separate holdings/steps. CIP-0112 EventLog makes credits/debits explicit — keep exact.
4. **Decimals confusion**: display-only, non-uniform (USDC=6), some revert. Canton: Daml Decimal, pin canonical scale, arithmetic in base units.
5. **Infinite allowances**: OZ special-cases uint256.max as never-decrement — UX win, phishing disaster. Canton lesson: standing authority time-boxed/amount-boxed by default, revocable by archiving one contract; CIP-0056 steers to allocations.
6. **Blocklist/pausability × DeFi**: pause/blacklist mid-flight strands funds. Lesson: define pause vs in-flight TransferInstruction/allocation semantics as a documented matrix (does pause block acceptance of proposed instructions? does freeze archive pending proposals?).
7. **Upgradeability hazards**: USDC/USDT proxies change semantics under integrators; storage collisions. Canton analogue: SCU — document upgrade/migration assumptions per template; package-version pinning by integrators is first-class ("who can upload a new package version and migrate holdings?").

## 4. CIP-0086 — ERC-20 Middleware and Distributed Indexer

Status: **Approved 2025-10-20**. Author Eric Saraniecki; delivery by ChainSafe, SV reward incentives (up to 5 weight, milestone-gated: first EVM-compatible token on mainnet within 180 days, TVL bonuses).

Three layers: (1) on-ledger Daml contracts implementing ERC-20 semantics (CIP-56-compliant core); (2) off-ledger middleware exposing ERC-20-compatible API (balanceOf, approve, transferFrom, …) translating to Ledger API commands; (3) distributed indexer aggregating token events (substitute for global balances mapping).

Allowance semantics: on-ledger **AllowanceContract per grant**; middleware handles "transfer composition under UTXO constraints" (transferFrom = middleware selects/splits/merges holding UTXOs, exercises against allowance contract). Authorization: spender acts via pre-created contract on which they are controller — standing authority is a contract, not a mapping entry.

Visibility modes: full visibility (Canton Coin — public middleware) vs scoped visibility (stablecoins/RWAs — issuer/user runs middleware; balanceOf restricted). ERC-20's read API is a privacy decision on Canton, per-token.

Relation: CIP-0086 builds on CIP-0056 (Phase 1 concrete token+middleware+indexer vs Canton Coin; Phase 2 generalize via interface abstraction; Phase 3 follow-up CIP for SV-operated network-wide infra). CIP-0112 does not mention CIP-0086 or allowances. CIP-0056 rejects allowances natively ("do not work well with a UTXO model and privacy"). Ecosystem position: **allocations are the native primitive; ERC-20 allowances are a compatibility layer for EVM-habituated integrators** — present in exactly that hierarchy.

## 5. ERC-20 concepts that do NOT translate

| ERC-20 concept | Why it fails | Canton-native equivalent |
|---|---|---|
| Global balances mapping / on-ledger totalSupply | no global state; would bottleneck synchronizer, destroy privacy | balance = sum of Holding UTXOs read off own Ledger API; CIP-0086 indexer for aggregates; EventLog for debits/credits; supply reporting off-ledger |
| msg.sender authorization | no global caller identity | choice controllers + signatories; roles = contracts granting controller rights |
| transfer as unilateral push | can't create contract with recipient signatory without authority | propose-accept TransferInstruction; TransferPreapproval for one-step UX (Canton Coin requires receiver preapproval) |
| allowance as shared mutable state | two writers on one slot; spender can't pull UTXOs; leaks relationship | allocations (time-bounded locks) + CIP-0112 committed/iterated; compatibility: CIP-0086 AllowanceContract per grant |
| approve-then-transferFrom DEX/escrow | workaround for EVM's inability to compose two parties' authority atomically | atomic DvP via allocations + SettlementFactory — no standing spender authority needed |
| ERC20Permit / EIP-2612 / ERC-7674 | exist because approve costs gas tx | nothing needed — propose-accept/allocations carry exactly-scoped authority |
| ERC20FlashMint | single-VM atomicity + mid-tx re-entry | no equivalent; use-cases served by atomic multi-leg settlement; omit |
| ERC1363 recipient hooks | plain transfer can't trigger recipient logic | propose-accept IS the notification |
| ERC20Votes checkpointing | reads past balance from global state | app-level snapshots; out of token-core scope |
| Events as integration surface | EVM logs globally readable | CIP-0112 EventLog re-creates standalone events within each party's visibility — adopt as integration surface |
| Blocklist mapping / global pause bool | no global state; policy translates | issuer-as-signatory freeze/pause leverage; pause = guard on factory/update path; document in-flight interaction matrix |

### What the reference should copy from OZ
1. One documented internal update seam (the _update lesson): auth at choice level, invariants (cap, pause, conservation) at the seam.
2. Minimal standard-exact core + small orthogonal extensions, each a separate package/interface with one-line hook contract.
3. No default mint policy — expose internal mint path, issuer wires access control explicitly.
4. OZ-grade docs/tests/versioning: reusable "behaves-like-CIP-0112" suites; frozen API packages; audited semver releases; upgrade-assumption docs per template.
5. Allowances (CIP-0086 style) as compatibility extension over native allocation/propose-accept core, never as the core.

## Sources
- OZ v5.7.0 release commit cab19933c33c2ad1d4c7a84864a3601dddfd16f3; ERC20.sol and extensions dir at that SHA
- docs.openzeppelin.com/contracts/5.x (erc20, api/token/erc20, erc20-supply, changelog); openzeppelin.com/news/introducing-openzeppelin-contracts-5.0
- github.com/OpenZeppelin/openzeppelin-contracts issues #3535, #4583; PRs #3838, #4585
- github.com/d-xo/weird-erc20; EIP-2612; ERC-3156
- github.com/canton-foundation/cips: cip-0056, cip-0086, cip-0112
