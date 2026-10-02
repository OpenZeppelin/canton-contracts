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
| [Token CIP-0112 workflows V1](token/tokenCIP112-workflows-v1/) | CIP-0112 transfer, allocation, settlement, mint, and burn choice bodies as functions over a consumer's own templates. |
| [Token CIP-0112 V1](token/tokenCIP112-v1/) | Ready-to-use CIP-0112 token templates: holdings, transfer instructions, allocations, and registry rules over the workflows package. |

These components are unreleased, unaudited library candidates. Tagged DARs and
their manifest entries define releases; placement here does not imply stability.

Each package `README.md` documents the public module, the authority and
lifecycle model, the build command, a consumption example, and the security
caveats. Read it before depending on the package.

Early-stage candidates live under [`experiments/`](../experiments/); see
[`experiments/README.md`](../experiments/README.md) for their status and
warnings.
