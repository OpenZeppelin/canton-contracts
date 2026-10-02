# Pausable Registry Example

Adoption of `Pausable` by a registry that serves CIP-0112
metadata. The pause records why it is in force, in the same transaction as the
flip.

| Field | Value |
|---|---|
| Package | `pausable-registry-example` |
| Module | `OpenZeppelin.Examples.Pausable.Registry` |
| Tests | `OpenZeppelin.Examples.Pausable.RegistryTest` in [`registry-test`](../registry-test) |
| Consumes | `openzeppelin-api-pausable-v1` `0.1.0`, `openzeppelin-pausable-v1` `0.1.0` |

## What it shows

- Flip choices that set `paused`, `pauseReason`, and `pauseUntil` in one
  create, after the library guard.
- `Registry_UpdatePauseInfo`, guarded with `whenPaused`, which changes the
  reason and the deadline while the pause stays in force.
- `pauseInfo.reason` and `pauseInfo.until` as fields of the registry.
  `PausableView` carries `paused` alone, so when CIP-0112 extends `PauseInfo`
  the registry adds a field under Smart Contract Upgrade and the interface
  stays frozen.
- One on-ledger contract answering the whole metadata response: the flag and the
  reason live on the same contract that the gated choices exercise.

`OpenZeppelin.Examples.Pausable.RegistryTest`, in the sibling `registry-test`
package, covers the lifecycle with one script per property: a registration, a
pause with a reason and a deadline, the refused registration and the unchanged
view, then an unpause that clears the recorded fields.

## Authority model

`admin` is the sole signatory of `Registry` and the pause authority. The flip
choices are consuming: each guards, then creates the successor with the flag
and its metadata changed. `auditor` is an observer that reads the registry
and its `PausableView`.

## The deadline

`pauseUntil` is published for reporting. The guard reads `paused` alone, so
the pause ends when `admin` exercises `Registry_Unpause`. `admin` extends the
published deadline with `Registry_UpdatePauseInfo`. A pause that expires on
its own is a feature the consumer writes, with its own rule for who may
extend it.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/pausable/registry dpm build
DAML_PACKAGE=examples/pausable/registry-test dpm test --all
```
