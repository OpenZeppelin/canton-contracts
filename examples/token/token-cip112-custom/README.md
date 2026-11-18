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
| Compliance freeze on accounts | A per-account `MyAccountStatus`, signed by the admin and the compliance officer, who replaces it through `MyAccountStatus_Freeze` and `MyAccountStatus_Unfreeze`. All three consumption operations read its id from the choice context and exercise `MyHolding_Spend`, which refuses a frozen account, so a frozen account's holdings cannot fund a transfer, allocation, or burn, and its locked funding is neither paid out nor returned. `MyHolding_OwnerUnlock` makes the same check. In a batch, the settlement factory forwards each allocation only its authorizer's status |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates and before a mint offer |
| Fee on every transfer except a burn | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

The pause does not cover pending transfer instructions. Their accept choice
does not read the rules contract, so a transfer, mint offer, or burn request
created before the pause can still be accepted while the registry is paused.

The auditor observes every holding and every holdings-change event, and the
compliance officer observes every holding. Every transaction that archives a
`MyHolding`, including `MyHolding_OwnerUnlock`, fails while either party has
no hosting participant or a participant hosting it has not vetted the
packages.

## Account statuses

The compliance officer opens one status per regular account through
`MyRules_OpenAccount`. Freezing or unfreezing replaces the status and leaves
the holdings untouched, so a pending transfer instruction or allocation keeps
naming live holdings and completes once the account is unfrozen. Nothing on
the ledger stops a second live status for the same account, and a submitter
could pass the one that is not frozen, so the officer, who signs every
status, opens each account once and retries an open with the same command
id, so that command deduplication refuses a second one.

Every choice that consumes a holding passes the current status of the
holding's account in its choice context, under `accountStatusKey`. A missing
entry, an archived status, a status of another account, and a status
signed by a compliance officer other than the one recorded on the holding
are all refused. The account parties observe their own status. Everyone else gets it as a
disclosed contract from the registry:

| Path | Submitter | Status passed |
|---|---|---|
| Transfer, allocation, or burn | The sender or authorizer | Its own |
| Accept or reject | The receiver | The sender's |
| Withdraw a transfer instruction or an allocation | The sender or authorizer | Its own |
| Admin expiry of an instruction | The admin | The sender's, in each `MyTransferInstruction_Expire` |
| Cancel, or admin expiry of an allocation | The executors or the admin | The authorizer's, in each `Allocation_Cancel` |
| Direct `Allocation_Settle` | The admin and the executors | The authorizer's |
| Batch settlement | The executors | Each authorizer's, under `batchStatusKey` of its account |

In a batch, `MyRules` passes `settleBatchImpl` a selector that forwards each
allocation only its authorizer's status, under `accountStatusKey`. The batch
context stays with the executors and the admin, because no authorizer
observes the batch. An allocation that locked nothing needs no status.

A freeze stops the account's own holdings from moving. It does not stop the
account from receiving: an accept or settle checks only the status of the
account whose funding it pays out.

What each status shows, and to whom:

- The receiver sees the sender's status, including whether it is frozen,
  when it accepts or rejects.
- The executors see the status of every authorizer in a batch they settle
  or an allocation they cancel.
- A frozen account fails the admin's whole expiry batch, so cleanup leaves
  frozen accounts out and expires them after they are unfrozen.

No workflow body changes. `token-cip112-custom-test` drives the token through the
standard interfaces and checks each addition.

From the repository root:

```sh
DAML_PACKAGE=examples/token/token-cip112-custom dpm build
DAML_PACKAGE=examples/token/token-cip112-custom-test dpm test
```
