# Custom token example

A compliance-grade token that owns every template it deploys (`MyHolding`,
`MyTransferInstruction`, `MyAllocation`, `MyRules`) and reuses the
OpenZeppelin CIP-0112 workflows unchanged. It depends on
`openzeppelin-token-cip112-types-v1`, `openzeppelin-token-cip112-utils`, and
`openzeppelin-blocklist-v1`, never on the default templates.

What it adds, and where each addition lives:

| Addition | Mechanism |
|---|---|
| Pauser and compliance-officer roles | Controllers of consumer choices; the admin stays the signatory and holds neither power |
| Auditor observing every contract and every holdings-change event | A consumer field on each template, reached through the closure that builds `HoldingOps`, plus the `eventObservers` operation |
| Compliance freeze on holdings | A template field plus `MyHolding_Freeze` and `MyHolding_Unfreeze`; `MyHolding_Spend` refuses a frozen holding, so every workflow path refuses it |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates and before a mint offer |
| Account blocklist | A `Blocklist` from `openzeppelin-blocklist-v1`, read from the choice context under `blocklistContextKey` and checked against the owner and provider of every account a choice debits or credits |
| Fee on every transfer except a burn | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

The pause does not cover pending transfer instructions. Their accept choice
does not read the rules contract, so a transfer, mint offer, or burn request
created before the pause can still be accepted while the registry is paused.

The blocklist covers pending contracts too, because it is read when value
moves:

- The transfer factory checks the sender and the receiver, the allocation
  factory checks the authorizer and the other side of every leg, and the
  settlement factory checks every leg and every authorizer. An allocation
  committed before a block does not settle while the block holds.
- Each allocation's settle checks its authorizer and the other side of every
  leg again, so a direct `Allocation_Settle` by the admin and the executors
  is checked too. The settlement factory passes it only the blocklist entry
  of the batch's context.
- Accepting a transfer, mint offer, or burn request checks the sender and the
  receiver.
- Withdraw, reject, cancel, admin expiry, and `MyHolding_OwnerUnlock` return
  locked funds to the account that locked them, so they stay open for a
  blocked account. The funds stay there, and every later transfer from that
  account is refused.
- The blocker sees the blocklist only, never a holding, instruction,
  allocation, or the rules contract. Block and unblock do not read the pause
  switch, so they work while the registry is paused.

The registry's off-ledger API supplies the blocklist contract id in
`ExtraArgs.context` under `blocklistContextKey` (`blocklist`), with the
contract as a disclosure. A call that needs it and lacks it fails with
`eBlocklistMissing`.

No workflow body changes. `token-cip112-custom-test` drives the token through the
standard interfaces and checks each addition.

From the repository root:

```sh
DAML_PACKAGE=examples/token/token-cip112-custom dpm build
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test
```

The blocklist tests also run against a static-time Canton sandbox:

```sh
OZ_SANDBOX_SUITE=custom-token scripts/check-sandbox.sh
```
