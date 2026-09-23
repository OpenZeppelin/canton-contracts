# Pausable API V1

A frozen Daml interface that gives a template an emergency-stop switch.

| Field | Value |
|---|---|
| Package | `openzeppelin-api-pausable-v1` |
| Public module | `OpenZeppelin.Api.PausableV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `Pausable`: the interface your template declares an instance of.
- `PausableView`: the flag, readable through the interface by every party
  that sees the contract.

The guards and the failure statuses live in
[`openzeppelin-pausable-v1`](../pausable-v1/). The flag lives on your
template, which binds the switch to the resource it protects.

## Usage

Add a `paused : Bool` field to the template you protect, and give it an
interface instance whose view reports the field:

```daml
import OpenZeppelin.Api.PausableV1

template Vault
  with
    admin : Party
    owner : Party
    balance : Decimal
    paused : Bool
  where
    signatory admin, owner

    interface instance Pausable for Vault where
      view = PausableView with paused
```

Your own choices flip the flag: each guards with `openzeppelin-pausable-v1`,
then creates the successor with `paused` changed. The
[`openzeppelin-pausable-v1` README](../pausable-v1/README.md) covers the
guards, the flip choices, and the failure statuses to assert on in tests.

A template that already has active contracts adopts the interface in its
next Smart Contract Upgrade (SCU) version. SCU accepts a new field only as
an `Optional` at the end of the record, so the flag is
`paused : Optional Bool`, `None` on every contract created before the
upgrade, and the view reads `None` as unpaused:

```daml
import DA.Optional (fromOptional)

template UpgradedVault
  with
    admin : Party
    holder : Party
    paused : Optional Bool
  where
    signatory admin
    observer holder

    interface instance Pausable for UpgradedVault where
      view = PausableView with paused = fromOptional False paused
```

The flip choices create with `paused = Some True` and `paused = Some False`.
The guards read the view, so the gated choices call `whenNotPaused this` as
before.

## Reading the flag off-ledger

A wallet, a registry's metadata endpoint, or an auditor reads `PausableView`
without knowing the implementing template. Query the Active Contract Service
or the update stream with an `InterfaceFilter` for `Pausable` that requests
the interface view; every implementing contract visible to the querying party
returns a `PausableView`. The JSON Ledger API accepts the same filter shape.
In Daml Script:

```daml
Some v <- queryInterfaceContractId reader (toInterfaceContractId @Pausable cid)
v.paused === True
```

The flip is the consumer's exercise node in the transaction tree, recorded
with its actor and its ledger time. The interval during which a pause was in
force is the lifetime of a contract whose view reads `paused = True`.

## Authority and lifecycle

The interface carries the view alone. Pause authority is the controller and
body of the consumer's flip choice.

## Scope and security caveats

- The switch is per contract. To pause several templates at once, put a flag
  on each, or exercise every protected operation on one contract that holds
  the flag.
- Pause authority is whatever the controller and body of your flip choice
  check. Review that choice as a privileged choice, and test that other
  parties are refused.
- `PausableView` carries `paused` alone. A registry that serves CIP-0112
  `reason` and `until` holds them as its own template fields beside `paused`,
  as [`examples/pausable/registry`](../../../examples/pausable/registry)
  shows.
- The ledger records when a pause held, not the attempts it blocked. An
  off-ledger client that needs those logs its own rejected submissions.

## Compatibility

Daml-LF `2.1`, built with the SDK that
[`multi-package.yaml`](../../../multi-package.yaml) declares.

The package is frozen. A change to `Pausable` or `PausableView` ships as a
sibling `openzeppelin-api-pausable-v2` package with module
`OpenZeppelin.Api.PausableV2`, and the two coexist. A change to a guard or a
failure status is a new version of `openzeppelin-pausable-v1`.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` binds your template to one
  package ID, and every participant that runs your gated choices vets that
  package ID.
- Your own template stays upgradeable. The interface instance is declared on
  your template, so you add fields, such as CIP-0112 `pauseInfo`, through
  Smart Contract Upgrade (SCU) of your package while this package stays at
  its frozen version.
- Adopting `openzeppelin-api-pausable-v2` takes one of two paths. Under SCU
  of your own package, you add a second `interface instance`; an interface
  instance stays through every SCU version, so your template implements both
  for life. To drop V1, you create a new template version outside SCU and
  migrate existing contracts to it offline.

`0.1.0` is a pre-release: the package ID may change between commits, and no
audit has been performed. See [`RELEASING.md`](../../../RELEASING.md).

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/security/api-pausable-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/api-pausable-v1/.daml/dist/openzeppelin-api-pausable-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Api.PausableV1
```

Runnable consumer projects live under [`examples/pausable/`](../../../examples/pausable/).
