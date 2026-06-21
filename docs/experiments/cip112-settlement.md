# CIP-0112 Settlement Scoping Experiment

Status: experimental, non-public, and outside the committed M1 library surface.

Root `PLAN.md` refers to "CIP-112"; the upstream Canton Foundation repository
spells the proposal as **CIP-0112**. This note uses CIP-0112 when referring to
the source proposal and CIP-112 when referring to the local root-plan slice.

Source evidence:

- CIP text: `canton-foundation/cips`, `main` commit
  `24b121264fcb473399e3d40615dabff915371ba5`,
  `cip-0112/cip-0112.md`.
- Daml API preview: `canton-network/splice`, branch
  `token-standard-v2-daml-preview`, commit
  `b91de5d4b910ded598151981654dce2acc6f84ba`.
- Local prior evidence:
  `/Users/x/cantonator/canton-token-template/docs/CIP-0112-EXTENSION-PLAN.md`.

The CIP text is approved, but the local package added by this slice is still an
experiment. `canton-contracts` has no stability ADR for this surface, so the
primitive is not a stable public API.

## What CIP-0112 Settles In M1

CIP-0112 is not an asset-free generic settlement DSL. It is Token Standard V2:
an evolution of CIP-0056 that adds account-aware holdings, allocation requests,
allocation instructions, allocations, settlement factories, transfer-leg sides,
event-log reporting, committed allocations, and iterated settlement.

Recommended v1 direction:

- Build toward a **Token Standard V2 interface-aligned settlement primitive**.
- Do not build a proprietary minimal token underneath as the M1 target.
- Do not treat CIP-56 as the active foundation; use it only as migration and
  compatibility evidence per root `PLAN.md`.
- Use toy holdings only as test witnesses until the accepted Token Standard V2
  DAR/import boundary and license boundary are settled.

Tradeoffs:

- Interface-aligned settlement preserves wallet/app/asset interoperability and
  follows the approved CIP-0112 account/allocation model. It also lets CIP-86,
  CIP-103, and CIP-104 interoperate with the settlement surface rather than a
  local token.
- A minimal token underneath would make local tests easier, but would recreate a
  CIP-56-like target that root `PLAN.md` explicitly superseded and would risk a
  non-standard settlement surface.
- Importing the Splice preview packages directly would reduce local type drift,
  but it would prematurely couple `canton-contracts` to a branch/DAR and
  licensing boundary before the repo-required ADR exists.

## Proposed Lifecycle

The proposed M1 lifecycle should follow the CIP-0112 V2 settlement flow:

1. **Instruction / request.** A settlement app or executor creates one or more
   `AllocationRequest`s for the authorizer accounts that must allocate funds or
   receipt authority. Requests can be split by authorizer to preserve privacy.
2. **Allocation instruction.** A wallet or account authority calls an
   `AllocationFactory`-style entrypoint to create an `AllocationInstruction` or
   directly create an `Allocation`.
3. **Lock / hold.** Allocation acceptance archives or reserves input holdings
   and creates locked backing state. Locked state must be visible to the
   affected account parties, the asset admin, and settlement executors required
   to settle or cancel.
4. **Settlement.** `SettlementFactory_SettleBatch` settles a batch for one asset
   admin and a shared `SettlementInfo`. The transfer legs must be authorized by
   matching sender and receiver `TransferLegSide`s across fetched allocation
   contracts or settlement receipts created earlier in the same batch sequence.
5. **Cancellation / failure.** Executors can cancel allocations to release
   locked funds; authorizers can withdraw uncommitted allocations. Committed
   allocations cannot be withdrawn before the settlement deadline.
6. **Atomicity.** Batch settlement should be one Daml transaction. Any failed
   leg, missing authorization side, expired settlement, missing required D1
   hook reference, or unresolved D2 in-flight hook must roll back the whole
   transaction. The direct `Allocation_Settle` choice is narrower: it proves
   that matching peer authorization exists through fetched peer allocations or
   prior receipts, then archives only the local allocation's locked holdings. It
   is not full direct delivery-versus-payment co-settlement.
7. **Privacy.** Visibility should stay per account, asset admin, and executor.
   Full settlement visibility belongs to the settlement app/executor; individual
   account parties should not see unrelated counterparties or legs unless the
   app intentionally discloses them. Release-quality reporting should use
   CIP-0112 `EventLog_HoldingsChange`, not broad observer expansion.

## D1 Compliance Extension

Root `PLAN.md` records D1 as no-cache, fail-closed, node-side. It also leaves
the implementation clarification open: whether the contract remains oblivious or
checks a signed node attestation/reference at exercise time.

