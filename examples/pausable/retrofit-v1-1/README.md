# Pausable Retrofit Example

A template that adopts `Pausable` in its next Smart Contract Upgrade (SCU)
version. [`retrofit-v1-0`](../retrofit-v1-0) is version `1.0.0`, without the
switch. This package is version `1.1.0`, which adds the flag and the interface
instance.

| Field | Value |
|---|---|
| Package | `pausable-retrofit-example` `1.0.0` and `1.1.0` |
| Module | `OpenZeppelin.Examples.Pausable.Retrofit` |
| Tests | `OpenZeppelin.Examples.Pausable.RetrofitTest` in [`retrofit-test`](../retrofit-test) |
| Consumes | `openzeppelin-api-pausable-v1` `0.1.0`, `openzeppelin-pausable-v1` `0.1.0` |

## What it shows

- The flag as `paused : Optional Bool` at the end of the record. Contracts
  created under `1.0.0` hold `None`, and the view reads `None` as unpaused.
- The flip choices create with `paused = Some True` and `paused = Some False`.
- The build option `-Wno-template-has-new-interface-instance`, which the SCU
  check needs to accept the new interface instance.

## Build and run

From the repository root:

```sh
dpm build --all
DAML_PACKAGE=examples/pausable/retrofit-test dpm test --all
```
