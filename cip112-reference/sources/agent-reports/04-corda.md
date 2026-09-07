# Agent report: Corda Prior Art for a CIP-0112 Reference Implementation

(Verbatim agent deliverable, 2026-08-26. Snapshots: corda/token-sdk master @ e4a4b85 (2020-10-29; maintenance tag release-1.3.4 @ 8669edc, 2026-08-18); corda/accounts master @ a19fb7d (2023-08-16).)

## 1. Corda Tokens SDK

Type hierarchy:
- TokenType(tokenIdentifier, fractionDigits) — plain value describing what the token is.
- EvolvableTokenType : LinearState — mutable reference data (bond terms), NOT a TokenType; referenced by TokenPointer proxy; maintainers may update. Direct ancestor of CIP-0112's holdings-reference-registry-metadata pattern. Updates propagate via push distribution lists (UpdateDistributionListFlow) — fragile, silently desyncs.
- IssuedTokenType(issuer, tokenType) — issuer welded into fungibility class; same TokenType from different issuers NOT mergeable (counterparty risk). Same instinct as CIP-0112 keeping admin identity in holding identity; each custody intermediary's claim is a distinct instrument on its own issuer.
- FungibleToken(amount: Amount<IssuedTokenType>, holder: AbstractParty, tokenTypeJarHash) / NonFungibleToken(token, holder, linearId, jarHash). holder = bare (possibly anonymous) key, NOT an account. tokenTypeJarHash pins contract JAR — upgrade wart.

Authorization (contract level): participants = [holder]. IssueTokenCommand → issuer signs; MoveTokenCommand → all input holders sign; RedeemTokenCommand → holder AND issuer sign (two-party burn handshake). Notary signs everything (uniqueness).

Token selection & contention:
- DatabaseTokenSelection: Hibernate + vault soft locks; InsufficientBalanceException / InsufficientNotLockedBalanceException. Design doc verbatim: DB implementation "is a bottleneck, and can lead to token exhaustion, where all tokens are locked by flows which are not making progress."
- LocalTokenSelector (in-memory TokenIndex buckets, CAS flags): experimental, heap exhaustion risk, documented restart race. Never matured; Corda 5 absorbed selection into the platform (TokenSelection API, TokenClaimCriteria).
- Lesson: UTXO holdings inevitably create a selection/locking subsystem; a library-level afterthought becomes the operational pain center. CIP-0112 committed allocations = soft locks promoted to first-class contract state — the right fix; keep them expiring/abortable or you recreate token exhaustion.

## 2. Corda Accounts library

AccountInfo(name unique-per-host, host: Party, identifier: UUID) : LinearState; participants = [host]. No standing key per account — fresh keypair per interaction via RequestKeyForAccountFlows; host maps PublicKey → UUID; vault partitions by externalIds.

