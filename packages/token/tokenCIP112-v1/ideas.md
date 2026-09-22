# Extension ideas — `openzeppelin-tokenCIP112-v1`

## 0. Reintroduce the batch-settlement authorization guard

Removed for now to keep the core small. The guard was an admin-signed
`BatchSettlementAuthorization` proof template: minted per allocation inside
`SettlementFactory_SettleBatch` after the exact-cover check, passed through the
choice context under `openzeppelin.com/batch-settlement-authorization`, and
consumed (fetched, validated, archived) by `allocation_settleImpl`. It bound
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

Working notes on possible extensions to the token package. These are ideas, not
commitments: nothing here is scheduled, and none of it is consumer
documentation (that lives in `README.md`). Spec section references are to
CIP-0112; see `cip112-reference/cip112-explainer.md` for context.

## 1. CIP-56 (Token Standard V1) compatibility instances

The V2 interface hierarchy is parallel to V1 — the two share only
`splice-api-token-metadata-v1` — so V1 wallets and tooling cannot see this
token today. The vendored utils ship `...V1...DefaultImplUsingV2` helpers for
exactly this pattern: add the V1 `interface instance` blocks to the same
templates (`TokenHolding`, `TokenTransferInstruction`, `TokenAllocation`,
`TokenRules`), expressing V1 semantics in terms of the V2 implementations. The
V1 DARs are already vendored under `dars/vendor/`. CIP-0112 §5 treats dual
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
legs (DvM/DvB). Supporting this needs a dedicated path in `allocateImpl` and
`settleAllocation` — a mint-side leg has no holdings to lock, so the admin's
authority must stand in for funding, and the cover check must treat the
special-account side as admin-authorized.

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
`fetchAndArchiveUnlockedHolding`, `TokenHolding_OwnerUnlock`, and the
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
`allocateImpl`. This is the natural hook for compliance gating
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
