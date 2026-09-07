---
stage: code
project: openzeppelin-tokenCIP112-v1
mode: extension
extends: experiments/token/tokenCIP112-v1
status: draft
timestamp: 2026-09-03
author: ionut.gingu
previous_stage: null
tags: [cip-0112, iterated-settlement, allocation, token-standard-v2]
---

# Token CIP-0112 V1 — Iterated Settlement Code Draft

## Summary

Extension of `openzeppelin-tokenCIP112-v1` implementing CIP-0112 §4.3.6
iterated settlement, which the registry previously rejected outright. An
allocation whose `AllocationSpecification.nextIterationFunding` is set now
locks the reserve alongside any net leg funding; at settlement the executors
supply `extraTransferLegSides` and a fresh `nextIterationFunding` through
`FinalizedAllocation`, and the settle body reserves the requested funding as
freshly locked holdings backing a successor `TokenAllocation`, returned as
`AllocationResult_Settled.nextIterationAllocationCid`. A settle with
`nextIterationFunding = None` ends the chain and pays everything out unlocked.

No new templates or choices were added; `BatchSettlementAuthorization` gained
a `nextIterationFunding` field and `TokenAllocation` gained `numIterations`,
`maxTTL`, and `lockGrace` fields.

## Modules

| Module | Purpose | Change | Status |
|---|---|---|---|
| `OpenZeppelin.TokenCIP112V1.Allocation` | Allocation + settle internals | Iteration successor creation, proof binding extended | Draft |
| `OpenZeppelin.TokenCIP112V1.Registry` | Factories, allocate path | Reserve validation and locking, proof carries reservation | Draft |
| `OpenZeppelin.TokenCIP112V1Test` (test pkg) | Component tests | 3 new scripts + finalized-batch helpers | Draft |

## Invariant Enforcement Map

| Invariant | Enforcement Location | Mechanism |
|---|---|---|
| Iterated settlement only when the authorizer enabled it (spec `nextIterationFunding` set) | `Allocation.allocation_settleImpl` and the factory (`validateNextIterationArgs`, vendored) | `require` on extra legs / settle-arg funding, checked in both the factory and the settle body |
| Reserve amounts positive, keyed by instrument | `Registry.allocateImpl` (creation); `validateNextIterationArgs` (settlement) | `require'` per entry |
| Reserve draws on a regular account only | `TokenAllocation` ensure; `Registry.allocateImpl` | structural + `require` |
| Reserve is locked upfront like net leg funding | `Registry.allocateImpl` `requiredAmounts` | `textMapUnionWith (+)` of net debits and reserve |
| Per-iteration conservation: reserve ≤ locked funds + net credit, totals ≥ 0 | `Allocation.settleAllocation` | `require'` per instrument, fail closed |
| Settle runs only with the exact iteration arguments the batch cover check validated | `BatchSettlementAuthorization` + `requireBatchAuthorization` | admin-signed proof binds effective legs (base + extra) and the reservation |
| Extra legs are covered by the batch `transferLegs` exactly | vendored `fetchAndValidateAllocations` | exact-cover check over the adjusted view (base + extra) |
| Successor keeps deadline and commitment, clears legs, points at the original | `Allocation.settleAllocation` successor create | `create this with` field carry-over |
| Expiry bumps monotonically per iteration, lock outlives expiry by `lockGrace` | `Allocation.settleAllocation` | `computeStorageExpiry` on snapshotted `maxTTL`; template ensure `expiresAt < lockExpiresAt` |
| Every holdings change emits exactly one `EventLog_HoldingsChange` | `Allocation.settleAllocation` | one `emitHoldingsChange` covering consumed locks, new reserve locks, and unlocked payouts, with the effective leg sides |

## Implementation Notes

- **Registry config is snapshotted on the allocation** (`maxTTL`, `lockGrace`):
  settlement runs on the allocation contract without the registry contract in
  scope, so per-iteration expiry bumps use the configuration captured at
  allocation time. A registry reconfiguration therefore does not retroactively
  change live allocations' expiry behavior.
- **The batch proof now also binds the settle arguments**: the effective leg
  set compared by `requireBatchAuthorization` is `base ++ extraTransferLegSides`,
  and the proof carries the approved `nextIterationFunding`, so a settle can
  never run with iteration arguments the factory's cover check did not see.
- **`authorizerHoldingCids` reports only the unlocked payouts**; reserved
  holdings are visible through the successor allocation's view (`holdingCids`).
- **First-iteration mixed shape is supported** (nonempty `transferLegSides`
  plus a reserve), per the spec's "Registries MAY allow" clause; successors
  always have an empty leg set.
- **`Some TextMap.empty` enables iterated settlement with no reserve** (the
  incoming-transfers-only case); a zero-amount entry is rejected as a caller
  error at both allocation and settlement.
- `numIterations` is a template field surfaced in the view; `createdAt` and
  `requestedAt` stay pinned to the original allocation across iterations.

## Out of Scope

- Committed-allocation-specific iterated flows beyond field carry-over — the
  commitment flag is carried onto successors unchanged; no additional
  committed-specific validation was added because withdraw/cancel paths are
  shared with non-iterated allocations.
- V1 (`splice-api-token-allocation-v1`) dual-compatibility for iterated
  allocations — the package is V2-only, matching its existing scope.
- Top-up/merge flows (§4.3.6.1) — they compose from the implemented
  primitives (extra legs moving value between two allocations of the same
  authorizer) and need no additional code; no dedicated test was added in
  this pass.

## Dev Notes

Implemented in Full Build mode (autonomous session). The vendored
`splice-token-standard-utils` already performs batch-level validation
(`validateNextIterationArgs`, adjusted-view cover check), so the package-side
work concentrated on funding conservation, the successor lifecycle, and
binding the proof.

## Open Questions

- Should a dedicated top-up/merge test (§4.3.6.1) be added to pin the
  composition behavior?
- Should `expiresAt` for deadline-less iterated deposits be surfaced more
  prominently in wallet-facing docs (funds require re-deposit after `maxTTL`
  without activity)?
