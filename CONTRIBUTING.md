# Contributing

## Code quality standards

[`GUIDELINES.md`](GUIDELINES.md) is the single source of truth for how Daml is written in this
repository: naming, layout, imports, types, functions and errors, idioms, testing, linting,
and documentation. [`ARCHITECTURE.md`](ARCHITECTURE.md) holds the package rules and their
reasons: package boundaries and the dependency policy. This file
holds the commands and the process, and restates no rule.

A change is ready for review when:

- it follows `GUIDELINES.md` and `ARCHITECTURE.md`;
- `dpm build --all`, `scripts/check.sh`, and `dpm damlc lint` on each affected package pass;
- every new or changed behavior has tests, as the "Testing" section of `GUIDELINES.md`
  describes;
- the coverage gate below passes.

**The coverage gate.** CI validates every production package and requires each production
template to be created and each production choice to be exercised, including the implicit
`Archive`. Daml reports template and choice coverage. It does not report source-line or branch
coverage, so the gate is a lower bound. The tests that `GUIDELINES.md` asks for are what cover
the branches.

For a package without templates, such as `packages/security/api-pausable-v1` or
`packages/security/pausable-utils`, the report shows zero production templates and zero
production choices, so it proves nothing about the package. The isolated test package is the
whole evidence for such a package.

CI runs the example tests without the coverage gate, because examples are not released.

## Development setup

Install DPM and Java 21+. From the repository root, install the Daml SDK declared
by [`multi-package.yaml`](multi-package.yaml), then build and validate the
workspace:

```sh
dpm install
dpm build --all
scripts/check.sh
```

`scripts/check.sh` enforces the package rules of `ARCHITECTURE.md` and the test-package and
manifest rules of `GUIDELINES.md`. It reads compiled DARs, so run it after `dpm build --all`.

## A typical workflow

The repository is DPM-native. Use `dpm build`, `dpm damlc lint`, `dpm test`, and
`dpm upgrade-check`. Do not introduce legacy Daml Assistant commands unless a documented
toolchain decision changes this.

Run every command from the repository root. To scope a command to one package, set
`DAML_PACKAGE` to the package path from `multi-package.yaml`. Do not use `--package-root`.

Lint an affected package:

```sh
DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm damlc lint
```

Run an affected component's test package with its coverage report:

```sh
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm test --all --show-coverage
```

`--all` includes the production DAR dependency in the coverage report. Production templates
and choices appear under `Modules external to this package`. Test fixtures appear under
`Modules internal to this package`.

Run an example's tests:

```sh
DAML_PACKAGE=examples/licensing-app-v1-test dpm test --all
```

`examples/` contains integration examples showing how to use the library. Each example builds
separately and imports the library DAR. Its test package lives beside it, with a `-test`
suffix.

Run the Ledger API checks against a Canton sandbox:

```sh
scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=authorization scripts/check-sandbox.sh
```

`scripts/check-sandbox.sh` runs the token suite. Set `OZ_SANDBOX_SUITE` to `authorization`,
`licensing`, or `treasury` for the grant and integration-example suites. CI runs all four on
separate fresh static-time ledgers.

The CI-only `scripts/check-lint.sh`, `scripts/check-coverage.sh`, and
`scripts/check-examples.sh` discover and validate every workspace package. Use the native DPM
commands above during development.

### Full validation

Before requesting review of a change that touches several packages, run everything:

