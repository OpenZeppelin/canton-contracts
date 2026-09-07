---
stage: research
project: cip112-reference
mode: greenfield
extends: null
status: draft
timestamp: 2026-08-26
author: ionut.gingu
previous_stage: null
tags: [cip-0112, cip-0056, token-standard, canton, splice, reference-implementation, settlement, accounts]
---

# CIP-0112 Reference Implementation — Research Report

> Companion document: `../cip112-explainer.md` explains the CIP-0112 standard itself in full.
> Raw agent research: `../sources/agent-reports/` (01 Splice V2, 02 CIP-0056/off-ledger, 03 Solidity/EVM, 04 Corda, 05 ecosystem needs). Specs: `../sources/cip-0112.md`, `../sources/cip-0056.md`.
> Per dev instruction, this research did **not** examine or reference the existing implementation in this repository's `experiments/token/`.

## Summary

Researched the full CIP-0112 (Canton Network Token Standard V2) surface — on-ledger Daml interfaces and off-ledger OpenAPI obligations — across the Canton/Splice ecosystem, OpenZeppelin's ERC-20 architecture, and Corda's tokens/accounts libraries, plus a demand assessment. Key finding: the only existing V2 token implementations are Amulet (production, but basic-accounts-only and Splice-entangled) and TestTokenV2, which CIP-0112 itself disqualifies for production use ("simplify and specialize it … rather than using it as provided") — the open, production-grade, adaptable reference slot is empty while institutional adoption (Circle, BitGo, Brale, Dfns, 35+ institutions on DA's registry platform) and auditor-documented failure classes (CertiK's six) are both real. **Recommendation: build** — a dual-version (V2-core, V1-via-shims) token reference with an opinionated, hardened account model and OZ-style single-update-seam extension architecture.

## Existing Canton Implementations

All Splice permalinks pin `hyperledger-labs/splice` main HEAD `6bcae32a2b9763b7c7b9800100aca7f0d426c76d` (2026-08-26). **The normative V2 artifacts live on splice `main`** — the CIP text's `token-standard-v2-upcoming` preview branch is the historical draft.

### 1. The V2 API packages (`token-standard/splice-api-token-*-v2`) — the standard itself

Pure-interface packages (no templates), version 1.0.0, SDK 3.5.2, Daml-LF `--target=2.1`:

