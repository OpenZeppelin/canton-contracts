# OpenZeppelin Contracts for Canton

[![CI](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Reusable, security-focused Daml packages for applications on Canton.
Each component is an independent Daml package so applications can build, review,
upload, and vet only the DARs they need.

> [!WARNING]
> This is experimental software and is provided on an "as is" and "as available"
> basis. We do not give any warranties and will not be liable for any losses
> incurred through any use of this code base.

## Packages

| Component | Package | Public module | Status |
|---|---|---|---|
| [Access Control](packages/access/access-control-v1/) | `openzeppelin-access-control-v1` | `OpenZeppelin.AccessControl.V1` | Experimental; unaudited |
| [Ownable](packages/access/ownable-v1/) | `openzeppelin-ownable-v1` | `OpenZeppelin.Ownable.V1` | Experimental; unaudited |
| [Pausable](packages/security/pausable-v1/) | `openzeppelin-pausable-v1` | `OpenZeppelin.Pausable.V1` | Experimental; unaudited |

There is no umbrella package. A DAR contains its transitive package closure, so
bundling unrelated components permanently couples their dependency,
upgrade, audit, and vetting surfaces.

## Get started

### Requirements

- DPM
- Java 21

The workspace declares its Daml SDK in
[`multi-package.yaml`](multi-package.yaml). Package manifests mirror that value
for Daml 3.4 compatibility, and repository checks keep them synchronized.

The [Canton building and packaging guide](https://docs.canton.network/appdev/modules/m3-building-packaging)
explains DPM workspaces, DARs, and `data-dependencies`.

```sh
git clone https://github.com/OpenZeppelin/canton-contracts.git
cd canton-contracts
dpm install package
scripts/check.sh
scripts/test.sh
```

`scripts/test.sh` builds every package and runs each component's isolated Daml
Script suite. Test packages depend on `daml-script`; production packages do not,
and test DARs must never be uploaded to a production participant.

To build one component independently:

```sh
cd packages/access/ownable-v1
dpm build
```

The resulting evaluation DAR is written to:

```text
packages/access/ownable-v1/.daml/dist/openzeppelin-ownable-v1-0.1.0.dar
```

## Consume a local build

Build a package from a pinned source commit and reference the resulting DAR from
a separate Daml project:

```yaml
dependencies:
  - daml-prim
  - daml-stdlib
data-dependencies:
  - /absolute/path/to/canton-contracts/packages/access/ownable-v1/.daml/dist/openzeppelin-ownable-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Ownable.V1
```

## Repository layout

```text
packages/
  access/                 Category for authorization and ownership components
  security/               Category for operational security components
test/                     Isolated, never-released component test packages
dars/
  released/               Immutable OpenZeppelin release baselines
  vendor/                 Verified third-party DAR inputs
examples/                 Standalone projects that consume packaged DARs
audits/                   Reports keyed to exact package releases
scripts/                  Repository checks and test entrypoints
```

Category directories are navigation only. They do not appear in package names,
module namespaces, dependencies, or DAR identity, so moving a component between
categories does not create a new package lineage.

## Package and compatibility model

- One independently released unit is one Daml package and one DAR.
- Components defining Daml interfaces use a frozen `-api-vN` package and a
  separate upgradeable implementation package. No empty API package is created
  for template-only components.
- Breaking changes create a sibling `-v2` package and `.V2` module namespace;
  compatible SCU releases retain the existing package name.
- Implementation packages do not depend on other implementation packages.
  Composition happens through interfaces or in the consuming application.
- `.Internal` communicates a non-public module; `exposed-modules` is not used as
  an API boundary because consumers normally import compiled DARs.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full rationale and dependency
rules, and [RELEASING.md](RELEASING.md) for release process guidance.

## Security

These packages are building blocks, not complete applications. A consuming
application remains responsible for selecting canonical contract instances,
binding authority and state to the correct resource, managing disclosure, and
reviewing its complete dependency graph.

Do not use a library candidate as a substitute for an application-specific
security review. See [SECURITY.md](SECURITY.md) to report a vulnerability
privately.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, package boundaries,
testing requirements, and the checklist for new components.

## Related projects

- [Canton Improvement Proposals](https://github.com/canton-foundation/cips) — canonical Canton standards
- [OpenZeppelin Canton specs](https://github.com/OpenZeppelin/canton-specs) — research, prototypes, reference architectures, and interoperability evidence
- [OpenZeppelin Canton ecosystem-stack proposal](https://github.com/canton-foundation/canton-dev-fund/blob/main/proposals/2026-04-OpenZeppelin-canton-ecosystem-stack.md) — ecosystem program context

## License

[MIT](LICENSE)
