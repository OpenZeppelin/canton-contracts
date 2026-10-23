# Integration guide

How to deploy `openzeppelin-token-cip112-v1`, together with the
`openzeppelin-token-cip112-types-v1` and `openzeppelin-token-cip112-utils`
packages it depends on, across participants and drive it from wallets and
settlement apps. Adoption basics — build, dependency, module
imports — are in [`README.md`](README.md).

## Topology

Three roles interact with the package:

- The **registry operator** hosts the `admin` party. Its participant uploads
  the Token Standard V2 DARs from [`dars/vendor/`](../../../dars/vendor/)
  first (a participant that already runs Splice has these exact packages),
  then the types, utils, and package DARs. The operator creates one
  `TokenRules` contract per registry configuration and serves it to
  consumers by explicit disclosure.
- **Wallet users** hold accounts. Their participants upload the same DARs.
  A user's wallet needs the disclosed `TokenRules` contract in every
  submission that exercises a factory choice; holdings, instructions, and
  allocations are visible to the user directly as a stakeholder.
- **Settlement apps** host executor parties. They receive allocations as
  contract observers and drive `SettlementFactory_SettleBatch` with the
  executors as actors.

Every participant needs these exact packages.
[`dars/manifest.yaml`](../../../dars/manifest.yaml) records their package IDs,
which are those of the Splice release artifacts, so a participant that has
vetted Splice's Token Standard V2 packages can vet this package alongside them.

## Patterns

### Launching a registry and minting

The operator creates `TokenRules` and issues supply with
`TokenRules_OfferMint`, which creates a pending transfer instruction from the
CIP-0112 mint account to the receiving account. The receiver's wallet accepts
it with `TransferInstruction_Accept`, which creates the holding and emits an
event naming `cip-112/mint` as the other side. The admin and the receiver
submit separately, each from their own participant. The example package
`examples/token/token-cip112-trading-test` runs this under `dpm test`.

Authorization: the admin signs the rules contract and alone offers a mint;
the receiver's account parties accept or reject the offer; the admin
withdraws it, or expires it after `executeBefore`.

### Burning

A holder burns by exercising `TransferFactory_Transfer` with the CIP-0112 burn
account (`cip-112/burn`) as the receiver. The burn account's only account
party is the admin, so the holder's submission creates a pending burn request
that locks the amount, and the admin accepts it from their own participant.
Accepting archives the locked amount and emits an event, on the holder's
account, naming `cip-112/burn` as the other side. When the holder and the
admin act together, the burn completes in one step. The test scripts
`testBurnRequestAccepted` and `testBurnOneStep` cover both paths.

Authorization: the holder's account parties request and withdraw; the admin
accepts or rejects, or expires the request after `executeBefore`.

### Two-step and one-step transfers

A sender exercises `TransferFactory_Transfer` with their account parties as
actors. When the actors also cover the receiver's account parties — including
any self-transfer — the transfer completes in one step; otherwise a
`TokenTransferInstruction` is created and the receiver accepts, rejects, or
lets it expire. `examples/token/token-cip112-trading-test` and the test scripts
`testTransferOneStep`, `testTransferTwoStep`, and
`testTransferRejectAndWithdraw` cover the paths.

Authorization: sender parties initiate; receiver parties accept or reject;
sender parties withdraw; the admin expires after the instruction's storage
bound.

### Delivery-versus-payment settlement

Each trader allocates their side of the legs through
`AllocationFactory_Allocate`; the settlement app settles all allocations in
one transaction through `SettlementFactory_SettleBatch`, which checks that the
batch's legs are covered exactly. `examples/token/token-cip112-trading-test` runs a full
DvP.

Authorization: each authorizer's account parties allocate; the executors alone
settle the batch.

### Delivery-versus-mint and delivery-versus-burn

The admin allocates the supply side of a trade from a CIP-0112 special
account: sender sides from `cip-112/mint` to issue, or receiver sides to
`cip-112/burn` to redeem. That allocation locks nothing. The counterparties
allocate their sides as in a DvP, and `SettlementFactory_SettleBatch` creates
the minted holdings or archives the burned ones in the same transaction as the
payment. The test scripts `testDeliveryVsMint` and `testDeliveryVsBurn` cover
both directions.

