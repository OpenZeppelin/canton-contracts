# Contributing

## Development setup

Install DPM and Java 21+. From the repository root, install the Daml SDK declared
by [`multi-package.yaml`](multi-package.yaml), then build and validate the
workspace:

```sh
dpm install
dpm build --all
scripts/check.sh
```

Lint an affected package directly with DPM:

```sh
DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm damlc lint
```

Use the corresponding package path from `multi-package.yaml` for another
production or test package.

Run an affected component's isolated test package directly with DPM:

```sh
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm test --all --show-coverage
```

`--all` includes the production DAR dependency in the coverage report.
Production templates and choices appear under `Modules external to this
package`; test fixtures appear under `Modules internal to this package`. Daml
reports template and choice coverage rather than source-line or branch coverage.
CI validates every production package and requires each production template to
be created and each production choice to be exercised.

`examples/` contains integration examples showing how to use the library.
Each example builds separately and imports the library DAR. Its isolated tests
live under `examples/test/<example>-vN-test`. Run the grant examples with:

```sh
DAML_PACKAGE=examples/test/licensing-app-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/test/treasury-rbac-v1-test dpm test --all --show-coverage
```

Coverage includes the dependency DARs and implicit Archive choices.
See [the authorization test matrix](test/scoped-authorization-grant-v1-test/README.md)
for behavioral and security coverage beyond those metrics.

Run `scripts/check-sandbox.sh` for the token sandbox gate. Set
`OZ_SANDBOX_SUITE` to `authorization`, `licensing`, or `treasury` for the grant
and integration-example Ledger API checks. CI runs all four suites on separate fresh
static-time ledgers.

## Choosing the right repository

This repository accepts reusable Daml library components and focused integration
examples. Broader application implementations, research prototypes,
interoperability experiments, and local replicas of upstream standards belong
elsewhere until their promotion criteria are met.

## Adding or changing a component

- Select one permanent component/SCU lineage per production package.
- Place it under the most useful navigation category without putting the
  category in its package name or module namespace.
- Use a frozen `-api-vN` package only when the component defines Daml interfaces
  or exceptions.
- Keep implementation packages independent of other implementation packages.
- Add an isolated package under `test/<component>-vN-test`, name it with a `-test`
  suffix, and give it no production release path.
- Add or update the package README, authority/privacy documentation, and tests.
  Add a changelog entry only for a user-visible production package or public API
  change.
- Do not introduce `daml-script` into a production package.
- Do not use `exposed-modules` as the public API mechanism.
- Treat any new production dependency as an architecture decision.

Package behavior changes should be separate from mechanical restructuring or
renaming so reviewers can evaluate authorization and ledger effects directly.

## Pull requests

Describe the affected package lineages, compatibility impact, dependency-graph
changes, authority/privacy changes, test evidence, and documentation changes.
Run the repository policy checks and all component test packages before
requesting review.

## Security findings

Do not open public issues for undisclosed vulnerabilities. Follow
[SECURITY.md](SECURITY.md).
