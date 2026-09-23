# Pausable Vault Example

Minimal adoption of `Pausable`: a vault that holds a balance
for one owner, with an emergency stop that the admin controls.

| Field | Value |
|---|---|
| Package | `pausable-vault-example` |
| Module | `OpenZeppelin.Examples.Pausable.Vault` |
| Tests | `OpenZeppelin.Examples.Pausable.VaultTest` in [`vault-test`](../vault-test) |
| Templates | `Vault`, `Payout` |
| Consumes | `openzeppelin-api-pausable-v1` `0.1.0`, `openzeppelin-pausable-v1` `0.1.0` |

## What it shows

- The `interface instance Pausable for Vault` that adopts the switch: one
  line, the view.
- `whenNotPaused this` in a gated choice. The guard reads the contract that the
  choice exercises, so no caller supplies the pause state.
- `whenPaused this` on `Vault_EmergencyDrain`, a recovery path that runs only
  during an incident and moves the balance to the admin as a `Payout`.
- `Vault_Redeem`, the ungated escape hatch: the owner takes the whole balance
  as a `Payout` at any time, paused or not, so the owner's funds stay
  reachable through a pause. Gating is a decision per choice.
- `Vault_Pause` and `Vault_Unpause`, the consumer-written choices that name
  the pause authority.
- An off-ledger read of `PausableView` through the interface, which works
  against every implementing template.

`OpenZeppelin.Examples.Pausable.VaultTest`, in the sibling `vault-test`
package, covers the lifecycle with one script per property: a withdrawal, a
pause, the refused withdrawal, the escape hatch, the recovery path, and the
return to normal operation.

## Authority model

`admin` and `owner` are signatories of `Vault`, and `admin` is the pause
authority. The flip creates the successor contract, which preserves the
signatory set, so the choice already carries the authority the create needs.

The flip choices are consuming. Each guards with `whenNotPaused` or
`whenPaused`, then creates the successor with the flag changed.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/pausable/vault dpm build
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
```
