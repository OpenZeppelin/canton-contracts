# Contributing

## Development setup

Install DPM and Java 21. From the repository root, install the Daml SDK declared
by [`multi-package.yaml`](multi-package.yaml), then run the validation scripts:

```sh
dpm install package
scripts/check.sh
scripts/test.sh
```

## Choosing the right repository

This repository accepts reusable Daml library components. Research prototypes,
reference implementations, interoperability experiments, and local replicas of
upstream standards belong elsewhere until their promotion criteria are met.

## Adding or changing a component

- Select one permanent component/SCU lineage per production package.
- Place it under the most useful navigation category without putting the
  category in its package name or module namespace.
- Use a frozen `-api-vN` package only when the component defines Daml interfaces
  or exceptions.
- Keep implementation packages independent of other implementation packages.
- Add an isolated package under `test/<component>-vN`, name it with a `-test`
  suffix, and give it no production release path.
- Add or update the package README, authority/privacy documentation, tests, and
  changelog entry.
- Do not introduce `daml-script` into a production package.
- Do not use `exposed-modules` as the public API mechanism.
- Treat any new production dependency as an architecture decision.

Package behavior changes should be separate from mechanical restructuring or
renaming so reviewers can evaluate authorization and ledger effects directly.

## Pull requests

Describe the affected package lineages, compatibility impact, dependency-graph
changes, authority/privacy changes, test evidence, and documentation changes.
Run both repository entrypoints before requesting review.

## Security findings

Do not open public issues for undisclosed vulnerabilities. Follow
[SECURITY.md](SECURITY.md).
