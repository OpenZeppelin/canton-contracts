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
  consumers by explicit disclosure. That is operator practice, not a ledger
  rule: the admin signs `TokenRules` alone, so it can create more at any
  time, and each one funds from and pays into the same holdings.
- **Wallet users** hold accounts. Their participants upload the same DARs.
  A user's wallet needs the disclosed `TokenRules` contract in every
  submission that exercises a factory choice, and the disclosed locked
  funding to accept or reject an incoming transfer. The user's own holdings,
  and the instructions and allocations the user takes part in, are visible
  to the user directly as a stakeholder. Open an account whose provider
  differs from its owner only when the provider commits to staying
  available, because every choice the owner takes for the account also
  needs the provider (see the
  [`README.md` security caveats](README.md#security-caveats)).
- **Settlement apps** host executor parties. They receive allocations as
  contract observers and drive `SettlementFactory_SettleBatch` with the
  executors as actors.

The admin is the only lock holder of locked funding, so only the admin and
the holding's account parties see a locked holding. The registry operator
serves locked holdings to receivers and executors by explicit disclosure, as
it serves `TokenRules`. A receiver's wallet attaches the holdings listed in
the instruction view's `transfer.inputHoldingCids` when it accepts or
rejects. A settlement app attaches the holdings listed in each allocation
view's `holdingCids` when it settles or cancels. A party that receives a
disclosed holding learns the sender's account, the amount, and the lock
context, and keeps that data. Serve each pending contract's funding only to
that contract's receiver account parties or settlement executors.

The receiver and the executors observe the pending contract itself. Until it
is archived, these parties must stay hosted, and every participant hosting
them must keep the packages below vetted. Otherwise every choice on the
pending contract fails, and the locked funds stay frozen until the lock
expires and the account parties recover them through
`TokenHolding_OwnerUnlock`. The
[`README.md` security caveats](README.md#security-caveats) describe who can
cause this and how long the funds stay frozen.

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

The receiver's account parties are controllers of a one-step transfer, so
they see the sender's consumed inputs and change holding. The sender's
account parties sign the instruction, so they see the receiver's new
holding when the receiver accepts. When the sender's balance must stay
private from the receiver, use a two-step transfer, or fund a one-step
transfer from a single holding of exactly the amount, which leaves no
change. Create that holding first, as
[Rebalancing holdings](#rebalancing-holdings) describes. Only the sender's
account parties and the admin see the rebalancing.

Authorization: sender parties initiate; receiver parties accept or reject;
sender parties withdraw; the admin expires after the instruction's storage
bound (see "Expiry and cleanup").

### Rebalancing holdings

A wallet merges small holdings or splits one into exact amounts in one of
two ways:

- **Through the holding's own choices.** A wallet that knows `TokenHolding`
  exercises `TokenHolding_Merge` on one holding, naming the others as
  `inputHoldingCids`, or `TokenHolding_Split` with the amounts to create,
  which must sum to the holding's amount. Each submission needs only the
  account's own holdings. Each emits one `EventLog_HoldingsChange` on the
  account with no transfer legs, naming every consumed and created holding.
- **Through a self-transfer.** `TransferFactory_Transfer` from an account to
  itself completes in one step: it consumes the inputs and creates one
  holding of the transfer amount, plus one of the change when the inputs
  exceed it. A wallet that uses only the `HoldingV2.Holding` interface
  rebalances this way. The event carries a sender and a receiver leg on the
  same account.

Authorization: the account parties alone, on both paths.

### Retrying a transfer

An accept of the old instruction can commit after `executeBefore` by record
time, as the [`README.md` security caveats](README.md#security-caveats)
describe, so a wallet that re-instructs a transfer withdraws the old
instruction with `TransferInstruction_Withdraw`. When other holdings fund the
new transfer, the wallet submits the withdraw and the new
`TransferFactory_Transfer` as one transaction. Otherwise it re-instructs with
the holdings the withdraw returns. When the withdraw fails because the
instruction is archived, the wallet re-instructs unless the transaction that
archived it is an accept. When the withdraw fails because the receiver is
not hosted with the packages vetted, the wallet re-instructs only after
`TokenHolding_OwnerUnlock` or the admin's `TokenHolding_AdminUnlock` releases
the funding, after which an accept of the old instruction fails.

The admin replaces a mint offer by withdrawing it in the same transaction
as the new `TokenRules_OfferMint`. An authorizer replaces a live allocation
for the same `settlement` by withdrawing it in the same transaction as the
new `AllocationFactory_Allocate`.
[Retrying an allocation](#retrying-an-allocation) covers a retry after an
allocate whose outcome the wallet does not know.

Authorization: sender parties withdraw and re-instruct; the admin withdraws
and re-offers a mint; the authorizer's account parties withdraw and
allocate.

### Delivery-versus-payment settlement

Each trader allocates their side of the legs through
`AllocationFactory_Allocate`; the settlement app settles all allocations in
one transaction through `SettlementFactory_SettleBatch`, which checks that the
batch's legs are covered exactly. `examples/token/token-cip112-trading-test` runs a full
DvP.

Every allocation in the batch, with or without a settlement deadline, must be
settled before its `expiresAt`. One allocation at or past its `expiresAt`
fails the settlement of every authorizer in the batch. Before submitting,
drop each trade with an expired allocation, legs included, or ask that
allocation's authorizer for a new allocation.

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

### Retrying an allocation

Each `AllocationFactory_Allocate` creates an allocation and locks its funding,
even when the authorizer already has a live allocation for the same
`settlement`. The authorizer can withdraw an uncommitted duplicate at any
time, and a committed one only after the settlement deadline. The executors
can cancel either at any time.

A retry that names any of the same `inputHoldingCids` fails once the first
allocate has archived them. A retry that selects other holdings locks the
funds again unless
[command deduplication](https://docs.canton.network/appdev/deep-dives/command-deduplication)
rejects it. A wallet must retry an allocate like any other Canton command:
with the same command ID, user ID, and `actAs` parties, through the same
participant. Deduplication holds only within the deduplication period. After
that period, the wallet must search the authorizer's transactions since the
first submission for an allocation with the same `settlement` and
`transferLegSides`, settled or not, and retry only when it finds none.

### Iterated settlement

An allocation created with `nextIterationFunding` set lets the executors bring
new legs each settlement round against a locked reserve, rolling the remainder
into a successor allocation. `testIteratedSettlementLifecycle` runs a
two-iteration chain; the trading example's deposit flow shows the consumer
shape. Each successor can be settled until its own `expiresAt`.

Authorization: as DvP, per iteration; the authorizer withdraws the current
successor to exit.

### Expiry and cleanup

The registry operator's automation ends stale workflow contracts once their
`expiresAt` has passed. Transfer instructions end through
`TokenRules_ExpireTransferInstructions`, with one
`TokenTransferInstruction_Expire` argument per instruction. Allocations end
through `TokenRules_ExpireAllocations`, with one `Allocation_Cancel` argument
per allocation and `actors = [admin]`. Each argument carries its own
`extraArgs`, whose choice context may hold the `expire-lock` flag (this key
has the same function as in Splice):

- A missing flag, or `AV_Bool True`, releases the funding to its account
  and emits the `EventLog_HoldingsChange` that wallets track returned funds
  by. Use it by default: it fails, rolling back the whole batch, if the
  funding is already gone.
- `AV_Bool False` clears the flag. The expiry then leaves the locked holdings
  untouched, emits nothing, and fails before `lockExpiresAt`. Use it only
  for a contract whose funding is already unlocked or spent.

The ledger cannot check that the funding is gone, so the automation must
look before it clears a flag. The flag covers every locked holding of the
contract, and an allocation locks one holding per instrument, so the
automation checks each of them. If the owner reclaimed only some of them,
the admin returns the rest with `TokenHolding_AdminUnlock` and then clears
the flag. A flag cleared while a holding is still locked ends the contract
and leaves that holding locked; the admin returns it with
`TokenHolding_AdminUnlock`, without the account's provider. For
allocations, the flag is read only when the actors are exactly `[admin]`,
including when the admin is the allocation's only executor. A cancel by any
other actor set releases the funding.

Authorization: the admin alone expires, clears flags, and runs the admin
unlock; the executors cancel an allocation at any time.

### Policy at delivery

`TokenRules` adds no policy. A policy in a consumer's own rules template,
such as a pause, binds after creation only when the consumer's pending
templates check it again on accept and settle. Before calling the utils
body, the choice:

1. Reads the rules contract id from `extraArgs.context`, under a key the
   registry documents, and fails if the entry is missing or is not a
   contract id. The submitter attaches the rules contract by explicit
   disclosure, as for a factory call.
2. Fetches it as the consumer's own rules template, not through an
   interface, so a contract of another template is refused.
3. Checks that its admin is the pending contract's admin, and that every
   other party meant to bind the admin, such as a pauser that co-signs the
   rules contract, is the party the pending contract records. The submitter
   chooses the id. Without the admin check, a rules contract of any party
   passes. Without the co-signer check, one the admin signed alone passes.
4. Applies the policy to the fetched contract.

Archive the rules contract in every choice that changes the policy, so a
fetch of an id from before the change fails. Any live rules contract that
the admin and the co-signers signed passes, so the policy holds at delivery
only while each such contract applies it. A batch settlement builds each
`Allocation_Settle`'s context through the selector passed to
`settleBatchImpl`, which can forward the factory's own id. Reject, withdraw,
cancel, and expiry return funds to their owner and need no check.
`examples/token/token-cip112-custom` checks its pause this way, with its
pauser as the co-signer.

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
- The standard tells senders they can
  [retry after `executeBefore`](https://github.com/canton-network/splice/blob/8460154135f39019b8bb370c9c1321ff13c9bb10/token-standard/splice-api-token-transfer-instruction-v2/daml/Splice/Api/Token/TransferInstructionV2.daml#L26-L31).
  A wallet for this token withdraws the old instruction first, as
  [Retrying a transfer](#retrying-a-transfer) describes.
- The standard's off-ledger halves are deployment infrastructure outside
  this package: factory discovery, instrument metadata, pause reporting, and
  serving the funding disclosures that receivers and executors attach to
  accept, reject, settle, and cancel. The trading example stands in for
  discovery and for the funding service: it queries the rules contract and
  the funding as the admin and attaches them as explicit disclosures.

The registry party model is a single `admin` party per instrument namespace:
it signs the rules contract, co-signs every holding, and controls supply and
cleanup.

## Common mistakes

| Mistake | What happens | Fix |
|---|---|---|
| Submitting a factory exercise without the disclosed `TokenRules` contract | The submission fails to resolve the contract | Attach the disclosure to every factory submission |
| Accepting or rejecting a transfer, or settling or cancelling an allocation, without its locked funding disclosed | The submission fails to resolve the locked holding | Attach the holdings the registry serves for the instruction view's `transfer.inputHoldingCids` or the allocation view's `holdingCids` |
| Holding a `ContractId TokenHolding` across a balance change | The client holds a stale id and the next exercise fails | Re-query holdings after every transfer, allocation, or settle |
| Funding one transfer with holdings of different instruments | `executeTransfer` fails: input holdings must all match the transfer's instrument | Split by instrument; only allocations take multi-instrument inputs |
| Exercising `TokenHolding_Merge` or `TokenHolding_Split` on a holding whose lock has expired | Refused: holding is locked | Pass it as an input of a merge on an unlocked holding, or release it with `TokenHolding_OwnerUnlock` first |
| Enabling iterated settlement with a zero reserve entry | Allocation is refused: reserve amounts must be positive | Use `Some TextMap.empty` for "iterated, no reserve" |
| Passing `extraTransferLegSides` or `nextIterationFunding` when settling a non-iterated allocation | The settle fails | Reserve iteration arguments for allocations created with `nextIterationFunding` set |
| Creating a committed allocation without a settlement deadline | Refused at the factory and by the template | Set `settlementDeadline`; commitment ends at the deadline |
| Requesting a deadline or execution window beyond the registry's `maxTTL` | Refused outright, not truncated | Keep `executeBefore` within `maxTTL` of ledger time, and a settlement deadline within `maxTTL` of the allocation's `requestedAt` |
| Backdating an allocation's `requestedAt` | Without a deadline, `expiresAt` is `requestedAt + maxTTL`, so the allocation expires early. A deadline later than `requestedAt + maxTTL` is refused | Set `requestedAt` to the time the wallet prepares the request |
| Expecting the admin to expire a live workflow | Expiry choices fail before the workflow deadline | Wait for `expiresAt`; only executors cancel early |
| Clearing the `expire-lock` flag on every contract past `lockExpiresAt` | A contract whose funding is still locked ends, and its holding stays locked | Clear the flag only after finding the locked holdings archived; return a holding left locked with `TokenHolding_AdminUnlock` |
| Running the default expiry after the owner unlocked or spent the funding | The expiry fails on the archived holding, and so does its whole batch | Expire that contract with `expire-lock` set to `AV_Bool False` |
| Reading `availableActions` as "exercisable now" | A committed allocation advertises withdraw that still fails before the deadline, and every allocation advertises settle that fails from `expiresAt` on | Treat the map as the actor sets; check the deadline and `expiresAt` separately |
| Reading `transferLegSides` or their `meta` in an `EventLog_HoldingsChange` as value movement | The reader records movements that never happened, such as a settlement whose legs net to zero | Derive value movement from the event's `inputHoldingCids` and `outputHoldingCids` only. Treat the event's `transferLegSides` and their `meta` as labels the submitters supplied |
