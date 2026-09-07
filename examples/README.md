# Examples

This directory contains standalone consumer projects that integrate packaged
DARs through `data-dependencies`.

Examples serve as executable documentation and integration evidence. Each one
builds against a production DAR and carries a Daml Script that runs its
lifecycle. Examples are never released or uploaded.

Directories group examples by component and never appear in a package name.

## `tokenCIP112`

Consumers of `openzeppelin-tokenCIP112-v1` and
`openzeppelin-allocation-request-v1`.

| Example | Shows |
|---|---|
| [`trading`](tokenCIP112/trading) | Launching a token from the DAR, allocation requests accepted and funded through the standard interfaces, exact-cover DvP batch settlement, and the iterated-settlement deposit flow |

## Build and run

From the repository root, using the package path from `multi-package.yaml`:

```sh
DAML_PACKAGE=examples/tokenCIP112/trading dpm build
DAML_PACKAGE=examples/tokenCIP112/trading dpm test
```
