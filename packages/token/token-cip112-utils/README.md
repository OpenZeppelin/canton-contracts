# Token CIP-0112 utils

The choice bodies of a CIP-0112 (Token Standard V2) registry as plain
functions, with every template decision left to the caller.

| Field | Value |
|---|---|
| Package | `openzeppelin-token-cip112-utils` |
| Public modules | `OpenZeppelin.Token.Cip112.Utils.Holding`, `.Transfer`, `.Allocation`, `.Registry` |
| Depends on | `openzeppelin-token-cip112-types-v1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `HoldingOps h`: the record a template owner builds inside a choice body
  with `createHolding`, three consumption operations, `withEventLog`, and
  `eventObservers` (extra informees of every holdings-change event, for
  auditors and regulators who must see the standard event stream). The
  consumption operations split by where the value goes: `fundHolding` for
  caller-supplied inputs, `deliverHolding` for locked funding paid out, and
  `returnHolding` for locked funding returned to its owner. Each receives the
  `ChoiceContext` of the choice the workflow runs in, and returns the
  consumed holding's view and its state `h`, usually the holding template.
  `createHolding` receives the new holding's sources (see
  [Holding state across re-creation](#holding-state-across-re-creation)).
  The record holds functions, so it is never stored.
- `holdingOpsFor @T`: a `HoldingOps T` whose three consumption operations
  are `consumeByArchive @T`, ready to override one operation with `with`.
- `consumeByArchive @T` and `pinAllocationTo @T`: the safe ways to write the
  consumption and allocation policies, pinned to one template.
  `consumeByArchive @T` returns the archived `T` as the state.
- `privateAssetAllocateExtraObservers`: the allocation factory's extra
  observers, which admit the settlement executors only to a call that needs
  no funding and names no input holdings.
- `isValid*` predicates for `ensure` clauses, and `transferInstructionView`
  and `allocationView` for interface views.
- `*Impl` functions for every interface method and template choice a registry
  needs: `transferFactoryImpl`, `transferAcceptImpl`, `allocationFactoryImpl`,
  `allocationSettleImpl`, `settleBatchImpl`, `offerMintImpl`, and the
  rest.
- `holdingOwnerUnlockImpl` and `holdingAdminUnlockImpl`: the bodies of a
  holding template's two unlock choices for an expired lock, one controlled
  by the account parties and one by the admin alone. A consumer holding
  template exposes both.
- `expireLockFromContext`: reads Splice's `expire-lock` flag from the choice
  context for `transferExpireImpl` and `allocationCancelImpl`. Set it to
  `AV_Bool False` only for a contract whose locked holdings are archived.
  A flag cleared earlier leaves them with their expired lock until the
  account parties spend or unlock them, or the admin unlock returns them.
- `holdingMergeImpl` and `holdingSplitImpl`: the bodies of consuming merge
  and split choices on a holding template, for account parties who
  rebalance without the registry.

The functions read and return the `RegistryConfig`,
`TransferInstructionState`, and `AllocationState` records of
`openzeppelin-token-cip112-types-v1`.

## Holding state across re-creation

The workflows consume holdings and create new ones in their place, building
each new holding through `createHolding` from its standard view and its
sources: the states of the holdings consumed in the same step whose value
funds it, all in its instrument, in the order the workflow consumed them.

| Path | Consumed through | New holdings and their sources |
|---|---|---|
| Transfer factory, including one-step transfers and burns | `fundHolding` | The sender's change, the locked funding, and a one-step receiver's holding, each from the inputs |
| Accept of a pending transfer | `deliverHolding` | The receiver's holding from the locked funding in the transfer's instrument, and the surplus in each instrument from that instrument's locked funding |
| Accept of a mint offer | Nothing | The minted holding, with no sources |
| Reject, withdraw, and expiry of a pending transfer | `returnHolding` | One returned holding per locked holding, each from the holding it replaces |
| Allocation factory | `fundHolding` | The locked funding and the change in each instrument, from that instrument's inputs |
| Settlement of an allocation | `deliverHolding` | The next-iteration reserve and the authorizer's payout in each instrument, from that instrument's locked funding; none for an instrument without locked funding |
| Withdraw, cancel, and expiry of an allocation | `returnHolding` | One returned holding per locked holding, each from the holding it replaces |
| Owner unlock and admin unlock | The unlock choice | The unlocked holding, from the exercised holding |
| Merge | The merge choice, and `fundHolding` for the inputs | The merged holding, from the exercised holding and then the inputs |
| Split | The split choice | Every part, from the exercised holding |

A template field outside the view keeps its value across re-creation only
when the closure derives it from the sources, and otherwise resets to the
closure's value. Every holding a factory, accept, or settlement creates in
one instrument receives the same sources, and the submitter picks the order
of a factory's inputs, so derive a field as the sources' most restrictive
value, such as the latest issue date, rather than the first source's or a
sum. The sources of a transfer receiver's holding are the sender's, so
compare each source's account with the new holding's to decide which fields
follow value between accounts. A settlement passes only the authorizer's
locked holdings, so state follows value through a transfer but not through
a settlement.

Keep a restriction that must hold while funds are in flight, such as a
compliance freeze, on a separate per-account contract. The `HoldingOps`
doc comment names the funds that a field on the holding misses.

## Compatibility

The package defines no templates, interfaces, exceptions, or serializable
types, so SCU ignores it. A consumer may move to any later version, switch to
a fork, or drop the dependency, because no contract payload references this
package. Versions follow semver, and the package name carries no `vN` suffix.

## Trust boundary

The workflows trust nothing they did not just create. Every caller-supplied
contract id enters through an operation the template owner wrote:

- `fundHolding`, `deliverHolding`, and `returnHolding` must each fail on any
  holding that is not an accepted implementation, and otherwise archive it
  and return its view and state. Use `holdingOpsFor @YourHolding`, or a
  custom spend choice reached through `fetchFromInterface @YourHolding`.
  Never archive a caller-supplied id by interface.
- A refusal in `deliverHolding` or `returnHolding` leaves the other
  operation's paths open, and a refusal in both holds the locked funds until
  the lock expires. After that the owner recovers them through the holding's
  owner-unlock choice or by passing the holding to a factory or to a merge
  choice as an input, both of which run `fundHolding`. Put a rule in
  `deliverHolding` or `returnHolding` only if a known party can lift it
  without re-creating the locked holding: pending instructions and
  allocations name their locked holdings by id, so they can neither pay out
  nor return a replaced holding. A rule that only limits new spending, such
  as a minimum holding age, belongs in `fundHolding`.
- A rule that tracks live registry state reads the current policy contract
  from the context and checks the contract it fetches. A value copied into
  the holding does not follow later registry changes, and a policy contract
  id stored in the holding fails every spend once the registry replaces that
  contract.
- Roles and policy on a rules contract restrict wallets only. The operations
  cannot tell which rules contract a holding came from: any check they make
  compares fields, and the admin can copy those fields into a contract it
  signs alone, such as a second rules contract without the first one's
  roles. A control that must bind the admin has to be held by a party that
  signs the holdings and the pending contracts. The operations must refuse a
  holding, and the `PinAllocation` an allocation, that names a different such
  party. `examples/token/token-cip112-custom` does this with its pauser.
- `settleBatchImpl` takes a selector that picks the part of the batch's
  choice context each `Allocation_Settle` receives, given the allocation's
  view. The batch metadata never reaches an allocation. A selector that
  forwards nothing, as `\_ _ -> emptyChoiceContext` does, makes a
  `deliverHolding` rule that requires a context entry refuse every batch
  settlement. `expireAllocationsImpl` cancels its allocations in one
  transaction, so one refusing `returnHolding` fails the whole batch.
- Each authorizer sees its own `Allocation_Settle` with that choice's
  arguments. The batch exercise, whose context may describe other
  authorizers' trades, stays with the factory's signatories and the
  executors only if `settlementFactory_settleBatchExtraObservers` is empty
  and the selector forwards only the entries for the view's
  `allocation.authorizer`. The vendored public-asset default makes every
  leg's account parties observers. An executor that is also an authorizer
  sees the whole batch.
- `holdingOwnerUnlockImpl` runs none of the consumption operations. A rule
  that must block an owner unlock, such as a freeze, is checked inside the
  holding's own owner-unlock choice. A rule that must hold funds after the
  lock expires also belongs in `fundHolding`, because `transferFactoryImpl`,
  `allocationFactoryImpl`, and `holdingMergeImpl` accept an input whose lock
  has expired.
- `holdingSplitImpl` runs none of the consumption operations either, and
  `holdingMergeImpl` runs `fundHolding` only on its inputs. Apply the
  template's own spend rules, such as a freeze, to the exercised holding
  inside its merge and split choices before calling the body. Otherwise the
  account parties can turn a frozen holding into unfrozen ones, because
  every holding these bodies create comes from `createHolding`.
- `holdingMergeImpl` checks each input's standard view only, and the merged
  holding takes its template fields from the `createHolding` closure. Refuse
  an input whose own fields differ from the exercised holding's, such as
  other roles, in the merge choice or in `fundHolding`. Otherwise the merge
  moves the input's value out from under those fields.
- Merge and split choices bypass the registry contract. Check a factory
  policy that must cover them, such as a pause, inside the holding's choice.
- The `PinAllocation` passed to `settleBatchImpl` and `expireAllocationsImpl`
  must fail on any allocation whose choice bodies the registry does not
  control. Use `pinAllocationTo @YourAllocation`.
- A choice that runs `expireAllocationsImpl`, or expires a batch of transfer
  instructions, must have no choice observers unless every party may see
  every account's holdings. A choice observer witnesses every expiry in the
  batch and every holding the expiries release. To show a party one account's
  holdings-change events, return the party from `eventObservers` for that
  account.
- `createHolding` must create a contract whose view equals the view
  argument and whose signatories include the admin and the account parties.
- The settlement factory must settle through `settleBatchImpl`, or keep its
  exact-cover check: every leg in the batch needs a sending and a receiving
  allocation with the same amount. Without it, a settlement can create
  tokens. No other choice may exercise `Allocation_Settle` with the admin's
  authority, because that skips the check.
- An allocation template's `allocation_settleImpl` must settle through
  `allocationSettleImpl`, or keep its checks of the actors, the settlement
  deadline, the allocation's `expiresAt`, and the iteration arguments.
  Without them, a settle can run after the allocation's `expiresAt`.
- A transfer instruction whose sender is the CIP-0112 mint account is a mint
  offer: `transferAcceptImpl` creates the receiver's holding without any
  locked funding. Only `offerMintImpl`, from a choice the admin alone
  controls, may create one. A factory body must refuse the mint account as a
  sender, as `transferFactoryImpl` does.

Each `EventLog_HoldingsChange` the workflows emit names the workflow in the
reason of its `extraArgs.meta`. A reader of the events, such as a wallet, an
indexer, or an auditor, must derive value movement from
`inputHoldingCids` and `outputHoldingCids` only, and must treat
`transferLegSides` and their `meta` as labels the submitters supplied.
Otherwise it records movements that never happened: an allocation whose legs
net to zero settles without consuming or creating a holding, and its event
names any instrument and amount the authorizer chose.

## Time bounds

No workflow reads the time with `getTime`. Every time check is a
ledger-time bound, which constrains the ledger time the participant picks
when the transaction executes instead of fixing it when the transaction is
prepared. An externally signed submission can therefore execute after the
ledger-time tolerance of its preparation while its bounds hold. Keep
`getTime` out of the choice bodies that call these functions and out of
their `HoldingOps`. Otherwise the submission must execute within the
ledger-time tolerance.

- A transfer, including a mint offer, needs `requestedAt` at or before
  ledger time and `executeBefore` after it. `executeBefore` may be at most
  `maxTTL` after ledger time and `requestedAt` at most `maxTTL` before it.
- An allocation's `expiresAt` is its settlement deadline, or `requestedAt`
  plus `maxTTL` without one, and must lie after ledger time. A deadline more
  than `maxTTL` after `requestedAt` is refused, so the lock never expires
  before the deadline.
- The authorizer's wallet chooses an allocation's `requestedAt`, at or
  before ledger time and less than `maxTTL` before it. `createdAt` equals
  `requestedAt`, so executors must not treat `createdAt` as the time the
  ledger created the allocation.
- A settlement that creates a successor moves `expiresAt` to the previous
  `expiresAt` plus the allocation's `maxTTL`, capped by the settlement
  deadline, and refuses a result that has already passed. A settlement
  without a successor sets no new bound.
- Without a settlement deadline, each settlement adds a full `maxTTL`, so
  the executors can push an iterated allocation's `expiresAt`, and its
  reserve's lock, well past `maxTTL` from ledger time by settling it
  repeatedly. The executors are trusted with the reserve, and an allocation
  without a deadline is never committed, so its authorizer can withdraw it
  and end the chain.
- A time computed from `maxTTL` or `lockGrace` saturates at the bounds of
  `Time`, which are `minBound` and `maxTime` (9999-12-31T23:59:59.999999Z).
  A check against a saturated `executeBefore - maxTTL` or
  `requestedAt + maxTTL` passes.
- A `lockExpiresAt` of `maxTime` never passes, so `holdingOwnerUnlockImpl`
  fails on the locked holding. An `expiresAt` of `maxTime` never passes
  either, so the admin can never expire the contract.
- A committed allocation must have a settlement deadline before `maxTime`,
  since one at `maxTime` would never let its authorizer withdraw it.

## Operational assumptions

`executeTransfer`, `allocationFactoryImpl`, and `allocationSettleImpl` name
the admin as the only lock holder of the funding they lock. When the holding
template's observers are its lock holders, as in `TokenHolding`, only the
admin and the account parties see that funding. The registry serves it to
receivers and executors by explicit disclosure. The owner's unlock after the
lock expires then involves only the holding's signatories, unless another
party observes the holding or the holdings-change event the unlock emits. A
workflow adds such a party when it names another lock holder, the holding
template when it adds an observer, and `eventObservers` when it returns a
party for the account. The unlock fails while any such party has no hosting
participant or a participant hosting it has not vetted the template
packages.

A template for transfer instructions or allocations can make the receiver or
the executors observers, as `TokenTransferInstruction` and `TokenAllocation`
do. Every choice on such a contract then needs those parties to stay hosted
and every participant hosting them to keep the template packages vetted. A
template owner that reuses these functions inherits these requirements and
must document them for its users.

`transferFactoryImpl`, `allocationFactoryImpl`, `transferAcceptImpl`,
`transferRejectImpl`, `transferWithdrawImpl`, and `allocationWithdrawImpl`
require every account party of the account they act for as an actor. A
template owner that reuses them inherits the provider dependency that the
[security caveats](../token-cip112-v1/README.md#security-caveats) of the
default templates describe.

`allocationFactoryImpl` creates an allocation and locks its funding on every
call, even when the authorizer already has a live allocation for the same
`settlement`. Wallets must retry an allocate as the
[integration guide](../token-cip112-v1/integration-guide.md#retrying-an-allocation)
describes.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/token/token-cip112-utils dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/token/token-cip112-types-v1/.daml/dist/openzeppelin-token-cip112-types-v1-0.1.0.dar
  - ../canton-contracts/packages/token/token-cip112-utils/.daml/dist/openzeppelin-token-cip112-utils-0.1.0.dar
```

