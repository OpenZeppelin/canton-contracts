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
- `setPaused`: the method your template writes; `pause` and `unpause` in
  [`openzeppelin-pausable-v1`](../pausable-v1/) call it.

The guards, the flips, and the failure statuses live in
[`openzeppelin-pausable-v1`](../pausable-v1/). The flag lives on your
template, which binds the switch to the resource it protects.

## Usage

Add a `paused : Bool` field to the template you protect, and give it an
interface instance. `setPaused` returns your own template with the flag set
and nothing else changed:

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
      setPaused b = toInterface (this with paused = b)
```

Call `pause` and `unpause` from `openzeppelin-pausable-v1` in your flip
choices rather than `setPaused`. The
[`openzeppelin-pausable-v1` README](../pausable-v1/README.md) covers the
guards, the flip choices, and the failure statuses to assert on in tests.

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

The interface carries the view and the `setPaused` method. Pause authority is
the controller and body of the consumer's flip choice, and the `create` in
that choice carries the implementing template's signatories. A flip archives
the contract and creates its successor, so a reader holds the view of one
contract at a time and re-queries after a flip.

## Scope and security caveats

- The switch is per contract. To pause several templates at once, put a flag
  on each, or exercise every protected operation on one contract that holds
  the flag.
- Pause authority is whatever the controller and body of your flip choice
  check. Review that choice as a privileged choice, and test that other
  parties are refused.
- `setPaused` must return your template with only the flag changed. `pause`
  and `unpause` verify the flag alone, so a `setPaused` that also rewrites
  another field rewrites contract state on every flip. Test one pause round
  trip and compare every other field.
- `PausableView` carries `paused` alone. A registry that serves CIP-0112
  `reason` and `until` holds them as its own template fields beside `paused`,
  as [`examples/pausable/registry`](../../../examples/pausable/registry)
  shows.
- A refused choice writes nothing to the ledger. The ledger records when a
  pause held; an off-ledger client that needs the attempts a pause blocked
  logs its own rejected submissions.

## Compatibility

Daml-LF `2.1`, built with the SDK that
[`multi-package.yaml`](../../../multi-package.yaml) declares.

The package is frozen. A change to `Pausable` or `PausableView` ships as a
sibling `openzeppelin-api-pausable-v2` package with module
`OpenZeppelin.Api.PausableV2`, and the two coexist. A change to a guard, a
flip, or a failure status is a new version of `openzeppelin-pausable-v1`.

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
