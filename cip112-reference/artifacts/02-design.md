---
stage: design
project: cip112-reference
mode: greenfield
extends: null
status: draft
timestamp: 2026-09-01
author: ionut.gingu
previous_stage: artifacts/01-research.md
tags: [cip-0112, cip-0056, token-standard, canton, splice, reference-implementation, deploy-as-is, daml-3.5]
---

# CIP-0112 Reference Token — Design Document

## Summary

A deploy-as-is CIP-0112 (Canton Network Token Standard V2) token package — the Daml
equivalent of OpenZeppelin's ERC-20: an issuer uploads the DAR, creates one `Registry`
contract with their `admin` party and `instrumentId`, stands up a thin off-ledger
endpoint server, and has a fully compliant token without writing Daml. The core is a
V2-native implementation with V1 compatibility via the upstream
`splice-token-standard-utils` shims, a single internal settle seam through which every
holding create/archive flows, and a single fixed account authorization policy
(owner-OR-provider). Customization beyond the deploy-time knobs is fork-and-adapt,
kept compliant by a vendored-source conformance suite.

## Toolchain

- **SDK pin: Daml 3.5.1** (Canton 3.5.1). Target **Daml-LF 2.3** — required for
  contract keys, which Canton 3.5 reintroduces with changed semantics: **keys are
  non-unique** (multiple contracts may share a key) and **negative lookups are not
  validated**. Both properties are load-bearing constraints below.
- **Upstream dependencies (exact DARs, never republished):** the six
  `splice-api-token-*-v2` packages, their V1 equivalents, and
  `splice-token-standard-utils` v2.0.0, pinned at splice commit
  `6bcae32a2b9763b7c7b9800100aca7f0d426c76d`. Upstream builds with SDK 3.5.2 at
  LF 2.1.
- **Validation gate (before any code is written):**
  1. The upstream DARs (built 3.5.2, LF 2.1) load and their interfaces are
     implementable under SDK 3.5.1.
  2. An LF 2.3 package may depend on LF 2.1 packages.
  3. `fetchByKey` / `lookupNByKey` authorization and visibility semantics under
     3.5.1 match the seam's assumptions (admin fetching admin-maintained keys;
     owner-maintained `Account` keys resolvable in the flows that need them).
  If the gate fails on (1)/(2), fallback is SDK 3.5.2 — a one-line revision. If (3)
  fails, key usage degrades to choice-context-served contract-ids (the keyless
  pattern), a local design patch.

**LF-mixing resolution (2026-09-01 discussion):** Daml-LF minor versions are backward
compatible within the 2.x major — a package targeting LF 2.3 depending on LF 2.1
packages is the supported direction (the reverse is impossible, and nothing upstream
imports us). Contract keys are template-level; the interfaces we implement neither
know nor care. The gate items above are retained as smoke tests; the one point worth
explicit exercise is an LF 2.3 template providing an interface instance for an LF 2.1
interface.

**Upstream reuse boundary:** the interface packages are consumed as-is and are
non-negotiable — wallets address tokens by interface identity *including package-id*,
so a republished copy is invisible to every integrator (the ChainSafe `canton-erc20`
1.0 failure). `splice-token-standard-utils` is imported as a function library. All
templates are ours — upstream ships none intended for production.

## Consumption Model

**Primary: deploy-as-is.** Every issuer-facing knob is a field, not a code edit:
`admin : Party`, `instrumentId : Text`, `maxInstructionTtl : RelTime` (all on
`Registry`, immutable after creation), plus static off-ledger metadata (name, symbol,
decimals, `supportedApis`). One uploaded DAR can serve many issuers (Registry is
parameterized, one contract per instrument).

**Secondary: fork-and-adapt.** Daml has no template inheritance or override —
changing semantics (KYC gates, fees, different account policies, pause) means editing
the source. The conformance suite is the contract that keeps forks compliant.

**Composition** (third parties importing the package to orchestrate our templates
from their own workflow contracts) works by construction and needs no design support.

**Runtime integrators** (wallets, exchanges, indexers, trading apps) code against the
upstream `splice-api-token-*` interfaces and the standard off-ledger endpoints — never
against this package. That is the standard working as intended, for every compliant
token including this one.

## Module Structure

