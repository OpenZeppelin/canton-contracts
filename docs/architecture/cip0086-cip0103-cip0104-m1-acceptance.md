# CIP-0086 / CIP-0103 / CIP-0104 M1 Acceptance Boundary

Status: accepted for Phase 2 acceptance-criteria planning. This is not a
public API stability, conformance, M1 acceptance, audit-readiness,
production-readiness, or release-readiness claim.

Date: 2026-06-18

Phase: Phase 2, Scope-Locked Library Foundation

Depends on:

- root `PLAN.md` Decision Log S1: M1 targets CIP-112 settlement instead of a
  standalone CIP-56 token foundation.
- root `PLAN.md` Decision Log S2: D2 in-flight seizure is lock-and-sweep to the
  admin-preset custodian destination; D4 is single-admin capability authority.
- [`cip0112-public-api-promotion-boundary.md`](./cip0112-public-api-promotion-boundary.md):
  Splice Token Standard V2 DAR import and public API stability remain gated.
- [`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md):
  current upstream package/release evidence is documented, but import and
  stability claims remain blocked.

## Context

CIP-0086, CIP-0103, and CIP-0104 remain in M1, but their acceptance criteria
are subordinate to the CIP-112 / Token Standard V2 settlement surface. They are
not independent M1 build targets and they do not revive CIP-56 as the active
library foundation.

The live M1 library target is:

1. CIP-112 / Token Standard V2 settlement primitives.
2. Settlement-leg compliance, seizure, authority, privacy, and upgrade seams.
3. Compatibility evidence showing how CIP-0086, CIP-0103, and CIP-0104
   interoperate with that settlement surface.

This note records what M1 must prove for those three CIPs before downstream
work treats them as accepted for the scoped library foundation.

## Source Evidence

Read-only prior workspace evidence used for this note:

- `/Users/x/canton/specs/cips/README.md`: frozen M1 CIP index with original
  commit-pinned titles and SHA-256 rows for CIP-0056, CIP-0086, CIP-0103,
  CIP-0104, and CIP-0112.
- canonical CIP text pin follows the sibling promotion ADR:
  `global-synchronizer-foundation/cips` `main` at
  `24b121264fcb473399e3d40615dabff915371ba5`.
- `/Users/x/excanton/CF/cips` at
  `67986a1ff820521ffd0dea92e32d8a49da340756`, clean worktree, was used only as
  a readable local checkout for the CIP text below; it is not the normative pin:
  - `cip-0086/cip-0086.md`
  - `cip-0103/cip-0103.md`
  - `cip-0104/cip-0104.md`
  - `cip-0112/cip-0112.md`

Local current-state evidence:

- root `PLAN.md`
- [`cip0112-public-api-promotion-boundary.md`](./cip0112-public-api-promotion-boundary.md)
- [`cip0112-m1-ri-spec.md`](./cip0112-m1-ri-spec.md)
- [`../experiments/cip112-settlement.md`](../experiments/cip112-settlement.md)
- `experiments/cip112-settlement/daml/OpenZeppelin/Experimental/Settlement/Cip112.daml`

## Decision

M1 acceptance for CIP-0086, CIP-0103, and CIP-0104 means scoped interoperability
with the CIP-112 settlement surface. It does not mean implementing or shipping
their full production systems.

The required M1 acceptance form is documentation and evidence until the
Token Standard V2 DAR/import gate lands:

- define the settlement-specific compatibility expectations;
- identify source pins, reference implementations, and unresolved external
  contacts needed for later validation;
- show which settlement lifecycle step each CIP touches;
- preserve D1/D2/D3/D4 boundaries without converting them into final public
  API semantics;
- keep all production middleware, wallet-provider, Scan, SV, custody, KYC,
  sanctions, bridge, relayer, validator, and reward-minting integrations out of
  scope.

## Shared M1 Acceptance Criteria

For all three CIPs, M1 acceptance requires:

- CIP-112 settlement remains the primary surface. CIP-56 is migration and
  compatibility evidence only.
- Token Standard V2 types come from upstream Splice API packages only after the
  promotion ADR's DAR/checksum/license/DPM/public-API gates land.
- The local `OpenZeppelin.Experimental.Settlement.Cip112` scaffold remains
  experimental-only and non-public.
- Stable/promotable candidate behavior is documented against the later facade
  over upstream Token Standard V2 imports, not against local stand-in records.
- Acceptance evidence names direct allocation settlement as an authorization
  proof path only. Atomic multi-allocation delivery-versus-payment must use
  `SettlementFactory_SettleBatch`.
- Third-party custodian credit separates D2 seizure authority from destination
  receipt authorization.
- Post-deadline seizure stays out of the M1 promotable surface unless a later
  ADR adds an explicit seizure-window field and lawful-process evidence model.
- SCU compatibility is preserved: add optional fields, metadata, or choices;
  do not mutate required public fields or existing choice arguments to add D1,
  D2, D3, or D4 behavior.
- D1 remains no-cache, fail-closed, node-side; this note does not choose
  contract-oblivious vs Daml-visible signed-node-attestation shape.
- D3 remains single-domain v1; the tech-ops one-pager is still required before
  downstream work cites D3 as fully closed.
- D4 is S2 single-admin capability authority for M1; on-ledger multi-sig and
  topology multi-hosted authority remain future extensions.

## CIP-0086 Acceptance Criteria

CIP-0086 is an ERC-20 middleware and distributed indexer proposal. Its source
text is framed around a concrete CIP-56/Canton Coin token and later
generalization. Under the S1 rescope, M1 does not implement that standalone
token target.

M1 accepts CIP-0086 only when the library docs and later tests show how an
ERC-20-style middleware/indexer can observe and command the Token Standard V2
settlement surface:

- map `transfer`, `transferFrom`, `approve`, `balanceOf`, `allowance`, and
  `totalSupply` expectations onto Token Standard V2 accounts, holdings,
  allocations, settlement receipts or `EventLog_HoldingsChange`, and any later
  approved allowance/delegation facade;
- distinguish full-visibility operation from scoped-visibility operation, and
  document which ERC-20 queries cannot be globally correct for a party lacking
  the relevant Canton projections;
- require ChainSafe source/contact/version alignment before any compatibility
  claim; the current M1 note is not a ChainSafe conformance result;
- treat indexer and middleware processes as out-of-repo integrations, with M1
  library evidence limited to event/reporting shape, privacy constraints,
  failure modes, and command-construction assumptions;
- ensure D1 fail-closed transfer validation is described as node-side and
  unavailable transfers return deterministic middleware errors without adding
  production KYC or sanctions services;
- ensure D2 lock-and-sweep allocations are represented as settlement failure or
  seizure-resolution states, not as ERC-20 burns or sender refunds;
- preserve D4 single-admin capability authority as the M1 seizure/mint/burn
  authority model and avoid implying production multi-sig.

Non-goals for M1:

- shipping an ERC-20 middleware server, distributed indexer, API gateway,
  database schema, deployment infrastructure, or hosted service;
- implementing a new ERC-20-compatible Daml token template as the M1 library
  foundation;
- claiming ChainSafe compatibility, ERC-20 conformance, MainNet availability,
  or TVL/adoption milestones.

## CIP-0103 Acceptance Criteria

CIP-0103 defines the wallet/dApp API surface for connecting, listing accounts,
signing messages, preparing/executing commands, proxying Ledger API reads, and
emitting transaction lifecycle events.

M1 accepts CIP-0103 only when settlement docs and later examples show how a
wallet or dApp can drive the CIP-112 lifecycle:

- use account discovery and primary-account selection to choose Token Standard
  V2 `Account` values for allocation requests and allocations;
- use `prepareExecute` to authorize allocation creation and, where appropriate,
  direct allocation commands for UI-driven flows;
- document the CIP-0112 V1-wallet compatibility path where a CIP-0103 signing
  flow may call the V2 allocation factory directly instead of persisting an
  `AllocationRequest`;
- surface `txChanged` lifecycle expectations for request, allocation,
  settlement, cancellation, withdrawal, D2 mark, and D2 sweep flows;
- map D1 fail-closed transfer blocking, D2 sweep-required state, post-deadline
  failure, and account-authorization failure to predictable wallet/dApp error
  handling;
- preserve Canton privacy by showing only the settlement info, transfer-leg
  sides, accounts, and counterparties the wallet must authorize;
- pin the accepted CIP-0103 / wallet-kernel / dApp SDK reference before any
  compatibility claim.

Non-goals for M1:

- shipping a wallet provider, browser extension, remote wallet gateway, SDK,
  custody service, signing provider, or hosted dApp;
- claiming CIP-0103 API conformance or wallet interoperability before a pinned
  reference implementation and validation harness exist;
- replacing persisted Token Standard V2 allocation requests with CIP-0103
  flows as the default settlement model.

## CIP-0104 Acceptance Criteria

CIP-0104 changes app rewards from marker contracts to traffic-based activity
records computed from sequencer and mediator data. It is relevant to M1 because
settlement workflows should be shaped so their confirming app-provider views
can be attributed without app-specific marker contracts.

M1 accepts CIP-0104 only when settlement docs and later examples show:

- which settlement transactions and views are expected to involve app provider
  parties as signatories, controllers, actors, or confirmers;
- how batch settlement, allocation creation, cancellation, and D2 sweep affect
  app-provider participation and traffic attribution assumptions;
- that M1 does not require `FeaturedAppActivityMarker` or `AppRewardCoupon`
  creation inside settlement contracts;
- how choice observers and privacy optimizations are expected to affect view
  count without changing settlement correctness;
- that app-reward computation is performed by network/SV/Scan infrastructure,
  not by `canton-contracts` templates;
- that LocalNet or DevNet reward previews, if later added, are evidence for
  transaction shape only and not a production reward claim.

Non-goals for M1:

- implementing Scan API extensions, SV automation, Amulet reward coupons,
  minting delegations, app-reward accounting, or traffic reimbursement logic;
- claiming traffic-reward eligibility, reward amount, or SV/tokenomics
  acceptance.

## Stable/Promotable Vs Experimental Surface

Stable/promotable candidate surface, after the DAR/import and public API gates:

- an OpenZeppelin facade over upstream Token Standard V2 settlement packages;
- `SettlementFactory_SettleBatch` as the stable atomic settlement route;
- Token Standard V2 reporting, preferably `EventLog_HoldingsChange`, as the
  observable route for wallets, dApps, and middleware/indexers;
- optional/additive extension points for D1 references or attestations, D2
  seizure state, D4 capability authority, and future D3 identity evidence.

Experimental-only surface:

- `OpenZeppelin.Experimental.Settlement.Cip112`;
- local copies of upstream-like Token Standard V2 records;
- `ToyHolding`, `SettlementReceipt`, `BurnerCapability`, `D1ComplianceHook`,
  `D2SeizureHook`, `Reference.cidText`, and the experiment feature flag;
- direct `Allocation_Settle` as a public DvP API;
- toy holding co-sign behavior as a production custodian-credit model.

## SCU And Upgrade Implications

CIP-0086, CIP-0103, and CIP-0104 acceptance evidence must not force unstable
fields into the future public settlement API. Later implementation should use
the same upgrade posture as the CIP-112 promotion ADR:

- add typed D1 node attestations as optional fields or new choices after the
  D1 attestation shape is decided;
- add lawful-process attestations, seizure-destination mutability, or explicit
  post-deadline seizure windows through optional fields or new choices;
- add future multi-sig or multi-hosted-party authority without changing the M1
  single-admin choice signatures;
- add CIP-0086 middleware/indexer metadata, CIP-0103 wallet-flow metadata, or
  CIP-0104 app-provider attribution metadata as optional/reporting surface, not
  as required baseline settlement fields.

## Residual Boundaries

- D1: no-cache, fail-closed, node-side is fixed, but the Daml-visible
  attestation shape is still open. This blocks final transfer-restriction API
  wording, not this acceptance rescope.
- D2: S2 lock-and-sweep to a preset admin-set custodian destination is fixed
  for M1. Destination mutability, lawful-process attestation, third-party
  custodian credit mechanics, and post-deadline seizure windows are additive
  promotion refinements.
- D3: single-domain v1 is accepted. The tech-ops one-pager still has to land
  before downstream work cites D3 as fully closed.
- D4: S2 single-admin capability authority is fixed for M1. Deployment-specific
  multi-sig review can happen later without reopening the M1 default.
- Splice DAR/import: no Splice DAR is imported, vendored, or treated as public
  API by this note. The current evidence-boundary result is
  [`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md);
  it does not close the import or public API gate.

## Acceptance Closeout

This note closes the Phase 2 acceptance-criteria re-scope at the documentation
boundary. It does not close:

- Splice Token Standard V2 DAR/import promotion;
- public API stability review;
- ChainSafe source/contact/version alignment;
- CIP-0103 reference implementation pin and validation harness;
- CIP-0104 LocalNet/Scan/SV reward evidence;
- D1 attestation-shape clarification;
- D3 tech-ops one-pager;
- M1 acceptance, audit readiness, production readiness, release readiness, or
  conformance.
