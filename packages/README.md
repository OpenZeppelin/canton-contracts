# Packages

OpenZeppelin Daml components for Canton smart contract development. Every
directory under a category is one Daml package and one DAR. Category directories
are navigation only and never appear in a package name or module namespace.

## Contents

| Package | Description |
|---------|-------------|
| [Scoped Authorization Grant V1](access/scoped-authorization-grant-v1/) | Revocable, time-bounded permissions with exact resource scope. |
| [Pausable API V1](security/api-pausable-v1/) | A frozen interface for reading a contract's pause state. |
| [Pausable utils](security/pausable-utils/) | Guards and structured failures for templates implementing Pausable. |
| [Timelock API V1](security/api-timelock-v1/) | Frozen interfaces for a mandatory delay between the proposal and the execution of an operation. |
| [Timelock utils](security/timelock-utils/) | Lifecycle functions, schedule functions, time guards, and structured failures for templates implementing Timelock. |
| [Token CIP-0112 types V1](token/token-cip112-types-v1/) | The registry configuration, transfer-instruction, and allocation records CIP-0112 templates store. |
| [Token CIP-0112 utils](token/token-cip112-utils/) | CIP-0112 transfer, allocation, settlement, and mint-offer choice bodies as functions over a consumer's own templates. |
| [Token CIP-0112 V1](token/token-cip112-v1/) | Ready-to-use CIP-0112 token templates: holdings, transfer instructions, allocations, and registry rules over the utils package. |
| [Async Vault API V1](vault/api-async-vault-v1/) | A frozen interface for a deposit gate, the contract an asynchronous vault asks before it accepts a deposit request. |
| [Async Vault types V1](vault/async-vault-types-v1/) | The configuration, state, price, and request records asynchronous vault templates store. |
| [Async Vault utils](vault/async-vault-utils/) | Share maths and the request, batch-settlement, and reserve choice bodies of an asynchronous vault as functions over a consumer's own templates. |
| [Async Vault V1](vault/async-vault-v1/) | Ready-to-use asynchronous vault templates: rules, deposit and redemption requests, and a ledger that settles them in batches at one price, over the utils package. |
| [Async Vault Permits V1](vault/async-vault-permits-v1/) | A deposit gate in which validators appointed by a vault's admin enable parties to deposit. |

These components are unreleased, unaudited library candidates. Tagged DARs and
their manifest entries define releases; placement here does not imply stability.

Each package `README.md` documents the public module, the authority and
lifecycle model, the build command, a consumption example, and the security
caveats. Read it before depending on the package.

Early-stage candidates live under [`experiments/`](../experiments/); see
[`experiments/README.md`](../experiments/README.md) for their status and
warnings.