```
Production package: openzeppelin-token-cip112-v2  (namespace OpenZeppelin.Token.CIP112.V2)

- ...V2.Registry        — factory hub template: TransferFactory (V1+V2), AllocationFactory
                          (V1+V2), SettlementFactory, EventLog on one contract; account
                          opening and mint entry points
- ...V2.Account         — Account + AccountOpenProposal templates, OR-policy helpers
- ...V2.Holding         — Holding template (lock as a field), HoldingV2 + V1 instances
- ...V2.Transfer        — TokenTransferInstruction, TransferInstruction V2 + V1 instances
- ...V2.Allocation      — TokenAllocationInstruction, AllocationV1V2, AllocationV2Only,
                          FinalizedAllocationReceipt
- ...V2.Internal.Settle — THE seam: every holding create/archive flows through here —
                          debit/credit, conservation, exact-cover batch validation,
                          exactly-one-EventLog-per-change (private module, .Internal)
- ...V2.Types           — shared records/variants (Lock, CallSource, account refs)
- ...V2.Errors          — error text constants, one per condition, INV-N tagged

Data-dependencies: the pinned upstream DARs listed under Toolchain.

Test/conformance package (never released, vendored-source layout consumers copy):
- Conformance.Adapter      — RegistryApi-style typeclass: the seam a fork implements
                             (allocate admin, create their factory, serve choice contexts)
- Conformance.Behaves      — behavesLikeCIP0112* suites (transfer, allocation, settlement,
                             account lifecycle, V1 compatibility)
- Conformance.Regressions  — V2_VALIDATION bug history + CertiK's six classes as named tests
```

There is no extension catalogue and no config contract in this design (see Out of
Scope): the core is the smallest compliant, hardened token.

## Core Templates

Notation: `accountParties = owner :: optionalToList provider`.

### Registry — factory hub (long-lived singleton, one per instrument)

```daml
-- | Implements TransferFactory (V1+V2), AllocationFactory (V1+V2), SettlementFactory,
-- and EventLog. Its ContractId is what off-ledger discovery serves to wallets —
-- deliberately immutable, never archive-recreate.
template Registry
  with
    admin : Party              -- the InstrumentId.admin; sole registry authority
    instrumentId : Text        -- single-instrument registry
    maxInstructionTtl : RelTime  -- deploy-time hygiene bound on instruction expiresAt
  where
    signatory admin
    ensure instrumentId /= ""
    key (admin, instrumentId) : (Party, Text)   -- exerciseByKey for admin ops/scripts
    maintainer key._1
```

### Account — authorization root (long-lived, one per account id)

```daml
-- | OR-policy account: owner always present, provider optional; EITHER account party
-- alone may move funds out or accept funds in. Admin is a SIGNATORY so that creation
-- is only possible through Registry_OpenAccount (registry-routed opening is enforced,
-- not voluntary). Admin cannot forge an account: owner (+ provider) must also sign
-- via the opening flow. Mint/burn accounts ("cip-112/mint"/"cip-112/burn") are
-- VIRTUAL — no Account contract; admin authorizes those flows directly.
template Account
  with
    admin : Party
    instrumentId : Text
    owner : Party              -- required ⇒ every holding has a total V1 view
    provider : Optional Party
    accountId : Text
  where
    signatory admin :: owner :: optionalToList provider
    ensure accountId /= "" && Some owner /= provider
    key (owner, accountId) : (Party, Text)   -- maintainer must be a signatory ⇒ owner.
    maintainer key._1                        -- Keys are NON-UNIQUE: dedup happens at
                                             -- opening (lookupNByKey + admin's index).
```

### AccountOpenProposal — propose-accept for provider accounts (short-lived, TTL)

```daml
template AccountOpenProposal
  with
    admin : Party
    instrumentId : Text
    owner : Party
    provider : Party
    accountId : Text
    expiresAt : Time
  where
    signatory admin, owner
    observer provider
```

### Holding — the asset (consumed on every movement)

```daml
-- | Admin's signature is the conservation guarantee: no holding exists that didn't
-- pass the seam. Account parties' signatures give them ledger-level authority over
-- the asset (the hole Corda's app-layer accounts had). A LOCKED holding is this same
-- template with lock = Some … — matching the V1 view's lock field and keeping
-- conservation a sum over one template. No contract key (many per account by design;
-- holdings are addressed by cid — they are the standard's capability tokens).
template Holding
  with
    admin : Party
    instrumentId : Text
    owner : Party
    provider : Optional Party
    accountId : Text
    amount : Decimal
    lock : Optional Lock       -- {holders, expiresAt, context}
  where
    signatory admin :: owner :: optionalToList provider
    ensure amount > 0.0
    -- interface instances: HoldingV2 (view builds Account{owner,provider,id});
    -- V1 Holding via the utils shims (account info mirrored into V1 meta)
```

### TokenTransferInstruction — in-flight transfer (short-lived, TTL-capped)

```daml
-- | Sender-side-locked two-step transfer: creation debits input holdings into one
-- locked holding; receiver accept consumes instruction + lock into the receiver's
-- holding. Implements TransferInstruction V2 natively, V1 via the *UsingV2 shims.
template TokenTransferInstruction
  with
    admin : Party
    transfer : Transfer            -- upstream record: sender/receiver accounts, amount,
                                   -- requestedAt, executeBefore, meta
    lockedHoldingCid : ContractId Holding
    expiresAt : Time               -- ≤ registry maxInstructionTtl
  where
    signatory admin :: senderAccountParties transfer
    observer receiverAccountParties transfer
```

