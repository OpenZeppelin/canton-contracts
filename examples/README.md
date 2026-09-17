# Examples

This directory contains standalone consumer projects that integrate packaged
DARs through `data-dependencies`.

Examples serve as executable documentation and integration evidence. Each one
builds against a production DAR. Its templates live in one package, and its
Daml Script tests live in a sibling `-test` package that data-depends on the
example DAR, so the example DAR does not depend on `daml-script`. Examples are
never released or uploaded.

Directories group examples by component and never appear in a package name.

## `pausable`

Consumers of `openzeppelin-api-pausable-v1`.

| Example | Tests | Shows |
|---|---|---|
| [`vault`](pausable/vault) | [`vault-test`](pausable/vault-test) | Minimal adoption: the interface instance, the guards, an escape hatch, and the pause authority |
| [`registry`](pausable/registry) | [`registry-test`](pausable/registry-test) | `pause` and `unpause` setting CIP-0112 `pauseInfo` fields in the same transaction as the flip |

## Build and run

From the repository root, using the package path from `multi-package.yaml`:

```sh
DAML_PACKAGE=examples/pausable/vault dpm build
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
```