Authorization: only participant/signer is the HOST. Logical owner has NO ledger-level authority; account permissions deferred to app layer. Gaps: keys not verifiably bound to accounts for third parties (issue #50), no account portability, no key reuse, host sees all.

Mapping to CIP-0112 Account(owner, provider, id):
- host ≈ provider (parallel), UUID+name ≈ id (parallel).
- MISMATCH (the big one): Corda's logical owner is off-ledger, cannot authorize anything; CIP-0112's owner is a first-class party signatory/controller.
- Corda accounts bolted on (2019) after holder: AbstractParty was fixed; retrofit friction (changeHolder threading, SyncKeyMappingFlow ceremony, account-aware selection).
- Lesson: put owner AND provider in the holding record from day one as real authorizing parties. Worth stealing: (host, name)-scoped naming with global UUID — don't pretend account names are global.

## 3. Settlement / DvP patterns

Atomic swap = one transaction (DvPTutorial): initiator addMoveNonFungibleTokens; counterparty generateMove + SendStateAndRefFlow; merge, SyncKeyMappingFlow, CollectSignaturesFlow, ObserverAwareFinalityFlow. Required signers = all input holders both legs + notary. Non-validating notary sees refs+Merkle root; validating notary sees everything. Cross-notary requires notary-change tx first.

Privacy limits:
- Confidential identities hide WHO, not WHAT: every signer validates and SEES the entire transaction. No per-leg projection — a 3-leg settlement shows every leg to every participant.
- Backchain hazard: verifying a received state downloads/verifies full dependency chain, exposing past owners and prior deals. Mitigations (SGX, ZK) never shipped; workarounds (re-issuance/"chain snipping") reintroduce issuer trust.
- No standard interfaces → no atomic multi-leg composability across independent CorDapps ever emerged (bespoke composite flows only).
- Contrast: Canton sub-transaction privacy is precisely the missing primitive. Corda proved "one atomic tx, everyone sees everything" is unacceptable to intermediated finance; per-leg visibility must come from the LEDGER MODEL, not flow-level identity blinding. CIP-0112 batch settlement solves the exact problem Corda documented and couldn't solve.

## 4. What worked / didn't — adoption lessons

Worked: IssuedTokenType issuer-in-fungibility-class; holding/evolvable-definition split by pointer; notary-scoped atomic DvP (SDX, HQLAx production); explicit required-signer semantics per command.

Didn't:
- Token selection as library bolt-on (exhaustion, races).
- Accounts as afterthought (key sprawl, no owner authority, no portability).
- Backchain privacy leak — never fixed; structural objection for banks.
- Push distribution lists for evolvable updates.
- Maintenance reality: token-sdk master frozen Oct 2020; only compat patches (1.3.4 @ 2026-08-18); corda5-token-sdk removed/private; May 2025 R3 pivoted to Solana partnership, Corda in maintenance/harvest mode.
- Consortium economics: Marco Polo insolvent 2023, Contour shut 2023, we.trade 2022, B3i 2022 — per-consortium bespoke apps, no interoperability.

Pitfalls for a Canton reference:
1. Don't leave holding selection/locking to consumers — committed allocations need bounded lifetimes and clean abort paths.
2. Owner and provider both contract-level authorizers from v1 (never retrofit accounts).
3. Pause/instrument metadata pull-based against registry contract, not push-distributed.
4. Don't pin implementation artifacts into state identity (tokenTypeJarHash) — use Daml upgrade model deliberately.
5. Standardize interfaces so independent apps compose atomically — absence caused Corda app silos and dead consortia.
6. Don't require lockstep platform/SDK versions (version matrix = adoption tax).

## 5. Regulated-finance production patterns (custody chains)

- HQLAx (live Dec 2019, Deutsche Börse + custodian TTPs): Digital Collateral Records — ownership transfers on registry while securities never move from custody accounts; TTP layer maps ledger ownership to real custody; legal model makes registry source of truth; atomic DvD of two collateral baskets. Strongest prior art for CIP-0112 custody chains: record moves through intermediary graph while physical custody static — the layered claim structure owner/provider Accounts encode natively. (SEC no-action request May 2026.)
- SDX (FINMA-licensed, live Nov 2021; UBS digital bond 2022): integrated issuance-trading-settlement-custody; CSD = universal provider for all member accounts. Works but recentralizes; CIP-0112 per-holding provider generalizes.
- Digital tenge (Kazakhstan CBDC, first production tx Nov 2023): two-tier central-bank-issues / commercial-banks-host — owner(citizen)/provider(bank) split on Corda accounts.
- Riksbank e-krona (2020–2024, not productionized): notary = central scaling/availability chokepoint; intermediated model limits anonymity — token history visible along chain. Bounded per-leg visibility is what central banks asked for and Corda couldn't provide.

Cross-cutting: Corda = participants (storage) + Command requiredSigners (authorization) + notary (uniqueness); Daml/Canton collapses these into signatories/observers/controllers with ledger-enforced sub-transaction privacy — precisely the capability gap between Corda DvP and CIP-0112 batch settlement.

## Key permalinks
- token-sdk @ e4a4b85: contracts/.../types/TokenType.kt, IssuedTokenType.kt, states/EvolvableTokenType.kt, FungibleToken.kt, NonFungibleToken.kt; design/token-selection.md; docs/DvPTutorial.md, IWantTo.md, InMemoryTokenSelection.md
- accounts @ a19fb7d: contracts/.../states/AccountInfo.kt; workflows/.../RequestKeyForAccountFlows.kt, services/AccountService.kt; docs.md; issue #50
- docs.r3.com token-selection (Corda 4.11, Corda 5.2); R3 CDL privacy-hazard docs; confidential-identities OVERVIEW.md
- HQLAx: hqla-x.com/post/redefining-collateral-mobility; sec.gov/files/tm/no-action/hqlax-nal-request-050426.pdf; SDX: six-group.com, ubs.com 2022 digital bond; R3 digital tenge case study; Riksbank e-krona phase 1 & 4 reports; ledgerinsights.com R3-Solana pivot; GTR consortium post-mortem
