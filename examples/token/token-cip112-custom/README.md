# Custom token example

A compliance-grade token that owns every template it deploys (`MyHolding`,
`MyTransferInstruction`, `MyAllocation`, `MyRules`) and reuses the
OpenZeppelin CIP-0112 workflows unchanged. It depends on
`openzeppelin-token-cip112-types-v1` and `openzeppelin-token-cip112-utils`
only, never on the default templates.

What it adds, and where each addition lives:

| Addition | Mechanism |
|---|---|
| Pauser and compliance-officer roles | Controllers of consumer choices; the admin stays the signatory and holds neither power |
| Auditor observing every contract and every holdings-change event | A consumer field on each template, reached through the closure that builds `HoldingOps`, plus the `eventObservers` operation |
| Compliance freeze on holdings | A template field plus `MyHolding_Freeze` and `MyHolding_Unfreeze`; `MyHolding_Spend` refuses a frozen holding, so every workflow path refuses it |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates; burns bypass it |
| Fee on every transfer except a burn | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

No workflow body changes. `token-cip112-custom-test` drives the token through the
standard interfaces and checks each addition.

From the repository root:

```sh
DAML_PACKAGE=examples/token/token-cip112-custom dpm build
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test
```
