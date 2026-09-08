# Packages

OpenZeppelin Daml components for Canton smart contract development. Every
directory under a category is one Daml package and one DAR. Category directories
are navigation only and never appear in a package name or module namespace.

## Contents

| Category | Component | Package | Public module | Solidity analogue |
|---|---|---|---|---|
| `security/` | [Pausable](security/pausable-api-v1/) | `openzeppelin-pausable-api-v1` | `OpenZeppelin.PausableV1` | `Pausable` |

Each package `README.md` documents the public module, the authority and
lifecycle model, the build command, a consumption example, and the security
caveats. Read it before depending on the package.

Early-stage candidates live under [`experiments/`](../experiments/); see
[`experiments/README.md`](../experiments/README.md) for their status and
warnings.
