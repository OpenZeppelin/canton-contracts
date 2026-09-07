# Agent report: Ecosystem Evidence for a CIP-0112 Reference Implementation Need

(Verbatim agent deliverable, 2026-08-26.)

## 1. Integrator pain points with CIP-0056 / token-standard integration

**Transaction-history parsing = the single most documented pain point.**
- DA registry integration guide: CIP-56-era parsing "involves additional complexity around template choice exercises"; CIP-112 EventLog path still requires understanding ledger-effects format, parsing choiceArgument transfer-leg structures, SenderSide/ReceiverSide classification. Ledger pruning warning (30-day retention on registry operator nodes); six-step migration with parallel ingestion pipelines for Registry 0.14 / CIP-112 parsing. https://docs.digitalasset.com/registry/guides/tx-history-parsing
- Splice 0.5.16 forced hard migration: "All exchanges and wallets that parse AmuletRules_Transfer transactions directly must either update their parsing methods... or move to CIP-0056 token standard transfers" — deadlines DevNet Apr 7, TestNet Apr 21, MainNet May 5, 2026. https://forum.canton.network/t/splice-0-5-16-coming-to-devnet-on-march-23rd/8468
- Splice release notes: "Greatly simplify the parsing of Amulet transaction history... by reporting all holding changes as V2.EventLog_HoldingsChange events." https://docs.canton.network/global-synchronizer/release-notes/splice

**Transaction construction (factory pattern, choice context, disclosed contracts) confuses integrators.**
- Forum (stanley_nie, Dec 2025): can token/transferCommand/disclosedContracts/transaction params be obtained without an SDK? Answer: curl registry URL + manually reverse-engineer wallet-kernel source. https://forum.canton.network/t/is-it-possible-to-obtain-the-complex-parameters-needed-to-construct-a-transaction-without-relying-on-an-sdk/8339
- Docs: frontends must exercise proxy choices, include FeaturedAppRight + proxy contracts as disclosed contracts alongside registry-API ones. https://docs.sync.global/app_dev/daml_api/index.html
- External-party signing for CC transfers recurring support topic. https://discuss.daml.com/t/external-party-transfer-cc-issue/7996
- Unanswered MainNet integration thread (Aug 24, 2026) requesting official config + docs across seven areas. https://forum.canton.network/t/canton-mainnet-wallet-dapp-integration-guidance/9079

**Building a compliant token from scratch is hard enough that teams get it wrong.**
- ChainSafe canton-erc20 issue #27 (Feb 2026): their CIP-56 token implemented "zero DAML interfaces," tokens "invisible to all Canton wallets"; breaking 2.0.0 rewrite to adopt HoldingV1, TransferFactory/TransferInstruction, standard Metadata, MergeDelegation. https://github.com/ChainSafe/canton-erc20/issues/27
- MergeDelegation/UTXO-merge onboarding and batching are extra wiring. https://docs.global.canton.network.sync.global/app_dev/token_standard/index.html

**V2-specific semantics already generating integrator questions.**
- Sergey_Kisel (June 25, 2026): does committed=True restrict only Allocation_Withdraw or also Allocation_Cancel? How to discover registry-specific cancellation policy? How to top up committed allocations? Bernhard (DA) answered (multiple/decentralized executors; top up via second allocation settled in batch). https://forum.canton.network/t/cip-0112-token-standard-v2-committed-allocations-and-cancellation-policy/8813

## 2. Auditor findings and security guidance

**CertiK "Where CIP-56 Security Actually Lives"** https://www.certik.com/blog/where-cip-56-security-actually-lives-a-guide-for-institutions-on-canton
Thesis: "CIP-56 compliance tells you that an implementation speaks the common interface. It does not, by itself, establish how registry inputs are checked." Security lives in: Daml implementation layer (Amulet checks permitted actor groups, expected admin, instrument, amount, timestamps, max transfer lifetime, required holdings), client-side transaction construction (availableActions is "a wallet-facing projection of the current authorization state, not the authorization state itself"), operational authority (Ledger API credential scope, CanReadAsAnyParty super-readers).

Six recurring issue classes:
1. Authorization-binding failures — V2's earlier, reusable authorization with configurable executors "makes correct binding the central invariant"; settlements "must verify that the allocations belong to the settlement being executed... and cover exactly the supplied transfer legs."
2. Incomplete interface verification — generic wallet cannot depend on knowledge of concrete templates.
3. Trust-domain confusion — deriving factory IDs and expected admins both from untrusted registry data defeats source separation; ChoiceContext references must be fetched against expected owner/admin; ExtraArgs.meta is a separate caller-supplied trust channel.
4. Incomplete event attribution — "a parser that accepts every structurally matching EventLog_HoldingsChange can ingest a transfer history emitted under another admin"; EventLog completeness is an implementation obligation.
5. Account-authority escapes — configurable movement rules can create standing authority exceeding scope; TestTokenV2 deliberately restricts account-authority mechanisms, keeps settlement authority separate from account policies.
6. Batch-settlement privacy leaks — "one allocation must not receive private reference data belonging only to another allocation in the same batch."

CertiK: active audit demand from "several teams targeting CIP-56 compatibility." Companion: https://www.certik.com/blog/cip-56-redefining-token-standards-for-institutional-defi

**Halborn** Canton/Daml practice: Tradecraft liquidity layer ("little established audit precedent" for Daml), Temple Daml contracts (Dec 2025) + diff review, Alpend privacy-first money market. https://www.halborn.com/case-studies/post/case-study-securing-a-first-of-its-kind-liquidity-layer-on-the-canton-network-for-tradecraft ; https://www.halborn.com/audits/temple/daml-contracts-225b21 ; https://www.halborn.com/audits/alpend/smart-contract-assessment-001d47