### TokenAllocationInstruction — pending allocation approval (short-lived, TTL-capped)

```daml
-- | Exists only when allocation creation needs another party's approval (the V2
-- AllocationInstruction_Accept flow); elided when requester authority suffices.
template TokenAllocationInstruction
  with
    admin : Party
    spec : AllocationSpecification
    fundingLockCid : Optional (ContractId Holding)
    expiresAt : Time
  where
    signatory admin :: senderAccountParties spec
    observer approvers spec
```

### AllocationV1V2 and AllocationV2Only — the dual pair (short-to-medium-lived)

```daml
-- | V2-only: full committed/iterated support (committed, nextIterationFunding);
-- optional funding lock (None when net movement is positive — Amulet net-locking).
-- Implements the V2 Allocation interface ONLY — cleanly invisible to V1 consumers.
template AllocationV2Only
  with
    admin : Party
    spec : AllocationSpecification
    fundingLockCid : Optional (ContractId Holding)
  where
    signatory admin :: senderAccountParties spec
    observer settlementExecutors spec

-- | Dual V1+V2: created only when the spec is V1-representable (not committed, no
-- iteration) — the ensure guard makes a lossy V1 view UNCONSTRUCTIBLE. Interface
-- instances are static per template; this pair is the only way to give V1 consumers
-- exactly the allocations they can fully parse. (TestTokenV2's validated pattern.)
template AllocationV1V2
  with
    admin : Party
    spec : AllocationSpecification
    fundingLockCid : Optional (ContractId Holding)
  where
    signatory admin :: senderAccountParties spec
    observer settlementExecutors spec
    ensure canViewAsAllocationV1 spec
```

The factory selects the template from the spec; wallets never choose. Both templates
carry the `CallSource = CalledFromV1 | CalledFromV2` archival discipline: the V2
interface declares choices nonconsuming, semantics require consumption, so bodies
archive explicitly and emit both parsers' events on every path.

### FinalizedAllocationReceipt — settlement receipt (created by settle)

```daml
-- | Implements the upstream FinalizedAllocation interface: durable evidence a settled
-- allocation existed (consumed by apps like TradingAppV2's receipt-delegation pattern).
template FinalizedAllocationReceipt
  with
    admin : Party
    spec : AllocationSpecification
    settledAt : Time
  where
    signatory admin :: senderAccountParties spec
    observer settlementExecutors spec
```

### Not templates, by design

- **EventLog** — interface instance on `Registry` (`EventLog_HoldingsChange`:
  nonconsuming, side-effect-free, controller admin, visibility via choice observers).
- **Mint/burn accounts** — virtual ids, no contracts; ownerless-ness confined here.
- **RegistryConfig / PauseState** — removed with the pause extension (see Out of Scope
  and Design Decisions Log #9).

### The seam (`Internal.Settle`) — mechanics

- **`debitHoldings` (the only input-consuming path):** asserts every input is
  unlocked, matches our `instrumentId`, and belongs to the sender account named in
  the transfer; asserts `sum ≥ amount`; archives all inputs; creates one **locked**
  holding of exactly `amount` and one unlocked **change** holding of `sum − amount`
  back to the sender account (omitted when zero).
- **`Lock` shape:** `holders = [admin]`, `expiresAt = instruction.expiresAt`,
  `context = <instruction reference>`. Counterparties are never lock holders — the
  only unlock paths are the instruction's own choices (accept/reject/withdraw/
  expire), all carrying admin authority. No standing authority escapes the
  instruction's scope (CertiK #5).
- **Expiry semantics (no race window):** all checks use ledger effective time —
  `Accept` requires `now < expiresAt`; `Expire` requires `now ≥ expiresAt`;
  `Reject`/`Withdraw` work regardless of expiry (reversal paths never strand funds).
- **EventLog emission points:** initiation is a merge/split (`logMergeSplit` —
  balances unchanged, holdings restructured); `Accept` emits the transfer
  (`logTransfer`, or `logMint`/`logBurn` on virtual endpoints); reject/withdraw/
  expire emit the reverse merge/split. Invariant: both parsers reconstruct exact
  balances on every path, one event per account-holdings change.

## Public API (Choices)

Upstream-interface choices are fixed shapes (all nonconsuming, `controller actors`,
validated via `checkActors`); template-local choices are ours. "OR-policy": `actors`
must contain the owner or the provider of the relevant account.

### Account lifecycle

