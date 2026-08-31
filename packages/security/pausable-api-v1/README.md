# Pausable API V1

A frozen Daml interface that gives a template an emergency-stop switch, modelled
on OpenZeppelin's `Pausable.sol`.

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-api-v1` |
| Public module | `OpenZeppelin.PausableV1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Solidity analogue | `Pausable` |

## What it provides

- `Pausable`: the interface a protected template implements.
- `PausableView`: the pause authority and the flag.
- `Pausable_Pause` and `Pausable_Unpause`: the pauser-controlled switch.
- `Pausable_Paused`: the `paused()` getter, callable by any party that sees the
  contract.
- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: `paused()` as a pure function, for a choice that branches on the
  flag rather than refusing to run.

The package defines no templates, so it carries no ledger state of its own. The
flag lives on the implementing template, which is what binds the switch to the
resource it protects.

## Authority and lifecycle

- `PausableView.pauser` is the only party that may pause or unpause.
- `Pausable_Pause` and `Pausable_Unpause` are consuming. They archive the
  current contract and create its successor through `setPausedImpl`.
- Pausing while paused fails, and unpausing while unpaused fails, matching
  `_pause` and `_unpause` in Solidity.
- The implementer owes exactly one method, `setPausedImpl`, which must re-create
  the contract with the new flag and every other field unchanged.
- A flip archives the contract, so outstanding contract IDs and disclosures for
  it go stale. Callers re-read the contract after a pause or an unpause.

## Security caveats

- The interface constrains the pause authority only. It does not restrict who
  may call the choices that `whenNotPaused` guards.
- `pauser` is one `Party`. A deployment that needs several pausers points the
  field at a party that represents the group.
- Pause is origination control. A gated choice refuses to start while paused;
  transactions already committed are unaffected.

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
