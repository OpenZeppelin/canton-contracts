# Custom token example

A compliance-grade token that owns every template it deploys (`MyHolding`,
`MyTransferInstruction`, `MyAllocation`, `MyRules`) and reuses the
OpenZeppelin CIP-0112 workflows unchanged. It depends on
`openzeppelin-token-cip112-types-v1` and `openzeppelin-token-cip112-utils`
only, never on the default templates.

What it adds, and where each addition lives:

| Addition | Mechanism |
|---|---|
| Pauser and compliance-officer roles | Controllers of consumer choices. The pauser also co-signs every holding, pending, and rules contract, so the admin holds neither power (see [Binding the admin](#binding-the-admin)) |
| Auditor observing every contract and every holdings-change event | A consumer field on each template, reached through the closure that builds `HoldingOps`, plus the `eventObservers` operation |
| Compliance freeze on holdings | A template field plus `MyHolding_Freeze` and `MyHolding_Unfreeze`; `fundHolding` and `deliverHolding` exercise `MyHolding_Spend`, which refuses a frozen holding, so a frozen holding cannot fund a transfer, allocation, or burn, and a payout of locked funding runs the same check. `returnHolding` archives without the spend, so no return path refuses a holding for being frozen. The freeze refuses a holding with a live lock |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates and before a mint offer |
| Fee on every transfer except a burn | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

The freeze does not cover funds locked for a pending transfer instruction or
allocation. The pending contract names its locked holding by contract id, and
a freeze re-creates the holding under a new id. `MyHolding_Freeze` therefore
refuses a holding until its lock expires, and the pending contract completes,
releases, or expires as usual.

The pause does not cover pending transfer instructions. Their accept choice
does not read the rules contract, so a transfer, mint offer, or burn request
created before the pause can still be accepted while the registry is paused.

The auditor observes every holding and every holdings-change event, and the
compliance officer observes every holding. Every transaction that archives a
`MyHolding`, including `MyHolding_OwnerUnlock`, fails while either party has
no hosting participant or a participant hosting it has not vetted the
packages.

No workflow body changes. `token-cip112-custom-test` drives the token through the
standard interfaces and checks each addition.

## Binding the admin

A role on the rules contract alone restricts wallets, not the admin. The admin
could sign a second `MyRules` by itself, unpaused, fee-free, or with other
executors or roles, and the workflows would accept this token's holdings
through it. So the pauser co-signs `MyRules`, `MyHolding`,
`MyTransferInstruction`, and `MyAllocation`, and `MyHolding_Spend` needs its
authority too. Every `MyRules` that accepts these holdings therefore carries
the pauser's signature, and with it the pause, the executor allowlist, the
fee, and the roles the pauser agreed to. A pending contract is a separate
case. Its choices run with the authority the pauser gave when it was created
and do not read `MyRules`, so neither the pause nor the allowlist binds a
settle that the admin and the executors exercise directly on an allocation.

The admin can still sign the same templates naming a pauser it controls.
Those contracts form a separate token: the consumption operations refuse a
`MyHolding` that names a different pauser, and the settlement and expiry
choices refuse such an allocation or transfer instruction. The two tokens
carry the same instrument id in the standard `Holding` view. Check that the
pauser is among a holding's signatories before crediting it. Otherwise a
holding the admin signed without the pauser passes as this token.

The co-signature has costs:

- Privacy. The pauser signs every holding, pending instruction, allocation,
  and the rules contract, so it sees every balance, every pending transfer
  and settlement, and every action on them.
- Liveness. The pauser's participant confirms every transaction that creates
  or consumes one of these contracts. Every mint, transfer, allocation,
  settlement, and expiry fails while that participant is unavailable, and
  for good if the pauser's keys are lost.
- Coordination. Creating `MyRules` or replacing it with a new fee,
  allowlist, or roles needs the admin's and the pauser's authority in one
  transaction.
  With the two on separate participants, the admin creates or replaces it
  through a `MyRulesProposal` that the pauser accepts. Archiving `MyRules`
  also needs the admin and the pauser in one transaction. No proposal does
  that, because accepting one always creates a `MyRules`. Pausing and
  unpausing need the pauser alone. The pauser itself cannot be replaced
  through a new rules contract. Every holding and pending contract names
  the old pauser, so a rules contract with a new pauser refuses them all,
  and moving each one needs the old pauser's authority.
- Independence. The binding holds only while the admin cannot act for the
  pauser, so host the pauser on participants the admin does not operate: a
  participant that hosts a party submits and confirms for it. The admin and
  the pauser together can create any contract.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/token/token-cip112-custom dpm build
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test
```
