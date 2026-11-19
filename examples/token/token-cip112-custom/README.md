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
| Compliance freeze on holdings | A template field plus `MyHolding_Freeze` and `MyHolding_Unfreeze`; `fundHolding` and `deliverHolding` exercise `MyHolding_Spend`, which refuses a frozen holding, so a frozen holding cannot fund a transfer, allocation, or burn, and a payout of locked funding runs the same check. `returnHolding` stays the pinned archive, so no return path refuses a holding for being frozen. `MyHolding_OwnerUnlock`, `MyHolding_Merge`, and `MyHolding_Split` refuse a frozen holding themselves, since each recreates it through `createHolding`; a merge's other inputs go through `fundHolding` and must carry the exercised holding's roles |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates and before a mint offer |
| Fee on every transfer except a burn | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

The pause does not cover pending transfer instructions. Their accept choice
does not read the rules contract, so a transfer, mint offer, or burn request
created before the pause can still be accepted while the registry is paused.

Nor does the registry cover merges and splits. `MyHolding_Merge` and
`MyHolding_Split` do not read the rules contract, so they run while the
registry is paused and pay no fee. A self-transfer through the transfer
factory rebalances the same way, but is paused and charged like any other
transfer.

No workflow body changes. `token-cip112-custom-test` drives the token through the
standard interfaces and checks each addition.

From the repository root:

```sh
DAML_PACKAGE=examples/token/token-cip112-custom dpm build
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test
```
