# ADR: CIP-0112 Public API Promotion Boundary

Status: accepted for Phase 2 promotion-boundary planning. This is not a public
API stability, conformance, audit-readiness, production-readiness, or release
readiness claim.

Date: 2026-06-17

Phase: Phase 2, Scope-Locked Library Foundation

Depends on: root `PLAN.md` Decision Log S2 for D2 lock-and-sweep to the
admin-preset custodian destination and D4 single-admin capability authority.

## Context

`canton-contracts/experiments/cip112-settlement` is an experimental local
scaffold for the CIP-0112 / Token Standard V2 settlement shape. It deliberately
mirrors upstream names, but it does not import or vendor the Splice Token
Standard V2 packages.

The promotion question is whether the experiment can become a stable
`canton-contracts` public surface. This ADR narrows that boundary. It chooses
the upstream source evidence and package boundary, but it does not accept a
Splice DAR import yet because this slice has not produced published DAR
provenance, checksums, or license-notice packaging evidence.

The follow-up import-gate evidence result is recorded in
[`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md).
It confirms that source/package evidence exists at the pinned upstream commit,
but actual import remains blocked until release-source confirmation, accepted
DAR or reproducible-build artifacts, DAR checksums, license/NOTICE packaging,
DPM wiring, and public API review land.

Companion M1 acceptance criteria for CIP-0086, CIP-0103, and CIP-0104 are
recorded in
[`cip0086-cip0103-cip0104-m1-acceptance.md`](./cip0086-cip0103-cip0104-m1-acceptance.md).
Those criteria remain interoperability evidence for the CIP-112 settlement
surface and do not widen this ADR's public API or import boundary.

## Evidence Pin

| Item | Boundary |
| --- | --- |
| CIP text | `global-synchronizer-foundation/cips` `main` at `24b121264fcb473399e3d40615dabff915371ba5`. The historical `canton-foundation/cips` remote resolves to the same commit. |
| Splice source repo of record | `hyperledger-labs/splice`. |
| Splice source branch/commit | `token-standard-v2-upcoming` at `1e34121b2b369c5dde357c098e2aaeb65250e736`, verified by `git ls-remote`. |
| Historical local preview | `canton-network/splice` branch `token-standard-v2-daml-preview` at `b91de5d4b910ded598151981654dce2acc6f84ba`; keep as prior evidence only, not the promotion source of record. |
| Upstream license posture | Repository root `LICENSE` is Apache-2.0; Token Standard Daml API package files and `daml.yaml` files carry `SPDX-License-Identifier: Apache-2.0`. |
| Local license posture | `canton-contracts` is MIT. Any vendored upstream source or redistributed upstream DARs would create a mixed MIT/Apache-2.0 distribution and must carry the required Apache-2.0 license and notice posture before publication. |

## Decision

1. Do not vendor Splice source or import Splice DARs in this slice.
2. Treat `hyperledger-labs/splice` `token-standard-v2-upcoming`
   `1e34121b2b369c5dde357c098e2aaeb65250e736` as the current source evidence
   pin for Token Standard V2 promotion work.
3. Keep the local `OpenZeppelin.Experimental.Settlement.Cip112` stand-ins
   experimental until a later slice accepts a published DAR or reproducible
   build artifact boundary with checksums, license/NOTICE handling, and DPM
   dependency wiring.
4. When promotion proceeds, prefer a thin local facade around direct upstream
   Token Standard V2 imports over a local public mirror of upstream types. The
   facade may add OpenZeppelin-specific compliance, seizure, and upgrade
   controls, but upstream Token Standard types should not be republished under
   local names as the stable API.

## Package And DAR Boundary

The promotable Token Standard V2 boundary is a set of API packages, not a single
monolithic Splice dependency:

| Package | Role |
| --- | --- |
| `splice-api-token-metadata-v1` | Shared `Metadata` / extra-argument support. |
| `splice-api-token-holding-v2` | `InstrumentId`, `Account`, `Lock`, and `Holding` interface. |
| `splice-api-token-allocation-v2` | `SettlementInfo`, `TransferLeg`, `TransferLegSide`, `Allocation`, and `SettlementFactory`. |
| `splice-api-token-allocation-request-v2` | Allocation request interface. |
| `splice-api-token-allocation-instruction-v2` | Allocation instruction interface. |
| `splice-api-token-transfer-instruction-v2` | Transfer instruction interface for wallet/app flows. |
| `splice-api-token-transfer-events-v2` | `EventLog_HoldingsChange` reporting interface. |

The package YAMLs observed at the evidence pin declare `version: 1.0.0` and
SDK `3.4.11`, but this ADR does not treat those values as sufficient publication
pins. A future import slice must identify the exact DAR source, package IDs or
SHA-256 checksums, and DPM/local build flow.

Out of boundary for M1 public API promotion: Amulet implementation packages,
wallet apps, featured-app APIs, validators, SV infrastructure, token-standard
examples/tests, CLI code, and Splice utility packages unless a later ADR adds a
specific package.

## Stable/Promotable Surface

"Stable/promotable" here means the candidate shape for a later public API after
the DAR/import evidence gate is accepted. It is not stable today.

- A Token Standard V2-aligned settlement primitive that depends on upstream
  Splice API packages for Token Standard types instead of local copies.
- A narrow OpenZeppelin facade for M1 regulated-settlement controls:
  D1 reference/attestation extension point, D2 lock-and-sweep state, D4
  single-admin capability authority, and SCU-safe upgrade metadata.
- `SettlementFactory_SettleBatch` as the stable atomic multi-allocation
  settlement entrypoint.
- Token Standard V2 `EventLog_HoldingsChange` as the promoted reporting route
  for wallet/app discoverability once the transfer-events DAR boundary is
  accepted.
- CIP-0086 / CIP-0103 / CIP-0104 interoperability evidence that targets the
  promoted settlement facade, not the local experiment or a standalone CIP-56
  token foundation.
- D2 in-flight seizure semantics from S2: marked in-flight allocations are
  lock-and-sweeped to the admin-preset custodian destination, not burned and
  not returned to sender.

## Experimental-Only Scaffold Surface

The following remain experiment-only and must not be documented as stable API:

- `OpenZeppelin.Experimental.Settlement.Cip112` and its DAR.
- `ToyHolding`, `SettlementReceipt`, `BurnerCapability`, `experimentalFeatureFlag`,
  and all local copies of upstream-like records such as `Metadata`,
  `InstrumentId`, `Account`, `Lock`, `SettlementInfo`, `TransferLeg`, and
  `TransferLegSide`.
- The local `Reference.cidText` compromise for contract-id references.
- The stringly typed `D1ComplianceHook` and `D2SeizureHook` fields.
- The direct `Allocation_Settle` peer-proof arguments
  (`peerAllocationCids`, `peerReceiptCids`, `extraTransferLegSides`) as a public
  delivery-versus-payment API.
- Any toy holding receipt co-sign behavior caused by `ToyHolding` signatories.

## SCU And Upgrade Contract

Once a public surface is accepted:

- Do not mutate required fields or required choice arguments on public
  templates/interfaces to add D1, D2, D3, or D4 behavior.
- Add optional fields, metadata, or new choices for typed behavior.
- Use Daml Smart Contract Upgrades compatibility checks before promoting any
  replacement package.
- Treat typed D1 node attestations, lawful-process attestations, seizure
  destination mutability, and future multi-sig authority as additive extensions.
- Keep old choices usable for old contracts where behavior is additive; only a
  deliberate major-version boundary may break choice arguments or archive
  semantics.

## Direct Allocation Settlement Vs Batch Settlement

Promoted M1 semantics:

- Batch settlement is the only stable atomic multi-allocation settlement path.
  The public story for delivery-versus-payment atomicity must go through
  `SettlementFactory_SettleBatch`.
- Direct allocation settlement may remain an implementation detail or advanced
  compatibility path. If exposed, it must be described as proving local
  authorization and consuming the local allocation, not as peer co-settlement,
  unless it also consumes or settles the peer allocations in the same Daml
  transaction.
- Existing experimental `Allocation_Settle` proves that matching peer sides
  exist through fetched peer allocations or receipts. It is not a stable
  direct-path DvP API.

## Third-Party Custodian Credit Model

D2 authority and destination credit are separate concerns.

- D2 seizure authority for M1 is the S2 single-admin capability model.
- The destination is preset by the registry/admin before seizure execution.
- A promoted M1 path may credit either an admin-managed special account or a
  pre-onboarded third-party custodian account.
- For a regular third-party account, receipt must be authorized by the account
  provider/owner through a standing account arrangement, a co-signed receipt
  transaction, or a later accepted propose/accept credit flow. That receipt
  authorization is not seizure approval authority.
- This ADR does not accept unilateral crediting of an arbitrary third-party
  regular account without a Token Standard V2 account-authorization model.

## Post-Deadline Seizure-Window Policy

For M1 promotion, the settlement deadline remains terminal for the current
in-flight allocation lifecycle:

- Normal settlement must not execute after `settlementDeadline`.
- Committed allocation withdrawal/release may proceed after the deadline.
- D2 in-flight sweep must complete on or before the settlement deadline unless
  a later ADR accepts an explicit seizure-window field and lawful-process
  evidence model.
- Post-deadline seizure is therefore out of the M1 promotable surface. If
  required by a specific deployment, add it later through SCU-safe optional
  fields or a new seizure choice.

## Residual D1/D3/D4 Boundaries

- D1 remains no-cache, fail-closed, node-side. This ADR does not finalize
  whether a Daml-visible signed node attestation exists. The current local D1
  hook is only an experimental fail-closed reference seam.
- D3 remains single-domain v1. The tech-ops one-pager is still required before
  downstream work cites D3 as fully closed.
- D4 is decided for M1 by S2: single-admin capability authority. On-ledger
  multi-sig and topology-level multi-hosted party authority remain future
  extensions unless a specific stakeholder deployment requires them earlier.

## Promotion Gates

Before importing upstream DARs or claiming public API stability, a later slice
must provide:

- published upstream DAR or reproducible build source;
- exact DAR SHA-256 and/or package IDs;
- license and NOTICE packaging plan for Apache-2.0 artifacts in the local
  MIT-licensed repo;
- DPM dependency wiring and local build/test evidence;
- confirmation that the imported Token Standard V2 branch/tag is the intended
  upstream release source, not only a working branch;
- public API review for the OpenZeppelin facade and SCU contract.

The current evidence-boundary result is
[`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md):
the upstream `daml/dars.lock` package IDs are useful identity evidence, but they
do not replace an accepted release/import source or DAR checksum list.

Until those gates land, the experiment remains local, non-public, and
non-conformant.