```daml
import OpenZeppelin.Token.Cip112.TypesV1
import OpenZeppelin.Token.Cip112.Utils.Holding
```

The ready-to-use templates over these functions are
`openzeppelin-token-cip112-v1`. `examples/token/token-cip112-custom` is a
complete consumer that owns its templates and reuses these functions.

## License

Three modules contain code derived from Splice and modified by OpenZeppelin:

- `OpenZeppelin.Token.Cip112.Utils.Holding`, from
  `Splice.Testing.Tokens.TestTokenV2.Holding`,
  `Splice.Testing.Tokens.TestTokenV2.Allocation`, and
  `Splice.TokenStandard.Utils.Internal.Events`.
- `OpenZeppelin.Token.Cip112.Utils.Transfer`, from
  `Splice.Testing.Tokens.TestTokenV2.Transfer` and
  `Splice.TokenStandard.Utils.Internal.Events`.
- `OpenZeppelin.Token.Cip112.Utils.Allocation`, from
  `Splice.Testing.Tokens.TestTokenV2.Allocation`.

The `Splice.Testing.Tokens.TestTokenV2` modules are in the Splice
[TestTokenV2](https://github.com/canton-network/splice/tree/8460154135f39019b8bb370c9c1321ff13c9bb10/token-standard/examples/splice-test-token-v2)
example, and `Splice.TokenStandard.Utils.Internal.Events` is in the Splice
[`splice-token-standard-utils`](https://github.com/canton-network/splice/tree/8460154135f39019b8bb370c9c1321ff13c9bb10/token-standard/splice-token-standard-utils)
package. Both are Copyright (c) 2024 Digital Asset (Switzerland) GmbH and/or
its affiliates, licensed under the Apache License 2.0
([`LICENSES/Apache-2.0.txt`](../../../LICENSES/Apache-2.0.txt)). The three
modules are licensed `MIT AND Apache-2.0`, and each carries its copyright and
license notice. The rest of the package is licensed under the repository's
MIT [`LICENSE`](../../../LICENSE).