| Package | Key contents |
|---|---|
| [`splice-api-token-holding-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-api-token-holding-v2/daml/Splice/Api/Token/HoldingV2.daml) | `Account {owner : Optional Party, provider : Optional Party, id : Text}`; view-only `Holding` interface (V1's `owner : Party` → `account : Account`) |
| [`splice-api-token-transfer-instruction-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-api-token-transfer-instruction-v2/daml/Splice/Api/Token/TransferInstructionV2.daml) | `TransferFactory`, `TransferInstruction` — all choices **nonconsuming**, `controller actors`, impl-defined choice observers; `availableActions : Map action [[Party]]` replaces `status`; **`expectedAdmin` dropped** (validate against `instrumentId.admin`) |
| [`splice-api-token-allocation-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-api-token-allocation-v2/daml/Splice/Api/Token/AllocationV2.daml) | `Allocation` (`Allocation_Settle/Cancel/Withdraw`, default settle authority `admin :: executors`), **new `SettlementFactory`** with `SettlementFactory_SettleBatch`; `AllocationSpecification` with `committed`, `nextIterationFunding`; `FinalizedAllocation` |
| [`splice-api-token-allocation-instruction-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-api-token-allocation-instruction-v2/daml/Splice/Api/Token/AllocationInstructionV2.daml) | `AllocationFactory`, `AllocationInstruction` (new `_Accept` for provider/joint approval; V1's admin `_Update` gone) |
| [`splice-api-token-allocation-request-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-api-token-allocation-request-v2/daml/Splice/Api/Token/AllocationRequestV2.daml) | `AllocationRequest` with `allocations : [AllocationSpecification]` and new `_Accept` (replay protection) |
| [`splice-api-token-transfer-events-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-api-token-transfer-events-v2/daml/Splice/Api/Token/TransferEventsV2.daml) | `EventLog` with side-effect-free nonconsuming `EventLog_HoldingsChange` (controller `admin`, observer-driven) — the ERC-20-events analogue |
| [`splice-token-standard-utils`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-token-standard-utils/daml/Splice/TokenStandard/Utils.daml) (v2.0.0, forced utility package) | The implementation kit: `basicAccount`/`accountParties`, `checkActors`/`archiveAndCheckActors`, `BackwardCompatible`/`ForwardCompatible` up/downcasts, all `*DefaultImplUsingV2`/`UsingV1` shims, `netAllocationCreditAmounts`, `ensureWithdrawIsAllowed`, `settlementFactoryV2_settleBatchDefaultImpl` (the canonical exact-cover batch validation), event-log helpers (`logMint/logBurn/logTransfer/logMergeSplit/logAllocationSettlement`), public- vs private-asset choice-observer defaults |

Each workflow package ships a matching OpenAPI spec. Pause reporting is off-ledger only: `paused`/`pauseInfo` on `token-metadata-v1.yaml` (no metadata-v2 Daml package). Note the yaml has moved past the CIP text: `showAccountInputFields` is **deprecated** in favor of `accountInputFieldsToShow : ["provider"|"accountId"]` (splice PR #6346).

*Limitations:* declared "ready for initial validation," "small refinements may still occur"; package hashes already changed twice across SDK bumps (3.4.11 → 3.5.2); the V2 DevNet requires alpha protocol version 35. Daml interfaces are not upgradeable — several empty result types exist purely as future-proofing.

### 2. TestTokenV2 ([`token-standard/examples/splice-test-token-v2`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/examples/splice-test-token-v2/daml/Splice/Testing/Tokens/TestTokenV2.daml)) — the spec's own reference

How it works: a singleton `TokenRules` factory (signatory admin) implements **eight interfaces on one contract** (V1+V2 factories, SettlementFactory, EventLog), with V1 delegating to V2 via the utils shims. Holdings are `Token` templates signed by `accountParties + admin`. The account model is an on-chain `AccountConfig {ownerConfig, providerConfig : PartyConfig {canInitiate, mustApprove}}` (signatory owner+provider, observer admin, served to choices via choice context) driving generic **authorization state machines** — ~20 distinct authorization flows for a simple transfer. Transfers use a sender-side lock step (debit inputs → locked holding → receiver accept consumes it). V1-incompatible allocations are handled by *two allocation templates* — `TokenAllocationV2` and a wrapper `TokenAllocationV1` with `ensure canViewAsAllocationV1`, plus `CallSource = CalledFromV1 | CalledFromV2` archival discipline. Mint/burn ride the standard flows against `cip-112/mint`/`cip-112/burn` ownerless accounts.

Limitations (its own docstrings): deliberately feature-maximal "to test all the possibilities the CIP-0112 account model offers"; explicit "in prod you would…" caveats (cap instruction TTLs against storage leaks, add admin allocation-expiry choice, tolerate expired-lock races); **CIP-0112 itself recommends not using it as provided**. No on-ledger pause.

### 3. Amulet / Canton Coin ([`daml/splice-amulet`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/daml/splice-amulet/daml/Splice/ExternalPartyAmuletRules.daml) v0.1.22) — the production V2 implementation

Implements V2 in the *opposite direction* from TestTokenV2 for transfers: **V2-on-top-of-V1** shims (its V2 Holding view is `upcast` of V1 — basic accounts only, single instrument). `ExternalPartyAmuletRules` (signatory DSO) is the factory hub for all five factory/settlement/event interfaces, using `settlementFactoryV2_settleBatchDefaultImpl` with no context filtering ("Amulet does not use any per-account information"). Native `AmuletAllocationV2` supports committed/iterated allocations backed by an optional `LockedAmulet` (`None` when net movement is positive — the net-locking guideline in practice). DSO housekeeping batch-expires only *expired* allocations so SV delegation can't cancel live ones. Shipped in Splice 0.6.11 with full wallet-UI V2 support.

Limitation as a reference: deeply entangled with Splice/DSO machinery (mining rounds, featured-app rights, DSO party); public-token privacy posture only.

### 4. Test harness ([`splice-token-standard-v2-test`](https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/token-standard/splice-token-standard-v2-test/daml/Splice/Testing/TokenStandard/RegistryApiV2.daml) + examples)

Daml Script infrastructure consumed *as source* (DARs not shareable across SDKs): `RegistryApi` typeclass mirroring the OpenAPI handler names (simulating off-ledger discovery in-script), `MultiRegistry` for mixed-version settlement tests, `WalletClientV2` (account-aware balance assertions, V1+V2 uniform action, event-log-based tx-history checking), and `TradingAppV2` — the reference *consumer* app (OTC trade, per-admin allocation batching, `TradeSettlementAgreement` receipt-allocation delegation guarded by `ensureIsReceiptAllocation`). The CLI's `parserv1.ts`/`parserv2.ts` with `--strict` (no unexplained creates/archives) is the wallet-parsing reference.

### 5. Adjacent: DA hosted products, CIP-0086, ChainSafe

- **DA Tokenization Utility / Registry** (proprietary, hosted): full CIP-0056 + CIP-0112 support, "zero deployment" mode where DA operates the token-standard backend; Registry 0.14+ parses via the CIP-112 EventLog path. Fills the production slot only as a closed product.
- **CIP-0086** (approved 2025-10-20, ChainSafe delivery): ERC-20 *middleware* — on-ledger `AllowanceContract` per grant + off-ledger ERC-20-API translation + distributed indexer, explicitly layered **on top of** CIP-0056 tokens. Ecosystem position: allocations are the native primitive; allowances are a compatibility layer.
- **ChainSafe `canton-erc20`** ([issue #27](https://github.com/ChainSafe/canton-erc20/issues/27)): cautionary tale — their first CIP-56 token implemented zero Daml interfaces and was invisible to every Canton wallet; required a breaking 2.0.0 rewrite.

### 6. Off-ledger surface a registry must serve (CIP-0056 baseline + V2 delta)

V1: `GET /registry/metadata/v1/info` (capability detection via `supportedApis`) and `/instruments[/{id}]`; `POST …/transfer-factory` and per-instruction `choice-contexts/{accept|reject|withdraw}`; `POST …/allocation-factory`; per-allocation `choice-contexts/{execute-transfer|withdraw|cancel}`. Every factory/context response = `factoryId/choiceContextData/disclosedContracts` (explicit disclosure records the wallet attaches verbatim to the Ledger API command). All unauthenticated by design — contract-ids function as capability tokens; BFT for decentralized registries by serving every node under its own URL prefix.

V2 delta (small): same-shape `/v2/` transfer endpoints; **new** allocation-*instruction*-level `choice-contexts/{accept|withdraw}` (provider acceptance under the account model); and `POST /registry/allocation/v2/settlement-factory` **replacing** V1's per-allocation execute-transfer context (≥ 25 legs / 50 allocations / 50 accounts / 100 parties per request). Advertising: V2 packages in `supportedApis`, `paused`/`pauseInfo`, `accountInputFieldsToShow`.

## Cross-Ecosystem Implementations

### Corda

Closest privacy/permissioned prior art; authorization model = state `participants` (storage) + per-`Command` required signers (authority) + notary (uniqueness). Full findings in `../sources/agent-reports/04-corda.md`; what binds our design:

- **Validated patterns:** issuer-in-the-fungibility-class (`IssuedTokenType` — same instinct as `InstrumentId.admin` in holding identity; each custody intermediary's claim is a distinct instrument of its own issuer); holdings referencing separately-evolving definition state (ancestor of registry-served instrument metadata — but Corda's *push* distribution lists desynced; keep metadata pull-based); explicit per-command signer semantics; production atomic DvP (SDX, HQLAx).
- **Failure lessons:** token selection as a library bolt-on became the operational pain center (soft-lock contention, "token exhaustion where all tokens are locked by flows not making progress") — CIP-0112 committed allocations are that soft lock promoted to first-class contract state, and they must keep bounded lifetimes/abort paths or the failure mode returns. Accounts were retrofitted (2019) onto `holder: AbstractParty`: the logical owner had *no ledger-level authority*, permissions were app-layer only — exactly the hole CIP-0112's owner/provider-as-real-parties closes; never weaken it. The backchain privacy leak (every signer sees the whole transaction; verification exposes history) was never fixed and was a structural objection for banks — Canton sub-transaction privacy is the differentiator CIP-0112 §4.1.1 builds on, and batch settlement must not squander it (call `SettleBatch` from executor-only contexts).
- **Custody-chain prior art:** HQLAx Digital Collateral Records — ownership moves on the registry while securities never leave custody accounts, TTP maps ledger to custody; the layered-claim structure the `Account {owner, provider}` model encodes natively. SDX shows single-operator-as-universal-provider works but recentralizes; Kazakhstan's digital tenge is an owner(citizen)/provider(bank) split in production.
- **Adoption lesson:** Corda tokens SDK froze in 2020, consortium apps died siloed — because *interfaces* were never standardized, independent apps couldn't compose. CIP-0112 fixes this at the standard level; a reference implementation's job is making compliant implementation cheap.

### Solidity / EVM

Largest pattern corpus; every pattern carries the `msg.sender` + global-state assumption — translate architecture, not authorization. Full findings in `../sources/agent-reports/03-solidity-evm.md`; what binds our design:

- **Why OZ ERC-20 became *the* reference** (v5.7.0, commit `cab19933`): (a) a **single internal choke point** — `_update` is the only path for every mint/burn/transfer, and the one documented extension seam (v5 deliberately collapsed the v4 dual hooks after ordering/double-invocation bugs); (b) minimal standard-exact core + small orthogonal extensions composed at one override point; (c) **no default mint policy** — `_mint` is internal, the issuer wires access control explicitly; (d) the actual moat: versioned docs, reusable behavior test suites (`shouldBehaveLikeERC20`) downstream forks run against their own tokens, strict semver with audited majors, and the Wizard for onboarding. Daml translation: authorization at choice controllers, invariants (conservation/cap/pause) at one shared internal settle function; extensions as separate packages/interfaces.
- **Extension demand ranking** (qualitative): the compliance cluster dominates — role-gated mint/burn, pausable, blocklist/freeze, cap. Permit/FlashMint/temporary-approval/Votes-checkpointing are EVM-model artifacts with no Canton counterpart needed (propose-accept and allocations already carry exactly-scoped authority).
- **Pitfalls to design around:** approve front-running (solved by construction if standing authority is a discrete contract per grant, consume-and-replace); fee-on-transfer breaking integrators (if issuer hooks can skim the update path, document loudly; EventLog debits/credits must stay exact); pause/blocklist vs in-flight instructions (define the interaction matrix explicitly); upgradeability trust ("who can upload a new package version and migrate holdings?" is the Canton form of the proxy-semantics problem — SCU assumptions documented per template).
- **CIP-0086 relationship:** present allowance-style delegation, if offered at all, as a compatibility extension over the native allocation core — never as the core.

### Other Ecosystems

Deliberately excluded per the agreed scope (see Out of Scope). One transferred observation retained from the exclusion decision: nothing in Cardano/Move's linear-resource models maps onto Canton's signatory-based enforcement in a way ERC-20 + Corda don't already cover better for *this* standard.

## Ecosystem Needs

Full evidence with links in `../sources/agent-reports/05-ecosystem-needs.md`.

- **Who consumes it:** stablecoin issuers (Circle USDCx via xReserve; Brale), RWA/treasury tokenizers (Circle USYC ~$3B AUM; Tradeweb on-chain repo), custodians/exchanges (BitGo CIP-56 qualified custody; Dfns wallet-as-a-service), 35+ institutions on DA's registry platform, and DeFi-style apps (CantonSwap's cross-issuer atomic swap ran purely on CIP-56 interfaces). CIP-0112's own target list: trading/settlement venues and custody-chain securities.
- **Documented pain points:** transaction-history parsing (hard migrations already forced on exchanges with MainNet deadlines; the EventLog path is the fix but has its own attribution subtleties); transaction construction via factory + choice-context + disclosed contracts (integrators reduced to reverse-engineering the wallet-kernel SDK); building a compliant token at all (ChainSafe shipped one invisible to every wallet); day-one V2 semantic questions (committed-allocation withdraw/cancel/top-up policy — forum-answered by DA, not by any implementation devs can read).
- **Auditor-documented issue classes (CertiK):** (1) authorization-binding failures — V2's reusable, earlier authorization "makes correct binding the central invariant"; (2) incomplete interface verification; (3) trust-domain confusion (factory ids and `expectedAdmin` both from untrusted registry data; `ChoiceContext`/`ExtraArgs.meta` as separate trust channels); (4) incomplete event attribution (accepting any structurally-matching `EventLog_HoldingsChange` ingests another admin's history); (5) account-authority escapes (standing authority exceeding its scope); (6) batch-settlement privacy leaks (one allocation receiving another's private reference data). Halborn has an active Canton audit practice; teams are asking on forums where to find audited baselines.
- **Integration requirements for the consumer API:** dual V1/V2 interface instances; exact EventLog emission discipline on every path; the off-ledger endpoint set of §6 above; `basicAccount` behavior exactly matching V1; honoring the 25-leg minimum; and test fixtures integrators can run (the `RegistryApi`-typeclass pattern) — plus documentation that answers the committed-allocation policy questions explicitly.

## Gap Analysis

- **The production-reference slot is empty and acknowledged.** Between DA's hosted/proprietary registry and the test-maximalist TestTokenV2 there is no open, audited, adaptation-oriented CIP-0112 token implementation. This is precisely the ERC-20-in-2017 position OpenZeppelin filled.
- **The hardening knowledge exists but is scattered** across the CIP, splice code comments, the V2_VALIDATION bug appendix (locked tokens usable as inputs; future `requestedAt` accepted; `netAllocationCreditAmount` mixing instruments; `SettleBatch` initially missing leg-id uniqueness; metadata not stripped on upcast; receipt-allocation guard permitting iteration), CertiK's blog, and forum answers. A reference implementation is the natural place to consolidate it as code + tests + docs.
- **The account-model policy space is unstandardized by design** — CIP-0112 deliberately leaves owner/provider authorization to registries. TestTokenV2 demonstrates ~20 flows; nobody ships an opinionated, safe *default*. An OZ-style move: pick 2–3 named policies (owner-only basic; provider-custodial; joint) as vetted configurations, with the generic machinery available underneath.
- **Missing OZ-style adoption infrastructure:** no "behaves-like-CIP-0112" reusable conformance test suite an adapter can run against *their* fork; no extension catalogue (pause with a defined in-flight-instruction matrix, cap, blocklist/freeze, role-gated mint/burn); no wizard/scaffolding story.
- **Known standard-level trap to document, not fix:** V1-created allocations settle on executor authority alone (deliberate — `extraSettlementAuthorizers` dropped); "only allocate to executors you trust" must be surfaced to integrators.
- **Not a gap:** wallet-side tooling (wallet-kernel SDK, BatchingUtility, CLI parsers exist); the interfaces themselves (frozen upstream — never republish under our namespace, consume exact upstream DARs per this repo's rules).

## Recommendation

- **Verdict: Build.**
- **Recommended approach:** Build an OpenZeppelin-grade, production-oriented CIP-0112 token implementation that a token issuer adapts, structured as: (1) a **V2-native core** — holdings, transfer factory/instruction, allocation factory/instruction/allocation(s), settlement factory, event log — with **V1 compatibility via the upstream `splice-token-standard-utils` shims** (TestTokenV2 direction: V1-on-top-of-V2, which is the forward-looking direction; Amulet's V2-on-V1 exists only for its legacy weight); (2) a **single internal settlement/update seam** through which every holding create/archive flows, carrying the conservation/pause/cap invariants and the exactly-one-EventLog-per-change discipline, with authorization checked at choice level (`checkActors`); (3) an **opinionated account model** — 2–3 named owner/provider policies as vetted defaults instead of TestTokenV2's generic state machines; (4) an **extension catalogue** for the compliance cluster (pausable with a defined in-flight matrix, role-gated mint/burn via the special accounts, cap, freeze/blocklist), each hooking the seam; (5) a **conformance test suite** consumers run against their adaptations, built on the upstream `RegistryApi`/`WalletClientV2` harness patterns, covering the V2_VALIDATION bug history and CertiK's six classes as named regression tests; (6) the **off-ledger contract documented as a specification** (endpoint-by-endpoint, with the trust rules: unauthenticated-by-design, contract-ids as capabilities, disclosed-contract handling) — implementing the HTTP server itself is optional scope, but the Daml side must be shaped so a thin server can serve it (e.g., admin observes what it must disclose, as TestTokenV2's `AccountConfig` does).
- **Key design considerations:**
  1. **Settlement binding is the central invariant** (CertiK #1 + spec MUSTs): allocations belong to *this* settlement; leg sides exactly cover `transferLegs` (set-equality, no missing/superfluous — reproduce or reuse `fetchAndValidateAllocations`); leg-id uniqueness; `actors` validated in every choice. This is where a V2 implementation is most likely to be exploitably wrong.
  2. **The dual-version compatibility machinery is not optional** and is the hardest part to get right: two allocation templates (dual V1/V2 + V2-only), `CallSource` archival discipline (V2 choices nonconsuming but MUST consume), account info mirrored into V1 metadata, both parsers' events emitted on every path, `basicAccount` exactly reproducing V1 semantics.
  3. **EventLog emission discipline**: exactly one `HoldingsChange` per account-holdings change with matching admin+account, on every code path including V1 choices, splits/merges, mint/burn, and settlement — plus consumer guidance that only admin-attributed events count.
  4. **Account authorization as configuration, not code**: bounded named policies, provider visibility standardized, authority never exceeding its scope (CertiK #5), settlement authority kept separate from account policy (TestTokenV2 does this deliberately).
  5. **Lifecycle hygiene as first-class**: `expiresAt`/`settlementDeadline` enforcement (deadline overrides `committed`), TTL caps on instructions, admin expiry choices, expired-lock handling — the anti-DoS and anti-token-exhaustion layer Corda proved is where operations break.
- **Risks:** (a) **standard churn** — V2 packages are 1.0.0 but "small refinements may still occur," hashes already changed twice with SDK bumps, and the V2 DevNet needs alpha protocol 35; pin exact upstream DARs and version-stamp compatibility. (b) Daml **interfaces are not upgradeable** — mistakes in which templates implement what are expensive; SCU strategy must be designed up front. (c) **Scope explosion** — full-surface (allocations + iteration + batch settlement + dual-version) is a large build; the account-policy space invites feature creep (TestTokenV2's warning is the cautionary tale). (d) **Privacy claims are testable only end-to-end** — Daml Script can't observe participant-level view distribution directly; view-count/observer assertions need deliberate test design. (e) **Upstream overlap** — if Splice or DA later ships an open production reference, differentiation shifts to hardening + extensions + conformance suite.

## Out of Scope

- **Cardano/Plutus, Aptos/Sui Move, CosmWasm/IBC** — dropped per dev instruction; authorization/resource models too distant to add signal beyond ERC-20 + Corda for this standard.
- **The existing implementation in this repository (`experiments/token/`)** — explicitly excluded from examination by dev instruction.
- **Wallet/client-side implementation** (wallet-kernel SDK, CLI parsers, BatchingUtility usage) — surveyed as integration expectations only; not a build target.
- **CIP-0103 dApp-API flows** — noted as the AllocationRequest-eliding optimization and V1-wallet escape hatch; not researched in depth.
- **CIP-0086 middleware implementation** (ERC-20 API server, indexer) — positioned relative to the standard only; the allowance component is a possible later extension, not core.
- **Off-ledger HTTP server implementation** — the endpoint *contract* is in scope (the Daml side must support it); building the server is deferred to a design-stage decision.
- **Registry operations** (CNS registration mechanics, BFT deployment topology, Scan integration) — documented as operator obligations, not implemented.

## Dev Notes

*(dev to fill after review)*

## Open Questions

1. **V1-on-V2 confirmed as our compatibility direction?** TestTokenV2 does V1-on-V2; Amulet does V2-on-V1 for transfers. Recommendation is V1-on-V2, but Design should confirm against the SCU story.
2. **Account-policy set:** which named owner/provider policies ship as vetted defaults (owner-only basic / provider-custodial / joint-approval?), and is the generic state-machine machinery exposed underneath or deliberately withheld?
3. **Pause mechanism:** the standard only standardizes off-ledger *reporting*. Does our reference implement on-ledger pause enforcement (guard at the update seam) with the off-ledger flag derived from it, and what is the defined pause × in-flight-instruction matrix?
4. **Allowance extension (CIP-0086-style `AllowanceContract`):** in the v1 extension catalogue or deferred? (Native position: allocations are the primitive.)
5. **Iterated settlement + committed allocations:** full support in the core, or a documented profile (e.g., Amulet supports them; a minimal registry might not)? The 25-leg/50-account/100-party minimum is mandatory either way.
6. **Off-ledger server scope:** ship a reference HTTP server (even skeleton/OpenAPI-generated), or Daml + specification only?
7. **Toolchain alignment:** upstream V2 packages build with SDK 3.5.2 / protocol 35 (alpha); this repository baselines Daml 3.4/Canton 3.4.11. What do we pin, and does the V2 DevNet matter for our validation story?
8. **Conformance suite packaging:** how do consumers run "behaves-like-CIP-0112" against their fork given Daml Script test code must currently be vendored as source across SDKs (splice TODO #594)?
