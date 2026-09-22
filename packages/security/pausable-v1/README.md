# Pausable V1

The guards, flips, and failure statuses for the `Pausable` interface in
[`openzeppelin-api-pausable-v1`](../api-pausable-v1/).

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-v1` |
| Public module | `OpenZeppelin.PausableV1` |
| Version | `0.1.0` |
| Depends on | `openzeppelin-api-pausable-v1` `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

Pure functions over any template that implements `Pausable`. The package
defines no template and no interface.

- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: the flag as a pure function, for a choice that branches on the
  flag rather than refusing to run.
- `pause` and `unpause`: the guarded flips. Each checks the guard, sets the
  flag through `setPaused`, verifies it, and returns the template value for
  your choice to create.
- `eEnforcedPause`, `eExpectedPause`, `eFlagNotApplied`, and
  `eImplementerTypeMismatch`: the failure statuses. Each is a `FailureStatus`
  with a stable `errorId` under `openzeppelin.com/pausable-`, so an off-ledger
  client matches the id in the `DAML_FAILURE` error, and your tests compare the
  whole value.

## Usage

Your template already holds the flag and implements the interface, as the
[`openzeppelin-api-pausable-v1` README](../api-pausable-v1/README.md) shows.
Adopting the functions is three steps.

**1. Guard the choices that a pause must stop.** Call `whenNotPaused this` as
the first statement of every gated choice body. It takes the contract value the
choice runs on, never a contract ID, so no caller can hand in a different
switch. A choice without the call is not gated; the library cannot detect the
omission.

```daml
import OpenZeppelin.Api.PausableV1 (Pausable, PausableView (..))
import qualified OpenZeppelin.PausableV1 as Pausable

    choice Vault_Withdraw : ContractId Vault
      with amount : Decimal
      controller owner
      do
        Pausable.whenNotPaused this
        create this with balance = balance - amount
```

`whenPaused this` is the mirror guard for a choice that may run only during an
incident, such as an emergency drain. `isPaused this` returns the flag as a
`Bool` for a choice that branches rather than refuses; it never fails.

**2. Write the flip choices.** Call `pause this` or `unpause this`
from a choice whose controller and body express your pause authority. Each one
checks the guard, verifies that `setPaused` set the flag, and returns the
template value with the new flag. Your choice creates it. A consuming choice
archives the predecessor before the body runs, so this is the whole flip:

```daml
    choice Vault_Pause : ContractId Vault
      controller admin
      do create =<< Pausable.pause this

    choice Vault_Unpause : ContractId Vault
      controller admin
      do create =<< Pausable.unpause this
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
        r <- Pausable.pause this
        create r with pauseReason = reason
```

The choice kind is yours. The functions archive nothing, so a nonconsuming
flip choice must call `archive self` beside the create, as any nonconsuming
choice that replaces its contract must.

**3. Assert on the failure statuses in your tests.** A gated choice that runs
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
status === Pausable.eEnforcedPause
```

A Ledger API or JSON API client sees the same failure as a `DAML_FAILURE` error
whose `errorId` is `openzeppelin.com/pausable-enforced-pause`. Match on that id,
not on the message text.

## Authority and lifecycle

The package ships no access control. You write the choice that decides who
may flip the switch, and the package supplies the flip and the guard. Any
authority model fits, because the check runs in the choice body rather than
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
    create =<< Pausable.pause this
```

- `pause` and `unpause` archive nothing. Your flip choice archives
  the predecessor and creates the successor: a consuming choice does the
  archive itself, and a nonconsuming one calls `archive self`.
- Pausing while paused fails with `eEnforcedPause`, and unpausing while unpaused
  fails with `eExpectedPause`.
- A flip archives the contract, so outstanding contract IDs and disclosures for
  it go stale. Callers re-read the contract after a pause or an unpause.
- `pause` and `unpause` are callable on an interface value, but each yields a
  value and changes nothing, and there is no `create` for an interface value.
  Creating the successor needs the implementing template's signatory
  authority. A party without that authority cannot flip the flag, whatever
  contract its choice runs on.

## Scope and security caveats

- Pause is origination control. A gated choice refuses to start while paused;
  transactions already committed are unaffected, and a flip rejects the
  concurrent operations that were reading the contract.
- Nothing forces a choice to call a guard, and the package does not restrict
  who may call the choices that `whenNotPaused` guards.
- The flag is checked after `setPaused`, and a flip that fails to apply it
  fails with `eFlagNotApplied`, but nothing checks the other fields of the
  returned value.
- After `pause` or `unpause`, the record update in your own `create`
  must leave `paused` alone. The package checks the value it returns, not the
  value you create, so `create r with paused = False` after `pause` is a
  pause that does not pause, with no error. The same update must not change a
  field that determines the signatories or the observers; dropping an observer
  succeeds and silently narrows who sees the paused contract.

## Compatibility

The package holds functions and values only, so it carries no ledger state and
nothing in it is frozen by the interface rule. A fix ships as a new version of
this package under the same name, and your package picks it up by rebuilding
against the new DAR. The `errorId` of every failure status is stable across
versions. The interface package does not move.

Your package binds to one package ID of this package at build time, and the
gated choices run its code, so every participant that runs them must have
vetted that package ID beside the interface package ID.

`0.1.0` is a pre-release and is not for upload to a shared ledger. Until a
tagged release records the DAR in `dars/released/`, the package ID may change
between commits, and no audit has been performed. See
[`RELEASING.md`](../../../RELEASING.md).

## Build

From the repository root, after building `openzeppelin-api-pausable-v1`:

```sh
DAML_PACKAGE=packages/security/api-pausable-v1 dpm build
DAML_PACKAGE=packages/security/pausable-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/api-pausable-v1/.daml/dist/openzeppelin-api-pausable-v1-0.1.0.dar
  - ../canton-contracts/packages/security/pausable-v1/.daml/dist/openzeppelin-pausable-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Api.PausableV1 (Pausable, PausableView (..))
import qualified OpenZeppelin.PausableV1 as Pausable
```

## Examples

Two runnable consumer projects, each building against both DARs through
`data-dependencies`:

- [`examples/pausable/vault`](../../../examples/pausable/vault): minimal
  adoption, the guards, an escape hatch that stays open while paused, and a
  recovery path that runs only while paused.
- [`examples/pausable/registry`](../../../examples/pausable/registry):
  `pause` and `unpause` recording CIP-0112 `pauseInfo` fields in the
  same transaction as the flip.
