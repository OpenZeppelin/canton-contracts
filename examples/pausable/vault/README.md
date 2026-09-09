# Pausable Vault Example

Minimal adoption of `openzeppelin-pausable-api-v1`: a vault that holds a balance
for one owner, with an emergency stop that the admin controls.

| Field | Value |
|---|---|
| Package | `pausable-vault-example` |
| Module | `OpenZeppelin.Examples.Pausable.Vault` |
| Tests | `OpenZeppelin.Examples.Pausable.VaultTest` in [`vault-test`](../vault-test) |
| Templates | `Vault`, `Payout` |
| Consumes | `openzeppelin-pausable-api-v1` `0.1.0` |

## What it shows

- The three lines of `interface instance Pausable.Pausable for Vault` that adopt the
  switch: the view, and `setPaused`.
- `whenNotPaused this` in a gated choice. The guard reads the contract that the
  choice exercises, so no caller supplies the pause state.
- `whenPaused this` on `Vault_EmergencyDrain`, a recovery path that runs only
  during an incident and moves the balance to the admin as a `Payout`.
- `Vault_Redeem`, an escape hatch that carries no guard, so a pause does not
  trap the owner's funds: the owner takes the whole balance as a `Payout` at
  any time. Gating is a decision per choice.
- `Vault_Pause` and `Vault_Unpause`, the choices that name the pause authority.
  The library ships none.
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

The pause authority does not have to be a signatory. Any party a controller
expression can name works. A non-stakeholder controller sees the template
payload at flip time, because a controller is an informee of the exercise node.

The flip choices are consuming. `pause` and `unpause` return the
flipped value and archive nothing, so the choice archives the predecessor and
creates the successor.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/pausable/vault dpm build
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
```
