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

Consumers of `openzeppelin-api-pausable-v1` and `openzeppelin-pausable-utils`.

| Example | Tests | Shows |
|---|---|---|
| [`vault`](pausable/vault) | [`vault-test`](pausable/vault-test) | Minimal adoption: the interface instance, the guards, an escape hatch, and the pause authority |
| [`registry`](pausable/registry) | [`registry-test`](pausable/registry-test) | Flip choices that set CIP-0112 `pauseInfo` fields in the same create as the flag |
| [`retrofit-v1-0`](pausable/retrofit-v1-0), [`retrofit-v1-1`](pausable/retrofit-v1-1) | [`retrofit-test`](pausable/retrofit-test) | Adoption in the next SCU version of a template with active contracts |

## `timelock`

Consumers of `openzeppelin-api-timelock-v1` and `openzeppelin-timelock-utils`.

| Example | Tests | Shows |
|---|---|---|
| [`treasury`](timelock/treasury) | [`treasury-test`](timelock/treasury-test) | A timelock, a governed config, and a treasury on separate contracts. The spending limit and the delay policy change only through timelocked operations: schedule, wait, apply, cancel, expiry cleanup, and self-administration of the delay |

## Token CIP-0112

Consumers of `openzeppelin-token-cip112-v1`, `openzeppelin-token-cip112-types-v1`,
and `openzeppelin-token-cip112-utils`.

| Example | Tests | Shows |
|---|---|---|
| [`token-cip112-trading-test`](token/token-cip112-trading-test/) | scripts only | Running the default templates of `openzeppelin-token-cip112-v1`: launching a token from the DAR, allocations funded through the standard factory, exact-cover DvP batch settlement, and the iterated-settlement deposit flow |
| [`token-cip112-custom`](token/token-cip112-custom/) | [`token-cip112-custom-test`](token/token-cip112-custom-test/) | A compliance-grade consumer that owns its own holding, instruction, allocation, and registry templates and reuses `openzeppelin-token-cip112-types-v1` and `openzeppelin-token-cip112-utils` unchanged: roles that bind the admin through a co-signing pauser, an auditor, a per-account compliance freeze enforced through every consumption operation, with each batch authorizer's status forwarded through the settlement selector, a pause switch checked again on accept and settle, a fee on transfer built from two workflow calls, and an executor allowlist |

## Async vault

Consumers of `openzeppelin-async-vault-v1`,
`openzeppelin-async-vault-permits-v1`, `openzeppelin-async-vault-types-v1`,
and `openzeppelin-async-vault-utils`.

| Example | Tests | Shows |
|---|---|---|
| [`async-vault-fund-test`](vault/async-vault-fund-test/) | scripts only | Running the default templates of `openzeppelin-async-vault-v1` end to end with `openzeppelin-async-vault-permits-v1` as the deposit gate and `openzeppelin-token-cip112-v1` as the registry of both instruments: a validator enabling depositors, requests made alone by disclosure, batches at a price within the admin's band, a deposit paying a redemption, and a validator's withdrawal |
| [`async-vault-custom`](vault/async-vault-custom/) | [`async-vault-custom-test`](vault/async-vault-custom-test/) | A lending pool that owns its rules, ledger, and request templates and reuses `openzeppelin-async-vault-types-v1` and `openzeppelin-async-vault-utils` unchanged: a smallest deposit, a price that never falls and rises by a bounded step per batch, and a limit on what one batch pays out to redemptions |

## Build and run

From the repository root, using the package path from `multi-package.yaml`:

```sh
DAML_PACKAGE=examples/pausable/vault dpm build
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
```
