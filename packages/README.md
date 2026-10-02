# Packages

OpenZeppelin Daml components for Canton smart contract development. Every
directory under a category is one Daml package and one DAR. Category directories
are navigation only and never appear in a package name or module namespace.

## Contents

| Package | Description |
|---------|-------------|
| [Scoped Authorization Grant V1](access/scoped-authorization-grant-v1/) | Revocable, time-bounded permissions with exact resource scope. |
| [Pausable API V1](security/api-pausable-v1/) | A frozen interface for reading a contract's pause state. |
| [Pausable V1](security/pausable-v1/) | Guards and structured failures for templates implementing Pausable. |
| [Timelock API V1](security/api-timelock-v1/) | Frozen interfaces for a mandatory delay between the proposal and the execution of an operation. |
| [Timelock V1](security/timelock-v1/) | Lifecycle functions, schedule functions, time guards, and structured failures for templates implementing Timelock. |

These components are unreleased, unaudited library candidates. Tagged DARs and
their manifest entries define releases; placement here does not imply stability.

Each package `README.md` documents the public module, the authority and
lifecycle model, the build command, a consumption example, and the security
caveats. Read it before depending on the package.

Early-stage candidates live under [`experiments/`](../experiments/); see
[`experiments/README.md`](../experiments/README.md) for their status and
warnings.
