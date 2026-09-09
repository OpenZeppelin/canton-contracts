# Pausable API V1

A frozen Daml interface that gives a template an emergency-stop switch.

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-api-v1` |
| Public module | `OpenZeppelin.PausableV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

One interface, `Pausable`, which names no pause authority and declares no
choice:

- `PausableView`: the flag, and the whole frozen data surface.
- `setPaused`: the implementer's one obligation. A pure method that returns the
  template value with the flag set and every other field unchanged.
- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: the flag as a pure function, for a choice that branches on the
  flag rather than refusing to run.
- `pause` and `unpause`: the guarded flips. Each checks the guard, sets the flag, verifies it, and returns the template
  value for your choice to create.
- `eEnforcedPause`, `eExpectedPause`, `eFlagNotApplied`, and
  `eImplementerTypeMismatch`: the failure statuses. Each is a `FailureStatus`
  with a stable `errorId` under `openzeppelin.com/pausable-`, so an off-ledger
  client matches the id in the `DAML_FAILURE` error, and your tests compare the
  whole value.

The package defines no templates, so it carries no ledger state of its own. The
flag lives on the implementing template, which is what binds the switch to the
resource it protects.

The interface declares no choice, because a choice needs a controller
expression and the view names no party. Reading the flag needs no choice
either: `isPaused` answers on-ledger with no extra node, and an off-ledger
reader queries the interface view.

## Usage

Adopting the switch is four steps. Each one names the function it uses and the
rule that goes with it.

**1. Hold the flag and implement the interface.** Add a `paused : Bool` field to
the template you protect, and give it an interface instance. `setPaused` must
return your own template with the flag set and nothing else changed:

```daml
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

Never call `setPaused` yourself. It is the hook the library calls; it runs no
guard and creates nothing.

**2. Guard the choices that a pause must stop.** Call `whenNotPaused this` as
the first statement of every gated choice body. It takes the contract value the
choice runs on, never a contract ID, so no caller can hand in a different
switch. A choice without the call is not gated; the library cannot detect the
omission.

```daml
    choice Vault_Withdraw : ContractId Vault
      with amount : Decimal
      controller owner
      do
        whenNotPaused this
        create this with balance = balance - amount
```

`whenPaused this` is the mirror guard for a choice that may run only during an
incident, such as an emergency drain. `isPaused this` returns the flag as a
`Bool` for a choice that branches rather than refuses; it never fails.

**3. Write the flip choices.** Call `pause this` or `unpause this`
from a choice whose controller and body express your pause authority. Each one
checks the guard, verifies that `setPaused` set the flag, and returns the
template value with the new flag. Your choice creates it. A consuming choice
archives the predecessor before the body runs, so this is the whole flip:

```daml
    choice Vault_Pause : ContractId Vault
      controller admin
      do create =<< pause this

    choice Vault_Unpause : ContractId Vault
      controller admin
      do create =<< unpause this
```

When the successor must also carry other field changes, set them with a record
update on the returned value and create once. Leave `paused` alone in that
update, and leave alone every field that determines the signatories or the
observers: a changed signatory field fails the create, and a dropped observer
silently narrows who sees the paused contract.

```daml
    choice Registry_Pause : ContractId Registry
      with reason : Optional Text
      controller admin
      do
        r <- pause this
        create r with pauseReason = reason
```

The choice kind is yours. The functions archive nothing, so a nonconsuming
flip choice must call `archive self` beside the create, as any nonconsuming
choice that replaces its contract must.

**4. Assert on the failure statuses in your tests.** A gated choice that runs
while paused fails with `eEnforcedPause`; a paused-only choice that runs while
unpaused, and `unpause` on an unpaused contract, fail with
`eExpectedPause`.
`eFlagNotApplied` and `eImplementerTypeMismatch` fire only when an interface
instance breaks the `setPaused` rule, so a test that pauses once catches a
mis-wired implementation before it ships. Every failure is raised with
`failWithStatus`, so Daml Script hands it back as a `FailureStatusError`:

```daml
Left (FailureStatusError status) <-
  trySubmit owner do exerciseCmd vault Vault_Withdraw with amount = 1.0
status === eEnforcedPause
```

A Ledger API or JSON API client sees the same failure as a `DAML_FAILURE` error
whose `errorId` is `openzeppelin.com/pausable-enforced-pause`. Match on that id,
not on the message text.

## Authority and lifecycle

The interface ships no access control. You write the choice that decides who
may flip the switch, and the interface supplies the flip and the guard:

```daml
interface instance Pausable for Vault where
  view = PausableView with paused
  setPaused b = toInterface (this with paused = b)

choice Vault_Pause : ContractId Vault
  controller admin
  do create =<< pause this
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
    create =<< pause this
```

- `pause` and `unpause` archive nothing. Your flip choice archives
  the predecessor and creates the successor: a consuming choice does the
  archive itself, and a nonconsuming one calls `archive self`.
- Pausing while paused fails with `eEnforcedPause`, and unpausing while unpaused
  fails with `eExpectedPause`.
- A flip archives the contract, so outstanding contract IDs and disclosures for
  it go stale. Callers re-read the contract after a pause or an unpause.
- `setPaused`, `pause`, and `unpause` are callable on an interface value, but
  each yields a value and changes nothing, and there is no `create` for an
  interface value. Creating the successor needs the implementing template's
  signatory authority. A party without that authority cannot flip the flag,
  whatever contract its choice runs on.

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
event carrying the new view. There is no event template: the consumer's flip
choice is a node in the transaction tree, recorded with its actor and its ledger time.

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
- After `pause` or `unpause`, the record update in your own `create`
  must leave `paused` alone. The library checks the value it returns, not the
  value you create, so `create r with paused = False` after `pause` is a
  pause that does not pause, with no error. The same update must not change a
  field that determines the signatories or the observers; dropping an observer
  succeeds and silently narrows who sees the paused contract.
- CIP-0112's `pauseInfo` fields are deliberately absent. A registry that must
  serve `reason` and `until` on its metadata endpoint carries them as its own
  template fields beside `paused`, so the whole response still comes from one
  on-ledger contract without freezing those fields into a frozen interface.

## Compatibility

The whole package is frozen at its first upload. Daml interfaces are not
upgradeable through Smart Contract Upgrade: an interface defined in one version
of a package must be absent from every later version. A later version of this
package could upload only without `Pausable`, which is the one thing it
exists to provide, so no later version is published. The guards, the flips,
and the failure statuses ship in the same DAR and run from the same package
ID, so they are frozen with the interface. Any change, including a bug fix in
`pause`, ships as a sibling `openzeppelin-pausable-api-v2` package with module
`OpenZeppelin.PausableV2`, and the two coexist.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` binds your template to one
  package ID, and every participant that runs your gated choices must have
  vetted that package ID.
- Your own template stays upgradeable. The interface instance is declared on
  your template, so you add fields, such as CIP-0112 `pauseInfo`, through Smart
  Contract Upgrade of your package while this package does not move.
- There is no patch release. Adopting a fix means importing the sibling
  package and either of two paths. Under Smart Contract Upgrade of your own
  package, you add a second `interface instance` for its interface; Smart
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
  `pause` and `unpause` recording CIP-0112 `pauseInfo` fields in the
  same transaction as the flip.
