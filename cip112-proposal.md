#### 1. Problem (short)

- What is being solved/improved?
    
    CIP-0112 (Canton Token Standard V2) defines interfaces only. The only existing V2 token implementations are Amulet (production-grade, but only supports basic accounts, is entangled with Splice/DSO machinery and has V2 shimmed over version 1) and the TestTokenV2 example. The open, production-grade, adaptable reference slot is empty. 
    
    Without a CIP112 reference implementation, each application will have to do the research and implement their own. They will spend significant resources to check the implementation for quality, correctness and security. We can provide them a ready-to-go token that contains all the best practices (the equivalent of our ERC20 contract but on Canton).
    
    Our package will supply a V2-native token implementation a registry adapts: holdings, transfer instructions, allocations with exact-cover batch settlement and CIP-0112 iterated settlement, a single registry rules contract hosting the three factories, and standard event logging.
    
- Who is the target user?
    
    Token issuers and the registries they run: stablecoin issuers, RWA/treasury tokenizers, custodians and exchanges integrating CIP-0112 assets. Wallets, auditors and general application developers are secondary users, through the standard interfaces.
    

#### 2. Existing solutions

*Source: research artifact* 

- What already exists in the Canton ecosystem?
    - The sixteen `splice-api-token-*` V2 packages define the interfaces (no templates).
    - `splice-token-standard-utils` ships reuseable functions as an implementation kit: `checkActors`, exact-cover batch validation (`fetchAndValidateAllocations`), net-credit computation, event-log helpers, and V1↔V2 shims.
    - Amulet/Canton Coin implements V2 in production via V2-on-V1 shims.
    - CIP-0086 layers ERC-20-style allowances on top as middleware.
- What does it do well / poorly?
    
    Amulet is a production implementation, but with basic accounts only single-instrument, and inseparable from mining rounds and the DSO party. Amulet also ported from V1, so the existing code is made to fit both CIP-056 and CIP-0112: our CIP-0112 implementation will target new tokens, solely implementing the V2 interfaces.
    
- Which constraints come from Canton's model?
    - Default settle authority is `admin :: executors`, so a factory-level cover check is only enforceable if the per-allocation settle refuses to run without factory-minted proof.
    - V2 lifecycle choices are nonconsuming but MUST consume - archival discipline is the implementation's responsibility.
    - Daml interfaces are not upgradeable; the vendored devnet-stage DARs are pinned exactly and package ids churn with upstream releases.
    - A non-stakeholder cannot read state: factories and choice contexts reach wallets via explicit disclosure.
    - Batch settlement preserves Canton's sub-transaction privacy only if invoked from executor-only contexts and per-allocation data is redacted from what authorizers witness.
    - The V2 interfaces explicitly mention everything that an implementation must respect - archival, actor checks, etc.

#### 3. Proposed approach and integration surface

One implementation package, `openzeppelin-tokenCIP112-v1` (public module namespace `OpenZeppelin.TokenCIP112V1`), V2-native, defining no interfaces or exceptions of its own. It builds against the 13 vendored Token Standard V2 DARs, targets Daml-LF 2.1 on SDK 3.4.11.

- `TokenRules` — one long-lived admin-signed contract implementing `TransferFactory`, `AllocationFactory`, and `SettlementFactory`, plus evented mint/burn and batched admin expiry choices. Config: `maxTTL` (storage bound) and `lockGrace`.
- `TokenHolding` — asset holding signed by admin plus account parties, with optional locks.
- `TokenTransferInstruction` — two-step transfer lifecycle (accept / reject / withdraw / expire) with net funding locked at instruction time.
- `TokenAllocation` + `BatchSettlementAuthorization` — net-funded allocations settled through exact-cover batch validation; the factory mints an admin-signed per-allocation proof binding the settlement, authorizer, effective leg set, and next-iteration reservation, so a direct settle cannot bypass the cover check.
- Iterated settlement: an allocation created with `nextIterationFunding` locks the reserve upfront; executors supply extra transfer legs and the next reservation per iteration via `FinalizedAllocation`; proceeds roll into a successor allocation returned as `nextIterationAllocationCid`, with per-iteration conservation checks and monotone expiry bumps. This is the equivalent of: I lock funds upfront, and the necessary legs are decided later (as a practical example, I lock 100 USD for my Claude subscription, and Claude pulls the necessary amount each day, depending on how much I spend).
- `TokenEventLog` — throwaway event-log host (create, exercise `EventLog_HoldingsChange`, archive in one transaction); exactly one event per account-holdings change on every path.
- Lifecycle hygiene: `expiresAt` equals the workflow deadline bounded by `maxTTL`; funding locks outlive expiry by `lockGrace` so the admin expiry path always has a guaranteed window; `TokenAllocation_AdminGC` cleans shells whose funding was reclaimed elsewhere.
- Companion package `openzeppelin-allocation-request-v1`: the app-side `TokenAllocationRequest` (accept / reject / withdraw), registry-independent, extracted into its own unit.
- Design artifact: `cip112-reference/artifacts/02-design.md` (describes the target v2 shape; the shipped v1 differs — single package, V2-only, no V1 shims). Iterated-settlement code artifact: `cip112-reference/artifacts/04-code-iterated-settlement.md`.

Consumer-side integration sketch — the intended consumption model: the issuer consumes the DAR and creates one `TokenRules` contract; the token is live, and wallets act through the standard interfaces. The full walkthrough (token launch, DvP, iterated settlement, failing paths) is the trading example.

