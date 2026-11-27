# Async Vault utils

The share maths and the choice bodies of an asynchronous vault as plain
functions, with every template decision left to the caller. An asynchronous
vault takes deposit and redemption requests and settles them in batches, at
one price per batch.

| Field | Value |
|---|---|
| Package | `openzeppelin-async-vault-utils` |
| Public modules | `OpenZeppelin.AsyncVault.Utils.Gate`, `.Math`, `.Request`, `.Reserves`, `.Settlement` |
| Depends on | `openzeppelin-async-vault-types-v1`, `openzeppelin-api-async-vault-v1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

The package defines no templates, interfaces, exceptions, or serializable
types. It calls registries through the Token Standard V2 interface DARs under
[`dars/vendor/`](../../../dars/vendor/).

## What it provides

`OpenZeppelin.AsyncVault.Utils.Settlement`:

- `settleBatchImpl`: the body of the choice that settles a batch of requests
  on both registries, at the price the batch is submitted with, and returns
  the state to record and each request's fill.
- `settleTrackedBatchImpl`: the same body for a vault that tracks its pool.
  It is funded from the tracked holdings alone and also returns the holdings
  the pool is left with.
- `priceBatch`, `depositFill`, and `redeemFill`: the pricing of a batch and of
  one request at a price, as pure functions an operator can also run before
  submitting.
- `checkBatch`: the rules a batch passes before it is priced.
- `depositShareLeg` and `redeemPayoutLeg`: the transfer legs a batch adds to a
  request's own.
- `eEmptyBatch`, `eBatchTooLarge`, `eForeignRequest`, `eDuplicateRequest`,
  `eRequestExpired`, `eZeroFill`, `eBelowMinimum`, `ePoolTracked`, and
  `ePoolMismatch`: the failure statuses.

`OpenZeppelin.AsyncVault.Utils.Reserves`:

- `recordReservesImpl`: the body of the choice that replaces the recorded
  reserves with the sum of the custodian's holdings it is given.
- `reserveAmount` and `sumReserves`: what one holding and a list of holdings
  add to the reserves, as pure functions.
- `heldReserves`: what a list of the custodian's holdings amounts to on the
  ledger.
- `eForeignHolding`, `eUnsignedHolding`, `eLockedHolding`, and
  `eDuplicateHolding`: the failure statuses.

`OpenZeppelin.AsyncVault.Utils.Gate`:

- `checkDepositGate`: asks a `DepositGate` contract, an interface of
  [`openzeppelin-api-async-vault-v1`](../api-async-vault-v1/), whether a
  deposit request may be opened. Use it as the policy's `authorizeDeposit`.
- `eForeignGate`: the failure status.

`OpenZeppelin.AsyncVault.Utils.Request`:

- `requestDepositImpl` and `requestRedeemImpl`: the bodies of the choices that
  open a request. Each makes the request's two allocations and creates the
  request through a constructor the caller passes.
- `cancelDepositImpl` and `cancelRedeemImpl`: the bodies of the choices by
  which a requester cancels and gets the escrow back.
- `rejectDepositImpl` and `rejectRedeemImpl`: the bodies of the choices by
  which the vault rejects a request and returns the escrow.
- `expireRequestImpl`: the body of a choice that drops a request from its
  deadline on.
- `VaultPolicy` and `defaultVaultPolicy`: the record of decisions a vault
  leaves to whoever deploys it: who may deposit, how many requests one batch
  may settle, and which prices a batch may settle at. It holds functions, so
  it is never stored.
- `vaultSettlement`, `settlementExecutors`, `requesterParties`,
  `requestLegId`, `depositEscrowLeg`, and `redeemEscrowLeg`: the settlement,
  the acting parties, and the transfer legs a request is built from.
- `checkDepositTerms`, `checkRedeemTerms`, `isValidDepositRequestState`, and
  `isValidRedeemRequestState`: the rules on a request's terms, as checks and
  as predicates for an `ensure` clause.
- `isValidVaultConfig`: the rules on a vault's config, as a predicate for an
  `ensure` clause.
- `eNonPositiveAmount`, `eInvalidRequester`, `eInvalidLabel`,
  `eAllocationIncomplete`, and `eDeadlineNotPassed`: the failure statuses.

`OpenZeppelin.AsyncVault.Utils.Math`:

- `convertToShares` and `convertToAssets`: the shares a deposit is issued and
  the underlying a redemption is paid, at a `SharePrice`.
- `checkPriceWithin`: whether a price is within a band around a reference
  price, for a policy that holds whoever submits batches to one.
- `stateAfterDeposit`, `stateAfterRedeem`, and `stateWithReserves`: the state
  a deposit, a redemption, or a record of the reserves leaves behind.
- `isValidSharePrice`, `checkSharePrice`, and `isValidVaultState`: the rules
  on a price and on a state, as a check and as predicates for an `ensure`
  clause.
- `mulDivDown`: `x * num / den` rounded down to the tenth decimal place, with
  no rounding of the product before the division.
- `eNegativeAmount`, `eInvalidPrice`, `ePriceOutOfBand`, `eOutOfRange`,
  `eTotalsOutOfRange`, `eInsufficientReserves`, and `eExceedsTotals`: the
  failure statuses.

The maths functions are pure and return `Either FailureStatus`, so a choice
body decides how to fail:

```daml
shares <- either failWithStatus pure (convertToShares price assets)
```

## Requests

A request is two allocations of the Token Standard and one contract of the
caller's template:

- **The escrow** locks the requester's funds in the requester's own holdings.
  It authorizes one transfer leg, fixed when the request is made: the assets
  to the vault's custodian for a deposit, the shares to the share
  instrument's burn account for a redemption.
- **The receipt** is an allocation on the other instrument's registry. It
  reserves nothing and lets the settlement's executors name what the
  requester receives.
- **The request** records the terms and the two allocation ids.

Authority and lifecycle:

- The requester's account parties, `requesterParties`, control the choice
  that opens a request. Together with the authority of the contract the
  choice is on, that is all a request needs, so a requester submits alone.
- Opening a request consumes no contract of the vault and reads no price, so
  concurrent requests do not contend. It spends only the requester's own
  holdings: the custodian's holdings are spent by a batch alone.
- `VaultPolicy.authorizeDeposit` runs before a deposit request locks anything
  and may refuse it. Redemption requests pass through no policy operation: a
  holder can always ask to redeem.
- Only a holder opens a redemption request. The account's own parties control
  the choice, and the escrow locks the shares the request asks to redeem, so a
  party without those shares opens none.
- Either side can end a request before it settles, and either way the escrow
  is back with the requester in the same transaction. Neither allocation is
  committed, so the requester cancels through the request at any time, which
  withdraws both allocations. The vault rejects a request with the authority
  of the settlement's two executors, which cancels both allocations.
- From its deadline on, no batch can settle a request, and
  `expireRequestImpl` drops it. Dropping releases nothing: the requester
  withdraws the allocations on their registries.

A request is refused when its requester is not a regular account or is the
vault's custodian, its label is empty or longer than `maxLabelLength`, its
amount is not positive or is above `maxOperand`, or its minimum is negative or
above `maxOperand`.

## Batches

A batch settles any number of deposit and redemption requests, up to the
policy's `maxBatchSize`, in one transaction:

- **One price.** A batch is submitted with a price, and every request in it
  is filled at that price, so the order of the requests changes nobody's
  fill.
- **The policy accepts the price or refuses the batch.**
  `VaultPolicy.checkPrice` runs with the state before the batch and the
  submitted price.
- **The state records the batch.** The state the body returns has the
  deposits added to the reserves and the redemptions taken from them, the
  shares issued and burned, the price the batch settled at, and one batch
  more.
- **Both registries, once each.** The batch allocates the vault's own sides,
  which are the custodian's on the underlying and the mint and burn accounts'
  on the share instrument, and settles each registry with one call.
- **Net funding.** The custodian's allocation is funded from the pool holdings
  the caller passes. Only what the batch pays out beyond what it takes in is
  locked, and the rest comes back to the custodian as change.
- **All or nothing.** A request that cannot be filled, a registry that fails
  or leaves an allocation unsettled, or a state the vault could not record
  fail the whole batch, and nothing moves.
- **A tracked pool, when the vault keeps one.** `settleTrackedBatchImpl`
  takes the holdings the vault's state names as its pool, funds the batch
  from them, and returns the holdings the underlying's registry reports
  back for the custodian: the change of its allocation and what its
  settlement paid it. It checks on the ledger that they amount to the
  reserves the batch records, and fails with `ePoolMismatch` when they do
  not. The caller stores them as the pool for the next batch.

A batch is refused when it is empty or above `maxBatchSize`, holds a request
made for another vault, holds two requests of one requester under the same
label, or holds a request whose deadline has passed. A request cannot be
filled when it converts to nothing at the batch's price or to less than its
requester's minimum. A batch is also refused when the recorded reserves and
its own deposits do not cover its redemptions.

A request that its requester cancels, or the vault rejects, while a batch
that names it is on its way fails that batch. Whoever submitted the batch
submits it again without the request.

The body returns a `SettledBatch` and consumes nothing of the caller's. The
caller's choice fetches the requests, passes their payloads, consumes them
with the fills it gets back, and records the returned state.

## The price

A price is a `SharePrice`: `priceShares` shares are worth `priceAssets` units
of the underlying. The package computes no price. Whoever submits a batch
supplies one, and `VaultPolicy.checkPrice` is the vault's say over it:

- `defaultVaultPolicy` accepts only the price the state already records, so
  whoever submits batches decides no price. A template that uses it needs
  another way to change the recorded price, such as a choice of the vault's
  admin.
- `checkPriceWithin reference maxDeviation` accepts a price up to a fraction
  above or below a reference. A policy that takes the reference from a value
  whoever submits batches cannot change holds every price to one band. A
  policy that passes the state's own price lets the price move by the
  deviation in each batch, with no limit over many batches.
- A policy can apply any other rule, because `checkPrice` is a function of
  the state and the price.

`checkPriceWithin` compares prices exactly, as ratios. The same price written
with other numbers is accepted as the same price, and a price that differs by
any amount is not. The deviation is rounded down to the tenth decimal place
of `reference.priceAssets`, so a band is never wider than stated, and a
reference written with very small numbers narrows it.

The state's `price` is the price of the last batch. A template that makes the
state readable lets a wallet show it. It is a record and not a quote: the
next batch settles at whatever price the policy accepts then.

## Reserves

The state's `reserves` are the most a batch pays out beyond what it takes in.
A batch adds its deposits to them and takes its redemptions from them.
Anything else that reaches or leaves the custodian, such as a gain paid in or
assets sent out to be invested, is not in them until they are recorded again:

- **Recorded from holdings.** `recordReservesImpl` takes holdings, fetches
  each one, and sets the reserves to their sum. The share total, the price,
  and the batch number stay as they are.
- **What counts.** A holding counts when it is of the underlying, in the
  custodian's account, signed by the underlying's admin, and not locked. One
  holding that does not count refuses the whole record, and so does a holding
  named twice.
- **Never above what is held.** A holding left out is not counted, so the
  record can be below what the custodian holds and cannot be above it. The
  party that records the reserves is trusted to show all of them, and nothing
  more.
- **True when recorded.** The custodian can move a holding in the next
  transaction. A batch that pays out more than the custodian then holds fails
  on the underlying's registry.

Until the reserves are recorded again after a gain, a redemption owed more
than the recorded reserves fails with `eInsufficientReserves` even when the
custodian holds enough.

## Trust boundary

- `checkDepositGate` exercises the gate with the authority of the vault's
  admin alone, after checking that the gate's view names that admin. The
  gate's code therefore cannot act for the requester. The caller takes the
  gate's contract id from its own contract: an id the requester supplies can
  be replaced by the requester.
- `requestDepositImpl` and `requestRedeemImpl` exercise the allocation
  factories with the requester's authority. They take the factories from
  `VaultRegistries`, never from the caller. The caller's template must let
  only the vault's admin set that record, and a requester should check that
  the factories are the ones the instruments' registries publish before
  submitting.
- `vaultSettlement` names the vault's admin and operator as the executors of
  every allocation. Each must act for an allocation to be settled or
  cancelled, so the caller's templates decide where both authorities meet.
- `settleBatchImpl` needs the authority of both executors, of the custodian's
  account parties, and of the share instrument's admin. A caller whose choice
  does not carry all of them cannot settle.
- The two executors acting together outside that choice can settle an escrow
  to the custodian without issuing shares. A requester trusts the pair not
  to, as it trusts the custodian with the pool and the share instrument's
  admin with the supply.
- Whoever submits a batch chooses its price, within what `checkPrice`
  accepts. A policy that accepts every price lets that party issue shares for
  next to nothing or pay the whole of the reserves for one share. Every
  requester of the batch bounds its own fill with the minimum in its terms,
  and holders who are not in the batch rely on the policy alone.
- `recordReservesImpl` takes a holding for one of the underlying because the
  underlying's admin is a signatory of its contract. A registry whose admin
  does not sign its holdings has none that count, and a registry whose admin
  signs a contract that shows a holding the custodian does not have makes the
  record wrong.
- Two vaults that share a custodian account can each record the same
  holdings. Give each vault an account of its own.
- `settleBatchImpl` exercises the settlement factories of `VaultRegistries`
  with the executors' authority, and relies on each registry to move exactly
  the legs it is given. It fails the batch unless every allocation is
  reported settled.
- The escrow cannot be redirected: a registry that follows the Token Standard
  settles only the leg the requester authorized. The receipt accepts any leg
  the executors name, but it holds no funds.
- A request's leg ids come from the requester's account and the label, so two
  requests of one account under the same label carry the same ids. So do two
  requests of one owner's accounts when one account's id and label, joined by
  `/`, read as the other's. Nothing here refuses the second request; a batch
  that holds both fails with `eDuplicateRequest`.
- A registry that does not complete an allocation, a withdrawal, or a
  cancellation in the same transaction fails the choice with
  `eAllocationIncomplete`.
- A requester can open and cancel requests as often as it likes, and each
  cancellation can fail a batch. Nothing here limits that, and nothing sets a
  smallest request. Deposit requests pass through `authorizeDeposit`, which
  can refuse a requester. Redemption requests pass through no policy
  operation, so the only requesters nothing can refuse are holders of the
  share instrument.
- A requester who withdraws an allocation on its registry directly leaves the
  request unable to be cancelled or rejected. It stays until its deadline,
  when it is dropped.

## Rounding and range

- Every conversion rounds down. A deposit is issued no more shares, and a
  redemption is paid no more of the underlying, than the price allows.
  Converting an amount one way and back never returns more than went in.
- A deposit too small for the price converts to zero shares.
  `convertToShares` returns zero, and a batch that holds such a request fails
  with `eZeroFill`.
- Results carry ten decimal places. The registries of both instruments must
  accept amounts of that precision, because the functions do not round to a
  coarser one.
- A conversion depends on the price and not on how the price is written: two
  units for two shares and one unit for one share fill every request alike.
- Each amount, each part of a price, and a state's reserves and share total
  are at most `maxOperand`, which is 10^18. An amount outside the range fails with
  `eOutOfRange`, and so does a result that does not fit a `Decimal`; neither
  raises an arithmetic error.
- A deposit that would take the reserves or the share total above
  `maxOperand` fails with `eTotalsOutOfRange`.
- A redemption is paid from the recorded reserves. One that is owed more than
  the reserves hold after the batch's deposits fails with
  `eInsufficientReserves`, and one that burns more shares than are
  outstanding fails with `eExceedsTotals`.
- A record of the reserves above `maxOperand` fails with `eTotalsOutOfRange`,
  whether one holding or the sum is above it.

## What it does not solve

- The functions decide no authority. Who may settle a batch, record the
  reserves, change the recorded state in any other way, or drop an expired
  request is for the caller's templates to define.
- Nothing chooses a batch. Which requests settle and when is the operator's
  decision; a requester who is left out can cancel.
- Nothing values the vault's assets. A price is correct only as far as the
  party that supplies it and the policy that accepts it make it so, and the
  package offers no check of a price against the reserves and the shares
  outstanding.
- Nothing records the reserves on its own. Between two records they follow
  the batches only, and when to record them again is the caller's decision.
- A record of the reserves proves a lower bound at one moment. It does not
  prove that the custodian holds nothing more, or that it still holds the
  amount afterwards.
- A locked holding is not counted, whether its lock has expired or not.
- A request settles whole or not at all, and no fee is taken.
- The functions trust their arguments. A caller that passes a state read from
  the wrong contract, or a state another transaction has already replaced,
  gets a correct result for that state. Identifying the vault's one current
  state is the caller's job.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/vault/async-vault-utils dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/vault/api-async-vault-v1/.daml/dist/openzeppelin-api-async-vault-v1-0.1.0.dar
  - ../canton-contracts/packages/vault/async-vault-types-v1/.daml/dist/openzeppelin-async-vault-types-v1-0.1.0.dar
  - ../canton-contracts/packages/vault/async-vault-utils/.daml/dist/openzeppelin-async-vault-utils-0.1.0.dar
```

```daml
import OpenZeppelin.AsyncVault.TypesV1
import OpenZeppelin.AsyncVault.Utils.Gate
import OpenZeppelin.AsyncVault.Utils.Math
import OpenZeppelin.AsyncVault.Utils.Request
import OpenZeppelin.AsyncVault.Utils.Reserves
import OpenZeppelin.AsyncVault.Utils.Settlement
```

[`examples/vault/async-vault-custom`](../../../examples/vault/async-vault-custom/)
is a consumer that owns its templates over these functions and passes them a
policy of its own.
