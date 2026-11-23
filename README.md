# OpenZeppelin Contracts for Canton

[![CI](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/ci.yml)
[![Choice Coverage](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/test.yml/badge.svg?branch=main&event=push)](https://github.com/OpenZeppelin/canton-contracts/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Reusable, security-focused Daml packages for applications on Canton.
Each component is an independent Daml package so applications can build, review,
upload, and vet only the DARs they need.

> [!WARNING]
> This is experimental software and is provided on an "as is" and "as available"
> basis. We do not give any warranties and will not be liable for any losses
> incurred through any use of this code base.

## Packages

The library provides the following packages under [`packages/`](packages/):

| Component | Package | Public module |
|---|---|---|
| [Scoped Authorization Grant](packages/access/scoped-authorization-grant-v1/) | `openzeppelin-scoped-authorization-grant-v1` | `OpenZeppelin.ScopedAuthorizationGrantV1` |
| [Pausable API](packages/security/api-pausable-v1/) | `openzeppelin-api-pausable-v1` | `OpenZeppelin.Api.PausableV1` |
| [Pausable utils](packages/security/pausable-utils/) | `openzeppelin-pausable-utils` | `OpenZeppelin.Pausable.Utils` |
| [Timelock API](packages/security/api-timelock-v1/) | `openzeppelin-api-timelock-v1` | `OpenZeppelin.Api.TimelockV1` |
| [Timelock utils](packages/security/timelock-utils/) | `openzeppelin-timelock-utils` | `OpenZeppelin.Timelock.Utils` |
| [Token CIP-0112 types](packages/token/token-cip112-types-v1/) | `openzeppelin-token-cip112-types-v1` | `OpenZeppelin.Token.Cip112.TypesV1` |
| [Token CIP-0112 utils](packages/token/token-cip112-utils/) | `openzeppelin-token-cip112-utils` | `OpenZeppelin.Token.Cip112.Utils` |
| [Token CIP-0112](packages/token/token-cip112-v1/) | `openzeppelin-token-cip112-v1` | `OpenZeppelin.Token.Cip112.V1` |

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

The resulting DAR is written to:

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

Each package `README.md` shows the consumer code for that component, and
[`examples/`](examples/) holds runnable consumer projects.

## Repository layout

See [ARCHITECTURE.md](ARCHITECTURE.md#repository-layout) for what each top-level
directory holds.

## Package and compatibility model

See [ARCHITECTURE.md](ARCHITECTURE.md) for how components are split into
packages and how they stay compatible across releases, and
[RELEASING.md](RELEASING.md) for release process guidance.

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

[MIT](LICENSE), except where a file states otherwise. Files in the CIP-0112
token packages that contain code derived from the Splice TestTokenV2 example
or the Splice `splice-token-standard-utils` package
(https://github.com/canton-network/splice/tree/8460154135f39019b8bb370c9c1321ff13c9bb10/token-standard/)
carry Digital Asset's copyright notice and are licensed `MIT AND Apache-2.0`.
The `README.md` of each token package lists those files and the Splice modules
they derive from. The Splice DARs under `dars/vendor/` are licensed Apache-2.0. The Apache
License 2.0 text is in [`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt).
