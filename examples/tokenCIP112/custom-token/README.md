# Custom token example

A compliance-grade token that owns every template it deploys (`MyHolding`,
`MyTransferInstruction`, `MyAllocation`, `MyRules`) and reuses the
OpenZeppelin CIP-0112 workflows unchanged. It depends on
`openzeppelin-tokenCIP112-workflows-v1` only, never on the default
templates.

What it adds, and where each addition lives:

| Addition | Mechanism |
|---|---|
| Pauser and compliance-officer roles | Controllers of consumer choices; the admin stays the signatory and holds neither power |
| Auditor observing every contract and every holdings-change event | A consumer field on each template, reached through the closure that builds `HoldingOps`, plus the `eventObservers` operation |
| Compliance freeze on holdings | A template field plus `MyHolding_Freeze` and `MyHolding_Unfreeze`; `MyHolding_Spend` refuses a frozen holding, so every workflow path refuses it |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates |
| Fee on every transfer | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

No workflow body changes. `custom-token-test` drives the token through the
standard interfaces and checks each addition.

From the repository root:

```sh
DAML_PACKAGE=examples/tokenCIP112/custom-token dpm build
DAML_PACKAGE=examples/tokenCIP112/custom-token-test dpm test
```
