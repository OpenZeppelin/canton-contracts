# Agent report: CIP-0056 and its Off-Ledger Surface, with CIP-0112 Deltas

(Verbatim agent deliverable, 2026-08-26. Permalinks: cips @ d67aa3e (cip-0056) / d86f613 (cip-0112); splice main @ 6bcae32a2b9763b7c7b9800100aca7f0d426c76d.)

## 1. CIP-0056 Architecture

Six APIs, each = one Daml package of pure interfaces (no templates) + optional off-ledger HTTP API:
- splice-api-token-metadata-v1 (Splice.Api.Token.MetadataV1) — Metadata, ChoiceContext, ExtraArgs, AnyValue, AnyContractId; off-ledger token-metadata-v1.yaml
- splice-api-token-holding-v1 — Holding, InstrumentId, Lock; NO off-ledger (Ledger API reads)
- splice-api-token-transfer-instruction-v1 — TransferFactory, TransferInstruction; transfer-instruction-v1.yaml
- splice-api-token-allocation-v1 — Allocation + settlement types; allocation-v1.yaml
- splice-api-token-allocation-instruction-v1 — AllocationFactory, AllocationInstruction; allocation-instruction-v1.yaml
- splice-api-token-allocation-request-v1 — AllocationRequest (implemented by APPS); no off-ledger

