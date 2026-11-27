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
| Compliance freeze on accounts | A per-account `MyAccountStatus`, signed by the admin and the compliance officer, who replaces it through `MyAccountStatus_Freeze` and `MyAccountStatus_Unfreeze`. All three consumption operations read its id from the choice context and exercise `MyHolding_Spend`, which refuses a frozen account, so a frozen account's holdings cannot fund a transfer, allocation, or burn, and its locked funding is neither paid out nor returned. `MyHolding_OwnerUnlock`, `MyHolding_Merge`, and `MyHolding_Split` make the same check, and a merge's other inputs must carry the exercised holding's roles. In a batch, the settlement factory forwards each allocation its own authorizer's status and no other account's |
| Pause switch on the registry | A template field plus `MyRules_Pause` and `MyRules_Unpause`, checked before each factory delegates and before a mint offer, and again when a pending instruction is accepted or an allocation settles (see [Pause at delivery](#pause-at-delivery)) |
| Fee on every transfer except a burn | Two workflow calls composed in the factory body: a one-step fee transfer to the treasury, then the main transfer on the fee leg's change |
| Executor allowlist | Checked before delegating to the allocation and settlement workflows |

`MyHolding_Merge` and `MyHolding_Split` bypass the rules contract, so they
run while the registry is paused and pay no fee. A self-transfer through
the transfer factory rebalances the same way, but is paused and charged
like any other transfer.

A one-step receiver witnesses the fee leg too: the sender's original
inputs, the treasury's fee holding, and the change the main transfer
spends. To keep the sender's balance private in a one-step transfer, fund
it from a single holding of exactly the amount plus the fee.

The auditor observes every holding and every holdings-change event, and the
compliance officer observes every holding. Every transaction that archives a
`MyHolding`, including `MyHolding_OwnerUnlock`, fails while either party has
no hosting participant or a participant hosting it has not vetted the
packages. The compliance officer also signs every account status, so its
participant confirms every `MyHolding_Spend` and `MyHolding_OwnerUnlock`, and
each one fails while that participant is unavailable.

## Pause at delivery

A pending transfer instruction or allocation completes without running a
factory again, so `MyTransferInstruction` checks the pause again when it is
accepted, and `MyAllocation` when it settles, in a batch or directly by the
admin and the executors. A transfer, mint offer, burn request, or
allocation made before a pause therefore completes only against an
unpaused `MyRules` of its admin.

Each accept and settle passes the registry's live `MyRules` in its choice
context, under `rulesKey`. The choice fetches it as `MyRules` and refuses
unless the pending contract's admin and pauser signed it and it is not
paused. A missing entry, an archived rules contract, a contract of another
template, and a `MyRules` of another admin or another pauser are all
refused. `MyRules_Pause` and
`MyRules_Unpause` archive the rules contract and create a new one, so a fetch
of an id from before the change fails. The receiver, and the executors
on a direct settle, get the rules contract by disclosure, as for a factory
call. In a batch, the selector also passes each allocation the factory's
own id under `rulesKey`, so every settle checks the rules contract the batch
runs on.

Reject, withdraw, cancel, and the admin's expiry choices run while the
registry is paused and return the funds to their owner. The fee binds when
a transfer instruction is created, and the executor allowlist when an
allocation is created and again in the settlement factory.

Any live `MyRules` of the admin and the pauser passes the check, so the
pause holds delivery only while every such rules contract is paused. The
admin alone can sign only a `MyRules` that names another pauser, which the
check refuses.

## Account statuses

The compliance officer opens one status per regular account through
`MyRules_OpenAccount`. Freezing or unfreezing replaces the status and leaves
the holdings untouched, so a pending transfer instruction or allocation keeps
naming live holdings and completes once the account is unfrozen. Nothing on
the ledger stops a second live status for the same account, and a submitter
could pass the one that is not frozen. The officer, who signs every status,
opens each account once and retries an open with the same command id, so
that command deduplication refuses a second one.

Every workflow choice that consumes a holding passes the current status of
the holding's account in its choice context, under `accountStatusKey`.
`MyHolding_OwnerUnlock` takes it as its `statusCid` argument. A missing
entry, an archived status, a status of another account, and a status signed
by a compliance officer other than the one recorded on the holding are all
refused. The account parties observe their own status. Everyone else gets it
as a disclosed contract from the registry:

| Path | Submitter | Status passed |
|---|---|---|
| Transfer, allocation, or burn | The sender or authorizer | Its own |
| Accept or reject | The receiver | The sender's |
| Withdraw a transfer instruction or an allocation | The sender or authorizer | Its own |
| Admin expiry of an instruction | The admin | The sender's, in each `MyTransferInstruction_Expire` |
| Cancel, or admin expiry of an allocation | The executors or the admin | The authorizer's, in each `Allocation_Cancel` |
| Direct `Allocation_Settle` | The admin and the executors | The authorizer's |
| Batch settlement | The executors | Each authorizer's, under `batchStatusKey` of its account |
| Owner unlock | The account parties | Its own, as the `statusCid` argument of `MyHolding_OwnerUnlock` |

In a batch, `MyRules` passes `settleBatchImpl` a selector that forwards each
allocation its own authorizer's status, under `accountStatusKey`, and no
other account's. The batch context stays with the executors and the admin,
because no authorizer observes the batch. An allocation that locked nothing
needs no status.

A freeze stops the account's own holdings from moving. It does not stop the
account from receiving: an accept or settle checks only the status of the
account whose funding it pays out.

What each status shows, and to whom:

- The receiver sees the sender's status, including whether it is frozen, on
  every path that pays out or returns the instruction's locked funding.
- The executors see the authorizer's status on every path that pays out or
  returns an allocation's locked funding, and each status they put in a
  batch context.

A frozen account fails the admin's whole expiry batch, so cleanup leaves
frozen accounts out and expires them after they are unfrozen.

A holding keeps the compliance officer of the contract whose choice created
it, and only a status signed by that officer covers it. A pending
instruction or allocation keeps its officer too, and creates its holdings
under it. Rules with another officer create every new holding under the new
officer, a fee leg's change included, and one choice context carries one
status. Through such rules, a transfer that pays a fee from an earlier
holding is refused whichever status the sender passes.

To change who acts as the compliance officer, keep the officer party and
change who controls it. To replace the party:

1. The pauser pauses the earlier rules, and the admin and the pauser create
   the new ones.
   The paused rules refuse new transfers, allocations, settlements, and
   mints. `MyRules_OpenAccount` and the admin's expiry choices still run on
   them. The earlier rules stay paused until the admin and the pauser
   archive them.
2. The earlier officer opens a status, through the paused rules, for each
   receiver of a pending instruction and each authorizer of a pending
   allocation that has none. These parties receive holdings under the
   earlier officer.
3. The new officer opens a status for every account and freezes each account
   the earlier officer has frozen. `MyRules_OpenAccount` opens every status
   unfrozen.
4. Each account moves its earlier holdings through the new rules on a path
   with no fee leg. An allocation funded with the earlier status and then
   withdrawn with the new one returns the funds under the new officer.

The earlier officer keeps its statuses live, and freezes through them, until
no earlier holding or pending instruction or allocation is left. The admin
and the pauser then archive the earlier rules in one transaction.

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
case. Its choices run with the authority the pauser gave when it was
created. Accept and settle check the pause against a `MyRules` passed in the
choice context (see [Pause at delivery](#pause-at-delivery)), but the
allowlist does not bind a settle that the admin and the executors exercise
directly on an allocation.

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