```daml
-- Registry (nonconsuming, template-local):
Registry_OpenAccount : Either (ContractId AccountOpenProposal) (ContractId Account)
  with owner : Party; provider : Optional Party; accountId : Text
  controller owner
  -- Rejects reserved ids (cip-112/*); best-effort dedup via lookupNByKey (positive
  -- finds are validated; the admin's off-ledger index is the authoritative backstop).
  -- provider = None → creates Account directly (admin authority from Registry +
  -- owner from controller). provider = Some p → creates AccountOpenProposal.

-- AccountOpenProposal:
AccountOpenProposal_Accept   : ContractId Account   controller provider  -- consuming
AccountOpenProposal_Reject   : ()                   controller provider  -- consuming
AccountOpenProposal_Withdraw : ()                   controller owner     -- consuming

-- Account:
Account_Close : ()  controller closer  -- consuming; closer must be an account party
```

### Mint and burn — they ARE transfers (no dedicated machinery)

Mint = standard transfer FROM virtual `cip-112/mint` (sender side = admin alone):
**two-step** — `Registry_Mint` (controller admin) creates a `TokenTransferInstruction`;
the receiver accepts it normally. Burn = standard transfer TO `cip-112/burn`:
**one-step** — `TransferFactory_Transfer` with receiver = burn account completes
immediately (the burn side needs only admin authority, already in scope at the
factory). Consequences: one seam path for all value movement; uniform EventLog
emission (`logMint`/`logBurn` fire on the virtual endpoints); receiver consent to
mint for free.

```daml
Registry_Mint : ContractId TokenTransferInstruction
  with to : AccountRef; amount : Decimal; ...
  controller admin   -- nonconsuming
```

### Transfers

```daml
-- Registry (upstream TransferFactory, V2 + V1 shim):
TransferFactory_Transfer   -- actors: sender side, OR-policy
  -- Seam: debit inputs (reject locked, reject wrong instrument), lock the debited
  -- sum, create instruction (TTL ≤ maxInstructionTtl), change output to sender.

-- TokenTransferInstruction (upstream TransferInstruction V2 + V1 shim; bodies
-- archive explicitly with CallSource):
TransferInstruction_Accept    -- actors: receiver side, OR-policy → unlock into receiver holding
TransferInstruction_Reject    -- actors: receiver side, OR-policy → funds return to sender
TransferInstruction_Withdraw  -- actors: sender side,  OR-policy → funds return to sender

-- Template-local:
TransferInstruction_Expire : ()  -- consuming; controller: admin OR a sender-side party;
                                 -- only after expiresAt; funds return to sender
```

### Allocations & settlement

```daml
-- Registry (upstream AllocationFactory V2 + V1 shim):
AllocationFactory_Allocate   -- actors: sender side, OR-policy
  -- Factory selects template: V1-representable → AllocationV1V2, else AllocationV2Only.
  -- Direct-create when requester authority suffices; else TokenAllocationInstruction.

-- TokenAllocationInstruction:
AllocationInstruction_Accept    -- actors: pending approvers
AllocationInstruction_Withdraw  -- actors: sender side
AllocationInstruction_Expire    -- template-local, consuming; admin or sender, post-TTL

-- Both allocation templates (upstream Allocation V2; + V1 on AllocationV1V2):
Allocation_Settle    -- actors: settle authority = admin :: executors (standard default)
Allocation_Cancel    -- actors: executors → funding lock released to sender
Allocation_Withdraw  -- actors: sender side — subject to the committed policy below

-- Registry (upstream SettlementFactory):
SettlementFactory_SettleBatch  -- controller executors; exact-cover validation via
  -- settlementFactoryV2_settleBatchDefaultImpl (leg set-equality, leg-id uniqueness);
  -- honors ≥25-leg/50-allocation/50-account/100-party minimums; executor-only
  -- submission context (privacy — the Corda backchain lesson)

-- Registry (upstream EventLog):
EventLog_HoldingsChange  -- nonconsuming, side-effect-free, controller admin;
                         -- exercised by the seam exactly once per account-holdings change

-- Admin housekeeping:
Registry_ExpireAllocations  -- batch-expires only EXPIRED allocations (Amulet
                            -- discipline: delegated cleanup cannot cancel live ones)
```

**Committed-allocation policy** (answered in code, not forums): while
`committed = True` and `settlementDeadline` has not passed, `Allocation_Withdraw`
fails — that is what committed means. Once the deadline passes the commitment is
void: withdraw succeeds and admin housekeeping may expire it. Deadline overrides
committed, always. Settle after the deadline fails.

**Iterated settlement mechanics** (pinned from upstream `AllocationV2.daml`):
`nextIterationFunding : Optional (TextMap Decimal)` (keyed by instrument id) has
three distinct states — `None` = iteration disabled (single-shot, exact legs only);
`Some empty` = iteration enabled, no funding reserved; `Some map` = iteration
enabled with reserved amounts. `Allocation_Settle` takes `extraTransferLegSides`
(MUST be rejected when iteration is disabled) and its own `nextIterationFunding` for
the following round; when the next round is funded, settle atomically creates a
**successor allocation** (returned as `nextIterationAllocationCid`). Our rules:

