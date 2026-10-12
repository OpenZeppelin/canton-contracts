# Token CIP-0112 utils

The choice bodies of a CIP-0112 (Token Standard V2) registry as plain
functions, with every template decision left to the caller.

| Field | Value |
|---|---|
| Package | `openzeppelin-cip112-token-utils` |
| Public modules | `OpenZeppelin.CIP112Token.Utils.Holding`, `.Transfer`, `.Allocation`, `.Registry` |
| Depends on | `openzeppelin-cip112-token-types-v1` |
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
- `isValid*` predicates for `ensure` clauses, and `transferInstructionView`
  and `allocationView` for interface views.
- `*Impl` functions for every interface method and template choice a registry
  needs: `transferFactoryImpl`, `transferAcceptImpl`, `allocationFactoryImpl`,
  `allocationSettleImpl`, `settleBatchImpl`, `mintImpl`, `burnImpl`, and the
  rest.

The functions read and return the `RegistryConfig`,
`TransferInstructionState`, and `AllocationState` records of
`openzeppelin-cip112-token-types-v1`.

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

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/token/cip112-token-utils dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/token/cip112-token-types-v1/.daml/dist/openzeppelin-cip112-token-types-v1-0.1.0.dar
  - ../canton-contracts/packages/token/cip112-token-utils/.daml/dist/openzeppelin-cip112-token-utils-0.1.0.dar
```

```daml
import OpenZeppelin.CIP112Token.TypesV1
import OpenZeppelin.CIP112Token.Utils.Holding
```

The ready-to-use templates over these functions are
`openzeppelin-cip112-token-v1`. `examples/cip112-token/custom-token` is a
complete consumer that owns its templates and reuses these functions.