**Teams asking where to get audits/audited baselines:** forum (AdrianK, Apr 2026) — is DA Utility generated-token config audited, which firms? Answer names Halborn/Temple only; no audited public reference offered. https://forum.canton.network/t/daml-utility-and-cip-56-audits/8593

## 3. Who would consume a CIP-0112 reference implementation

- Stablecoin issuers: Circle USDCx live on Canton via xReserve as CIP-56-compliant (https://www.canton.network/private-stablecoin-payments-on-public-blockchain). Brale = Canton native stablecoin stack, validator, key stablecoin issuer (https://brale.xyz/case-studies/canton-network).
- RWA/treasury: Circle USYC tokenized MMF ~$3B AUM on Ethereum/Sui/Canton (https://eco.com/support/en/articles/15254018-usyc-deep-dive-2026-hashnote-and-circle-s-tokenized-money-market). Tradeweb on-chain UST repo on Canton Dec 2025 (https://www.canton.network/blog/the-ultimate-guide-to-canton-networks-ecosystem).
- Custodians/exchanges: BitGo extended Canton infra to CIP-56, qualified custody for USDCx and cBTC (https://www.stocktitan.net/news/BTGO/bit-go-extends-canton-network-infrastructure-to-cip-56-token-rfehqtkvbh4i.html). Dfns wallet-as-a-service CIP-56 (https://dfns.co/article/canton-token-standard-support).
- Tokenization platforms: DA registry platform "35+ institutions, issuers, global FMIs and platform providers" (https://www.canton.network/developer-resources); DA Utility full token standard support via Registry module (https://docs.digitalasset.com/utilities/releases/0.8.html).
- DeFi-style apps/token builders: CantonSwap first cross-issuer atomic swap CC↔cBTC purely via CIP-56 interfaces (CertiK); ChainSafe canton-erc20; Tradecraft, Temple, Alpend. CIP-0112 targets trading/settlement venues + on-chain securities with custody chains.

## 4. Existing guidance gaps

- "Simplify and specialize" guidance is from CIP-0112 itself: TestTokenV2 is for "testing V2 token standard workflows in all their possible permutations"; verbatim: "It is recommended that developers wanting to use it as a base simplify and specialize it to their own domain rather than using it as provided." The only V2 reference is explicitly not production-intent — feature-maximal.
- Splice ships test harnesses, not production token code: "Take a copy of these files and modify them to your liking for testing your app" (splice-token-standard-test). https://docs.sync.global/app_dev/api/splice-token-standard-test/index.html
- What shipped instead: DA proprietary/hosted — Utility/Registry with token-standard support, "zero deployment" registry where "DA operates the backend components for the token standard (CIP-056, CIP-0112)" (https://docs.digitalasset.com/utilities/releases/0.8.html; https://blog.digitalasset.com/blog/institutional-assets-canton-fast); Wallet SDK/wallet-kernel client side only (https://github.com/hyperledger-labs/splice-wallet-kernel/tree/main/sdk/wallet-sdk); on-ledger utils (splice-token-standard-utils, BatchingUtilityV2) help consume, not implement.
- **Nobody has shipped an open, audited, production-grade CIP-0112 token implementation library — the gap sits exactly between "hosted registry product" and "test-only reference."**
- Splice token-standard docs cover interface APIs and wallet-side integration; no production registry implementation guidance beyond CIP + TestTokenV2.

## 5. Adoption status of CIP-0112 (Aug 2026)

- Approved June 12, 2026.
- Canton Coin (Amulet) = flagship V2 adopter: Splice 0.6.11 includes V2 APIs + Amulet implementation, committed allocations, EventLog_HoldingsChange for all holding changes, BatchingUtilityV2, wallet UI V2 support (https://docs.canton.network/global-synchronizer/release-notes/splice). CertiK (Aug 2026): V2 packages + Canton Coin compat + TestTokenV2 live on Splice main.
- DA Registry 0.14+ recommends CIP-112 EventLog parsing path, stops creating legacy Executed* contracts — forcing integrator migration (https://docs.digitalasset.com/registry/guides/tx-history-parsing); DA Utility supports CIP-0112 alongside CIP-056.
- No V1 deprecation — dual-interface support mandatory (independent upgrades; user-safety rationale). Deprecated: legacy Splice wallet transfer offers (since splice-0.4.11); TransferCommand "deprecated and will be removed."
- Migration precedent with hard MainNet deadlines (0.5.16: May 5, 2026).

## Strongest evidence of need

1. The ecosystem's only V2 reference is officially disqualified for production use (CIP-0112's own "simplify and specialize"; Splice artifacts are test harnesses/client SDKs). Production-implementation slot empty; DA fills it only with hosted/proprietary products.
2. CertiK documents six recurring subtle issue classes living precisely in the implementation layer a reference would harden; multiple teams currently seeking CIP-56 audits.
3. Real teams demonstrably fail without a reference: ChainSafe token invisible to every wallet, breaking rewrite; integrators reverse-engineering SDKs; day-one V2 committed-allocation design questions.
4. Demand side institutional and named: Circle (USDCx, USYC), Brale, BitGo, Dfns, Tradeweb, CantonSwap, 35+ institutions on DA registry platform.
5. Timeline pressure proven: forced exchange/wallet migrations with hard deadlines; Canton Coin + DA Registry moved to V2/EventLog; TransferCommand on removal path.
