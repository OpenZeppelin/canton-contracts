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

- `HoldingOps`: the record a template owner builds inside a choice body with
  `createHolding`, `consumeHolding`, `withEventLog`, and `eventObservers`
  (extra informees of every holdings-change event, for auditors and
  regulators who must see the standard event stream). It holds functions,
  so it is never stored.
- `consumeByArchive @T` and `pinAllocationTo @T`: the safe ways to write the
  consumption and allocation policies, pinned to one template.
- `privateAssetAllocateExtraObservers`: the allocation factory's extra
  observers, which admit the settlement executors only to a call that needs
  no funding and names no input holdings.
- `isValid*` predicates for `ensure` clauses, and `transferInstructionView`
  and `allocationView` for interface views.
- `*Impl` functions for every interface method and template choice a registry
  needs: `transferFactoryImpl`, `transferAcceptImpl`, `allocationFactoryImpl`,
  `allocationSettleImpl`, `settleBatchImpl`, `offerMintImpl`, and the
  rest.

The functions read and return the `RegistryConfig`,
`TransferInstructionState`, and `AllocationState` records of
`openzeppelin-token-cip112-types-v1`.

## Compatibility

The package defines no templates, interfaces, exceptions, or serializable
types, so SCU ignores it. A consumer may move to any later version, switch to
a fork, or drop the dependency, because no contract payload references this
package. Versions follow semver, and the package name carries no `vN` suffix.

## Trust boundary

The workflows trust nothing they did not just create. Every caller-supplied
contract id enters through an operation the template owner wrote:

- `consumeHolding` must fail on any holding that is not an accepted
  implementation. Use `consumeByArchive @YourHolding`, or a custom spend
  choice reached through `fetchFromInterface @YourHolding`. Never archive a
  caller-supplied id by interface.
- The `PinAllocation` passed to `settleBatchImpl` and `expireAllocationsImpl`
  must fail on any allocation whose choice bodies the registry does not
  control. Use `pinAllocationTo @YourAllocation`.
- `createHolding` must create a contract whose view equals the argument and
  whose signatories include the admin and the account parties.
- A holding with a live lock belongs to the pending transfer instruction or
  allocation that names it in `lockedHoldingCids`. Every path that ends the
  pending contract consumes that exact contract id. No choice on the holding
  template may archive or re-create the holding before the lock's
  `expiresAt`, for example to freeze, merge, split, or edit metadata.
  Otherwise the pending contract can no longer complete, release, or expire.
- The settlement factory must settle through `settleBatchImpl`, or keep its
  exact-cover check: every leg in the batch needs a sending and a receiving
  allocation with the same amount. Without it, a settlement can create
  tokens. No other choice may exercise `Allocation_Settle` with the admin's
  authority, because that skips the check.
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
