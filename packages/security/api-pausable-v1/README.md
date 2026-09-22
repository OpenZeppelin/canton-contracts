# Pausable API V1

A frozen Daml interface that gives a template an emergency-stop switch.

| Field | Value |
|---|---|
| Package | `openzeppelin-api-pausable-v1` |
| Public module | `OpenZeppelin.Api.PausableV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

One interface, `Pausable`, which names no pause authority and declares no
choice:

- `PausableView`: the flag, and the whole frozen data surface.
- `setPaused`: the implementer's one obligation. A pure method that returns the
  template value with the flag set and every other field unchanged.

The guards, the flips, and the failure statuses live in the separate
[`openzeppelin-pausable-v1`](../pausable-v1/) package. That split keeps this
package down to the one thing Daml cannot upgrade, the interface, so a fix to a
function ships without a new interface generation.

The package defines no templates, so it carries no ledger state of its own. The
flag lives on the implementing template, which is what binds the switch to the
resource it protects.

The interface declares no choice, because a choice needs a controller
expression and the view names no party. Reading the flag needs no choice
either: an on-ledger guard reads the field of the contract it runs on, and an
off-ledger reader queries the interface view.

## Usage

Add a `paused : Bool` field to the template you protect, and give it an
interface instance. `setPaused` must return your own template with the flag set
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

Never call `setPaused` yourself. It is the hook that `pause` and `unpause` in
`openzeppelin-pausable-v1` call; it runs no guard and creates nothing. The
[`openzeppelin-pausable-v1` README](../pausable-v1/README.md) covers the
guards, the flip choices, and the failure statuses to assert on in tests.

## Reading the flag off-ledger

`PausableView` is the whole data surface of the interface:

| Field | Type | Meaning |
|---|---|---|
| `paused` | `Bool` | `True` while the contract refuses its gated choices |

A wallet, a registry's metadata endpoint, or an auditor reads it without knowing
the implementing template. Query the Active Contract Service or the update
stream with an interface filter on `OpenZeppelin.Api.PausableV1:Pausable` and
request the interface view; every implementing contract visible to the querying
party returns a `PausableView`. On the Ledger API this is a `CumulativeFilter`
with an `InterfaceFilter` that sets `include_interface_view`, and the JSON
Ledger API accepts the same filter shape. In Daml Script the equivalent is:

```daml
Some v <- queryInterfaceContractId reader (toInterfaceContractId @Pausable cid)
v.paused === True
```

A flip archives one contract and creates another, so an Active Contract Service
delta subscriber sees the state change as an archive event followed by a create
event carrying the new view. There is no event template: the consumer's flip
choice is a node in the transaction tree, recorded with its actor and its ledger time.

The interval during which a pause was in force is the lifetime of a contract
whose view reads `paused = True`. Refused operations write nothing to the
ledger, so the record shows when the pause held, not which attempts it blocked.

## Scope and security caveats

- This is a switch per contract. Pausing several templates at once means one
  flag on each, or a single contract that all the protected operations are
  exercised on.
- The interface does not restrict who may exercise any choice, and nothing
  forces a choice to call a guard at all.
- `setPaused` must preserve every field other than the flag. `pause` and
  `unpause` check the flag, but nothing checks the other fields, so a wrong
  implementation silently rewrites contract state on every pause.
- CIP-0112's `pauseInfo` fields are deliberately absent. A registry that must
  serve `reason` and `until` on its metadata endpoint carries them as its own
  template fields beside `paused`, so the whole response still comes from one
  on-ledger contract without freezing those fields into a frozen interface.

## Compatibility

The whole package is frozen at its first upload. Daml interfaces are not
upgradeable through Smart Contract Upgrade: an interface defined in one version
of a package must be absent from every later version. A later version of this
package could upload only without `Pausable`, which is the one thing it
exists to provide, so no later version is published. Any change to the
interface or its view ships as a sibling `openzeppelin-api-pausable-v2` package
with module `OpenZeppelin.Api.PausableV2`, and the two coexist. A change to a
guard, a flip, or a failure status is a new version of `openzeppelin-pausable-v1`
and does not touch this package.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` binds your template to one
  package ID, and every participant that runs your gated choices must have
  vetted that package ID.
- Your own template stays upgradeable. The interface instance is declared on
  your template, so you add fields, such as CIP-0112 `pauseInfo`, through Smart
  Contract Upgrade of your package while this package does not move.
- There is no patch release. Adopting an interface change means importing the
  sibling package and either of two paths. Under Smart Contract Upgrade of your
  own package, you add a second `interface instance` for its interface; Smart
  Contract Upgrade cannot remove an interface instance, so your template
  keeps the V1 instance for life and implements both. To drop V1 you instead
  create a new template version outside Smart Contract Upgrade, and migrate
  existing contracts to it offline.

`0.1.0` is a pre-release and is not for upload to a shared ledger. Until a
tagged release records the DAR in `dars/released/`, the package ID may change
between commits, and no audit has been performed. The version in that first
release is the version this package keeps for life. See
[`RELEASING.md`](../../../RELEASING.md).

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

## Examples

Two runnable consumer projects, each building against this DAR and the
`openzeppelin-pausable-v1` DAR through `data-dependencies`:

- [`examples/pausable/vault`](../../../examples/pausable/vault): minimal
  adoption, the guards, an escape hatch that stays open while paused, and a
  recovery path that runs only while paused.
- [`examples/pausable/registry`](../../../examples/pausable/registry):
  `pause` and `unpause` recording CIP-0112 `pauseInfo` fields in the
  same transaction as the flip.