Roles: registry admin (InstrumentId.admin — controls workflows, serves off-ledger APIs, _Update choices controlled admin+extraActors); owner/sender/receiver (sender initiates: TransferFactory_Transfer controller = transfer.sender); executor/app (SettlementInfo.executor — emits AllocationRequests, submits atomic settlement); wallets (read via user's validator Ledger API, write via factories; external signing target 24h prepare→submit).

ExtraArgs = { context : ChoiceContext (TextMap AnyValue — FROM REGISTRY off-ledger API), meta : Metadata (TextMap Text — FROM CALLER) }. AnyContractId via coerceContractId. Standard meta keys: splice.lfdecentralizedtrust.org/{registry-urls, lock-context, reason, tx-kind, sender, burned}.

Factory + disclosed-contracts pattern: registry HTTP endpoint returns factoryId + choiceContextData (→ extraArgs.context) + disclosedContracts (templateId, contractId, createdEventBlob, synchronizerId — attach to Ledger API command). Wallet exercises by interface id on factoryId. expectedAdmin: "Implementations MUST validate that this matches the admin of the factory. Callers SHOULD ensure they get expectedAdmin from a trusted source." Off-ledger rationale: scalability, traffic costs, hiding impl details, standard tech.

V1 signatures (condensed):
- HoldingView { owner : Party, instrumentId, amount : Decimal, lock : Optional Lock, meta }; Lock { holders, expiresAt, expiresAfter, context }.
- Transfer { sender, receiver : Party, amount, instrumentId, requestedAt, executeBefore : Time, inputHoldingCids, meta }.
- TransferFactory_Transfer { expectedAdmin, transfer, extraArgs } controller transfer.sender (nonconsuming); TransferFactory_PublicFetch { expectedAdmin, actor }.
- TransferInstruction: _Accept/_Reject controller receiver; _Withdraw controller sender; _Update { extraActors, extraArgs } controller admin+extraActors. Result output: Pending cid | Completed receiverHoldingCids | Failed; senderChangeCids.
- SettlementInfo { executor : Party, settlementRef : Reference, requestedAt, allocateBefore, settleBefore : Time, meta }.
- TransferLeg { sender, receiver : Party, amount, instrumentId, meta }; AllocationSpecification { settlement, transferLegId : Text, transferLeg }.
- Allocation: _ExecuteTransfer controller [executor, sender, receiver]; _Cancel same; _Withdraw controller sender.
- AllocationFactory_Allocate { expectedAdmin, allocation, requestedAt, inputHoldingCids, extraArgs } controller allocation.transferLeg.sender.
- AllocationInstruction: _Withdraw controller sender; _Update controller admin+extraActors. Output: Pending | Completed allocationCid | Failed.
- AllocationRequest (view: settlement, transferLegs : TextMap TransferLeg, meta): _Reject { actor } controller actor; _Withdraw controller settlement.executor.

FOP flow: getTransferFactory (returns transferKind: self|direct|offer + context + disclosures) → TransferFactory_Transfer → Completed | Pending (offer: receiver fetches accept context, TransferInstruction_Accept; status TransferPendingReceiverAcceptance / TransferPendingInternalWorkflow with pendingActions : Map Party Text). Registries MUST fail after executeBefore.
DvP: app writes AllocationRequest → wallet getAllocationFactory + AllocationFactory_Allocate (locks until settleBefore) → app exercises Allocation_ExecuteTransfer on all in one tx (per-allocation contexts via getAllocationTransferContext).

## 2. Off-ledger surface (registry must serve; all unauthenticated, public URL prefix; discovery via CNS registry-urls meta — wallets currently maintain admin→URL maps themselves)

V1 endpoints (complete):
- GET /registry/metadata/v1/info → {adminId, supportedApis} (capability detection — wallets call FIRST)
- GET /registry/metadata/v1/instruments (paginated), GET /registry/metadata/v1/instruments/{instrumentId} → Instrument {id, name, symbol, decimals (0-10, default 10), totalSupply?, totalSupplyAsOf?, supportedApis, paused?, pauseInfo?, showAccountInputFields?, accountInputFieldsToShow?}
- POST /registry/transfer-instruction/v1/transfer-factory (getTransferFactory) — GetFactoryRequest{choiceArguments (Daml-JSON intended choice arg, context/meta empty), excludeDebugFields} → TransferFactoryWithChoiceContext{factoryId, transferKind, choiceContext}
- POST /registry/transfer-instruction/v1/{id}/choice-contexts/{accept|reject|withdraw} → ChoiceContext{choiceContextData, disclosedContracts[]}
- POST /registry/allocation-instruction/v1/allocation-factory
- POST /registry/allocations/v1/{allocationId}/choice-contexts/{execute-transfer|withdraw|cancel} (execute-transfer called by EXECUTOR pre-settlement, one per allocation)
- No off-ledger for holding-v1 / allocation-request-v1 (Ledger API reads; AllocationRequest choices called with empty context).

Disclosed-contract flow: disclosedContracts copied verbatim into command (createdEventBlob authoritative; debug* fields "use only if you trust the provider"); choiceContextData → extraArgs.context. "Clients SHOULD avoid reusing the same FactoryWithChoiceContext for multiple choices." synchronizerId tells wallet which synchronizer; mid-reassignment → HTTP 409.

## 3. CIP-0112 off-ledger changes

3.1 token-metadata-v1.yaml additions (spec version 1.2.0, NO metadata-v2 package):
- paused : boolean (default false) — "A paused instrument cannot be transferred or allocated" (splice eeb3543f, PR #5405)
- pauseInfo { reason?, until? (exclusive) }
- showAccountInputFields : boolean (default false) — now DEPRECATED in favor of accountInputFieldsToShow : ["provider"|"accountId"] (splice 565c6437, PR #6346). "Wallets should always show non-null account providers and ids when DISPLAYING transfers/allocations."
- supportedApis now lists V2 packages — how apps/wallets decide V1-vs-V2 per instrument (GET /info used "to verify whether a given tokenizer supports the CIP-112 interfaces, or whether a fallback to CIP-56 is needed" — DA registry docs).

3.2 New V2 endpoints (same request/response shapes as V1):
- transfer-instruction-v2.yaml: /registry/transfer-instruction/v2/transfer-factory + /{id}/choice-contexts/{accept|reject|withdraw} (structurally identical, /v1/→/v2/)
- allocation-instruction-v2.yaml: /registry/allocation-instruction/v2/allocation-factory (25-leg guarantee) + NEW /{allocationInstructionId}/choice-contexts/{accept|withdraw} (V1 had no instruction-level context endpoints; needed because V2 instructions can require provider acceptance)
- allocation-v2.yaml: POST /registry/allocation/v2/settlement-factory (getSettlementFactory) — REPLACES V1 per-allocation execute-transfer context; serves factory+context for SettleBatch; MUST support ≥25 legs / 50 allocations / 50 accounts / 100 parties per request. Plus /registry/allocations/v2/{id}/choice-contexts/{withdraw|cancel}. NO v2 execute-transfer endpoint.
- DA hosted Tokenization Utility serves all under https://api.utilities.digitalasset.com/api/token-standard/v0/registrars/<admin-party-id>/... (docs.digitalasset.com/registry/apis/token-standard/off-ledger-api).

## 4. Wallet / exchange integration expectations

- Listing holdings: JSON Ledger API /v2/state/active-contracts, InterfaceFilter on #splice-api-token-holding-v1:...:Holding, includeInterfaceView + includeCreatedEventBlob; viewValue = JSON HoldingView. Same for pending instructions/allocations. PQS for fleet scale.
- Tx history: stream /v2/updates with interface filters + WildcardFilter for child nodes; TRANSACTION_SHAPE_LEDGER_EFFECTS. V1 parsing: tree-walk nodeId/lastDescendantNodeId, tx-kind meta keys (transfer|merge-split|burn|mint|unlock|expire-dust), meta merge order transfer.meta → extraArgs.meta → choiceArgument.meta → exerciseResult.meta. V2 parsing: filter EventLog_HoldingsChange exercises — "a parser only needs to resolve inputHoldingCids/outputHoldingCids; everything else is in the choiceArgument". Persist offset checkpoints (crash resume + Major Splice Upgrades).
- Initiating transfers: registry factory endpoint → ExerciseCommand by interface id on factoryId → external parties prepare/execute (external signing); hosted parties submit-and-wait — always attaching disclosedContracts.
- Exchange operator pattern (DA guide): Tx History Ingestion (→ Canton Integration DB), Withdrawal Automation, Deposit Automation (auto-accept offers via accept-context + TransferInstruction_Accept). Deposit attribution via .../reason meta as memo/account-id; withdrawal = same tx sender/receiver swapped; CC caveat: fees make choice-arg amount ≠ holdings delta. Don't act on deposits with unknown accounts; still ingest for support.
- Registry operator must run: (a) on-ledger implementation (V2: + SettlementFactory, EventLog, dual V1/V2 instances per §5.1); (b) off-ledger HTTP server with every endpoint, public, one URL prefix per node; (c) CNS registration of registry-urls on admin party's (single) CNS entry; (d) Global Synchronizer connectivity (recommended). Amulet/Scan = reference.
- UTXO hygiene (wallet duty): keep users below ~10 Holding UTXOs; prefer small holdings; MergeDelegation at onboarding; batched merge daemon (BatchMergeUtility_MergeHoldings ~100 merges/call) using CanReadAsAnyParty; CC caps 100 input contracts, expires dust.

## 5. Security / operational guidance for registries

1. No authentication off-ledger BY DESIGN: sensitive data only readable from investor's own validator; endpoints serve public data or data protected by unguessable contract-ids. Implication: treat contract-ids as capability tokens; never expose via choice contexts anything unsafe behind an unguessable id.
2. BFT for decentralized registries: serve endpoints from every node, one URL prefix per node; Daml code written so no node can influence integrity of transactions built from its HTTP response; clients query random prefix, retry.
3. Untrusted-source hardening: factories from HTTP are untrusted — impls MUST validate expectedAdmin; callers SHOULD obtain expectedAdmin from trusted source. debug* fields only if trusted. Deadline checks mandatory: TransferFactory_Transfer MUST fail if executeBefore past; allocations lock only until settleBefore.
4. DoS/resource protection (CIP-0112): expiresAt expiry recovers storage, protects DoS; expiry ≈ settlement deadline, bump per iteration. Caps allowed but 25-leg/50-account/100-party minimum. Settle validations MUST: allocations belong to settlement, legs authorized both sides, exact cover; SettleBatch MUST check actors. Apps MUST keep SettlementInfo ids unique per executor set; wallets SHOULD AllocationRequest_Accept in allocation tx (replay protection).
5. Privacy: need-to-know; Lock.context visibility may be wider than context contracts — choose contents carefully; providers MUST see all movements; V2 privacy only if SettleBatch called from executor-only context; EventLog events MUST explain all changes + both sides, observers ⊇ account parties; consumers only trust events from the instrument admin.
6. Operational: 24h prepare-to-submit target (CC: 10 min); totalSupply = sum of active Holding.amount, reported off-ledger; logo ~200x200; small on-ledger metadata; registry meta on lexicographically-smallest CNS entry (allocate exactly one). Off-Canton-authoritative registries may skip holdings API. DA hosted registry publishes audits/monitoring pages + tx-history-parsing guide (product-specific).

Practical note: normative V2 artifacts live on splice main (the CIP's token-standard-v2-upcoming preview branch is historical). V2 off-ledger delta is small (three endpoint groups); the bulk of CIP-0112 complexity is on-ledger.