The experimental package therefore exposes only an optional `D1ComplianceHook`
and a per-settlement `d1ComplianceRef` reference. If the optional hook requires
a reference, settlement fails when no reference is supplied. The package does
not verify KYC, sanctions, validator service output, cryptographic signatures,
or production node attestations.

Upgrade-safe rule:

- Keep the baseline settlement choice stable.
- If D1 later requires typed node-attestation fields, add them via optional
  appended fields and/or new choices, following the SCU pattern from
  `identity-hook-upgrade.md`.
- If D1 later confirms the contract must remain oblivious, remove or ignore the
  hook before any public API is proposed.

## D2 Seizure / In-Flight Extension

Root `PLAN.md` records D2 as custodian-routed seizure: seized funds route to a
deployer-configurable third-party destination, not burn and not
return-to-sender. S1 reopened the in-flight handling question for M1 because
settlement makes in-flight funds first-class.

The experimental package therefore carries an optional `D2SeizureHook` with a
custodian destination and an explicit `inFlightHandlingStatus`. Marking an
allocation with this hook blocks settlement with
`Cip112Settlement: D2 in-flight seizure handling unresolved`.

This is deliberate. The scaffold records where D2 attaches, but it does not
choose between wait-to-settle-then-reallocate, burn-as-last-resort containment,
or any other in-flight policy. Those remain Phase 1/Phase 2 blockers before a
stable settlement primitive can land.

## Upgrade And Migration Assumptions

Reuse the SCU pattern from the identity-hook upgrade evidence:

- Do not mutate an existing public choice to require new fields.
- Add optional fields to records/templates for extension state.
- Add new choices for typed behavior once final semantics are accepted.
- Keep old choices usable for old contracts when a behavior is additive.
- Treat changing a required choice argument as the breaking boundary.

For this slice, `originalRequestCid`, `originalInstructionCid`, and
`originalAllocationCid` mirror CIP-0112 correlation fields. The local
`Reference.cidText` is only a standalone-package compromise; the CIP source uses
an optional contract-id reference.

## Experimental Scaffold

Package: `experiments/cip112-settlement`

Module: `OpenZeppelin.Experimental.Settlement.Cip112`

Templates:

- `ToyHolding`: local witness for account-aware holdings and locks.
- `SettlementFactory`: request, instruction, and batch-settlement entrypoint.
- `AllocationRequest`: app/executor request to an authorizer account.
- `AllocationInstruction`: wallet/authorizer instruction that locks holdings.
- `Allocation`: ready-to-settle allocation with D1 and D2 extension points.
- `SettlementReceipt`: experiment-only receipt. Release-quality reporting
  should use CIP-0112 `EventLog_HoldingsChange`.

The direct `Allocation_Settle` choice does not accept caller-asserted peer
transfer-leg sides. Peer sides must come from fetched `Allocation` contracts or
from fetched `SettlementReceipt` contracts produced earlier in a sequential
batch. This is still an experimental proof shape, but it removes fabricated
off-ledger peer sides from the direct path. It proves authorization existence,
not atomic peer consumption. If promotion requires direct-path atomic
co-settlement, `Allocation_Settle` must consume or settle the referenced peer
allocations as part of the same transaction, or the batch entrypoint must remain
the sole settlement path.

Test coverage:

- request -> instruction -> lock -> two-sided batch settlement;
- missing required D1 reference fails closed;
- direct single-side settlement without peer allocation context fails;
- direct settlement with a fetched peer allocation authorization proof succeeds;
- iterated settlement with `nextIterationFunding` and extra local sides
  succeeds;
- transfer-leg/allocation-side mismatch fails;
- expired settlement fails;
- input-holding instrument mismatch fails before lock;
- committed withdraw before settlement deadline fails;
- wrong-actor cancel fails;
- wrong-actor withdraw fails;
- executor cancellation unlocks a locked holding;
- D2 in-flight seizure marker blocks settlement until the in-flight policy is
  resolved.

## Non-Goals

This experiment does not implement:

- production KYC, sanctions, validator, custody, bridge, relayer, or oracle
  services;
- production Token Standard V2 DAR vendoring;
- a stable public `canton-contracts` API;
- CIP-0112 conformance;
- RI-specific business logic;
- D4 multi-sig resolution.

## Teardown Checklist

Removing this experiment later requires:

- deleting `experiments/cip112-settlement`;
- removing its entry from `multi-package.yaml`;
- removing its DAR from `test/daml.yaml`;
- deleting `test/daml/OpenZeppelin/Test/Cip112Settlement.daml`;
- deleting this note or replacing it with the accepted ADR / design note.
