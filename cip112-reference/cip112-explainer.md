# CIP-0112 Explained — The Canton Network Token Standard V2

*Companion document to the CIP-0112 reference-implementation research report. Written from the
primary sources: [CIP-0112](https://github.com/canton-foundation/cips/blob/main/cip-0112/cip-0112.md)
(approved 2026-06-12) and [CIP-0056](https://github.com/canton-foundation/cips/blob/main/cip-0056/cip-0056.md)
(final, approved 2025-03-31). Local copies: `sources/cip-0112.md`, `sources/cip-0056.md`.*

---

## 1. Where CIP-0112 sits

CIP-0056 defined the **Canton Network Token Standard** ("V1"): a set of Daml interfaces plus
off-ledger OpenAPI endpoints that let any wallet, app, and asset registry interoperate without
knowing each other's implementations. CIP-0112 is **V2 of that standard** — a backwards-compatible
evolution targeting three things its title names: **privacy** (batch settlement where each party
sees only their own legs), **performance** (explicit view-count optimization guidance and
configurable choice observers), and **traditional accounting** (accounts with providers/custodians
instead of bare parties).

It is *not* a replacement standard. V2 ships as new major versions of the same packages, and the
compatibility machinery (Section 5 of the CIP) is a first-class part of the spec — a compliant V2
asset is expected to keep serving V1 wallets and apps.

### 1.1 The V1 baseline in one page

CIP-0056 defines six APIs, each an on-ledger Daml interface package plus (optionally) an off-ledger
HTTP API:

| API | Purpose | Daml package |
|---|---|---|
| Token metadata | symbol, name, total supply, supported APIs, registry UI/logo URLs | `splice-api-token-metadata-v1` |
| Holdings | portfolio view + transaction history | `splice-api-token-holding-v1` |
| Transfer instruction | initiate/monitor free-of-payment (FOP) transfers | `splice-api-token-transfer-instruction-v1` |
| Allocation | assets earmarked for a DvP settlement | `splice-api-token-allocation-v1` |
| Allocation request | apps request allocations from wallets uniformly | `splice-api-token-allocation-request-v1` |
| Allocation instruction | wallets create allocations uniformly | `splice-api-token-allocation-instruction-v1` |

Three actor roles: **asset registries** (own the ownership records — e.g. Amulet for Canton Coin,
or a tokenization utility issuing a stablecoin), **wallets/custody solutions** (manage holdings
across registries via the user's validator-node Ledger API), and **apps** (anything else touching
tokens — exchanges, collateral managers, payment acceptors).

Key V1 design facts you need to understand V2:

- **UTXO model.** Every holding is a Daml contract (one contract = one UTXO), visible only to its
  stakeholders. Transfers consume input holdings and create outputs.
- **Factory + off-ledger discovery.** Wallets never call implementation templates directly; they
  call registry-provided factory interfaces (`TransferFactory`, `AllocationFactory`). Because the
  factory contracts and supporting UTXOs are private to the registry, registries serve
  **off-ledger OpenAPI endpoints** that return the factory contract-id plus the *disclosed
  contracts* and extra `ChoiceContext` needed to exercise the choice. This is deliberate: it hides
  implementation details, avoids synchronizer traffic, and lets registries restructure internals
  without breaking clients.
- **Two transfer workflows.** FOP transfer: sender instructs via `TransferFactory_Transfer`;
  settles either immediately or via a multi-step `TransferInstruction` (registries may need extra
  approvals or off-Canton ledgers). DvP: investors **allocate** holdings to a settlement; when all
  allocations exist, the settlement app executes every transfer atomically in one Daml transaction.
- **Allocation as authorization.** An `Allocation` is the on-ledger authorization from a trader for
  specific transfer legs of a specific settlement, valid until a deadline. In V1 it covers exactly
  one leg and is executed via `Allocation_ExecuteTransfer` with fixed controllers
  `[executor, sender, receiver]`.
- **Metadata everywhere.** Text key-value maps (Kubernetes-annotation-style namespaced keys, e.g.
  `splice.lfdecentralizedtrust.org/reason`) on choice args, results, views, and data records —
  the standard's extensibility mechanism.
- **Explicitly no allowance API.** ERC-20-style unconstrained allowances don't fit a private UTXO
  model (the spender can't see which UTXOs to spend, and would contend with the owner). CIP-0056
  says allocations cover most allowance use cases and defers a UTXO-compatible allowance API to a
  future CIP.
- **Amounts are Daml `Decimal`** (38-digit fixed point, 10 decimal digits) for every token —
  `decimals()` is effectively the constant 10. No per-token decimals.

## 2. What CIP-0112 adds and why

### 2.1 The package surface

V2 ships as *new major versions* alongside V1 (V1 packages remain deployed and valid):

- `splice-api-token-holding-v2`
- `splice-api-token-transfer-instruction-v2`
- `splice-api-token-allocation-v2` (package name in CIP: `splice-api-token-allocation-allocation-v2`)
- `splice-api-token-allocation-instruction-v2`
- `splice-api-token-allocation-request-v2`
- `splice-api-token-transfer-events-v2` — **new**: the `EventLog` transaction-parsing interface
- `splice-api-token-standard-utils` — **new**: shared types, upcast/downcast mappings, and default
  V1-in-terms-of-V2 choice implementations for cross-version compatibility

There is deliberately **no `splice-api-token-metadata-v2`**: the metadata Daml API is unchanged;
only the `token-metadata-v1.yaml` **OpenAPI** spec gains backwards-compatible fields (paused
status, account-input hints — see §2.8, §2.9).

Additionally, `splice-token-standard-wallet` gains a `BatchingUtilityV2` module (§2.10).

### 2.2 Accounts instead of Parties (§4.3.2 of the CIP)

The single most pervasive change. Everywhere V1 used a `Party` to denote the *location* of an
asset (owner, sender, receiver), V2 uses an `Account` record:

```daml
data Account = Account with
    owner : Optional Party      -- MUST be set for regular accounts; None reserved for
                                -- admin-managed special accounts (mint/burn sources)
    provider : Optional Party   -- account provider (custodian/account keeper). Providers MUST
                                -- have visibility of all movements & holdings; how authorization
                                -- splits between owner and provider is up to the registry
    id : Text                   -- account number or similar; "" is the default

basicAccount : Party -> Account
basicAccount owner = Account (Some owner) None ""
```

Why: in TradFi, holdings live in accounts managed by custodians/account keepers who enforce
compliance and act on the beneficial owner's instructions. V1 could only smuggle account info
through metadata and couldn't express the *authorization* consequences. V2 standardizes the data
and makes authorization configurable:

- **Visibility is standardized** (providers see everything on the account); **authorization is
  registry-defined** (a provider may co-sign everything, may act on the owner's behalf, or may be
  purely observational).
- Every choice previously callable by the `owner` now takes an **`actors : [Party]`** field and is
  `controller actors`. Implementations **MUST validate** `actors` contains the expected parties —
  this is the mechanism that lets a registry decide whether owner, provider, both jointly, or a
  delegate can act. The `owner` MUST always be able to call `TransferFactory_Transfer` and
  `AllocationFactory_Allocate` (though the registry may route it into a pending instruction that
  the provider must accept).
- The `status` field on instructions is replaced by
  **`availableActions : Map TransferInstructionAction [[Party]]`** — a disjunction of conjunctions
  of parties per action (`TIA_Accept`, `TIA_Reject`, `TIA_Withdraw`, `TIA_Custom id`) — so wallets
  can tell users exactly what they can do and who they're waiting on.
- Fields changed `Party → Account`: `AllocationSpecification.authorizer`,
  `AllocationRequestView.authorizer`, `TransferLeg.sender/.receiver`,
  `TransferInstruction.sender/.receiver`. **Not** changed (roles, not locations): `admin`,
  `actors`, `Lock.holders : [Party]`, `SettlementInfo.executors : [Party]`.
- `basicAccount owner` must behave *exactly* like a V1 bare party (same visibility and
  authorization) — that's the compatibility bridge.

**Mint/burn as accounts (§4.3.2.1).** Special accounts with `owner = None, provider = None` and
`id = "cip-112/mint"` / `"cip-112/burn"` represent the mint source and burn destination — the
Canton analogue of ERC-20's zero address. This lets standard transfer *and allocation* flows
express mints and burns, enabling **Delivery-vs-Mint / Delivery-vs-Burn** trades (stablecoin/fund
subscription and redemption as an atomic settlement leg). Wallets recognize these ids for uniform
UX.

**Account existence (§4.3.2.2).** Accounts are either **implicit** (transferable-to without setup
— Canton Coin allows only implicit basic accounts) or **explicit** (registry requires account
setup first). Factory OpenAPI calls SHOULD error on transfers to nonexistent accounts, and
registries advertise `showAccountInputFields` so wallets know whether to display account-id and
provider inputs (§2.9).

### 2.3 Privacy-enhanced batch settlement via `SettlementFactory` (§4.1.1, §4.3.1)

**The V1 problem.** `Allocation_ExecuteTransfer` has controllers `[executor, sender, receiver]`.
Low trust — sender and receiver self-validate atomicity — but everyone sees all consequences of
the settlement they're in. A multi-leg netted settlement (the CIP's example: Alice/Bob/Carol
trading X vs $ through an exchange app, nine legs) cannot be executed with TradFi-style
visibility, where traders see only their own debits/credits, each asset admin sees the legs on
its asset, and only the settlement processor (executor) sees everything.

**The V2 model.** The trust model is made explicit and configurable:

- A trader trusts the `admin` of each asset **plus the executors** for atomicity *within* that
  admin's asset, and trusts the **executors** for atomicity *across* admins.
- An `Allocation` is the trader's authorization for a set of transfer legs under those
  assumptions. Minimum privacy cost: executors see all legs; assets may reveal more (Canton Coin
  legs are public).

Mechanics:

- Traders SHOULD create **one Allocation per settlement per admin**, covering *all* their legs on
  that admin's assets (sending *and* receiving — receiving legs need no funding but do carry the
  receiver's authorization; some assets, like Canton Coin, require receiver authority to move).
  `AllocationSpecification` therefore holds `transferLegSides : [TransferLegSide]` (leg id +
  `SenderSide|ReceiverSide` + counterparty account + amount) and an `authorizer : Account`.
- `SettlementInfo.executors : [Party]` is now a **list** (V1's single `executor` generalized; the
  V1 trust set `[executor, sender, receiver]` is expressible as an executor list).
- Settlement moves **off the Allocation contract onto a new `SettlementFactory` interface**:

```daml
nonconsuming choice SettlementFactory_SettleBatch : SettlementFactory_SettleBatchResult
  with
    settlement    : SettlementInfo
    transferLegs  : [TransferLeg]          -- all same admin as the factory; >= 1
    allocations   : [FinalizedAllocation]  -- proof of sender+receiver authorization
    actors        : [Party]                -- MUST be validated; default: == settlement.executors
    extraArgs     : ExtraArgs
  observer settlementFactory_settleBatchExtraObservers this arg
  controller actors
```

  Implementations MUST ensure: the allocations were created for *this* `settlement`; the
  allocations' legs authorize both send and receipt of every leg in `transferLegs`; and
  `transferLegs` covers *exactly* what the allocations authorize. Because the admin co-validates
  the batch, the admin can net debits/credits per account and restrict each credit/debit's
  visibility to executors + admin + affected account parties only.
- The privacy only materializes if `SettleBatch` is exercised from a context visible only to the
  executors — if senders/receivers authorize the enclosing transaction they see everything anyway.
- `extraReceiptAuthorizers : [Account]` on `SettleBatch` lets the factory auto-create missing
  receipt-side allocations for accounts that co-authorize the call — used for V1 compatibility
  (V1 only senders allocate) and as a performance optimization (§2.7).

### 2.4 Single-signature flows with trusted venues (§4.1.2) and `AllocationRequest` changes

Venues that execute trades off-chain write the executed trade on-chain with only their own
signature as `AllocationRequest`s; each trader's wallet shows the full requested settlement and
the trader authorizes it **once** by creating their allocation(s). The executors can then settle
without any further trader signature. In V1 this was impossible — there was no way to assemble
the allocations' authority for settlement (the settle choice needed sender+receiver again), so
off-chain venues needed a second round of trader signatures.

`AllocationRequestView` now carries a **list** `allocations : [AllocationSpecification]` (an app
may need multiple allocations per trader per admin when `committed`/iteration settings differ)
and timing hints `requestedAt : Time`, `settleAt : Optional Time`. Apps MUST make the request
visible to all owner and provider parties of every authorizer account; wallets MUST create one
Allocation per specification with the *exact same* `SettlementInfo`, and SHOULD consume the
request via `AllocationRequest_Accept` in the same transaction (replay protection).

With CIP-0103 (dApp connectivity), the on-ledger `AllocationRequest` can be skipped entirely: the
app asks the wallet to sign the `AllocationFactory_Allocate` call directly.

### 2.5 Committed allocations and iterated settlement (§4.1.6, §4.3.6)

Two new fields on `AllocationSpecification`:

```daml
nextIterationFunding : Optional (TextMap Decimal)
  -- None: behaves like CIP-0056 — settle once, exactly the specified legs.
  -- Some m: iterated settlement enabled; m = funds (per instrument id) reserved
  --         for the next iteration (may be empty if expecting only inflows).
committed : Bool
  -- True: authorizer CANNOT withdraw until settlement, executor cancel,
  --       settlement deadline, or admin expiry. False: withdrawable as in V1.
```

What this unlocks:

- **Prefunded trading**: allocate funds to an exchange *before* legs are known; the executor
  supplies legs at settlement time (via `FinalizedAllocation.extraTransferLegSides`), up to the
  allocated amounts.
- **Iterated settlement**: each `SettleBatch` outputs a *new* Allocation carrying change plus
  incoming assets and the executor-specified `nextIterationFunding`; excess funds return to the
  authorizer. An off-chain order book with on-chain settlement needs zero custom Daml. Top-ups
  and merges of allocations are themselves expressed as settlement legs between a trader's own
  allocations (§4.3.6.1).
- **The DeFi primitive**: committed allocations are Canton's analogue of "deposit into the
  protocol contract" — except the asset stays owned by the trader, in a committed allocated state
  the app can act on. Lending and staking patterns build on this. The counterparty-risk tradeoff
  is explicit: withdrawable allocations risk withdraw-vs-settle races; committed allocations
  require trusting the venue to honor withdrawals.

`FinalizedAllocation` (the settle-time wrapper): `allocationCid`, `extraTransferLegSides`
(MUST be empty unless the authorizer enabled iteration), `nextIterationFunding` (MUST NOT be set
unless iteration enabled).

### 2.6 Timing model rework (§4.1.4, §4.3.3)

V1's mandatory `allocateBefore`/`settleBefore` on `SettlementInfo` were too rigid for
business-event-driven settlement. `SettlementInfo` is now purely an *identifier*:
`executors : [Party]`, `id : Text`, `cid : Optional AnyContractId` (contract-ids can't be
rendered to text inside Daml), `meta : Metadata` — executors MUST keep `(id, cid, meta)` unique.
Timing now lives in three places:

1. `AllocationRequest.requestedAt` / `settleAt : Optional Time` — the app's *hints* to wallets.
2. `AllocationSpecification.settlementDeadline : Optional Time` — the authorizer-agreed TTL;
   after it, settlement must be impossible and the authorizer can withdraw **even if committed**
   (this is the safety valve on `committed = True`).
3. `AllocationView.expiresAt : Optional Time` — the *registry's* housekeeping bound; registries
   MAY expire and refund after it (DoS/storage protection), SHOULD set it ≈ `settlementDeadline`
   and bump it each iteration.

### 2.7 `EventLog` — ERC-20-style events for transaction parsing (§4.1.5, §4.3.5)

V1 transaction parsing interprets factory/instruction *choices* as events, with a metadata
fallback — meaning observers of an "event" see all its consequences (showing a receiver the
transfer event also shows them the sender's pre-split input holding), and clients must traverse
transaction trees. It also breaks down for dual-version emission (V1 choice would have to call V2
and vice versa — circular).

V2 adds `splice-api-token-transfer-events-v2` with interface `EventLog` and one **side-effect-free
non-consuming choice**, exercised by the `admin`, whose only purpose is making its arguments
visible to chosen observers:

```daml
nonconsuming choice EventLog_HoldingsChange : EventLog_HoldingsChangeResult
  with
    admin             : Party
    account           : Account
    inputHoldingCids  : [ContractId Holding]  -- archived in same tx, owned by account
    transferLegSides  : [TransferLegSide]     -- net balance change MUST match holdings delta;
                                              -- both sides reported, ids unique & matching
    outputHoldingCids : [ContractId Holding]
    observers         : [Party]               -- at least the account parties
    extraArgs         : ExtraArgs             -- reason under splice.../reason; ChoiceContext
                                              -- for contract-id links
  observer observers
  controller admin
```

Rules: every create/archive of a Holding of a regular account MUST be explained by **exactly one**
`EventLog_HoldingsChange` with matching admin+account; both sides of each transfer reported;
splits/merges may have empty legs; zero-net legs may have empty holdings. Contract-ids (not
views) are shipped for space efficiency — indexers fetch views from the same transaction's
create/archive events. A wallet indexes holdings by filtering for these events from the trusted
`admin` only. This is deliberately the ERC-20 `Transfer`-event ergonomic, rebuilt for a private
ledger where *the asset controls who observes each event*.

### 2.8 Pause reporting (§4.1.7, §4.3.7)

RWAs near-universally have a global pause; V1 wallets could only discover it by failing.
V2 extends the **OpenAPI** `metadata/v1/instruments` schema (no Daml change):
`paused : boolean` (default false) and `pauseInfo { reason : string, until : date-time }`.
Backwards-compatible, so V1 clients benefit too. Note what this is *not*: the standard does not
define the pause mechanism itself (that's registry-internal); it standardizes *reporting*.

### 2.9 Advertising compatibility (§5.2)

Assets advertise supported standards via the existing `supportedApis` field on
`GET /registry/metadata/v1/instruments/{instrumentId}` — V2 assets list the V2 packages there.
Wallets call `GET /registry/metadata/v1/info` first to decide V1-vs-V2 flows per registry.
The CIP text says to set `showAccountInputFields : Bool`; the current OpenAPI spec on Splice
`main` has **deprecated** that field in favor of `accountInputFieldsToShow : ["provider" | "accountId"]`
(fine-grained control; wallets always show non-null account info when *displaying*, the field only
governs *input* forms). Canton Coin shows neither.

### 2.10 Batching utility (§4.1.9, §4.3.9)

Common need: several token-standard actions in one transaction (e.g. split a 100.0 UTXO into
transfers to 10 recipients). Possible in V1 only with custom Daml deployed by the user. V2 ships
a standard `BatchingUtility` template (in `splice-token-standard-wallet`, deployed on all Splice
validators): signatory `user`; choice `BatchingUtility_ExecuteBatch` takes an `inputHoldingMap`
and a list of `TokenStandardAction`s (a sum type wrapping V1 *and* V2 `TransferFactory_Transfer`,
`TransferInstruction_Accept`, `AllocationFactory_Allocate`, `AllocationRequest_Accept` calls),
threads holdings through the actions, and optionally archives itself (`createAndExercise`
pattern).

### 2.11 Performance guidance (§4.3.8 "Guidelines & Interfaces for Performance Optimization")

Canton cost ≈ number of *views* per transaction (a new view forms when a sub-choice adds
informees). The CIP walks the 9-leg example from 6 transactions / 28 views down to 2 / 4:

- Apps: at most one `AllocationRequest` per trading account (covering all its legs).
- Wallets: create all allocations in one transaction.
- Assets **MUST** provide `allocationFactory_allocateExtraObservers` (choice observers on
  `AllocationFactory_Allocate` — typically executor + authorizer's owner/provider ⇒ single view)
  and `settlementFactory_settleBatchExtraObservers`; assets SHOULD keep `SettleBatch` to ≤ 1
  sub-view per input allocation. Public assets (Canton Coin) can set all leg parties as choice
  observers so informees only ever shrink down-tree.
- CIP-0103 direct signing elides `AllocationRequest`s; `extraReceiptAuthorizers` elides
  allocations for parties who co-authorize settlement.

Also from the app/wallet/asset guidelines (§4.3.8, first list): registries MUST support
allocations of **at least 25 transfer legs** (worst case: 25 instrument ids, 50 accounts,
100 parties); assets that lock holdings SHOULD lock only **net** amounts; assets SHOULD guarantee
that matching allocations (same `SettlementInfo`, every leg present on both sender and receiver
side) always settle — with carve-outs only for context changes like blocklisting.

## 3. Backwards compatibility (§5) — the part implementers underestimate

The design goal: apps, assets, and wallets upgrade **independently**; V1 feature set keeps
working across versions; users must never sign something whose meaning their (V1) wallet couldn't
show them.

Obligations for a V2 **asset** (the role a reference implementation plays):

1. `Holding` and `TransferInstruction` implementations SHOULD implement **both** V1 and V2
   interfaces. `splice-api-token-standard-utils` supplies upcast/downcast between V1/V2 views and
   default V1-choice-in-terms-of-V2 implementations (e.g. Amulet's V2 `Holding` view is
   `upcast` of its V1 view; TestTokenV2's V1 `TransferInstruction` choices delegate via
   `transferInstruction_v1_*DefaultImplUsingV2`).
2. Whichever version's choice is exercised, **both** V1 and V2 transaction-parsing information
   MUST be emitted (V1 may fall back to metadata; V2 requires exactly-one `EventLog_HoldingsChange`
   per holdings change).
3. On V1 interfaces of V2 implementations, account info (`id`, `provider`) MUST be mirrored into
   V1 `metadata`; V2 implementations SHOULD avoid storing *redundant* account info in their own
   metadata.
4. Implement both V1 and V2 `TransferFactory_Transfer` / `AllocationFactory_Allocate`. Outputs of
   the V1 allocate choice MUST be fully V1-compatible.
5. **Two Allocation implementations are required in practice**: assets MUST NOT implement the V1
   `Allocation` interface on allocations that can't settle via V1 `Allocation_ExecuteTransfer` —
   so a V2-only allocation template (committed/iterated features) and a dual V1/V2 template
   (which additionally MUST settle via `SettlementFactory_SettleBatch` on executors' authority
   alone).

Apps SHOULD implement V1 `AllocationRequest` on their V2 implementation and MUST validate that
received allocations match what they requested (V1 wallets can produce mismatched allocations for
V2-feature requests). Wallets MUST use the V1 factory for V1-only assets/apps, SHOULD warn users
when an `AllocationRequest` demands V1-incompatible features from a V1 asset, and SHOULD fund
transfers only from holdings of the same `Account` (explicit inter-account transfers otherwise).

The compatibility matrices (§5.4, §5.5): transfers are compatible in 7 of 8 wallet×wallet×asset
combinations — the gap is a V1 *sender* wallet to a V2 asset with a non-basic receiver account
(the V1 sender can't specify account info; asset can bridge via a pending-workflow step or
account resolution in the factory). Allocations: everything V1-app works; a V2-featured app needs
V2 wallets and V2 assets for full function, with CIP-0103 direct signing as the escape hatch for
V1 wallets (§5.6).

## 4. Reference implementations named by the CIP

- **Canton Coin / Amulet** (Section 6): implements V2 alongside V1, full Section-5 compatibility,
  the reduced-privacy optimization (all leg parties as choice observers), implicit basic accounts
  only, `showAccountInputFields = false`. The canonical *public-token* V2 implementation.
- **TestTokenV2** (Section 7): the spec's own reference token, built to exercise every V2
  workflow permutation — implements V1+V2 interfaces, the full privacy flow of the 9-leg example,
  and on-chain `AccountConfig` contracts supporting many owner/provider authorization splits.
  The CIP itself recommends that developers **"simplify and specialize it to their own domain
  rather than using it as provided"** — i.e., it is a test maximalist, not a production template.

## 5. What a CIP-0112-compliant token implementer must build — checklist

**On-ledger (Daml):**

- [ ] `Holding` template(s) implementing HoldingV1 + HoldingV2 (account-based view; V1 view via downcast, account info mirrored to V1 metadata)
- [ ] `TransferFactory` (V1 + V2 `TransferFactory_Transfer`; `actors` validation; account existence checks)
- [ ] `TransferInstruction` for multi-step transfers (V1 + V2; `availableActions`; accept/reject/withdraw with `actors`)
- [ ] `AllocationFactory` (V1 + V2 `AllocationFactory_Allocate`; `allocationFactory_allocateExtraObservers` for single-view allocation; net-amount locking)
- [ ] Allocation templates: dual V1/V2 allocation (settleable both via V1 `ExecuteTransfer` and `SettleBatch`) *and* V2-only allocation (committed / iterated)
- [ ] `SettlementFactory` with `SettleBatch`: settlement-matching validation (right settlement, both-side authorization, exact leg coverage), `actors` check, netting, per-account visibility, iterated-settlement outputs, `extraReceiptAuthorizers`, `settlementFactory_settleBatchExtraObservers`
- [ ] `EventLog` instance + emission discipline: exactly one `HoldingsChange` per account-holdings change, on every path (V1 choices included)
- [ ] Mint/burn modeled as `cip-112/mint` / `cip-112/burn` special accounts, usable in transfer and allocation flows (DvM/DvB)
- [ ] Account model: implicit and/or explicit accounts; owner/provider authorization policy; timing enforcement (`settlementDeadline` overrides `committed`; `expiresAt` housekeeping)
- [ ] Allocation capacity ≥ 25 legs

**Off-ledger (OpenAPI):**

- [ ] Registry metadata endpoints incl. `supportedApis` (listing V2 packages), `paused`/`pauseInfo`, `showAccountInputFields`
- [ ] Factory-discovery / choice-context endpoints returning factory cids + disclosed contracts (per CIP-0056), erroring on nonexistent accounts
- [ ] Registry URL discovery via CNS entry metadata (`splice.lfdecentralizedtrust.org/registry-urls`)

## 6. Spec text vs. Splice `main` — what the CIP prose doesn't show

The CIP was written against a preview branch; the **normative artifacts now live on Splice `main`**
(pinned here at commit `6bcae32a2b9763b7c7b9800100aca7f0d426c76d`, package versions 1.0.0, SDK
3.5.2, Daml-LF 2.1). Where they differ, trust the code. The deltas an implementer must know:

- **`Allocation_Settle` lives on the `Allocation` interface**, with `SettlementFactory_SettleBatch`
  orchestrating over it. The default/reference batch implementation
  (`settlementFactoryV2_settleBatchDefaultImpl` in `splice-token-standard-utils`) does
  `checkActors` against `settlement.executors`, then `fetchAndValidateAllocations` — unique leg
  ids, positive amounts, allocation↔settlement match, per-(authorizer, legId, side) uniqueness,
  and **set-equality** between required and allocated authorizations — then settles each
  allocation with default controllers `admin :: executors`.
- **All V2 workflow choices are `nonconsuming` with `controller actors`** — but implementations
  MUST still consume (archive) the contract, typically via a `CallSource = CalledFromV1 |
  CalledFromV2` discipline so a V1 (consuming) choice and a V2 (nonconsuming) choice can share
  one implementation without double-archiving.
- **`expectedAdmin` is gone from every V2 factory choice.** V1's anti-spoofing argument is
  replaced by validating the admin against `transfer.instrumentId.admin` /
  `allocation.admin` inside the implementation.
- **`TransferLeg.instrumentId` is plain `Text`** in V2 (the admin is factored out into
  `AllocationSpecification.admin`), and an allocation authorizes `TransferLegSide`s (leg id +
  `SenderSide|ReceiverSide` + counterparty + amount), not whole legs.
- **`SettlementInfo.cid` is `Optional AnyContractId`** and V1's `settlementRef : Reference` shape
  is gone; results are unified (`AllocationResult { output : Pending|Settled{nextIterationAllocationCid}|Cancelled|Withdrawn, authorizerHoldingCids : TextMap [ContractId Holding] }`
  keyed by instrument id).
- **New instruction-level choices/endpoints:** `AllocationInstruction_Accept` exists in V2 (for
  provider/joint acceptance; V1's admin-only `_Update` is gone from instructions), with matching
  new off-ledger `choice-contexts/{accept|withdraw}` endpoints on
  `/registry/allocation-instruction/v2/`.
- **Off-ledger settlement discovery:** `POST /registry/allocation/v2/settlement-factory`
  *replaces* V1's per-allocation `execute-transfer` choice-context endpoint. There is no V2
  execute-transfer endpoint.
- **A standing security note from V2 validation:** because `extraSettlementAuthorizers` was
  dropped, V1-created allocations on dual-version assets are settleable with the **executors'
  authority alone**. Asset owners must only create allocations for executors they trust — a
  reference implementation should surface this in its integrator documentation.
- **Utility toolbox to reuse rather than reinvent** (`splice-token-standard-utils`, a forced
  utility package so it stays SCU-compatible): `basicAccount`/`accountParties`,
  `checkActors`/`archiveAndCheckActors`, `BackwardCompatible`/`ForwardCompatible`
  upcast/downcast instances, all the `*DefaultImplUsingV2`/`UsingV1` shims,
  `netAllocationCreditAmounts`, `ensureWithdrawIsAllowed` (the `committed` check),
  `ensureIsReceiptAllocation`, event-log helpers (`logMint`/`logBurn`/`logTransfer`/
  `logMergeSplit`/`logAllocationSettlement`), and public- vs private-asset choice-observer
  defaults.
- **Known implementation bug history worth turning into regression tests** (from Splice's
  V2_VALIDATION appendix): locked tokens accepted as allocation/transfer inputs; future
  `requestedAt` accepted; net-credit calculation mixing instruments; the receipt-allocation
  guard permitting iterated allocations; V1-allocate shim copying the wrong timestamp; metadata
  not stripped when upcasting; `SettleBatch` initially not checking transfer-leg-id uniqueness.

## 7. Reading map into the CIP text

| Topic | CIP-0112 section |
|---|---|
| Feature motivations | 4.1.1–4.1.9 |
| Worked 9-leg privacy example | 4.2 |
| SettlementFactory / trust model | 4.3.1 |
| Accounts, actors, availableActions, mint/burn | 4.3.2 |
| Timing | 4.3.3 |
| EventLog | 4.3.5 |
| Committed/iterated allocations, FinalizedAllocation, AllocationRequest lists | 4.3.6 |
| Pause metadata | 4.3.7 |
| App/wallet/asset allocation guidelines + performance | 4.3.8 (two sections share the number in the source) |
| Batching utility | 4.3.9 |
| Compatibility rules, matrices, dApp-API path | 5.1–5.6 |
| Canton Coin plan | 6 |
| TestTokenV2 | 7 |

*Known spec quirks to be aware of: the CIP text contains two sections numbered 4.3.8, no 4.3.4,
and several internal anchors that point at renumbered sections; field names occasionally drift
between prose and code blocks (`nextIterationFunding` vs `nextIteratedSettlement`). Treat the
code blocks and the Splice `main` sources as authoritative over prose anchors.*
