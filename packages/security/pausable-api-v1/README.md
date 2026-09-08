# Pausable API V1

A frozen Daml interface that gives a template an emergency-stop switch, modelled
on OpenZeppelin's `Pausable.sol`.

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-api-v1` |
| Public module | `OpenZeppelin.PausableV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |
| Solidity analogue | `Pausable` |

## What it provides

One interface, `Pausable`, which names no pause authority and declares no
choice:

- `PausableView`: the flag, and the whole frozen data surface.
- `setPaused`: the implementer's one obligation. A pure method that returns the
  template value with the flag set and every other field unchanged.
- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: `paused()` as a pure function, for a choice that branches on the
  flag rather than refusing to run.
- `pause` and `unpause`: the `_pause()` and `_unpause()` analogues. Each checks
  the guard and creates the successor contract with the new flag.
- `markPaused` and `markUnpaused`: the same guard and flip, returning the
  template value instead of creating it, so that your choice can set sibling
  fields on it and create once.
- `eEnforcedPause`, `eExpectedPause`, `eFlagNotApplied`, and
  `eImplementerTypeMismatch`: the failure messages, exported so that your tests
  assert on a constant rather than on a string.

The package defines no templates, so it carries no ledger state of its own. The
flag lives on the implementing template, which is what binds the switch to the
resource it protects.

The interface declares no choice, because a choice needs a controller
expression and the view names no party. Reading the flag needs no choice
either: `isPaused` answers on-ledger with no extra node, and an off-ledger
reader queries the interface view.

## Authority and lifecycle

The interface ships no access control, exactly as `_pause()` and `_unpause()`
are `internal` in Solidity. You write the choice that decides who may flip the
switch, and the interface supplies the flip and the guard:

```daml
interface instance Pausable for Vault where
  view = PausableView with paused
  setPaused b = toInterface (this with paused = b)

choice Vault_Pause : ContractId Vault
  controller admin
  do
    pause this
```

Any authority model fits, because the check runs in the choice body rather than
in a controller expression. A Daml controller expression is pure, so it cannot
fetch a credential to decide who may act; a role, an M-of-N approval, or a
timelock therefore takes the caller and the credential as choice arguments:

```daml
choice TokenRules_Pause : ContractId TokenRules
  with caller : Party; grantCid : ContractId RoleGrant
  controller caller
  do
    grant <- fetch grantCid
    requireRole caller "PAUSER_ROLE" admin grant
    pause this
```

- Your pause choice must be **consuming**. `pause` creates the successor
  contract but archives nothing, because only the consuming choice archives the
  contract it runs on. A `nonconsuming` pause choice leaves the unpaused
  contract live beside its paused copy.
- Pausing while paused fails with `eEnforcedPause`, and unpausing while unpaused
  fails with `eExpectedPause`, matching `_pause` and `_unpause` in Solidity.
- A flip archives the contract, so outstanding contract IDs and disclosures for
  it go stale. Callers re-read the contract after a pause or an unpause.
- `setPaused` is a public interface method, but it is pure: it yields a value
  and changes nothing. Creating the successor needs the implementing template's
  signatory authority, which only a choice on that template carries, so a
  choice on an unrelated contract cannot flip another template's flag.

## Reading the flag off-ledger

`PausableView` is the whole data surface of the interface:

| Field | Type | Meaning |
|---|---|---|
| `paused` | `Bool` | `True` while the contract refuses its gated choices |

A wallet, a registry's metadata endpoint, or an auditor reads it without knowing
the implementing template. Query the Active Contract Service or the update
stream with an interface filter on `OpenZeppelin.PausableV1:Pausable` and
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
event carrying the new view. There is no event template, and no `Paused` or
`Unpaused` event as in Solidity: the consumer's flip choice is a node in the
transaction tree, recorded with its actor and its ledger time.

The interval during which a pause was in force is the lifetime of a contract
whose view reads `paused = True`. Refused operations write nothing to the
ledger, so the record shows when the pause held, not which attempts it blocked.

## Scope and security caveats

- This is a switch per contract. Pausing several templates at once means one
  flag on each, or a single contract that all the protected operations are
  exercised on.
- Pause is origination control. A gated choice refuses to start while paused;
  transactions already committed are unaffected, and a flip rejects the
  concurrent operations that were reading the contract.
- The interface does not restrict who may call the choices that `whenNotPaused`
  guards, and nothing forces a choice to call a guard at all.
- `setPaused` must preserve every field other than the flag. The flag itself is
  checked, and a flip that fails to apply it fails with `eFlagNotApplied`, but
  nothing checks the other fields, so a wrong implementation silently rewrites
  contract state on every pause.
- After `markPaused` or `markUnpaused`, the record update in your own `create`
  must leave `paused` alone. The library checks the value it returns, not the
  value you create, so `create r with paused = False` after `markPaused` is a
  pause that does not pause, with no error.
- CIP-0112's `pauseInfo` fields are deliberately absent. A registry that must
  serve `reason` and `until` on its metadata endpoint carries them as its own
  template fields beside `paused`, so the whole response still comes from one
  on-ledger contract without freezing those fields into a frozen interface.

## Compatibility

The public surface is frozen. Daml interfaces are not upgradeable through Smart
Contract Upgrade, so this package never changes `Pausable`, `PausableView`, or
the exported functions after its first release. A breaking change ships as a
sibling `openzeppelin-pausable-api-v2` package with module
`OpenZeppelin.PausableV2`, and the two coexist.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` binds your template to one
  package ID, and every participant that runs your gated choices must have
  vetted that package ID.
- Your own template stays upgradeable. The interface instance is declared on
  your template, so you add fields, such as CIP-0112 `pauseInfo`, through Smart
  Contract Upgrade of your package while this package does not move.
- A patch release of this package, if one ever ships, changes documentation or
  metadata only. It does not change any type or function, and it is a new
  package ID that consumers adopt by rebuilding.

`0.1.0` is a pre-release. Until a tagged release records the DAR in
`dars/released/`, the package ID may change between commits, and no audit has
been performed. See [`RELEASING.md`](../../../RELEASING.md).

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/security/pausable-api-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/pausable-api-v1/.daml/dist/openzeppelin-pausable-api-v1-0.1.0.dar
```

```daml
import OpenZeppelin.PausableV1
```

## Examples

Two runnable consumer projects, each building against this DAR through
`data-dependencies`:

- [`examples/pausable/vault`](../../../examples/pausable/vault): minimal
  adoption, the guards, an escape hatch that stays open while paused, and a
  recovery path that runs only while paused.
- [`examples/pausable/registry`](../../../examples/pausable/registry):
  `markPaused` and `markUnpaused` recording CIP-0112 `pauseInfo` fields in the
  same transaction as the flip.
