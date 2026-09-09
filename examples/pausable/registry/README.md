# Pausable Registry Example

Adoption of `openzeppelin-pausable-api-v1` by a registry that serves CIP-0112
metadata. The pause records why it is in force, in the same transaction as the
flip.

| Field | Value |
|---|---|
| Package | `pausable-registry-example` |
| Modules | `MyApp.Registry`, `MyApp.RegistryDemo` |
| Consumes | `openzeppelin-pausable-api-v1` `0.1.0` |

## What it shows

- `pause` and `unpause`. The library guards, sets the flag, and
  returns the value; the consuming choice sets `pauseReason` and
  `pauseUntil` on the value and creates once, through the library rather than
  around it.
- `pauseInfo.reason` and `pauseInfo.until` as fields of the registry rather than
  of the frozen interface. `PausableView` carries `paused` alone, so the
  interface does not move when CIP-0112 extends `PauseInfo`; the registry adds a
  field under Smart Contract Upgrade instead.
- One on-ledger contract answering the whole metadata response: the flag and the
  reason live on the same contract that the gated choices exercise.

`MyApp.RegistryDemo` registers an entry, pauses with a reason and a deadline,
shows the refused registration and the unchanged view, then unpauses and clears
the recorded fields.

## Authority model

`admin` is the sole signatory of `Registry` and the pause authority. The flip
choices are consuming: `pause` and `unpause` return a value and
archive nothing, so the choice archives the predecessor and creates once.
`auditor` is an observer. It reads the registry and its `PausableView` and
controls no choice.

## Reporting, not enforcement

`pauseUntil` is published for reporting. Nothing in this example enforces it,
and the library keeps ledger time out of the guard. A pause that expires on its
own is a feature the consumer writes, and it raises questions this example does
not answer, such as who may extend a pause.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/pausable/registry dpm build
DAML_PACKAGE=examples/pausable/registry dpm test
```