- **Single-instrument degeneration:** the `TextMap` has at most one entry and the
  seam asserts its key equals our `instrumentId` — this is also the defense against
  the V2_VALIDATION `netAllocationCreditAmounts` instrument-mixing bug.
- **Successor funding = net-locking:** the successor's funding lock holds exactly
  the reserved amount (no lock when zero); iteration N's lock is never reused.
- **Template stability:** any spec with `nextIterationFunding = Some …` fails
  `canViewAsAllocationV1`, so iterated allocations and all successors are
  `AllocationV2Only`; the dual-template split never flips mid-lifecycle.
- **Inheritance:** the successor inherits `committed` and the same
  `settlementDeadline`; the committed policy above applies per iteration.

### View discipline: `availableActions`

Upstream type (both instructions and allocations): `Map <Action> [[Party]]` — "a
disjunction of conjunctions": each inner list is a group acting jointly; multiple
inner lists are alternatives. Under the OR-policy every inner list is a singleton,
e.g. for a transfer pending into Bob's custodial account:

```daml
availableActions = Map.fromList
  [ (TransferInstructionAction_Accept,   [[bob], [cust]])            -- receiver side
  , (TransferInstructionAction_Reject,   [[bob], [cust]])
  , (TransferInstructionAction_Withdraw, [[senderOwner], [senderProvider]]) ]
```

Consequences: (1) instruction/allocation payloads must carry **both accounts' party
sets**, captured from the `Account` contracts at creation — views are pure functions
of the payload; (2) the invariant is **bidirectional**: every listed group succeeds
as `actors` (soundness) and every actor set that succeeds is listed (completeness).
A wrong map never fails on-ledger — it silently breaks wallet UIs — so it carries
its own INV and conformance tests drive both directions.

## Party / Authorization Model

```
Role → Contract → Relationship

admin     → Registry                  → signatory (factory hub; sole registry authority)
admin     → Account, AccountOpenProposal → signatory (enforces registry-routed opening;
                                        cannot forge — owner/provider must also sign)
admin     → Holding                   → signatory (conservation: every holding passed the seam)
admin     → all instruction/allocation/receipt templates → signatory

owner     → Account, Holding          → signatory (ledger-level authority over own assets)
owner     → AccountOpenProposal       → signatory (proposer)
owner     → sender-side instructions/allocations → signatory (their funds locked within)

provider  → same as owner when present (Optional) — owner and provider are
            interchangeable as ACTORS in choices (OR-policy); both always SIGN

receiver side (owner/provider of destination account)
          → TokenTransferInstruction  → observer (to Accept/Reject); signs nothing sender-side
executors → allocations + receipts    → observer (settle authority = admin :: executors)
pending approver → TokenAllocationInstruction → observer
```

Privacy properties:

1. **The admin sees everything** — signatory on every contract. Inherent to the
   single-registry model (Amulet is identical) and what lets a thin off-ledger server
   serve choice contexts and disclosures. A stated property, not a leak.
