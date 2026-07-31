# AGENTS.md — canton-contracts

## Repository role

This repository is the reusable OpenZeppelin Daml contracts library for Canton.
Keep components independent, auditable, and useful outside any single reference
implementation.

Research prototypes, local replicas of upstream standards, interoperability
harnesses, and application-specific business logic belong in `canton-specs` or
the relevant application repository. A component enters this repository only
after its promotion boundary is accepted.

## Read order

Before changing the repository, read:

1. `README.md`
2. `ARCHITECTURE.md`
3. The affected package `README.md`
4. `CONTRIBUTING.md`
5. `RELEASING.md` when changing package identity or artifacts

All instructions are self-contained in this checkout; do not assume parent
workspace files exist.

## Package rules

- One independently released unit equals one package and one DAR.
- Package names use `openzeppelin-<component>-vN`; module namespaces use
  `OpenZeppelin.<Component>.VN`.
- A component that defines Daml interfaces or exceptions uses a frozen
  `-api-vN` package containing no templates. Template-only components do not get
  empty API packages.
- API packages may depend only on API packages. Implementation packages must not
  depend on other implementation packages without an accepted architecture
  decision; prefer interface composition or consumer-side wiring.
- Production packages must not depend on `daml-script`.
- Test code lives in an isolated `-test` package under the root `test/`
  directory and is never released or uploaded.
- Do not use `exposed-modules` as an API boundary. Use documented public modules
  and `.Internal` naming for implementation details.
- Category directories under `packages/` are navigation only and never appear
  in package names or module namespaces.
- Do not publish upstream Canton or Splice interfaces under an OpenZeppelin
  namespace. Consume exact, verified upstream DARs.

Every production template or interface must document signatories, observers,
controllers, choices, disclosure and privacy expectations, authorization
assumptions, archival behavior, failure modes, and upgrade/migration assumptions.

## Daml toolchain

The repository is DPM-native. `multi-package.yaml` declares the workspace SDK,
and every package manifest mirrors that version because Daml 3.4 requires the
field locally; `scripts/check.sh` enforces consistency. Package manifests target
Daml-LF `2.1`. Use `dpm build`, `dpm test`, and `dpm upgrade-check`; do not
introduce legacy Daml Assistant commands unless a documented toolchain decision
changes this.

## Validation

Run from the repository root:

```sh
scripts/check.sh
scripts/test.sh
```

`scripts/check.sh` enforces the package boundaries. `scripts/test.sh` builds the
multi-package workspace and executes every component test suite with coverage.

## Documentation

The root README is for consumers. Do not add milestone-review language, internal
delivery shorthand, stale generated hashes, or commands that require an absent
parent workspace. Package-specific behavior and caveats belong beside the
package's `daml.yaml`.
