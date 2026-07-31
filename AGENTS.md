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
- Package names use `openzeppelin-<component>-vN`; module names use
  `OpenZeppelin.<Component>VN`.
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
dpm build --all
scripts/check.sh
dpm test --package-root test/access-control-v1 --all --show-coverage
dpm test --package-root test/ownable-v1 --all --show-coverage
dpm test --package-root test/pausable-v1 --all --show-coverage
```

`scripts/check.sh` enforces package boundaries. Component tests and production
template/choice coverage run directly through DPM; keep `--all` so the report
includes the production DAR dependency.

## Documentation

The root README is a consumer landing page. It presents the available production
packages, their purpose, how to build and consume them, their compatibility
model, and security guidance. Contributor testing, coverage, maintenance, and CI
instructions belong in `CONTRIBUTING.md` or the workflow itself; the root README
links to the contributing guide.

All READMEs use present-tense, user-facing language that describes the current
repository contents, the purpose of each directory, and supported usage. Do not
describe removed content, previous layouts, rejected alternatives, empty
scaffolding, milestones, internal review context, or planned future work.
Architectural trade-offs and design rationale belong in `ARCHITECTURE.md`.
Security limitations and operational assumptions describe current behavior and
must remain visible in the relevant package README.

Use repository-relative paths in documentation and configuration. Never include
a developer username, home directory, temporary directory, or another
machine-specific absolute path. Package READMEs document the public module,
capabilities, authority and lifecycle model, build command, consumption example,
and security caveats.

`CHANGELOG.md` contains only user-visible changes to downloadable production
packages and their public APIs. Exclude repository organization, CI, tests,
tooling, and documentation-only changes.

The CI-only `scripts/check-coverage.sh` discovers and validates every production
package. Public and contributor documentation shows native DPM commands instead
of presenting that helper as the testing interface.