Authorization: the admin alone allocates for a special account, with
`actors = [admin]`; the executors settle the batch.

### Iterated settlement

An allocation created with `nextIterationFunding` set lets the executors bring
new legs each settlement round against a locked reserve, rolling the remainder
into a successor allocation. `testIteratedSettlementLifecycle` runs a
two-iteration chain; the trading example's deposit flow shows the consumer
shape.

Authorization: as DvP, per iteration; the authorizer withdraws the current
successor to exit.

## Token Standard

The package implements CIP-0112 / Token Standard V2: `HoldingV2.Holding`,
`TransferInstructionV2.TransferFactory` and `TransferInstruction`,
`AllocationInstructionV2.AllocationFactory`, `AllocationV2.Allocation` and
`SettlementFactory`, and `TransferEventsV2.EventLog`, against the official
Splice release DARs vendored under [`dars/vendor/`](../../../dars/vendor/).

Conformance notes:

- Allocation is synchronous: `AllocationFactory_Allocate` returns
  `AllocationInstructionResult_Completed`; no pending allocation-instruction
  state exists. Wallets must still handle all result variants.
- Token Standard V1 interfaces are not implemented, so V1-only tooling cannot
  see this token (see the README's "Standards conformance").
- Lock shape is restricted: locks always carry a finite `expiresAt` and never
  `expiresAfter`; holdings with `expiresAfter` locks are rejected at creation.
- A completed transfer reports `transferLegId = ""` on both sides, as Splice's
  own `logTransfer` does: the standard paths complete one transfer per
  choice. Leg ids are therefore unique within one choice, not across
  commands submitted together in one transaction. A parser that meets
  several sides under one id in a transaction pairs them by the leg id
  together with the accounts, instrument, and amount each side names.
- The standard's off-ledger halves — factory discovery, instrument metadata,
  pause reporting — are deployment infrastructure outside this package. The
  trading example substitutes explicit disclosure for discovery.

The registry party model is a single `admin` party per instrument namespace:
it signs the rules contract, co-signs every holding, and controls supply and
cleanup.

## Common mistakes

| Mistake | What happens | Fix |
|---|---|---|
| Submitting a factory exercise without the disclosed `TokenRules` contract | The submission fails to resolve the contract | Attach the disclosure to every factory submission |
| Holding a `ContractId TokenHolding` across a balance change | The client holds a stale id and the next exercise fails | Re-query holdings after every transfer, allocation, or settle |
| Funding one transfer with holdings of different instruments | `executeTransfer` fails: input holdings must all match the transfer's instrument | Split by instrument; only allocations take multi-instrument inputs |
| Enabling iterated settlement with a zero reserve entry | Allocation is refused: reserve amounts must be positive | Use `Some TextMap.empty` for "iterated, no reserve" |
| Passing `extraTransferLegSides` or `nextIterationFunding` when settling a non-iterated allocation | The settle fails | Reserve iteration arguments for allocations created with `nextIterationFunding` set |
| Creating a committed allocation without a settlement deadline | Refused at the factory and by the template | Set `settlementDeadline`; commitment ends at the deadline |
| Requesting a deadline or execution window beyond the registry's `maxTTL` | Refused outright, not truncated | Keep workflow deadlines within `maxTTL` of submission time |
| Expecting the admin to expire a live workflow | Expiry choices fail before the workflow deadline | Wait for `expiresAt`; only executors cancel early |
| Completing two transfers in one choice through `executeTransfer` with the same `legId` | Both transfers report the same leg id, which CIP-0112 forbids for different legs | Give each transfer completed in the choice a distinct `legId`, as the custom example's fee leg does with `fee` |
| Reading `availableActions` as "exercisable now" | A committed allocation advertises withdraw that still fails before the deadline | Treat the map as the actor sets; check the deadline separately |
