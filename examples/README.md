# Examples

This directory contains standalone consumer projects that integrate packaged
DARs through `data-dependencies`.

Examples serve as executable documentation and integration evidence. Each one
builds against a production DAR and carries a Daml Script that runs its
lifecycle. Examples are never released or uploaded.

Directories group examples by component and never appear in a package name.

## `pausable`

Consumers of `openzeppelin-pausable-api-v1`.

| Example | Shows |
|---|---|
| [`vault`](pausable/vault) | Minimal adoption: the interface instance, the guards, an escape hatch, and the pause authority |
| [`registry`](pausable/registry) | `pause` and `unpause` setting CIP-0112 `pauseInfo` fields in the same transaction as the flip |

## `timelock`

Consumers of `openzeppelin-timelock-api-v1`.

| Example | Shows |
|---|---|
| [`treasury`](timelock/treasury) | A spending limit and a delay policy that change only through timelocked operations: schedule, wait, apply, cancel, expiry cleanup, and self-administration of the delay |

## Build and run

From the repository root, using the package path from `multi-package.yaml`:

```sh
DAML_PACKAGE=examples/pausable/vault dpm build
DAML_PACKAGE=examples/pausable/vault dpm test
```
