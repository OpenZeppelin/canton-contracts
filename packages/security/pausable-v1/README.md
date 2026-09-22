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

Functions over any template that implements `Pausable`:

- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: the flag as a `Bool`, for a choice that branches on the flag
  rather than refusing to run.
- `pause` and `unpause`: the guarded flips. Each checks the guard, sets the
  flag through `setPaused`, verifies it, and returns the template value for
  your choice to create.
- `eEnforcedPause`, `eExpectedPause`, `eFlagNotApplied`, and
  `eImplementerTypeMismatch`: the failure statuses. Each has a stable
  `errorId` under `openzeppelin.com/pausable-`, so an off-ledger client
  matches the id in the `DAML_FAILURE` error, and your tests compare the
  whole value.

## Usage

Your template holds the flag and implements the interface, as the
[`openzeppelin-api-pausable-v1` README](../api-pausable-v1/README.md) shows.
Adopting the functions is three steps.

**1. Guard the choices that a pause must stop.** Call `whenNotPaused this` as
the first statement of every gated choice body. It takes the contract value
the choice runs on, so the caller supplies nothing.

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

`whenPaused this` is the mirror guard for a choice that runs only during an
incident, such as an emergency drain. `isPaused this` returns the flag for a
choice that branches rather than refuses.

**2. Write the flip choices.** Call `pause this` or `unpause this` from a
choice whose controller and body express your pause authority. Each returns
the template value with the new flag, and your choice creates it:

```daml
    choice Vault_Pause : ContractId Vault
      controller admin
      do create =<< Pausable.pause this

    choice Vault_Unpause : ContractId Vault
      controller admin
      do create =<< Pausable.unpause this
```

To change other fields in the same transaction, update the returned value and
create once. Keep `paused` and the fields that determine the signatories and
the observers unchanged in that update.

```daml
    choice Registry_Pause : ContractId Registry
      with reason : Optional Text
      controller admin
      do
        r <- Pausable.pause this
        create r with pauseReason = reason
```

`pause` and `unpause` return a value, and the calling choice performs the
archive and the create. A nonconsuming flip choice calls `archive self`
beside the create.

**3. Assert on the failure statuses in your tests.** A gated choice that runs
while paused fails with `eEnforcedPause`; a paused-only choice that runs while
unpaused fails with `eExpectedPause`. `eFlagNotApplied` and
`eImplementerTypeMismatch` fire only when an interface instance breaks the
`setPaused` rule, so a test that pauses once catches a mis-wired
implementation before it ships:

```daml
Left (FailureStatusError status) <-
  trySubmit owner do exerciseCmd vault Vault_Withdraw with amount = 1.0
status === Pausable.eEnforcedPause
```

A Ledger API or JSON Ledger API client sees the same failure as a
`DAML_FAILURE` error whose `errorId` is
`openzeppelin.com/pausable-enforced-pause`. Match on that id rather than on
the message text.

## Authority and lifecycle

You write the choice that decides who may flip the switch; the package
supplies the flip and the guard. The check runs in the choice body, so any
authority model fits. A role, an M-of-N approval, or a timelock takes the
caller and its credential as choice arguments and checks them before the
flip:

```daml
    choice RoleVault_Pause : ContractId RoleVault
      with
        caller : Party
        credCid : ContractId PauseCredential
      controller caller
      do
        cred <- fetch credCid
        unless (cred.admin == admin) (failWithStatus eWrongCredentialIssuer)
        unless (cred.account == caller) (failWithStatus eCredentialNotCallers)
        create =<< Pausable.pause this
```

- Creating the successor needs the implementing template's signatory
  authority. `pause` on an interface value yields a value and leaves the
  ledger unchanged.
- A flip controller who is not a stakeholder receives the contract through
  disclosure and sees its whole payload.
- A flip archives the contract, so contract IDs and disclosures held for it
  go stale. Callers re-read the contract after a pause or an unpause.

## Scope and security caveats

- Pause is origination control. A gated choice refuses to start while paused,
  and transactions already committed stand.
- A choice is gated only by its own guard call, and the guard checks the flag
  alone. Call `whenNotPaused` first in every choice a pause must stop, and
  keep each choice's controller as its access control.
- After `pause` or `unpause`, the record update in your own `create` must
  keep `paused` as returned. The package verifies the value it returns, so
  `create r with paused = False` after `pause` is a pause that does not
  pause, with no error. The same update must keep the fields that determine
  the signatories and the observers: a changed signatory field fails the
  create, and a dropped observer silently narrows who sees the paused
  contract.
- The `setPaused` caution in the
  [`openzeppelin-api-pausable-v1` README](../api-pausable-v1/README.md)
  applies: `pause` and `unpause` verify the flag alone.

## Compatibility

Daml-LF `2.1`, built with the SDK that
[`multi-package.yaml`](../../../multi-package.yaml) declares.

The package holds functions and values, so a fix ships as a new version under
the same name, and your package picks it up by rebuilding against the new
DAR. The `errorId` of every failure status is stable across versions. The
interface package stays at its frozen version.

Your package binds to one package ID of this package at build time, and the
gated choices run its code, so every participant that runs them vets that
package ID beside the interface package ID.

`0.1.0` is a pre-release: the package ID may change between commits, and no
audit has been performed. See [`RELEASING.md`](../../../RELEASING.md).

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

Runnable consumer projects live under [`examples/pausable/`](../../../examples/pausable/).
