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

## Time bounds

No workflow reads the time with `getTime`. Every time check is a
ledger-time bound, which constrains the ledger time the participant picks
when the transaction executes instead of fixing it when the transaction is
prepared. An externally signed submission therefore executes whenever its
bounds still hold, not only within the ledger-time tolerance of its
preparation.

- A transfer, including a mint offer, needs `requestedAt` at or before
  ledger time and `executeBefore` after it. `executeBefore` may be at most
  `maxTTL` after ledger time and `requestedAt` at most `maxTTL` before it.
- An allocation counts its storage bound from the request's `requestedAt`.
  `expiresAt` is the settlement deadline, or `requestedAt` plus `maxTTL`
  without one, and must lie after ledger time. A settlement deadline more
  than `maxTTL` after `requestedAt` is refused, so a deadline is always the
  allocation's `expiresAt`, and the lock never expires before it.
- The authorizer's wallet chooses `requestedAt`, up to `maxTTL` in the past.
  An older value shortens the allocation's life, and `createdAt`, which is
  `requestedAt`, reports it. Executors must not treat `createdAt` as the
  time the ledger created the allocation.
- A settlement that creates a successor moves `expiresAt` to the previous
  `expiresAt` plus the allocation's `maxTTL`, capped by the settlement
  deadline, and refuses a result that has already passed. A settlement
  without a successor sets no new bound.
- Without a settlement deadline, each settlement adds a full `maxTTL`, so
  the executors can push an iterated allocation's `expiresAt`, and its
  reserve's lock, well past `maxTTL` from ledger time by settling it
  repeatedly. This is intended. The executors are already trusted with the
  reserve, and an allocation without a deadline is never committed, so its
  authorizer can withdraw it, and end the chain, at any time.
- Every time derived from `maxTTL` or `lockGrace` saturates at the bounds of
  `Time`, which ends at `maxTime` (9999-12-31T23:59:59.999999Z), instead of
  failing the workflow with an `ArithmeticError`. A bound that saturates no
  longer limits anything: once `executeBefore` minus `maxTTL` saturates, any
  execution window passes, and once `requestedAt` plus `maxTTL` does, any
  request age and any settlement deadline pass, and an allocation without a
  deadline expires at `maxTime`. A lock expiry that saturates keeps the
  funding locked until `maxTime`, so the owner can never unlock it, but the
  admin can still expire the contract after its `expiresAt`. A contract whose
  `expiresAt` is itself `maxTime` has a lock expiry equal to it and never
  expires: only its own choices release the funding. A committed allocation
  must have a settlement deadline before `maxTime`, since one at `maxTime`
  would never let its authorizer withdraw it.

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
