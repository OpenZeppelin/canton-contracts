# OpenZeppelin Contracts for Canton

[![CI](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/ci.yml)
[![Choice coverage](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/coverage.yml/badge.svg?branch=main&event=push)](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/coverage.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Reusable, security-focused Daml packages for applications on Canton.
Each component is an independent Daml package so applications can build, review,
upload, and vet only the DARs they need.

> [!WARNING]
> This is experimental software and is provided on an "as is" and "as available"
> basis. We do not give any warranties and will not be liable for any losses
> incurred through any use of this code base.

## Packages

No component has been released or audited yet. Scoped Authorization Grant is a
library candidate under `packages/`. Earlier designs remain under
[`experiments/`](experiments/); their APIs and package identities are unstable.

| Component | Package | Public module | Status |
|---|---|---|---|
| [Scoped Authorization Grant](packages/access/scoped-authorization-grant-v1/) | `openzeppelin-scoped-authorization-grant-v1` | `OpenZeppelin.ScopedAuthorizationGrantV1` | Candidate; unaudited |
| [Pausable](experiments/security/pausable-v1/) | `openzeppelin-pausable-v1` | `OpenZeppelin.PausableV1` | Experimental; unaudited |

Each component is a separate dependency and release unit. Applications select
the components they use, and participant operators review and vet the matching
package IDs.

## Get started

### Requirements

- DPM
- Java 21+

The workspace declares its Daml SDK in
[`multi-package.yaml`](multi-package.yaml). Package manifests mirror that value
for standalone builds, and repository checks keep them synchronized. The SDK is
3.5.8; packages target LF 2.1.

The [Canton building and packaging guide](https://docs.canton.network/appdev/modules/m3-building-packaging)
explains DPM workspaces, DARs, and `data-dependencies`.

```sh
git clone https://github.com/OpenZeppelin/canton-contracts.git
cd canton-contracts
dpm install
dpm build --all
```

To build one component independently:

```sh
DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm build
```

The resulting evaluation DAR is written to:

```text
packages/access/scoped-authorization-grant-v1/.daml/dist/openzeppelin-scoped-authorization-grant-v1-0.1.0.dar
```

## Consume a local build

Build a package from a pinned source commit and reference the resulting DAR from
a separate Daml project:

```yaml
dependencies:
  - daml-prim
  - daml-stdlib
data-dependencies:
  - ../canton-contracts/packages/access/scoped-authorization-grant-v1/.daml/dist/openzeppelin-scoped-authorization-grant-v1-0.1.0.dar
```

```daml
import qualified OpenZeppelin.ScopedAuthorizationGrantV1 as SAG
```

## Repository layout

```text
packages/                 Library components and release candidates
test/                     Isolated library test packages
experiments/
  security/               Category for operational security components
  token/                  Category for token components
  test/                   Isolated component test packages
dars/
  released/               Immutable OpenZeppelin release baselines
  vendor/                 Verified third-party DAR inputs
examples/                 Integration examples demonstrating library usage
  test/                   Isolated integration-example test packages
audits/                   Reports keyed to exact package releases
scripts/                  Repository validation tooling
```

Category directories organize related components for navigation. Package names,
module names, dependency declarations, and DAR identity define each component's
release lineage.

## Package and compatibility model

- One independently released unit is one Daml package and one DAR.
- Components defining Daml interfaces use a frozen `-api-vN` package and a
  separate upgradeable implementation package. Template-only components use one
  implementation package.
- Breaking changes create a sibling `-v2` package and `V2` module suffix;
  compatible SCU releases retain the existing package name.
- Composition between implementations happens through interfaces or in the
  consuming application.
- Documented modules form the public API; implementation details use an
  `.Internal` suffix.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full rationale and dependency
rules, and [RELEASING.md](RELEASING.md) for release process guidance.

## Security

These packages provide reusable building blocks. A consuming application is
responsible for selecting canonical contract instances, binding authority and
state to the correct resource, managing disclosure, and reviewing its complete
dependency graph.

Do not use a library candidate as a substitute for an application-specific
security review. See [SECURITY.md](SECURITY.md) to report a vulnerability
privately.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, package boundaries,
testing requirements, and the checklist for new components.

## Related projects

- [Canton Improvement Proposals](https://github.com/canton-foundation/cips) - canonical Canton standards
- [OpenZeppelin Canton specs](https://github.com/OpenZeppelin/canton-specs) - research, prototypes, reference architectures, and interoperability evidence
- [OpenZeppelin Canton ecosystem-stack proposal](https://github.com/canton-foundation/canton-dev-fund/blob/main/proposals/2026-04-OpenZeppelin-canton-ecosystem-stack.md) - ecosystem program context

## License

[MIT](LICENSE)
