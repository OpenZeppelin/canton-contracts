# Token CIP-0112 V1 workflows

The choice bodies of a CIP-0112 (Token Standard V2) registry as plain
functions, with every template decision left to the caller.

| Field | Value |
|---|---|
| Package | `openzeppelin-tokenCIP112-workflows-v1` |
| Public modules | `OpenZeppelin.TokenCIP112WorkflowsV1.Holding`, `.Transfer`, `.Allocation`, `.Registry` |
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
- `RegistryConfig`, `TransferInstructionState`, and `AllocationState`: the
  records the workflows read and return. A template may store them for
  one-line delegations, which binds it to this package's upgrade lineage
  (later versions append `Optional` fields only), or store their fields
  itself and build the record per call, which keeps this package swappable.
- `isValid*` predicates for `ensure` clauses, and `transferInstructionView`
  and `allocationView` for interface views.
- `*Impl` functions for every interface method and template choice a registry
  needs: `transferFactoryImpl`, `transferAcceptImpl`, `allocationFactoryImpl`,
  `allocationSettleImpl`, `settleBatchImpl`, `mintImpl`, `burnImpl`, and the
  rest.

The package defines no template or interface.

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
DAML_PACKAGE=packages/token/tokenCIP112-workflows-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/token/tokenCIP112-workflows-v1/.daml/dist/openzeppelin-tokenCIP112-workflows-v1-0.1.0.dar
```

```daml
import OpenZeppelin.TokenCIP112WorkflowsV1.Holding
```

The ready-to-use templates over these workflows are
`openzeppelin-tokenCIP112-v1`. `examples/tokenCIP112/custom-token` is a
complete consumer that owns its templates and reuses these workflows.
