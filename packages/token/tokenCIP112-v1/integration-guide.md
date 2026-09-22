# Integration guide

How to deploy `openzeppelin-tokenCIP112-v1` across participants and drive it
from wallets and settlement apps. Adoption basics — build, dependency, module
imports — are in [`README.md`](README.md).

## Topology

Three roles interact with the package:

- The **registry operator** hosts the `admin` party. Its participant uploads
  the vendored Token Standard V2 DARs from
  [`dars/vendor/`](../../../dars/vendor/) first, then the package DAR. The
  operator creates one `TokenRules` contract per registry configuration and
  serves it to consumers by explicit disclosure.
- **Wallet users** hold accounts. Their participants upload the same DARs.
  A user's wallet needs the disclosed `TokenRules` contract in every
  submission that exercises a factory choice; holdings, instructions, and
  allocations are visible to the user directly as a stakeholder.
- **Settlement apps** host executor parties. They receive allocations as
  contract observers and drive `SettlementFactory_SettleBatch` with the
  executors as actors.

Every participant needs the identical vendored DARs: the package IDs are pinned
by [`dars/manifest.yaml`](../../../dars/manifest.yaml) and change when upstream
cuts a release.

## Patterns

### Launching a registry and minting

The operator creates `TokenRules` and issues supply with `TokenRules_Mint`,
which requires the admin and the receiving account's parties as controllers.
The example package `examples/tokenCIP112/trading` runs this under `dpm test`.

Authorization: the admin signs the rules contract; admin plus account parties
control mint and burn.

### Two-step and one-step transfers

A sender exercises `TransferFactory_Transfer` with their account parties as
actors. When the actors also cover the receiver's account parties — including
any self-transfer — the transfer completes in one step; otherwise a
`TokenTransferInstruction` is created and the receiver accepts, rejects, or
lets it expire. `examples/tokenCIP112/trading` and the test scripts
`testTransferOneStep`, `testTransferTwoStep`, and
`testTransferRejectAndWithdraw` cover the paths.

Authorization: sender parties initiate; receiver parties accept or reject;
sender parties withdraw; the admin expires after the instruction's storage
bound.

### Delivery-versus-payment settlement

Each trader allocates their side of the legs through
`AllocationFactory_Allocate`; the settlement app settles all allocations in
one transaction through `SettlementFactory_SettleBatch`, which checks that the
batch's legs are covered exactly. `examples/tokenCIP112/trading` runs a full
DvP.

Authorization: each authorizer's account parties allocate; the executors alone
settle the batch.

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
`SettlementFactory`, and `TransferEventsV2.EventLog`, against the vendored
devnet-stage DARs.

Conformance notes:

- Allocation is synchronous: `AllocationFactory_Allocate` returns
  `AllocationInstructionResult_Completed`; no pending allocation-instruction
  state exists. Wallets must still handle all result variants.
- Token Standard V1 interfaces are not implemented, so V1-only tooling cannot
  see this token (see the README's "Standards conformance").
- Lock shape is restricted: locks always carry a finite `expiresAt` and never
  `expiresAfter`; holdings with `expiresAfter` locks are rejected at creation.
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
| Reading `availableActions` as "exercisable now" | A committed allocation advertises withdraw that still fails before the deadline | Treat the map as the actor sets; check the deadline separately |