```sh
dpm build --all
scripts/check.sh
DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm damlc lint
DAML_PACKAGE=packages/security/api-pausable-v1 dpm damlc lint
DAML_PACKAGE=packages/security/pausable-utils dpm damlc lint
DAML_PACKAGE=packages/security/api-timelock-v1 dpm damlc lint
DAML_PACKAGE=packages/security/timelock-utils dpm damlc lint
DAML_PACKAGE=packages/token/token-cip112-types-v1 dpm damlc lint
DAML_PACKAGE=packages/token/token-cip112-utils dpm damlc lint
DAML_PACKAGE=packages/token/token-cip112-v1 dpm damlc lint
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm damlc lint
DAML_PACKAGE=test/api-pausable-v1-test dpm damlc lint
DAML_PACKAGE=test/pausable-utils-test dpm damlc lint
DAML_PACKAGE=test/api-timelock-v1-test dpm damlc lint
DAML_PACKAGE=test/timelock-utils-test dpm damlc lint
DAML_PACKAGE=test/token-cip112-types-v1-test dpm damlc lint
DAML_PACKAGE=test/token-cip112-utils-test dpm damlc lint
DAML_PACKAGE=test/token-cip112-v1-test dpm damlc lint
DAML_PACKAGE=examples/licensing-app-v1 dpm damlc lint
DAML_PACKAGE=examples/licensing-app-v1-test dpm damlc lint
DAML_PACKAGE=examples/pausable/registry dpm damlc lint
DAML_PACKAGE=examples/pausable/registry-test dpm damlc lint
DAML_PACKAGE=examples/pausable/retrofit-v1-0 dpm damlc lint
DAML_PACKAGE=examples/pausable/retrofit-v1-1 dpm damlc lint
DAML_PACKAGE=examples/pausable/retrofit-test dpm damlc lint
DAML_PACKAGE=examples/pausable/vault dpm damlc lint
DAML_PACKAGE=examples/pausable/vault-test dpm damlc lint
DAML_PACKAGE=examples/timelock/treasury dpm damlc lint
DAML_PACKAGE=examples/timelock/treasury-test dpm damlc lint
DAML_PACKAGE=examples/treasury-rbac-v1 dpm damlc lint
DAML_PACKAGE=examples/treasury-rbac-v1-test dpm damlc lint
DAML_PACKAGE=examples/token/token-cip112-trading-test dpm damlc lint
DAML_PACKAGE=examples/token/token-cip112-custom dpm damlc lint
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm damlc lint
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/api-pausable-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/pausable-utils-test dpm test --all --show-coverage
DAML_PACKAGE=test/api-timelock-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/timelock-utils-test dpm test --all --show-coverage
DAML_PACKAGE=test/token-cip112-types-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/token-cip112-utils-test dpm test --all --show-coverage
DAML_PACKAGE=test/token-cip112-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/licensing-app-v1-test dpm test --all
DAML_PACKAGE=examples/pausable/registry-test dpm test --all
DAML_PACKAGE=examples/pausable/retrofit-test dpm test --all
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
DAML_PACKAGE=examples/timelock/treasury-test dpm test --all
DAML_PACKAGE=examples/treasury-rbac-v1-test dpm test --all
DAML_PACKAGE=examples/token/token-cip112-trading-test dpm test --all
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test --all
scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=authorization scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=licensing scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=treasury scripts/check-sandbox.sh
```

Keep `--all` on the component test commands so the report includes the production DAR
dependency.

## API documentation

Generate the API reference for a package from the repository root, for example:

```sh
DAML_PACKAGE=packages/security/api-pausable-v1 dpm damlc docs \
  --output build/docs/api-pausable-v1 --format md --doc-ext md \
  packages/security/api-pausable-v1/daml/OpenZeppelin/Api/PausableV1.daml
```

Pass every source file of the package, because a file renders only its own
module. The "Documentation" section of `GUIDELINES.md` says when to run it and where each
kind of comment goes.

## Adding or changing a component

- Select one permanent component/SCU lineage per production package.
- Place it under the most useful navigation category.
- Name its packages as the "Naming" section of `GUIDELINES.md` describes, and structure them
  as `ARCHITECTURE.md` describes.
- Add or update the tests, the package `README.md`, and `CHANGELOG.md`, as `GUIDELINES.md`
  describes.
- Treat any new production dependency as an architecture decision. Raise it in the pull
  request description.

Keep a change to package behavior separate from mechanical restructuring or renaming, so
reviewers can evaluate authorization and ledger effects directly.

## Pull requests

Describe the affected package lineages, compatibility impact, dependency-graph
changes, authority/privacy changes, test evidence, and documentation changes.
Run the repository policy checks and all component test packages before
requesting review.

## Security findings

Do not open public issues for undisclosed vulnerabilities. Follow
[SECURITY.md](SECURITY.md).
