# Examples

Integration examples show how to use the library in Daml applications.
Each example builds separately and imports the library DAR through
`data-dependencies`. Each example has a sibling `-test` package for Daml Script
tests. See [CONTRIBUTING.md](../CONTRIBUTING.md) for build and test commands.

## Scoped Authorization Grant

Policy modules define trusted requirements; application choices bind the actor
and apply the guard.

- [Licensing](licensing-app-v1/): delegate issuance on a registry to an operator.
- [Treasury RBAC](treasury-rbac-v1/): reusable role grants, separate authorities,
  and a proposal–approval–execution workflow.

Tests live in
[`licensing-app-v1-test`](licensing-app-v1-test/) and
[`treasury-rbac-v1-test`](treasury-rbac-v1-test/).

## Pausable

Consumers of `openzeppelin-api-pausable-v1` and `openzeppelin-pausable-v1`.

| Example | Tests | Shows |
|---|---|---|
| [`vault`](pausable/vault) | [`vault-test`](pausable/vault-test) | Minimal adoption: the interface instance, the guards, an escape hatch, and the pause authority |
| [`registry`](pausable/registry) | [`registry-test`](pausable/registry-test) | Flip choices that set CIP-0112 `pauseInfo` fields in the same create as the flag |
| [`retrofit-v1-0`](pausable/retrofit-v1-0), [`retrofit-v1-1`](pausable/retrofit-v1-1) | [`retrofit-test`](pausable/retrofit-test) | Adoption in the next SCU version of a template with active contracts |

## Build and run

From the repository root, using the package path from `multi-package.yaml`:

```sh
DAML_PACKAGE=examples/pausable/vault dpm build
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
```
