# Extension ideas — `openzeppelin-tokenCIP112-v1`

Working notes on possible extensions to the token packages (the templates
here and the bodies in `openzeppelin-tokenCIP112-workflows-v1`). These are
ideas, not commitments: nothing here is scheduled, and none of it is consumer
documentation (that lives in `README.md`). Spec section references are to
CIP-0112.

## 0. Reintroduce the batch-settlement authorization guard

Removed for now to keep the core small. The guard was an admin-signed
`BatchSettlementAuthorization` proof template: minted per allocation inside
`SettlementFactory_SettleBatch` after the exact-cover check, passed through the
choice context under `openzeppelin.com/batch-settlement-authorization`, and
consumed (fetched, validated, archived) by `allocationSettleImpl`. It bound
the settlement, authorizer, effective leg set (own legs plus executor-supplied
extras), and next-iteration reservation to the arguments the cover check
validated, and its single-use consumption prevented replay.

Without it, `Allocation_Settle` is directly exercisable by admin plus
executors, bypassing exact cover: a lone receiver-side settle mints value, a
lone sender-side settle burns it, and iterated-settlement extra legs and
reservations go unvalidated. Supply integrity currently rests on the
operational rule that the admin's authority never co-signs a settle outside
the factory (see the README caveat and `testDirectSettleAllowed`, which
documents the behavior). Reintroducing the guard turns that rule back into a
structural property; the residual admin-forgery case (admin is the proof's
signatory) is inherent to the admin being the asset's root of trust.

## 1. CIP-56 (Token Standard V1) compatibility instances

The V2 interface hierarchy is parallel to V1 — the two share only
`splice-api-token-metadata-v1` — so V1 wallets and tooling cannot see this
token today. The vendored utils ship `...V1...DefaultImplUsingV2` helpers for
exactly this pattern: add the V1 `interface instance` blocks to the same
templates (`TokenHolding`, `TokenTransferInstruction`, `TokenAllocation`,
`TokenRules`), expressing V1 semantics in terms of the V2 implementations. The
V1 interface packages already ship inside the vendored utils DAR. CIP-0112 §5 treats dual
serving as the expected posture for a compliant V2 asset. Decide whether this
lands in this package (SCU can add interface instances) or ships as an opt-in
sibling.

## 2. Delivery-vs-Mint / Delivery-vs-Burn settlement legs

Special accounts (`owner = None`, id `cip-112/mint` / `cip-112/burn`,
§4.3.2.1) are recognized today only defensively: they can never hold
(`TokenHolding` ensure), and events on them are suppressed. Supply changes go
through the `TokenRules_Mint` / `TokenRules_Burn` choices instead. The spec's
intent is stronger: mint/burn expressible as ordinary transfer and allocation
legs, so stablecoin/fund subscription and redemption become atomic settlement
legs (DvM/DvB). Supporting this needs a dedicated path in `allocationFactoryImpl` and
`settleAllocation` — a mint-side leg has no holdings to lock, so the admin's
authority must stand in for funding, and the cover check must treat the
special-account side as admin-authorized. Note: `allocationFactoryImpl` rejects
special-account authorizers outright (`testSpecialAuthorizerRefused`), so the
dedicated path must deliberately lift that guard.

## 3. Pause support

Two coordinated pieces:

- On-ledger: gate the origination choices on `TokenRules` (mint, transfer
  factory, allocation factory, settle batch) behind a pause flag, using the
  frozen `openzeppelin-api-pausable-v1` interface once it merges (PR #46). Its
  documentation already sketches the registry pattern: the flag and the
  CIP-0112 `pauseInfo` fields (reason, until) live as `TokenRules` template
  fields, set in the same transaction as the flip.
- Off-ledger: CIP-0112 §4.1.7 reports pause purely through the metadata
  OpenAPI (`paused`, `pauseInfo`) — no Daml interface. Whatever serves the
  registry's metadata endpoint must read the flag from the `TokenRules` view.

Decide who may flip: a single admin party today, or role-gated (see idea 4).

## 4. Role-gated admin operations

Every admin power (mint, burn, expiry, GC, future pause) is controlled by the
single `admin` party. An extension could split these into roles
(MINTER / BURNER / PAUSER-style) using the `access-control-v1` component once
it graduates from `experiments/`, following the pattern the pausable API
documents: the choice takes the caller plus a role-grant credential and the
body validates it. Constraint to respect: `admin` remains the signatory
everywhere — roles delegate *invocation*, not signatory authority — and the
implementation-package dependency rules in `ARCHITECTURE.md` mean this
probably composes consumer-side rather than as a package dependency.

## 5. CIP-86 allowance component

An ERC-20-style approve/transferFrom surface (a `TokenAllowance` template
spent through registry choices) existed in an earlier iteration of this
package and was removed in the simplification pass. CIP-0056 deliberately
ships no allowance API and defers a UTXO-compatible one to a future CIP;
CIP-86 middleware (ChainSafe) is the consumer that needs it. If reintroduced,
it should be a separate component layered on the token core — not part of this
package — so the core stays exactly the standard surface.

## 6. `Lock.expiresAfter` support

`TokenHolding` rejects locks carrying `expiresAfter` at creation, because the
effective lock expiry would be the earlier of the two bounds and this
package's expiry model (`expiresAt` / `lockGrace` windows) does not account
for that. Supporting it means threading the earlier-of-two-bounds rule through
`consumeUnlockedHolding`, `holdingOwnerUnlockImpl`, and the
admin-expiry window guarantees. Only worth it if a real consumer needs
relative-time locks; the fail-closed rejection is correct until then.

## 7. `extraReceiptAuthorizers` on batch settlement

§4.3.1 lets `SettlementFactory_SettleBatch` auto-create missing receipt-side
allocations for accounts that co-authorize the call — a V1-compatibility aid
and a performance optimization (receivers skip the allocate round-trip). The
current implementation relies on the vendored default behavior; verify what it
does with a non-empty `extraReceiptAuthorizers` and either support it
deliberately (validate the co-authorization, emit the right events) or reject
it explicitly.

## 8. Explicit account lifecycle

Accounts are implicit today: any `basicAccount owner` (or provider account)
can receive. §4.3.2.2 also allows explicit accounts — registry-side account
setup before a transfer is accepted, advertised to wallets via
`showAccountInputFields` on the metadata endpoint. An extension would add an
account registry template plus existence checks in `executeTransfer` /
`allocationFactoryImpl`. This is the natural hook for compliance gating
(credential-checked account opening) without touching the transfer paths
themselves.

## 9. Off-ledger registry companion

The spec's off-ledger halves — factory discovery endpoints returning the
`TokenRules` contract id plus disclosed contracts and `ChoiceContext`,
metadata/instruments (incl. pause reporting), account-input hints — are
operational infrastructure, not Daml, and sit outside this repository's scope.
Worth capturing as a reference deployment or example service elsewhere
(`canton-specs` or an RI), since today the trading example substitutes
explicit disclosure for discovery and every real consumer will face the same
gap.

## 10. Registry-wide account authorization model

Status: designed 2026-10-01, revised 2026-10-02, not implemented. Answers
the PR #45 review thread on owner-only initiation for provider accounts
(CIP-0112 §4.3.2) with a deployer-chosen model instead of Splice
`TestTokenV2`'s per-account `AccountConfig`. The vault copy is
`output/2026-10-01-cip112-registry-account-model-design.md`.

A single authorization model for provider accounts, chosen when the registry
is deployed and applied to every account, that reproduces the authorization
outcomes of Splice `TestTokenV2`'s per-account `AccountConfig` without
per-account contracts, proposal flows, choice-context delivery, or delegation
choices. Revision 2 replaces the "approvers act jointly" simplification of
revision 1 with bounded accumulation, after checking the reference wallet
client.

### 1. Ledger facts the design is built on

Every decision below follows from these; a design that contradicts one of
them fails at the ledger, not in review.

- **F1 Creation.** Creating a contract needs the authority of all its
  signatories, present in the transaction.
- **F2 Archive.** A plain `archive` needs the authority of all signatories.
- **F3 Choice authority.** Exercising a choice needs the controllers'
  authority. Inside the body, the available authority is the controllers
  plus the signatories of the contract being exercised. So a choice on a
  contract signed by `S` can create or archive anything `S` can, however
  small its controller set is.
- **F4 Fetch.** A fetch inside a body needs at least one stakeholder of the
  fetched contract among the authorizers, and the contract must be on the
  submitting participant or disclosed.
- **F5 Storage.** Functions cannot be stored; party lists can.
- **F6 Wallets act for one party.** `availableActions` is a set of joint
  actor groups, but the V2 interface docs say registries "MUST report the
  parties that can accept unilaterally", and Splice's reference wallet
  client (`WalletClientV2.listTransferInstructionsV2`) shows an instruction
  to party `p` only when `[p]` is one of the groups. A group of two is
  invisible to it. Every step must therefore offer a single-party actor.
- **F7 The spec.** Providers MUST see all holdings and movements. The owner
  MUST be able to call `TransferFactory_Transfer` and
  `AllocationFactory_Allocate`; the registry decides whether that executes
  or yields a pending instruction the provider accepts. The factory docs add
  SHOULDs: complete in one step when the actors cover everyone required;
  let every sender account party initiate on their own; let the provider
  allocate where it "has the right to allocate funds".

### 2. Where authorization lives in the current packages

`accountParties admin account` ([owner] for a basic account, [owner,
provider] when the provider is distinct) plays three roles today, and the
design separates them.

| Role | Current uses |
| --- | --- |
| Signatory (authority to create and archive) | `TokenHolding`, `TokenTransferInstruction` (sender side), `TokenAllocation` (authorizer side) |
| Controller or actor check (who may act) | transfer factory actors, accept and reject (receiver parties), withdraw (sender parties), allocate actors, allocation withdraw, owner unlock, mint and burn controllers |
| Visibility | instruction observers (receiver parties), event observers, transfer-lock holders (admin plus receiver parties) |

The owner-only call fails today because of the first role, not the second:
holdings are signed by both account parties, so consuming one needs both
authorities (F2), and the factory's actor check merely states that
requirement up front. Loosening the actor check alone would move the failure
to the archive.

### 3. Mechanisms considered

| Mechanism | How the provider's authority is supplied when the provider need not approve | Verdict |
| --- | --- | --- |
| **M1 Model-determined signatories.** Approvers sign holdings and pending contracts; non-approvers observe. | Never needed: a non-approver is not a signatory. | Chosen. No extra contract, no context, no delegation. Cost: the model is baked into every holding's signatories, so it is fixed per registry. |
| **M2 Co-sign always, registry-wide delegation.** Keep both parties as signatories; each provider signs one delegation contract per registry that the workflow exercises to borrow its authority. | From the delegation contract (F3). | Rejected. The workflow must fetch it (F4), so it needs the contract id in the choice context and the contract disclosed: the same plumbing as `AccountConfig`, per provider instead of per account. |
| **M3 Co-sign always, consumption through a choice controlled by approvers.** | From the holding's own signatories (F3). | Rejected. Works for consumption, fails at creation (F1): a holding signed by the provider cannot be created in a transaction where the provider's authority is absent, which is exactly the owner-only case. |
| **M4 Owner-only calls always produce a request the provider funds.** | Later, from the provider's own accept. | Subsumed by M1 as the `coSigned` model. It cannot express "provider need not approve". |

M1 is the only mechanism that covers the full `AccountConfig` range with no
on-ledger plumbing. Its one real cost is immutability, treated in section 9.

### 4. The model

```daml
-- OpenZeppelin.TokenCIP112WorkflowsV1.Holding
data AccountModel = AccountModel with
    ownerMustApprove : Bool
      -- ^ The owner signs the account's holdings and pending contracts and
      -- is part of every value-moving approval.
    providerMustApprove : Bool
      -- ^ Likewise for the provider.
    providerCanInitiate : Bool
      -- ^ The provider may start a transfer or allocation. The owner always
      -- may (F7, MUST).
  deriving (Eq, Show)

isValidAccountModel : AccountModel -> Bool
isValidAccountModel m = m.ownerMustApprove || m.providerMustApprove
```

Stored in `RegistryConfig` as `accountModel`. Basic accounts (no provider,
or provider equal to owner) ignore it: owner initiates, owner approves, as
today.

| Preset | owner approves | provider approves | provider initiates | `AccountConfig` pair (owner, provider as canInitiate/mustApprove) | Reading |
| --- | --- | --- | --- | --- | --- |
| `ownerControlled` | yes | no | no | T/T, F/F (`ic`) | Self-directed; provider watches |
| `jointControl` | yes | yes | yes | T/T, T/T (`j`) | Either starts, both approve |
| `coSigned` | yes | yes | no | T/T, F/T | Both approve, only the owner starts |
| `providerConfirmed` | no | yes | no | T/F, F/T (`pc`) | Owner requests, provider executes |
| `providerControlled` | no | yes | yes | F/F, T/T (`p`) plus owner requests | Custodial; the provider moves funds |

The single deviation from `AccountConfig`: the owner can always initiate,
because the spec says MUST. Under `providerControlled` an owner-initiated
call creates a request the provider funds or withdraws; it never moves
funds.

Derived sets, pure functions beside the type:

```daml
approvers  : AccountModel -> Party -> HoldingV2.Account -> [Party]
-- [owner | ownerMustApprove] <> [provider | providerMustApprove] for a
-- provider account; accountParties otherwise.

initiators : AccountModel -> Party -> HoldingV2.Account -> [Party]
-- owner :: [provider | providerCanInitiate] for a provider account;
-- accountParties otherwise.
```

Visibility never shrinks: `accountParties` remains the observer set, the
event observer set, and the lock-holder set (F7, providers MUST see).

### 5. Who signs what

| Contract | Signatories | Observers |
| --- | --- | --- |
| Holding | admin, `approvers` of its account | lock holders, the account's non-approving party |
| Transfer instruction, any stage | admin, `authorizedBy` (section 6) | remaining sender account parties, receiver account parties |
| Allocation instruction (new) | admin, `authorizedBy` | remaining authorizer account parties, executors |
| Allocation | admin, `approvers` of the authorizer | executors, the authorizer's non-approving party |
| Rules | admin | as today |

Consequences to state in the README: under the two provider-approves models
the owner does not sign their own holdings and the provider can move them
without the owner's authority. That is what those models mean. The owner
sees every movement.

### 6. Bounded accumulation

With F6, a step that needs two approvers cannot be one joint submission. It
is two unilateral submissions, and the contract between them carries the
first approver's authority forward as a signatory (F1 and F3). That is the
whole state machine: a pending contract records `authorizedBy : [Party]`,
each remaining approver accepts alone, and the step completes when
`authorizedBy ∪ actors ⊇ approvers`. There are at most two approvers per
account, so at most two submissions per side, and `availableActions` lists
each remaining approver as a group of one.

Which steps accumulate follows from F3. A step needs accumulation only when
it consumes a contract or creates one whose signatories are not yet all
present:

| Step | Needs all of | Carried by the exercised contract | Accumulates? |
| --- | --- | --- | --- |
| Fund a transfer (consume inputs, create locked holding) | sender approvers | request: admin plus initiators | yes, if an approver is missing |
| Accept a funded transfer (create receiver holding) | receiver approvers | instruction: admin plus sender approvers | yes, if the receiver has two approvers |
| Fund an allocation (consume inputs, create locked holding and allocation) | authorizer approvers | allocation instruction: admin plus initiators | yes, if an approver is missing |
| Withdraw, reject, cancel, expire a funded instruction (unlock to sender) | sender approvers | instruction signatories already include them | no: unilateral by any permitted controller |
| Withdraw or cancel an allocation (unlock) | authorizer approvers | allocation signatories already include them | no |
| Settle (consume locked, create payouts) | authorizer approvers | allocation signatories | no |
| Owner unlock (recreate unlocked) | approvers | the holding's own signatories | no: unilateral by any approver |
| Mint, burn | admin plus approvers | nothing | operational, submitted jointly |

So accumulation exists in exactly three places, each a two-step loop at
most, and everything that returns value to its own account stays a single
submission.

### 7. Authorization per operation

| Operation | Actors accepted | Outcome |
| --- | --- | --- |
| `TransferFactory_Transfer` | a non-empty subset of sender account parties containing an `initiator` | actors ⊇ sender approvers ∪ receiver approvers: one step. Actors ⊇ sender approvers: funded instruction, `Pending`. Otherwise: request, `Pending`, nothing consumed |
| `TransferInstruction_Accept`, request stage | any missing sender approver | records the approver; funds when complete, creating the funded instruction with `originalInstructionCid` set |
| `TransferInstruction_Accept`, funded stage | any missing receiver approver | records the approver; pays when complete, `Completed` |
| `TransferInstruction_Reject` | any receiver account party | request: archive; funded: unlock to sender, `Failed` |
| `TransferInstruction_Withdraw` | any sender account party that initiated or approves | request: archive; funded: unlock, `Failed` |
| `AllocationFactory_Allocate` | a non-empty subset of authorizer account parties containing an `initiator` | actors ⊇ approvers: allocation, `Completed` (today's path). Otherwise: allocation instruction, `Pending` |
| `AllocationInstruction_Accept` | any missing approver | records; funds when complete, `Completed` |
| `AllocationInstruction_Withdraw` | any authorizer account party that initiated or approves | archive, `Failed` |
| `Allocation_Withdraw` | any authorizer approver | as today |
| `Allocation_Settle`, `Allocation_Cancel` | admin plus executors; executors or admin after expiry | unchanged |
| `TokenHolding_OwnerUnlock` | any approver of the account | as today |
| Mint, burn | admin plus all approvers | as today |
| Admin expiry | admin, after `expiresAt`, on every pending stage | request and allocation instruction: archive; funded: unlock |

Reject and withdraw are deliberately open to any account party rather than
only approvers: they return value to where it came from or leave it where it
is, so there is nothing to protect, and a provider who cannot stop an
outgoing request the owner started is a worse policy than one who can.

### 8. Transfer, stage by stage

```text
TransferFactory_Transfer by initiator(s)
  ├─ actors ⊇ approvers(sender) ∪ approvers(receiver) ──► moved, Completed
  ├─ actors ⊇ approvers(sender)                        ──► Funded, Pending
  └─ otherwise ──► Request, Pending
        payload: transfer, original inputs (still unlocked), authorizedBy = actors
        ├─ Accept by a missing sender approver
        │     ├─ still missing one ──► Request, authorizedBy grown
        │     └─ complete ──► inputs consumed, amount locked ──► Funded
        ├─ Withdraw / Reject ──► archived, Failed
        └─ admin expiry after expiresAt ──► archived

Funded (signatories admin + sender approvers)
        ├─ Accept by a missing receiver approver
        │     ├─ still missing one ──► Funded, authorizedBy grown
        │     └─ complete ──► receiver paid, Completed
        └─ Reject / Withdraw / expiry ──► unlocked to sender (as today)
```

A request references inputs that stay spendable. If the owner spends them
first, the funding accept fails on the missing contracts and the request is
withdrawn or expires. No value is at risk in a request, so it carries no
lock and no grace window.

### 9. Immutability and migration

The model is part of each holding's signatory set, so it cannot change
underneath live holdings. `RegistryConfig` is per rules contract, and a new
rules contract with a different model would meet old holdings with the old
signatories:

- **Tightening** (adding an approver) is safe: the new actor check demands
  more than the old archive needs, so old holdings still move once everyone
  acts.
- **Loosening** (removing an approver) strands old holdings: the new check
  lets the owner act alone, and the archive then fails for lack of the
  removed party's authority. A loosening needs a migration choice on the
  holding, controlled by its old signatories, that recreates it under the
  new model. Out of scope; documented.

The README states the model is chosen at launch per instrument admin and
that only tightening is a configuration change. The code cannot enforce this
across contracts.

### 10. Changes against the current two packages

#### workflows

- `Holding`: `AccountModel`, presets, `isValidAccountModel`, `approvers`,
  `initiators`; `RegistryConfig.accountModel`; the `createHolding` law
  becomes "signatories include the admin and `approvers model admin
  view.account`".
- `Transfer`: `TransferInstructionState` gains `stage : TransferStage`
  (`Request | Funded`), `authorizedBy : [Party]`, `accountModel`;
  `isValidTransferInstructionState` ties the stage to whether
  `lockedHoldingCids` is empty; `transferInstructionView` lists each missing
  approver alone, per stage; `transferFactoryImpl` makes the three-way
  split; `transferAcceptImpl` dispatches on stage and accumulates;
  `transferRejectImpl` and `transferWithdrawImpl` handle the request stage
  by archiving only.
- `Allocation`: `AllocationState.accountModel`; new
  `AllocationInstructionState`, `allocationInstructionView`,
  `allocationInstructionAcceptImpl` (accumulate, then today's funded
  allocate body), `allocationInstructionWithdrawImpl`,
  `allocationInstructionExpireImpl`; `allocationFactoryImpl` splits on
  whether the actors cover the approvers.
- `Registry`: `mintImpl` and `burnImpl` take `approvers`; a new
  `expireAllocationInstructionsImpl`.

#### templates

- `TokenHolding`: a `model : AccountModel` field; `signatory admin,
  approvers model admin holding.account`; the non-approving account party
  becomes an observer; `TokenHolding_OwnerUnlock` controlled by any
  approver. `defaultHoldingOps admin model`.
- `TokenTransferInstruction`: `signatory admin, state.authorizedBy`, one
  rule for every stage.
- New `TokenAllocationInstruction` implementing
  `AllocationInstructionV2.AllocationInstruction`, with admin expiry.
- `TokenRules`: a fourth constructor `createAllocationInstruction`;
  `ensure` adds `isValidAccountModel`; a
  `TokenRules_ExpireAllocationInstructions` choice.

All records are pre-release, so the new fields are plain fields now; after a
release they would have to be `Optional`.

#### consumers

A consumer serving only basic accounts changes nothing but the new fields
and the extra constructor. A consumer serving provider accounts picks a
model at launch and gains a thin `AllocationInstruction` wrapper. Per-account
models later would keep `approvers` and `initiators` unchanged and feed them
a model looked up per account.

### 11. Tests

- Table-driven over the five presets, sender and receiver each with a
  distinct provider: transfer initiated by owner, by provider, by both;
  allocation by owner and by provider; assert the stage, the unilateral
  actor sets reported, and the final balances. Thirty scenarios in the shape
  of Splice's `test_transfer_flows`.
- Accumulation: under `jointControl`, owner then provider fund; provider
  then owner accept on the receiver side; the intermediate contract's
  signatories include the first approver.
- Negatives: provider initiating under `providerConfirmed` and `coSigned`;
  owner funding alone under `providerConfirmed`; a non-account party; an
  approver accepting twice.
- Request lifecycle: inputs spent before funding, request expiry, request
  reject, request withdraw by the provider.
- Visibility: under every model the provider sees every holding and pending
  contract of the account.
- Synchronous completion: a factory call whose actors cover every account
  party completes in one step under every preset.
- Parity: the existing thirty-six scripts unchanged on basic accounts.

### 12. What this gives up relative to `AccountConfig`

- One model per registry, not per account.
- Accumulation only where authority forces it; withdraw, reject, and cancel
  are unilateral rather than accumulated.
- The model is fixed at launch; loosening needs a migration.
- The provider is never both a signatory and excused from approving: where
  `TestTokenV2` keeps the provider signing and lends its authority, this
  design makes a non-approving provider an observer. Same movements, a
  different answer to who could in principle block them.

### 13. Open questions

1. `model : AccountModel` on `TokenHolding` versus `approvers : [Party]`
   written at creation. The field is self-describing; the list keeps the
   signatory clause trivial for consumers. Proposal: the model.
2. Should a funding accept that happens to include the receiver's approvers
   complete the transfer in one go? Proposal: no; the receiver accepts the
   funded instruction separately. Fewer paths.
3. Whether reject and withdraw should be open to any account party or only
   to initiators and approvers. Proposal: any account party, for the reason
   in section 7.