2. **Third parties see nothing** — no observers beyond direct workflow counterparties.
3. **SettleBatch: each party sees only their own legs — a HARD REQUIREMENT**
   (dev-stated, 2026-09-01; CertiK #6). Canton's projection model delivers it:
   `SettleBatch` is the root exercise (informees: admin + executors) with one
   `Allocation_Settle` sub-exercise per allocation (informees: that allocation's
   stakeholders); a party's projection is the nodes they're informee of plus their
   subtrees, so leg parties never see the root or sibling legs. Four rules preserve
   it: (a) leg parties are never choice observers on the root node; (b) no
   batch-wide data flows downward — per-leg sub-exercise arguments, receipts, and
   holdings carry only that leg's data; (c) admin and executors see the whole batch
   (unavoidable and correct — they orchestrate it); (d) events are per-leg, with
   that account's parties as choice observers — never one batch event observed by
   all. Testability split: per-party contract visibility is assertable in Daml
   Script; node-level projection needs end-to-end validation against a real
   participant.
4. **Interface views leak nothing extra** — V1/V2 views expose fields the template's
   stakeholders already see.

Hosting: admin, owners, providers, and executors may all be on separate participants;
nothing assumes co-hosting.

## Integration Patterns

### The issuer (primary consumer): deploy-as-is

| OZ ERC-20 world | This package |
|---|---|
| `contract MyToken is ERC20("MyToken","MTK")` | Upload the DAR; `create Registry with admin = you, instrumentId = "MTK", maxInstructionTtl = …` |
| Constructor args | Deploy-time fields + static off-ledger metadata |
| `_mint` + your access control | `Registry_Mint`, controller = your admin party |
| Wallet/DEX integration via the ERC-20 ABI | Via CIP-0112 interfaces + your off-ledger endpoints — integrators never see this package |
| Custom behavior → override hooks | Custom behavior → fork the source; conformance suite keeps the fork compliant |

Operating a CIP-0112 token additionally means running the off-ledger endpoint server
(standard-inherent; a last-step deliverable of this project — the Daml side is shaped
so the server stays thin: admin observes everything it must disclose).

### The wallet's-eye flow (Daml Script sketch — also the conformance suite's shape)

```daml
example : Script ()
example = do
  admin <- allocateParty "Registry"
  alice <- allocateParty "Alice"     -- self-custodied owner
  bob   <- allocateParty "Bob"; cust <- allocateParty "Custodian"

  registryCid <- submit admin $ createCmd Registry with
    admin, instrumentId = "OZT", maxInstructionTtl = hours 24

  -- Account opening: registry-routed; provider-less is one step,
  -- with provider it is propose-accept.
  Right aliceAcct <- submit alice $ exerciseCmd registryCid
    Registry_OpenAccount with owner = alice, provider = None, accountId = "alice-main"
  Left prop <- submit bob $ exerciseCmd registryCid
    Registry_OpenAccount with owner = bob, provider = Some cust, accountId = "bob-cust"
  bobAcct <- submit cust $ exerciseCmd prop AccountOpenProposal_Accept

  -- Mint: transfer from cip-112/mint; the CUSTODIAN alone accepts (OR-policy).
  -- In production the wallet fetches choice context + disclosures from the
  -- off-ledger endpoints; in script the conformance Adapter plays that role.
  mintInstr <- submit admin $ exerciseCmd registryCid
    Registry_Mint with to = accountRef bobAcct, amount = 1_000.0
  [bobHolding] <- submit cust $ exerciseCmd
    (toInterfaceContractId @TI.TransferInstruction mintInstr)
    TI.TransferInstruction_Accept with actors = [cust], extraArgs = ctx.extraArgs

  -- Transfer Bob → Alice: sender-side factory call (Registry arrives as a
  -- disclosed contract — wallets are never stakeholders on it), receiver accepts.
  instr <- submitWithDisclosures cust [registryDisclosure] $ exerciseCmd
    (toInterfaceContractId @TF.TransferFactory registryCid)
    TF.TransferFactory_Transfer with
      transfer = Transfer with sender = accountRef bobAcct, receiver = accountRef aliceAcct,
                               amount = 250.0, inputHoldingCids = [toInterfaceContractId bobHolding], ..
      actors = [cust], extraArgs = ctx.extraArgs
  submit alice $ exerciseCmd instr TI.TransferInstruction_Accept with actors = [alice], ..

  -- Burn: a transfer to cip-112/burn — completes in one step, no receiver accept.
  pure ()
```

Allocations follow the same grammar; executors drive `SettlementFactory_SettleBatch`
from an executor-only submission. Trading apps (upstream `TradingAppV2` pattern)
integrate through `Allocation`/`SettlementFactory` interface cids without knowing our
templates exist.

### Off-ledger endpoint ↔ Daml artifact mapping (the server spec's skeleton)

| Endpoint | Backed by |
|---|---|
| `GET /registry/metadata/v1/info` | static config: `supportedApis` (V1+V2), `paused: false` |
| `GET …/instruments[/{id}]` | static metadata for the single `instrumentId` |
| `POST …/transfer-instruction/{v1,v2}/transfer-factory` | `Registry` cid + disclosure + choice context |
| `POST …/choice-contexts/{accept,reject,withdraw}` (transfer + allocation-instruction) | choice context (near-empty — no config contract) + needed disclosures |
| `POST …/allocation-instruction/{v1,v2}/allocation-factory` | `Registry` cid + disclosure + context |
| `POST /registry/allocation/v2/settlement-factory` | `Registry` cid (as SettlementFactory) + batch disclosures |

Near-empty choice contexts are a deliberate simplicity payoff: less untrusted registry
data for wallets to mishandle (CertiK #3).

**Indexers/parsers:** both upstream CLI parsers (`parserv1.ts`, `parserv2.ts`) must
produce correct history from our ledger output, run `--strict` (zero unexplained
creates/archives) in the conformance suite. Consumers count only EventLog events
attributed to our admin (CertiK #4).

## ensure and Runtime Checks

All error texts in `OpenZeppelin.Token.CIP112.V2.Errors`, one constant per condition,
INV-N tags assigned by Stage 3:

```daml
-- ensure clauses (creation-time)
eAmountNotPositive      = "holding amount must be positive"                 -- Holding.ensure
eAccountIdEmpty         = "accountId must be non-empty"                     -- Account.ensure
eProviderIsOwner        = "provider must differ from owner"                 -- Account.ensure
eNotV1Representable     = "allocation spec not representable in V1"         -- AllocationV1V2.ensure

-- authorization & actors (checkActors, every interface choice)
eActorNotAuthorized     = "actor is neither owner nor provider of the account"

-- seam checks (debit/credit — the invariant chokepoint)
eLockedInputHolding     = "locked holdings cannot be used as inputs"        -- V2_VALIDATION regression
eWrongInstrument        = "input holding is of a different instrument"      -- instrument-mixing regression
eInsufficientInputs     = "input holdings do not cover the amount"

-- account lifecycle (Registry_OpenAccount)
eReservedAccountId      = "account id uses a reserved prefix (cip-112/)"
eDuplicateAccountId     = "an account with this id already exists"          -- best-effort, lookupNByKey

-- instruction lifecycle
eRequestedAtInFuture    = "requestedAt must not be in the future"           -- V2_VALIDATION regression
eExecuteBeforePassed    = "instruction has expired"
eTtlExceedsMax          = "requested TTL exceeds the registry's maxInstructionTtl"
eNotYetExpired          = "cannot expire before expiresAt"

-- allocations & settlement
eCommittedNoWithdraw    = "committed allocation cannot be withdrawn before the settlement deadline"
eSettlementDeadlinePassed = "settlement deadline has passed"
eLegMismatch            = "allocations do not exactly cover the settlement legs"
eDuplicateLegId         = "duplicate leg id in settlement batch"            -- V2_VALIDATION regression
eAllocationWrongSettlement = "allocation is bound to a different settlement"  -- CertiK #1, the central one
```

Authorization violations (missing signatory/controller) are ledger-level rejections,
not messages; Stage 3 names them anyway so tests assert them via `submitMustFail`.

## Ledger Observability

No event templates. The standard's `EventLog` interface on `Registry` is the
mechanism; the discipline (a top-tier invariant): **the seam exercises
`EventLog_HoldingsChange` exactly once per account-holdings change, on every path** —
transfers, accepts, rejects/withdraws/expiry returns, change outputs, mint/burn
(attributed to the virtual `cip-112/mint`/`cip-112/burn` endpoints), and settlement.
Event visibility via choice observers = the affected account's parties (the utils'
private-asset default).

- **Wallets/exchanges:** balance = active `Holding` interface views; history = both
  upstream CLI parsers, `--strict`.
- **Issuer backend/PQS:** full state from creates/archives (admin is signatory on
  everything) + the EventLog stream; only admin-attributed events count.
- **Counterparties:** exactly the visibility in the authorization table; nothing via
  divulgence beyond what `SettleBatch`'s transaction structure requires.

## Design Decisions Log

1. **Deploy-as-is primary, fork-and-adapt secondary.** Daml has no template
   inheritance — import-and-override does not exist. Every issuer knob is a field
   (`admin`, `instrumentId`, `maxInstructionTtl`); semantics changes are forks kept
   compliant by the conformance suite. Standing tenet adopted mid-design: **where two
   compliant options exist, ship the leaner one.**
2. **V1 compatibility via V1-on-V2 shims** (TestTokenV2 direction) — dev-confirmed;
   the forward-looking direction, and the utils package provides the shims.
3. **SDK 3.5.1 / LF 2.3 with contract keys.** Corrected mid-design: Canton 3.5
   reintroduces keys (initially designed keyless on stale 3.4 knowledge). New
   semantics bind us: non-unique keys ⇒ keys give lookup, never uniqueness;
   unvalidated negative lookups ⇒ never encode state in a contract's absence.
   Keys used on `Registry` and `Account` only.
4. **Registry-routed account opening, enforced by admin's signatory role on
   `Account`.** (Corrected mid-design: with owner/provider-only signatories, routing
   would be voluntary — direct `create` would bypass it.) Why routing matters:
   (a) reserved-id protection — without it anyone could claim `cip-112/mint` and
   poison event attribution (CertiK #4); (b) duplicate suppression — non-unique keys
   can't dedup, the opening choice + admin's index can; (c) a single policy hook for
   forks (KYC, blocklist); (d) off-ledger index consistency. Routing adds admin's
   process AND signature to creation, but admin cannot forge accounts (owner/provider
   must sign via the flow).
   **Dedup layering (resolved 2026-09-01):** hard on-ledger uniqueness is impossible
   (non-unique LF 2.3 keys; the "no duplicate" branch is an unvalidated negative
   lookup). But: the security-critical reserved-id check is a pure predicate (fully
   validated, no lookup); the key `(owner, accountId)` means only an owner can
   collide with themselves (self-inflicted, third parties can't create it);
   `lookupNByKey` catches all honest/sequential duplicates; and the admin's backend
   index is authoritative — it refuses to resolve duplicated ids off-ledger, making
   them operationally inert. Hard-uniqueness path for forks that need it: an
   admin-issued one-shot `OpenAccountTicket` (backend as sequencing point).
5. **Single fixed account policy: owner-OR-provider** (dev decision). Either account
   party alone initiates and accepts. Provider-less accounts degrade to owner-only =
   V1 `basicAccount` semantics exactly. No generic policy machinery (TestTokenV2's
   ~20-flow trap), no joint-approval — one policy, closed.
6. **`owner : Party` required on real accounts** — makes every V1 view total;
   ownerless-ness confined to virtual mint/burn accounts.
7. **Lock is a field on `Holding`, not a separate template.** The standard's API
   passes holdings as interface cids, so a type split cannot protect the public
   boundary — the seam must runtime-check locks regardless; a second template would
   only split conservation accounting and double interface instances. Compensating
   control: a single internal `debitHoldings` function is the only input-consuming
   path, rejects locked inputs, owns an INV, and the V2_VALIDATION locked-inputs case
   is a named regression test.
8. **Dual allocation templates** (`AllocationV1V2` with `ensure canViewAsAllocationV1`
   + `AllocationV2Only`), factory-side selection. Interface instances are static per
   template; a single dual-interface template would show V1 consumers lossy views of
   committed/iterated allocations (silent misaccounting). TestTokenV2's validated
   pattern; `CallSource` archival discipline on both.
9. **Pause dropped entirely** (dev decision, simplicity) — and `RegistryConfig` with
   it: pause was its only content, so the seam needs no config fetch at all. Choice
   contexts become near-empty; off-ledger `paused` reports `false`. Known
   reintroduction path for forks: a seam-checked, admin-signed config contract
   fetched by key (positive fetch = validated + fresh; never existence-as-state).
10. **Mint/burn ride the standard transfer flow** against virtual
    `cip-112/mint`/`cip-112/burn` accounts (TestTokenV2 pattern): one seam path for
    all value movement, uniform events, receiver consent to mint for free. Mint is
    two-step (receiver accepts), burn one-step (admin authority already in scope).
11. **Expiry controllers: admin OR sender-side party, post-TTL only** (dev-confirmed),
    on both instruction types; admin housekeeping batch-expires only *expired*
    allocations (Amulet discipline). Expiry outcomes are deterministic (funds →
    sender), so the wider controller set adds no attack surface and prevents Corda's
    token-exhaustion failure.
12. **Committed-allocation policy:** committed blocks sender withdraw until
    `settlementDeadline`; deadline overrides committed, always; settle after deadline
    fails; admin cleanup is expired-only.
13. **Admin sees everything** — signatory on every contract; inherent to the
    single-registry model and required for thin off-ledger serving. Stated property.
14. **Conformance suite: vendored source with a typeclass adapter seam** (dev choice
    of option a) — the upstream `RegistryApi` pattern; compiled-DAR distribution is
    blocked upstream (splice TODO #594). Our own Stage 5 tests are the suite's first
    consumer.

## Out of Scope

- **Pause / on-ledger pause enforcement** — dropped for simplicity (dev decision);
  off-ledger `paused` reports `false`. Reintroduction path documented in Decision #9.
- **The entire extension catalogue** (cap, freeze/blocklist, role-gated mint roles,
  allowance/CIP-0086) — no extensions in this design; allowance explicitly rejected
  by dev. Forks add these by editing the seam they own.
- **Generic account-policy machinery and joint-approval policies** — one fixed
  OR-policy only (Decision #5).
- **On-ledger uniqueness of account ids** — impossible with non-unique LF 2.3 keys;
  mitigated at opening + admin's off-ledger index (Decision #4).
- **Off-ledger HTTP server implementation** — in project scope but deferred to the
  final steps (dev decision); this design fixes the Daml-side shape and the endpoint
  mapping it must serve.
- **CIP-0103 dApp-API flows and the `AllocationRequest` interface** — implemented by
  consumer apps, not registries; we only prove our allocations satisfy such apps.
- **Multi-instrument registries** — one `Registry` per instrument; multiple
  instruments = multiple Registry contracts (possibly same DAR, same admin).
- **Wallet/client-side tooling** — upstream's (wallet-kernel SDK, CLI parsers);
  consumed as test oracles only.
- **Self-transfer prohibition** — sender = receiver account is allowed (ERC-20
  precedent; rejecting adds a check without a threat model).

## Dev Notes

*(dev to fill after review)*

## Open Questions

Original questions 1–3, 5, and 6 were resolved in post-artifact discussion
(2026-09-01) and folded into the sections above (Toolchain, View discipline,
Iterated settlement mechanics, Decision #4, and the seam mechanics respectively).
Remaining:

1. **Toolchain validation gate** (see Toolchain) — expected to pass, but must run
   before Code Draft: upstream DARs (built 3.5.2) under SDK 3.5.1; an LF 2.3
   template instancing an LF 2.1 interface; `fetchByKey`/`lookupNByKey`
   authorization/visibility semantics. Fallbacks are local patches (SDK 3.5.2 or
   context-served cids).
2. **SettleBatch privacy testability boundary (for Invariants/Tests):** per-party
   *contract* visibility is assertable in Daml Script; node-level *projection*
   ("each party sees only their own legs" — hard requirement, see Party /
   Authorization Model) needs end-to-end validation against a real participant.
   The invariants artifact must state which assertions live on which side.
