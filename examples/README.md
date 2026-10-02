# Examples

This directory contains standalone consumer projects that integrate packaged
DARs through `data-dependencies`.

Examples serve as executable documentation and integration evidence. Each one
builds against a production DAR and carries a Daml Script that runs its
lifecycle. Examples are never released or uploaded.

Directories group examples by component and never appear in a package name.

## `tokenCIP112`

Consumers of the CIP-0112 packages under `packages/token/` and
`openzeppelin-allocation-request-v1`.

| Example | Shows |
|---|---|
| [`trading`](tokenCIP112/trading/) | Running the default templates of `openzeppelin-tokenCIP112-v1`: launching a token from the DAR, allocation requests accepted and funded through the standard interfaces, exact-cover DvP batch settlement, and the iterated-settlement deposit flow |
| [`custom-token`](tokenCIP112/custom-token/) | A compliance-grade consumer that owns its own holding, instruction, allocation, and registry templates and reuses `openzeppelin-tokenCIP112-workflows-v1` unchanged: roles, an auditor, a compliance freeze enforced through the spend hook, a pause switch, a fee on transfer built from two workflow calls, and an executor allowlist |
| [`custom-token-test`](tokenCIP112/custom-token-test/) | Scripts driving `custom-token` through the standard interfaces and checking each consumer addition |

## Build and run

From the repository root, using the package path from `multi-package.yaml`:

```sh
DAML_PACKAGE=examples/tokenCIP112/trading dpm build
DAML_PACKAGE=examples/tokenCIP112/trading dpm test
```