```haskell
-- daml.yaml
data-dependencies:
  - .../openzeppelin-tokenCIP112-v1-0.1.0.dar

-- The issuer launches the token: one registry contract, no per-instrument
-- deployment; mint/burn and the three factories are choices on it.
rulesCid <- submit admin do
  createCmd TokenRules with admin; maxTTL = days 90; lockGrace = hours 1

-- A wallet initiates a transfer through the standard interface; the
-- registry contract arrives via disclosure.
submit (actAs [sender] <> discloseMany [rulesDisclosure]) do
  exerciseCmd (toInterfaceContractId @TransferInstructionV2.TransferFactory rulesCid)
    TransferInstructionV2.TransferFactory_Transfer with
      transfer   -- sender, receiver, amount, instrumentId, executeBefore, inputHoldingCids
      actors = [sender]
      extraArgs = emptyExtraArgs
```

#### 4. Minimal end-to-end examples (required)

- Link to example repo/module(s)
    - canton-contracts/examples/tokenCIP112/trading at igingu-cip112-simplification-and-rad · OpenZeppelin/canton-contracts — the intended consumption model: launching a token from the DAR, then an exchange settling trades between two traders through the standard interfaces: allocation requests accepted and funded in one transaction, atomic DvP batch settlement, and the iterated-settlement deposit flow.
- Both Happy and Failing paths are demoed here:
    - https://github.com/OpenZeppelin/canton-contracts/blob/igingu-cip112-simplification-and-rad/examples/tokenCIP112/trading/daml/MyApp/TradingDemo.daml — `demoCreateToken` (issuer creates one `TokenRules` contract and the token is live; a second instrument is just another id under the same registry), `demoDvpSettlement` (direct settle without the factory proof refused; under-covered batch refused; then the atomic DvP), and `demoIteratedSettlement` (over-reservation refused; two fills rolling into successor deposits; chain ended with all funds released).
- Component tests: experiments/test/tokenCIP112-v1 — 30 Daml Script scenarios covering happy and failing paths (under-funded senders, missing batch authorization, superfluous/missing cover legs, iterated-settlement bounds, admin expiry, lock grace), with 100% production template and choice coverage under `dpm test --all --show-coverage`.
- Sandbox gate: scripts/check-sandbox.sh runs mint/query, the transfer lifecycle, and mint+burn against a real static-time Canton sandbox over the Ledger API gRPC endpoint.

#### 5. Invariants summary

Not written yet.

#### 6. Why this is better (the delta)

- Improvements over existing solutions
    - Against Amulet: V2-native rather than V2-on-V1, standalone rather than DSO-entangled, private-asset observer posture by default.
    - Settlement binding is enforced: the factory's exact-cover check, and an admin-signed per-allocation proof that binds settlement, authorizer, effective legs, and reservation, consumed by the settle body. One cannot settle the allocations directly, it needs to go through the settlement factory.
    - Iterated settlement: per-iteration conservation (reserve ≤ locked funds + net credit, totals ≥ 0, fail closed), successor chains with pinned original id and bumped expiry.
- Alternatives considered, and why this one wins
    - V1 dual-compatibility now: deferred. V2-only keeps the package small and auditable; the upstream utils ship the V1-on-V2 shims when a deployment target needs V1 visibility.
    - CIP-0086-style allowances: removed from the package. Allocations are the native delegation primitive; an allowance layer is a possible later compatibility extension, not core.
    - Separate `-api` package: not needed — the package defines no interfaces or exceptions of its own, so it ships as a single implementation package per repo policy.
- Trade-offs introduced
    - V2-only: invisible to V1 wallets and parsers until V1 instances are added.
    - Registry config (`maxTTL`, `lockGrace`) is snapshotted onto each allocation so settlement iterations can bump expiry without the registry contract in scope; reconfiguration does not retroactively change live allocations.
    - The vendored TSv2 DARs are devnet-stage: every package id changes when upstream cuts a release.
- What it does NOT solve
    - No on-ledger pause (see the Pausable component) and no defined pause × in-flight-instruction matrix yet.
    - No allowances, no account owner/provider policy machinery beyond basic accounts, no role-gated mint/burn catalogue.
    - No off-ledger HTTP server: the Daml side is shaped for it (choice contexts, explicit disclosure), but the endpoint set is not implemented.
    - No reusable "behaves-like-CIP-0112" conformance suite consumers can run against their forks yet.

#### 7. Review readiness

- [x]  Problem is written down
- [x]  Research artifact exists and has a go recommendation
- [x]  Design artifact exists (describes the target v2 shape; shipped v1 diverges — see §3)
- [ ]  Invariants artifact exists
- [ ]  Integration surface is clear (consumer sketch present, not yet reviewed)
- [x]  Examples compile
- [x]  Examples include happy + failing cases
- [x]  Delta is explicit (why this is better, what it doesn't solve)
- [x]  Open questions listed

#### Open questions / follow-ups

- V1 dual-compatibility: ship V1 interface instances via the upstream shims in this package, or as a sibling package when a deployment target requires it?
- Account policies: does the reference stay basic-accounts-only, or ship 2–3 named owner/provider policies as vetted defaults?
- Pause: integrate the Pausable component at the registry seam, or keep it as some sort of extension, i.e. `TokenRulesPausable`, `TokenRulesAccessControl`
- Off-ledger server scope: OpenAPI spec only, or a skeleton HTTP server?
- Toolchain: upstream V2 builds on SDK 3.5.2 / alpha protocol 35; this repo baselines 3.4.11 — what is pinned for the validation story?
