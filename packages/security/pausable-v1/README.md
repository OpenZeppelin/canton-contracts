# Pausable V1

The guards and failure statuses for the `Pausable` interface in
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
- `eEnforcedPause` and `eExpectedPause`: the failure statuses. Each has a
  stable `errorId` under `openzeppelin.com/pausable-`, so an off-ledger
  client matches the id in the `DAML_FAILURE` error, and your tests compare
  the whole value.

`OpenZeppelin.PausableV1.Internal` is not public API. Its contents can change
in any version, so do not import it.

## Usage

Your template holds the flag and implements the interface, as the
[`openzeppelin-api-pausable-v1` README](../api-pausable-v1/README.md) shows.
Adopting the functions is three steps.

**1. Guard the choices that a pause must stop.** Call `whenNotPaused this` in
every gated choice body, before the choice changes state. It takes the
contract value the choice runs on, so the caller supplies nothing.

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

**2. Write the flip choices.** A flip is a choice whose controller and body
express your pause authority. It guards with `whenNotPaused` or `whenPaused`,
then creates the successor with `paused` changed:

```daml
    choice Vault_Pause : ContractId Vault
      controller admin
      do
        Pausable.whenNotPaused this
        create this with paused = True

    choice Vault_Unpause : ContractId Vault
      controller admin
      do
        Pausable.whenPaused this
        create this with paused = False
```

The flip choice is consuming, or calls `archive self` beside the create, so
one contract stays active after the flip.

To change other fields in the same transaction, set them in the same create.

```daml
    choice Registry_Pause : ContractId Registry
      with reason : Optional Text
      controller admin
      do
        Pausable.whenNotPaused this
        create this with paused = True, pauseReason = reason
```

**3. Assert on the failure statuses in your tests.** A gated choice that runs
while paused fails with `eEnforcedPause`; a paused-only choice that runs while
unpaused fails with `eExpectedPause`. A flip choice that guards as above
refuses a second pause or a second unpause with the same statuses:

```daml
Left (FailureStatusError status) <-
  trySubmit owner do exerciseCmd vault Vault_Withdraw with amount = 1.0
status === Pausable.eEnforcedPause
```

Test one round trip as well: after a pause, the predecessor id returns `None`
from `queryContractId` and the successor's view reads `paused = True`; after
an unpause, the mirror.

A Ledger API or JSON Ledger API client sees the same failure as a
`DAML_FAILURE` error whose `errorId` is
`openzeppelin.com/pausable-enforced-pause`. Match on that id rather than on
the message text.

## Authority and lifecycle

You write the choice that decides who may flip the switch; the package
supplies the guard. The check runs in the choice body, so any authority
model fits. A role, an M-of-N approval, or a timelock takes the
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
        Pausable.whenNotPaused this
        create this with paused = True
```

The interface defines no choice (other than the implicit `Archive`), so a party
that holds only a `ContractId Pausable` cannot flip the flag.

## Scope and security caveats

- Pause is origination control: a gated choice refuses to start while
  paused.
- A choice is gated only by its own guard call, and the guard checks the flag
  alone. Call `whenNotPaused` before the state change in every choice a pause
  must stop, and keep each choice's controller as its access control.
- The implementing template's `Archive` carries no guard, so its signatories
  archive a paused contract. They can also create it again with any flag
  value, which skips the flip choice and its authority checks. Make every
  signatory part of your pause authority model, or trust it with the flag.
- Pass `this` to guards. A `Pausable` value fetched from a contract id the
  caller supplies is the caller's choice of switch: the caller presents an
  unpaused contract and the gated choice runs, with no error.

## Compatibility

Daml-LF `2.1`, built with the SDK that
[`multi-package.yaml`](../../../multi-package.yaml) declares.

Your package picks up a fix to this package in its next Smart Contract
Upgrade version, built against the new DAR. The fix reaches only exercises
that run your new version. A submission that selects your old version still
runs the old guard, so unvet the old version of your package to remove it. The `errorId` of every failure status is stable across
versions.

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
