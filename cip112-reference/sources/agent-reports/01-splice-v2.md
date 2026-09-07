# Agent report: Canton Network Token Standard V2 (CIP-0112) in Splice

(Verbatim agent deliverable, 2026-08-26. Permalinks pinned to splice main HEAD commit 6bcae32a2b9763b7c7b9800100aca7f0d426c76d. Base: https://github.com/hyperledger-labs/splice/blob/6bcae32a2b9763b7c7b9800100aca7f0d426c76d/)

Big picture: entire V2 surface lives in token-standard/ on main (merged from token-standard-v2-daml-preview; preview PR #4562 closed). V2 API packages named splice-api-token-*-v2, version 1.0.0, SDK 3.5.2, --target=2.1. V1 packages side by side; dual-version implementation pervasive. Dedicated "Token Standard V2 DevNet" (TOKEN_STANDARD_V2_DEVNET.md: single SV, protocol version 35, weekly resets) + V2_VALIDATION.md guide.

## 1. V2 API packages

### 1.1 splice-api-token-holding-v2 — Splice.Api.Token.HoldingV2
- Account { owner : Optional Party (None = admin-controlled special account), provider : Optional Party (MUST see all movements; auth split impl-defined), id : Text ("" default; deliberately Text not Optional) }
- InstrumentId { admin, id } and Lock { holders, expiresAt, expiresAfter, context } unchanged from V1.
- interface Holding, view-only (no choices). HoldingView: V1 owner:Party → account:Account; other fields unchanged.
- Utils helpers: basicAccount, accountPrincipal (fromOptional admin acct.owner), accountParties (Conversions L147-L169); mintAccount/burnAccount with owner=None provider=None namespaced ids (Events L53-L69).

### 1.2 splice-api-token-transfer-instruction-v2
- Transfer: sender/receiver now Account.
- interface TransferInstruction: choices ALL nonconsuming, controller actors, impl-defined choice observers:
  - TransferInstruction_Accept { actors, extraArgs } — generalized from "receiver accepts" to anyone authorizing on either side (joint accounts). Also _Reject, _Withdraw same shape. Impl methods transferInstruction_{accept,reject,withdraw}Impl + ...ExtraObservers : choice -> [Party].
- TransferInstructionView: status → availableActions : Map TransferInstructionAction [[Party]] + expiresAt : Optional Time. TIA_Accept|TIA_Reject|TIA_Withdraw|TIA_Custom{id}.
- interface TransferFactory: TransferFactory_Transfer { transfer, actors, extraArgs } controller actors (SHOULD one-step if actors include all authorizers); TransferFactory_PublicFetch { actors }.
- Vs V1: V1 choices consuming with fixed controllers (receiver Accept/Reject, sender Withdraw, admin+extraActors Update — Update removed in V2); V1 factories take expectedAdmin — V2 DROPS expectedAdmin (validate against transfer.instrumentId.admin). V2 nonconsuming so impls can archive by delegating to consuming V1 choice for V1 parser compat (MUST still consume).

### 1.3 splice-api-token-allocation-v2
Module header goals: multi-leg allocations, net-amount allocation, executor-finalized transfers, iterated settlement, committed allocations, accounts in legs, flexible actors, impl-defined choice observers, removal of expectedAdmin.
- SettlementInfo { executors:[Party], id, cid : Optional AnyContractId, meta } (V1: single executor + requestedAt/allocateBefore/settleBefore removed/moved).
- TransferLeg { transferLegId, sender:Account, receiver:Account, amount, instrumentId:Text (admin factored out), meta }.
- TransferSide = SenderSide|ReceiverSide; TransferLegSide { transferLegId, side, otherside:Account, amount, instrumentId:Text, meta } — allocation authorizes SIDES of legs.
- AllocationSpecification { admin, authorizer:Account, transferLegSides, settlementDeadline : Optional Time, nextIterationFunding : Optional (TextMap Decimal), committed : Bool, meta }.
- AllocationView { originalAllocationCid, settlement, allocation, holdingCids, createdAt, numIterations, expiresAt, availableActions : Map AllocationAction [[Party]], meta }.
- FinalizedAllocation { allocationCid, extraTransferLegSides, nextIterationFunding }.
- interface Allocation: all nonconsuming, controller actors, *ExtraObservers methods:
  - Allocation_Settle { actors, extraTransferLegSides, nextIterationFunding, extraArgs } — default auth SHOULD be admin :: executors only (deliberate late change so V1 allocations settle with executor authority + privacy).
  - Allocation_Cancel (executors; admin for expired), Allocation_Withdraw (authorizer account parties; blocked pre-deadline if committed).
  - Unified AllocationResult { output : Pending|Settled{nextIterationAllocationCid}|Cancelled|Withdrawn, authorizerHoldingCids : TextMap [ContractId Holding] keyed by instrumentId.id, meta } (V1: three result types with senderHoldingCids).
- interface SettlementFactory (NEW): SettlementFactory_SettleBatch { settlement, transferLegs, allocations:[FinalizedAllocation], actors, extraArgs } controller actors (default settlement.executors). MUST check: allocations belong to settlement; leg sides cover EXACTLY both sides of transferLegs; net debit/credit per account. Per-account net movements visible only to executors, admin, affected account parties. SettlementFactory_PublicFetch.
- Vs V1: V1 = one allocation per single leg, consuming Allocation_ExecuteTransfer controlled [executor,sender,receiver]; V2 = one allocation per authorizer covering N leg-sides across N instruments (same admin), settled net in batch by admin+executors.

### 1.4 splice-api-token-allocation-instruction-v2
- AllocationInstruction: nonconsuming AllocationInstruction_Accept { actors } (NEW vs V1 — joint accounts) and _Withdraw { actors }; V1's admin-controlled _Update GONE.
- View { originalInstructionCid, settlement, allocation, requestedAt, inputHoldingCids, expiresAt, availableActions, meta }; AIA_Withdraw|AIA_Accept|AIA_Custom.
- AllocationFactory_Allocate { settlement, allocation:AllocationSpecification, requestedAt, inputHoldingCids, extraArgs, actors } controller actors (V1: controller allocation.transferLeg.sender + expectedAdmin).
- AllocationInstructionResult { output : Pending|Completed{allocationCid}|Failed, authorizerChangeCids : TextMap [ContractId Holding], meta }.

### 1.5 splice-api-token-allocation-request-v2
- Three nonconsuming actor-controlled choices + extra observers: AllocationRequest_Accept (NEW — wallets consume request atomically with allocation creation = replay protection; apps MUST still clean up), _Reject, _Withdraw (executors). Concrete AllocationRequest_*Result{meta} (V1: bare ChoiceExecutionMetadata).
- View { originalRequestCid, settlement, allocations : [AllocationSpecification], requestedAt, settleAt, availableActions, meta } — V1's transferLegs : TextMap TransferLeg becomes full AllocationSpecifications (committed/iterated requestable).

### 1.6 splice-api-token-transfer-events-v2 (entirely new)
- interface EventLog, one nonconsuming choice EventLog_HoldingsChange { admin, account, inputHoldingCids, transferLegSides, outputHoldingCids, observers, extraArgs } observer observers controller admin.
- Wallets parse tx stream by looking ONLY for EventLog_HoldingsChange exercises by the instrument admin. Admins MUST report all holding changes + both sides of all transfers for regular accounts; net-zero legs may have empty holdings; merges/splits may have empty legs. TransferLegSide duplicated locally to avoid coupling to AllocationV2. EventLog_HoldingsChangeResult = {} reserved for future interface upgrades.

### 1.7 splice-token-standard-utils (v2.0.0, --force-utility-package=yes → unserializable types, SCU-compatible)
- Account helpers: accountParties, basicAccount, ensureBasicAccount, accountFromMeta/accountToMeta (smuggle accounts through V1 metadata).
- Requirements DSL: require, require', isEqualR, isGreaterOrEqualR, requireMatchExpected, requireUnique; checkActors, archiveAndCheckActors (nonconsuming-choice-that-archives-itself helper).
- BackwardCompatible v1 v2 (upcast) / ForwardCompatible v1 v2 (downcast) classes + non-typeclass converters (upcast_v1_v2_AllocationView, downcast_v2_v1_AllocationRequestView, tryDowncast_v2_v1_AllocationView...).
- Events: eventLog_holdingsChangeDefaultImpl, mintAccount/burnAccount, logMint, logBurn, logTransfer, logMergeSplit, logAllocationSettlement.
- Allocation math/validation: netAllocationCreditAmounts (per-instrument net credit, ignoring mint/burn accounts), isValidAllocationSpecificationV2, validateNextIterationArgs, ensureWithdrawIsAllowed (committed check), ensureIsReceiptAllocation.
- Dual-version glue: transferFactoryV1_transferDefaultImplUsingV2, transferInstructionV1_{accept,reject,withdraw,update}DefaultImplUsingV2, transferInstructionV2_receiverActor_acceptDefaultImplUsingV1 (+variants), allocationFactoryV1_allocateDefaultImplUsingV2, allocationV1_{executeTransfer,withdraw,cancel}DefaultImplUsingV2, viewAsAllocationV1/canViewAsAllocationV1, V1-history taggers transferAcceptanceTxHistoryV1ToMeta / allocationSettlementTxHistoryV1ToMeta.
- settlementFactoryV2_settleBatchDefaultImpl (Allocations L360-L463): checkActors actors [settlement.executors] → fetchAndValidateAllocations (unique leg ids, positive amounts, allocation↔settlement match, per-(authorizer,legId,side) uniqueness, SET-EQUALITY of required vs allocated authorizations — no missing, no superfluous) → Allocation_Settle each with default controllers admin::executors, per-allocation extra-args filter hook for privacy redaction.
- Choice-observer defaults: *_publicAsset_*ExtraObserversDefaultImpl vs *_privateAsset_* (view compression).
- token-metadata-v1.yaml extended: paused : boolean, pauseInfo { reason, until } (L160-L247). splice-api-token-burn-mint-v1 = docs stubs only; V2 burn/mint = special accounts + EventLog. Each V2 API package ships OpenAPI spec (transfer-instruction-v2.yaml, allocation-v2.yaml, allocation-instruction-v2.yaml) incl new 409 response for in-flight reassignments.

## 2. TestTokenV2 (examples/splice-test-token-v2)
Header warns: "very rich and generic account authorization model … you probably want to specialize it".
- TokenRules (singleton factory, signatory admin) implements EIGHT interfaces on one contract: V1+V2 TransferFactory, V1+V2 AllocationFactory, V2 SettlementFactory, EventLog — V1 impls delegate via *DefaultImplUsingV2 shims. SettlementFactory filters choice context per allocation so only authorizer's own AccountConfig is disclosed (privacy); settleBatchExtraObservers = [].
- Holding: template Token with holding : V2.HoldingView; signatory accountParties admin account, admin; ensure amount > 0.0 && isSome account.owner. Implements V1 (downcast) + V2. fetchAndArchiveUnlockedToken allows spending expired-lock holdings (combined unlock+use), rejects indefinite locks.
- AccountConfig: PartyConfig { canInitiate, mustApprove }; template AccountConfig { admin, account, ownerConfig, providerConfig }, signatory owner+provider, observer admin (serves configs as choice context), ensure ≥1 initiator ∧ ≥1 approver ∧ provider set. Established via AccountProposal propose/accept. ~20 distinct authorization flows for a simple transfer ("to test all possibilities the CIP-0112 account model offers").
- Basic accounts: synthetic default config (owner canInitiate+mustApprove), MUST NOT supply contract; provider accounts MUST supply AccountConfig cid via choice context key testTokenV2/accountConfigs (extractAccountConfigMap).
- Auth state machines: AuthStateMachine action state, AuthState = Map action [Party]. Transfers: TIS_Init -(sender account Accept)-> TIS_Authorized -(receiver account Accept)-> TIS_Accepted (+Withdraw/Reject). Allocations: AS_Init -> AS_Withdrawn (authorizer) | AS_Cancelled (executors) | AS_Settled (admin::executors). applyStateMachineTransitions checks actor set vs availableActions, accumulates authorizations, executes when fully authorized, else re-creates Pending.
- Authority transfer: nonconsuming AuthorizeTransferInstructionAction / AuthorizeAllocationAction / AuthorizeAllocationInstructionAction on AccountConfig, controller actor, admin — canInitiate party acts with other party's authority when that party has mustApprove=False.
- Transfers: one template TokenTransferOffer { actionAuthorizers, availableActions, transfer, originalInstructionCid, mintAmount }, signatory Accept-authorizers + admin. Implements V1+V2 TransferInstruction + EventLog (on the offer itself so Rules needn't be fetched). Sender-side auth: debit inputs, create LOCKED holding (lock holders = admin + sender account parties, expires executeBefore), emit "lock" HoldingsChange. Receiver accept: consume locked holding, create receiver Token, logTransfer, tag result meta transferAcceptanceTxHistoryV1ToMeta for V1 parsers.
- Allocations: TokenAllocationInstructionV2/TokenAllocationV2 carry TextMap instrumentId → [Holding] (multi-instrument same admin). Funding = netAllocationCreditAmounts + nextIterationFunding; settleTokenAllocationV2 nets debits vs incoming credits, re-locks next-iteration funding, creates next-iteration TokenAllocationV2 (numIterations+1, empty leg sides), logs settlement.
- V1 backcompat pattern: holdings/transfer-offers implement both versions directly (clean downcast). Allocations don't always downcast (multi-leg) → V1-created allocations wrapped: template TokenAllocationV1 { allocationV2 : TokenAllocationV2 } with ensure canViewAsAllocationV1, implementing V1.Allocation AND V2.Allocation (same for instruction). AllocationKind = CreateV1Allocation | CreateV2Allocation decides factory output; CallSource = CalledFromV1 | CalledFromV2 with archiveIfCalledFromV2 handles consuming-V1 vs nonconsuming-V2 archival. V1 Allocation_ExecuteTransfer re-creates just-consumed allocation to route through V2.Allocation_Settle.
- Mint = admin TokenRules_OfferMint creating TokenTransferOffer with sender=mintAccount + mintAmount credited at debit. Burn = legs targeting burnAccount (TestDeliveryVersusBurnMint). NO on-ledger pause — pause is off-ledger metadata only.

## 3. Amulet / Canton Coin V2 (production splice-amulet v0.1.22, depends on V2 API dars)
- Amulet + LockedAmulet implement HoldingV1 + HoldingV2 (V2 view = upcast of V1 → basic accounts only).
- AmuletTransferInstruction: both versions; V2 impls are utils transferInstructionV2_receiverActor_*DefaultImplUsingV1 shims — Amulet = V2-on-top-of-V1 for transfers (OPPOSITE direction from TestTokenV2's V1-on-top-of-V2). V2 view hardcodes availableActions sender-withdraw/receiver-accept-reject.
- ExternalPartyAmuletRules (signatory DSO) = factory hub: V1+V2 TransferFactory (transferFactoryV2_transferDefaultImplUsingV1), V1+V2 AllocationFactory, V2 SettlementFactory (settlementFactoryV2_settleBatchDefaultImpl, no context filtering — "Amulet does not use any per-account information"), EventLog.
- AmuletAllocationV2: native V2 allocation backed by Optional LockedAmulet (None if net movement positive); ensure isBasicAccount authorizer && isValidAllocationSpecificationV2 (== amuletInstrumentIdName) — single instrument, basic accounts. allocation_settleImpl: extra legs, next-iteration funding, expiry bumping via getTokenStandardMaxTTL, burn-account legs, event log. V1-created AmuletAllocation implements both V1+V2 Allocation.
- DSO housekeeping: ExternalPartyAmuletRules_ExpireAmuletAllocationsV2 batch-cancels EXPIRED V2 allocations (checks expiresAt passed so SV delegation can't cancel live ones).
- AmuletEventLog: standalone create-exercise-archive template (withTempAmuletEventLog) when no EventLog contract in scope; events emitted for ALL amulet choices incl ANS-payment burns + legacy wallet workflows.
- splice-util-token-standard-wallet: BatchingUtility_ExecuteBatch, mixed V1/V2 batches in one tx.
- Tests: daml/splice-amulet-test/.../TokenStandard/ (TestAmuletAllocationHappyV2, TestAmuletTransferInstructionV2, TestAmuletDeliveryVersusBurn, UnitTest_AmuletAllocationV2).

## 4. V2 testing harness (splice-token-standard-v2-test + examples) — consumed as SOURCE (dars not shareable across SDKs, TODO(#594))
- RegistryApiV2: class RegistryApi app mirroring V2 OpenAPI handler names: getTransferFactory, getAllocationFactory, getSettlementFactory, get*Context per choice → EnrichedFactoryChoice/OpenApiChoiceContext (factory cid + disclosures + choice context). GenericRegistry record-of-functions for heterogeneous registries.
- MultiRegistry: Map Party RegistryApis { v1Api, v2Api }, supportsV2, mkRegistryApisV1V2 — per-admin discovery + version negotiation for mixed-version settlement tests.
- WalletClientV2: account-aware balances (checkAccountBalance), uniform V1+V2 listing/acting, batch construction vs BatchingUtility (TSABatch, mk* builders), V2 event-log-based tx-history checking (submitAndCheckTxHistory, expectTxHistoryReasons).
- Registry fixtures: AmuletRegistryV2, TestTokenV2_RegistryV2 (serves AccountConfig disclosures), TestRegistries.
- Reference tests (V2_VALIDATION blueprints): Splice.Tests.TestSettlement_V1V2Mixed, TestSettlement_V1App, TestIteratedSettlement; example suites TestTransferInstructionV1/V2, TestAllocationHappy/NegativeV1/V2, TestAccountProviderTransfer/Allocation, TestDeliveryVersusBurnMint, TestTransfer_V1V2Mixed, UnitTest_AccountConfig.
- TradingAppV2 (examples/splice-token-test-trading-app-v2) — reference CONSUMER app: OTC trading, mixed V1/V2 settlement; OTCTradeAllocationRequest implements V1+V2 AllocationRequest; OTCTrade batches per-admin allocations, settles via SettleBatch; TradeSettlementAgreement = trader→venue delegation to auto-create missing RECEIPT allocations (guarded ensureIsReceiptAllocation).
- CLI (token-standard/cli): parserv1.ts + parserv2.ts with --strict (no unexplained creates/archives) — wallet-parsing reference.
- splice-token-standard-utils-test: UnitTest_Allocations/Choices/Conversions/Transfers, TestEnsureReceiptAllocation, TestAllocationRequestDefaults.

## 5. Known limitations / TODOs / open items
- V2_VALIDATION: Daml APIs "ready for initial validation"; "small refinements may still occur". Packages 1.0.0 but SDK bumps (3.4.11→3.5.1→3.5.2) changed package hashes twice. V2 DevNet requires alpha protocol version 35.
- SECURITY (V2_VALIDATION L91-L105): dropping extraSettlementAuthorizers means V1-created allocations settleable with executor authority ALONE; owners "must only create allocations for executors that they trust".
- Interfaces NOT upgradeable in Daml today; result types (EventLog_HoldingsChangeResult, AllocationRequest_*Result) exist to hedge future upgrades.
- Daml Script test packages vendored as source across SDKs (TODO(#594)).
- WalletClientV2 expiresAfter lock constraints unsupported (needs LET access); GenericRegistry should subsume typeclass; TextMap/Time helpers await stdlib (TODO #4865).
- Amulet duplicates human-readable reason besides EventLog meta (tech-debt); Amulet V2 limited to basic accounts + single instrument.
- TestTokenV2 "in prod you would…" caveats: cap instruction TTLs (storage leaks), admin choice to expire allocations, pass unlock targets as arguments (expired-lock consumption races).
- BUG HISTORY (V2_VALIDATION appendix — test these in any reimplementation): locked tokens usable as allocation/transfer inputs; future requestedAt accepted; netAllocationCreditAmount mixing instruments; ensureIsReceiptAllocation permitting iterated allocations; allocationFactoryV1_allocateDefaultImplUsingV2 copying wrong timestamp; metadata not stripped when upcasting; SettleBatch initially not checking transfer-leg-id uniqueness.
- Registries must honor documented limits on legs/accounts/instruments/parties per settlement (off-ledger reference data under a few 100kB).

### Key takeaways for an independent implementation
1. Universal pattern = dual-version templates: implement V2 logic once, expose V1 via utils shims (or V2-on-V1 like Amulet), with CallSource-style archival discipline (V2 choices nonconsuming but MUST consume).
2. actors : [Party] + availableActions : Map action [[Party]] + impl-defined choice observers triad replaces fixed controllers everywhere — implementation MUST check actors itself (checkActors/archiveAndCheckActors).
3. expectedAdmin is gone; validate admin against instrumentId.admin / allocation.admin in every factory impl.
4. Batch settlement correctness hinges on exact-cover check between transferLegs and allocated TransferLegSides (fetchAndValidateAllocations) — reuse or faithfully reproduce.
5. Mint/burn = transfers against ownerless special accounts reported through EventLog_HoldingsChange; pause = off-ledger metadata (paused/pauseInfo).
