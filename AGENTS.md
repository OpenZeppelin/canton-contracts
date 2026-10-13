# AGENTS.md - canton-contracts

## Repository role

This repository is the reusable OpenZeppelin Daml contracts library for Canton.
Keep components independent, auditable, and useful outside any single reference
implementation.

Research prototypes, local replicas of upstream standards, interoperability
harnesses, and application-specific business logic belong in `canton-specs` or
the relevant application repository. A component enters this repository only
after its promotion boundary is accepted. Focused integration examples under
`examples/` demonstrate library usage and build separately from the library.

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
- Package names follow these patterns:
  - `openzeppelin-api-<component>-vN`, with modules under
    `OpenZeppelin.Api.<Component>VN`, holds frozen interfaces.
  - `openzeppelin-<component>-vN`, with modules under
    `OpenZeppelin.<Component>VN`, holds templates and serializable types.
  - `openzeppelin-<component>-utils`, with modules under
    `OpenZeppelin.<Component>.Utils`, holds pure functions, failure statuses,
    and reusable `Update` functions such as choice bodies. It is versioned by
    semver only and defines no templates, interfaces, exceptions, or
    serializable types.
  - `openzeppelin-<component>-types-vN`, with modules under `OpenZeppelin.<Component>.TypesVN`, holds records that `-utils` functions read and that templates store.
- `<component>` names the domain and, when the component implements a named
  standard, the standard as a second segment. A multi-segment component maps
  each segment to a module namespace segment, so its templates package sits
  under `OpenZeppelin.<Domain>.<Standard>.VN`. The CIP-0112 token component is
  `token-cip112`: its packages are `openzeppelin-token-cip112-v1`,
  `openzeppelin-token-cip112-utils`, and `openzeppelin-token-cip112-types-v1`,
  with modules under `OpenZeppelin.Token.Cip112.V1`,
  `OpenZeppelin.Token.Cip112.Utils`, and `OpenZeppelin.Token.Cip112.TypesV1`.
  The package `README.md` names the standard it implements.
- A component's templates package may depend on its `-utils` package.
- A component's templates package and its `-utils` package may both depend on its `-types` package.
- A component that defines Daml interfaces or exceptions uses a frozen
  `openzeppelin-api-<component>-vN` package containing no templates. Template-only components do not get empty API packages.
- API packages may depend only on API packages. Implementation packages must not
  depend on other implementation packages without an accepted architecture
  decision; prefer interface composition or consumer-side wiring.
- Production packages must not depend on `daml-script`.
- Test code lives in an isolated `-test` package under the root `test/`,
  `experiments/test/` and `examples/*-test` directories and is never released
  or uploaded.
- Token test packages are named after the package they test plus `-test`.
  Their modules sit under `<Root>.Test`, where `<Root>` is the tested package's
  module root, with one module per suite under `<Root>.Test.<Suite>`: for
  example `OpenZeppelin.Token.Cip112.V1.Test` and `OpenZeppelin.Token.Cip112.V1.Test.Sandbox`.
- Do not use `exposed-modules` as an API boundary. Use documented public modules
  and `.Internal` naming for implementation details.
- Category directories under `packages/` and `experiments/` are navigation only
  and never appear in package names or module namespaces.
- Do not publish upstream Canton or Splice interfaces under an OpenZeppelin
  namespace. Consume exact, verified upstream DARs.

Every production template or interface must document what it adds to
signatories, observers, controllers, choices, disclosure and privacy
expectations, authorization assumptions, archival behavior, failure modes, and
upgrade/migration assumptions. Document only what the component defines or
changes. Do not restate standard Daml or Canton semantics or repository release
policy, and omit a topic where the component adds nothing.

## Daml toolchain

The repository is DPM-native. `multi-package.yaml` declares the workspace SDK,
and every package manifest mirrors that version for standalone builds;
`scripts/check.sh` enforces consistency. Package manifests target
Daml-LF `2.1`. Use `dpm build`, `dpm damlc lint`, `dpm test`, and
`dpm upgrade-check`; do not introduce legacy Daml Assistant commands unless a
documented toolchain decision changes this. For package-scoped commands run from
the repository root, set `DAML_PACKAGE` to the repository-relative package path
instead of using `--package-root`.

## Validation

Run from the repository root:

```sh
dpm build --all
scripts/check.sh
DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm damlc lint
DAML_PACKAGE=packages/security/api-pausable-v1 dpm damlc lint
DAML_PACKAGE=packages/security/pausable-v1 dpm damlc lint
DAML_PACKAGE=packages/token/token-cip112-types-v1 dpm damlc lint
DAML_PACKAGE=packages/token/token-cip112-utils dpm damlc lint
DAML_PACKAGE=packages/token/token-cip112-v1 dpm damlc lint
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm damlc lint
DAML_PACKAGE=test/api-pausable-v1-test dpm damlc lint
DAML_PACKAGE=test/pausable-v1-test dpm damlc lint
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
DAML_PACKAGE=examples/treasury-rbac-v1 dpm damlc lint
DAML_PACKAGE=examples/treasury-rbac-v1-test dpm damlc lint
DAML_PACKAGE=examples/token/token-cip112-trading-test dpm damlc lint
DAML_PACKAGE=examples/token/token-cip112-custom dpm damlc lint
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm damlc lint
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/api-pausable-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/pausable-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/token-cip112-types-v1-test dpm test --all --show-coverage
DAML_PACKAGE=test/token-cip112-utils-test dpm test --all --show-coverage
DAML_PACKAGE=test/token-cip112-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/licensing-app-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/pausable/registry-test dpm test --all
DAML_PACKAGE=examples/pausable/retrofit-test dpm test --all
DAML_PACKAGE=examples/pausable/vault-test dpm test --all
DAML_PACKAGE=examples/treasury-rbac-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/token/token-cip112-trading-test dpm test --all
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test --all
scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=authorization scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=licensing scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=treasury scripts/check-sandbox.sh
```

`scripts/check.sh` enforces package boundaries. Component tests and production
template/choice coverage run directly through DPM; keep `--all` so the report
includes the production DAR dependency.

## Documentation

The root `README.md` is a consumer landing page. It presents the available
production packages, their purpose, how to build and consume them, their
compatibility model, and security guidance. Contributor testing, coverage,
maintenance, and CI instructions belong in `CONTRIBUTING.md` or the workflow
itself; the root `README.md` links to the contributing guide.

All `README.md` files use present-tense, user-facing language that describes the
current repository contents, the purpose of each directory, and supported usage.
Do not describe removed content, previous layouts, rejected alternatives, empty
scaffolding, milestones, internal review context, or planned future work.
Architectural trade-offs and design rationale belong in `ARCHITECTURE.md`.
Security limitations and operational assumptions describe current behavior and
must remain visible in the relevant package `README.md`.

Use repository-relative paths in documentation and configuration. Never include
a developer username, home directory, temporary directory, or another
machine-specific absolute path. Refer to repository files by their exact
filenames, including extensions, and format literal filenames and paths with
backticks. Package `README.md` files document the public module, capabilities,
authority and lifecycle model, build command, consumption example, and security
caveats.

`CHANGELOG.md` contains only user-visible changes to downloadable production
packages and their public APIs. Exclude repository organization, CI, tests,
tooling, and documentation-only changes.

The CI-only `scripts/check-lint.sh`, `scripts/check-coverage.sh`, and
`scripts/check-examples.sh` discover and validate workspace packages. Public
and contributor documentation shows native DPM commands instead of presenting
those helpers as the development interface.
