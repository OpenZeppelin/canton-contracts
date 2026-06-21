# Canton Token Standard V2 (CIP-0112) — M1 Reference Implementation: Architecture & Specification

Status: **experimental architecture & scoping spec**, non-public, outside the
committed M1 public-library surface. This document specifies the M1 settlement
RI target and records the adopted design decisions and their grounding in code.
The promotion boundary for Token Standard V2 imports and the public API
candidate surface is recorded in
[`cip0112-public-api-promotion-boundary.md`](./cip0112-public-api-promotion-boundary.md);
that ADR keeps this scaffold experimental until the later DAR/import evidence
gates land. The current import-gate evidence boundary is recorded in
[`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md);
it documents the upstream package IDs and build/release evidence that still do
not authorize a local import or stability claim. The M1 acceptance boundary for
CIP-0086, CIP-0103, and CIP-0104 is
recorded in
[`cip0086-cip0103-cip0104-m1-acceptance.md`](./cip0086-cip0103-cip0104-m1-acceptance.md);
those CIPs are settlement-interoperability criteria, not standalone CIP-56-token
deliverables.

> **Google Docs import:** paste this file into Docs with *Edit → Paste* after
> *File → Open* of the `.md`, or use a Markdown add-on. Headings (H1/H2/H3) drive
> the Docs outline pane; the tables below import cleanly; apply a monospace
> paragraph style to the fenced code blocks after import.

> **Source-grounding tags used throughout:**
> `[IMPLEMENTED]` real code in `canton-contracts` (the M1 library base) ·
> `[EVIDENCE]` real code in `canton-token-template` (migration/evidence source,
> *not* the M1 surface) · `[UPSTREAM]` Splice reference, not vendored here ·
> `[FUTURE]` not built in M1 scope.

---

## 1. Introduction / Executive Summary

The OpenZeppelin Canton M1 reference implementation targets the **Canton Network
Token Standard V2 (CIP-0112)** settlement surface, replacing the superseded
CIP-0056 token foundation (root `PLAN.md` Decision Log S1). The goal of M1 is
not a production DeFi application but a **scope-locked settlement primitive**
that can later enter audit-readiness review, plus a deep settlement exemplar
that proves the library against a real consumer. CIP-86 / CIP-103 / CIP-104 are
re-scoped to interoperate with this settlement surface.

What exists today, in code:

- `canton-contracts` — an experimental settlement scaffold
  (`experiments/cip112-settlement`) modeling the V2 allocation/settlement
  lifecycle with optional D1 (compliance) and D2 (seizure) extension points.
- `canton-token-template` — prior CIP-0112 evidence: a `HoldingV1`/`HoldingV2`
  interface holding with an embedded `Lock`, a `SimpleEventLog` implementing the
  V2 `EventLog`, a capability-based admin layer, and in-flight seizure of locked
  holdings.

What this document is: an honest architecture spec that (a) puts the decisions
needing input at the top, (b) records the intentional scope-tightening choices —
including the **2026-06-17 seizure realignment** — and (c) lists the planned
extension points in the order we expect to grow them. Code samples are tagged by
exactly which repo implements them so nothing reads as built when it isn't.

The grant's larger framing (production-ready blueprints, audited library,
ecosystem-wide adoption) is **directional context**, not a claim about the
current state of this code.

---

## 2. Promotion Boundary Status And Open Questions

Ordered by **level of input required** — most cross-cutting / highest-effort
first. These are the items where external or architectural input changes the
build; the seizure and authority model are **no longer** in this list (see §4,
adopted). The Splice / Token Standard V2 source and import posture are now
bounded by the promotion ADR, but the ADR is not a stability claim.

| # | Status | Boundary / question | Follow-up |
| --- | --- | --- | --- |
| B1 | Bounded by ADR | **Splice branch/commit of record.** Use `hyperledger-labs/splice` branch `token-standard-v2-upcoming` at `1e34121b2b369c5dde357c098e2aaeb65250e736` as the source evidence pin. The older `canton-network/splice @ token-standard-v2-daml-preview` (`b91de5d4…`) remains historical local evidence only. | Re-check if upstream cuts a release tag or changes the intended Token Standard V2 source branch. |
| B2 | Evidence-boundary documented; import still blocked | **Token Standard V2 DAR / import & license boundary.** Do not vendor or import Splice DARs. The import-gate note records current upstream source, package IDs from `daml/dars.lock`, Splice build wiring, the DevNet prerelease bundle, and Apache-2.0 posture; local stand-ins remain experimental until release-source confirmation, accepted DAR or reproducible-build artifacts, DAR checksums, license/NOTICE handling, DPM wiring, and public API review exist. | [`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md). |
| B3 | Bounded by ADR | **Public API candidate.** The ADR defines the promotable candidate surface, experimental-only scaffold surface, SCU contract, direct-vs-batch semantics, third-party custodian credit model, and post-deadline seizure-window policy. | Later stability ADR/review before any public API claim. |
| B4 | Bounded by acceptance note | **CIP-0086 / CIP-0103 / CIP-0104 M1 criteria.** These CIPs are accepted for M1 only as interoperability evidence against the CIP-112 settlement surface. They do not add production middleware, wallet-provider, Scan/SV reward, custody, KYC, sanctions, hosted-service, or standalone CIP-56-token scope. | Use the acceptance note for downstream docs and review packets. |
| Q1 | Open | **D1 attestation shape.** D1 is decided no-cache / fail-closed / node-side. Open: does the contract stay oblivious to the result (off-ledger gate), or verify a signed node attestation at exercise time? Shapes the audit story. | OZ architecture. |
| Q2 | Open after DAR gate | **EventLog adoption implementation.** The ADR treats Token Standard V2 `EventLog_HoldingsChange` as the promoted reporting route, but implementation still waits on the transfer-events DAR boundary. | OZ architecture after DAR/import evidence. |
| Q3 | Open | **Legacy package naming.** Public docs now use `canton-contracts`, but M0 package/DAR names still contain `oz-daml-contracts`. Renaming packages is a separate compatibility decision. | OZ architecture. |

---

## 3. Architecture & Specification

### 3.1 Topology & Splice context `[UPSTREAM]`

The RI is a layered dApp on the Canton Network using Hyperledger Splice for
decentralized synchronizer operation, with CIP-0112 tokens deployed alongside
the Amulet utility token. Sub-transaction privacy is enforced by Canton's
projection model: a party sees only the projection of choices it authorizes.
**None of the Splice/Amulet/SV infrastructure is vendored in this workspace** —
it is the deployment substrate, referenced for context.

### 3.2 The V1 → V2 privacy fix `[UPSTREAM]` / `[EVIDENCE]`

V1 batched settlement appended all trading parties as `extraSettlementAuthorizers`
on a single `SettleBatch`, which — under Canton projection — leaked every party's
legs to every other party. V2 drops `extraSettlementAuthorizers` /
`extraReceiptAuthorizers` and decouples receipt allocations from the central
atomic settlement so each trader sees only its own receipt projection.

Our scaffold reflects the decoupled posture: the direct `Allocation_Settle`
choice does **not** accept caller-asserted peer sides — peer authorization must
come from *fetched* peer allocations or prior receipts, and atomic
multi-allocation settlement is a property of the batch entrypoint.

```
-- [IMPLEMENTED] canton-contracts/experiments/cip112-settlement/.../Cip112.daml
-- TransferLegSides with explicit polarity (replaces V1 TransferLegs)
data TransferSide = SenderSide | ReceiverSide
data TransferLegSide = TransferLegSide with
    transferLegId : Text
    side : TransferSide
    otherside : Account
    amount : Decimal
    instrumentId : Text
    meta : Metadata
```

### 3.3 Core primitives & data model

`[IMPLEMENTED]` = `Cip112.daml`; `[EVIDENCE]` = `canton-token-template`;
`[UPSTREAM]` = Splice V2 API.

| Component | Field | Status | Where |
| --- | --- | --- | --- |
| `Holding` | `instrumentId : InstrumentId {admin, id}` | `[EVIDENCE]` + `[IMPLEMENTED]` | `Holding.daml`; `Cip112.daml` `InstrumentId` |
| `Holding` | `lock : Optional Lock` (replaces standalone `LockedAsset`) | `[EVIDENCE]` | `Holding.daml` `SimpleHolding` / `LockedSimpleHolding` |
| all V2 ifaces | `meta : Metadata (TextMap Text)` | `[IMPLEMENTED]` | `Cip112.daml` `Metadata` |
| `TransferInstruction` | `pendingActions : Map Party Text` | `[UPSTREAM]` | not modeled locally |
| `TransferInstruction` | `inputHoldingCids : [ContractId Holding]` (deliberate contention) | `[EVIDENCE]` | `TransferInstruction.daml` |
| `Allocation` | `d1ComplianceHook` / `d2SeizureHook` extension points | `[IMPLEMENTED]` | `Cip112.daml` |
| `EventLog` | `EventLog_HoldingsChange` non-consuming event | `[EVIDENCE]` | `Reporting.daml` `SimpleEventLog` |
| `MergeDelegation` | UTXO-merge delegation | `[FUTURE]` | not present in this workspace |

### 3.4 Holding + Lock `[EVIDENCE]`

The V2 single-state holding (lock embedded, no separate `LockedAsset`) and the
in-flight seizure of locked funds are already implemented in the evidence repo:

```
-- [EVIDENCE] canton-token-template/simple-token/daml/SimpleToken/Holding.daml
template LockedSimpleHolding with
    admin : Party; owner : Party; instrumentId : InstrumentId
    amount : Decimal; lock : Lock; extraObservers : [Party]; meta : Metadata
  where
    signatory admin, owner, lock.holders
    -- Forced clawback of IN-FLIGHT funds, gated by a Burner capability:
    choice LockedSimpleHolding_ForcedBurn : ()
      with burner : Party; burnerCap : ContractId RoleCapability
      controller burner
      do _ <- requireRole burner Burner admin (Some instrumentId) burnerCap
         pure ()
```

### 3.5 Compliance (D1) extension `[IMPLEMENTED]`

```
-- [IMPLEMENTED] Cip112.daml — optional, fail-closed reference hook.
-- NOTE: this is a contract-side guard, NOT D1's node-side placement.
data D1ComplianceHook = D1ComplianceHook with
    hookRef : Text
    requiresPerSettlementReference : Bool

requireD1Reference : Optional D1ComplianceHook -> Optional Text -> Update ()
requireD1Reference hook ref = case hook of
  None -> pure ()
  Some h -> if h.requiresPerSettlementReference
              then assertMsg eD1ComplianceReferenceMissing (ref /= None)
              else pure ()
```

### 3.6 Event-driven wallet integration `[EVIDENCE]` / `[UPSTREAM]`

`EventLog_HoldingsChange` is a side-effect-free, non-consuming choice emitted on
any holding mutation; wallets subscribe to it instead of reverse-engineering
factory interactions (which would leak the sender's UTXO graph to the receiver).
Implemented as evidence via `SimpleEventLog`:

```
-- [EVIDENCE] canton-token-template/simple-token/daml/SimpleToken/Reporting.daml
interface instance TransferEventsV2.EventLog for SimpleEventLog where
  view = TransferEventsV2.EventLogView with ...
  -- emits EventLog_HoldingsChange and records a standalone entry
```

Upstream, this lives in `splice-api-token-transfer-events-v2`; the promotion ADR
treats it as the promoted reporting route, with implementation still gated by
the transfer-events DAR boundary (**Q2**).

---

## 4. Intentional Design Choices (scope kept tight & clean)

Each choice below was made to keep the M1 surface small, auditable, and
upgrade-safe. Where a choice records a decision, it is stated as decided.

1. **Seizure = lock in-flight + sweep to a preset admin-set destination, under
   single-admin capability authority (adopted 2026-06-17, Amar).**
   In-flight locked holdings are seized and routed to a destination address
   **preset by the registry admin**, under single-admin (`Burner`-capability)
   authority — not burned, not returned to sender, not gated on two-person
   control. This reuses the implemented capability model
   (`RoleCapability` / `Burner`, admin-signed — `[EVIDENCE]`
   `Admin/Capability.daml`) and the implemented in-flight clawback path
   (`LockedSimpleHolding_ForcedBurn` — `[EVIDENCE]`), changing the terminal
   action from *destroy* to *route-to-preset-destination*. The scaffold carries
   the implemented attachment points: `D2SeizureHook { custodianDestination :
   Account, … }`, `BurnerCapability`,
   `Allocation_MarkD2InFlightSeizure`, and
   `Allocation_SweepD2InFlightSeizure` — `[IMPLEMENTED]` `Cip112.daml`. In the
   toy witness, a true third-party destination co-authorizes receipt of the
   replacement holding because `ToyHolding` account parties are signatories;
   that co-authorization is a receipt constraint, not seizure approval
   authority.
   *Realignment note (for auditors, not a blocker):* this supersedes the earlier
   2026-06-15 multi-party D2 lean (custodian destination + two-person control,
   in-flight deferred). It is an internal M1 development decision; production
   deployment by a specific issuer still carries the standard re-validation
   against that issuer's compliance obligations.

2. **In-flight handling is concrete, not deferred.** Normal settlement rejects
   an active D2 marker and the adopted resolution path is lock-and-sweep (choice
   1). This un-defers the S1 in-flight question by deciding it and implementing
   the dedicated sweep choice.

3. **Single admin authority model.** Authority is capability-based and
   admin-rooted (`RoleCapability`, admin-signed, possession-is-authorization),
   not a multi-hosted-party topology or an N-of-M on-ledger multi-sig. This
   collapses the open D4 fork to the implemented single-admin capability path
   for M1.

4. **Toy holdings as test witnesses only.** `ToyHolding` exists to make locking
   testable without shipping a public token; real assets implement the Token
   Standard V2 holding interface once the promotion ADR's DAR/import gates land.

5. **Batch-only atomicity.** Atomic multi-allocation settlement is a property of
   `SettlementFactory_SettleBatch`; the direct `Allocation_Settle` proves
   authorization existence via fetched peers, not direct-path co-settlement.
   Keeps the atomic surface in one place.

6. **Optional, additive extension hooks.** D1/D2 hooks are `Optional` appended
   fields; typed behavior is added via new choices, never by mutating a baseline
   choice argument (SCU pattern). Keeps the surface upgrade-safe.

7. **Single-domain v1 (D3 deferred).** Cross-domain identity is layered later
   via additive SCU upgrade; M1 does not carry cross-domain machinery.

---

## 5. Acknowledged Risks / Planned Extension Points

Ordered by **where we expect future extension to occur first**, each motivated
by stakeholder confirmation that the extension is generally useful on top of the
M1 base. These are not defects; they are the deliberate seams.

1. **Third-party custodian credit model.** The experiment can route to a true
   third-party `Account` only when that destination account party co-authorizes
   receipt of the replacement `ToyHolding`, because the toy holding makes
   account parties signatory. The promotion ADR separates D2 seizure authority
   from destination credit authorization: regular third-party credit needs a
   pre-onboarded account arrangement, co-signed receipt transaction, or later
   propose/accept flow. *Expected extension:* implement that selected model
   against real Token Standard V2 account authorization after the DAR/import
   gate. *Trigger:* accepted import boundary or a custodian destination that
   cannot use the co-authorized/admin-managed account model.

2. **Seizure destination mutability & authority escalation.** M1 ships
   single-admin, preset-destination seizure (§4.1). *Expected extension:* if
   institutions (DTCC / large banks) require it, escalate to multi-sig or
   multi-party authority for the seizure path and/or a mutable, per-order
   destination with a lawful-process attestation field. *Trigger:* stakeholder
   confirmation that single-admin seizure is unacceptable for their audit.

3. **Seizure window after settlement deadline.** The experiment fails the D2
   sweep path after `settlementDeadline`; committed allocations can be withdrawn
   only after that same deadline. The promotion ADR keeps that terminal deadline
   as the M1 promotable policy. *Expected extension:* if lawful seizure must
   remain available after the deadline, add an explicit seizure-window field and
   lawful-process evidence model through a later ADR. *Trigger:*
   legal/compliance review or exemplar threat model.

4. **D1 node-side attestation typing.** M1 carries a contract-side reference
   guard only. *Expected extension:* add a typed signed-node-attestation field /
   choice once the node-side attestation shape (Q1) is decided. *Trigger:* audit
   story requires on-ledger proof of the node check.

5. **Real Token Standard V2 interfaces.** M1 uses local stand-ins / evidence-repo
   interfaces. *Expected extension:* implement real `HoldingV2`,
   `AllocationV2`, `AllocationRequestV2`, `AllocationInstructionV2`,
   `TransferInstructionV2`, and `EventLog` against upstream Splice API packages
   only after the promotion ADR's DAR/checksum/license/DPM gates land.
   *Trigger:* DAR/import boundary accepted.

6. **EventLog adoption in the library surface.** Carried as evidence today.
   *Expected extension:* promote `EventLog_HoldingsChange` into the M1 primitive
   for wallet discoverability. *Trigger:* Q2 implementation after the
   transfer-events DAR boundary is accepted.

7. **UTXO defragmentation (`MergeDelegation`).** Not present. *Expected
   extension:* add delegated background merge once fragmentation is a measured
   problem under a real consumer. *Trigger:* exemplar shows UTXO-count pressure.

8. **Mixed-version (V1/V2) settlement.** Not built. *Expected extension:* add a
   bridging path if live V1 assets must settle against V2 during migration.
   *Trigger:* an actual V1 asset in scope.

9. **Cross-domain identity (D3).** Deferred. *Expected extension:* ONCHAINID /
   ERC-735-style typed claim via additive SCU upgrade. *Trigger:* multi-subnet
   requirement.

10. **Modular transfer hooks (DeFi composability).** The generalized
   `TransferInstruction_Accept` + `pendingActions` map is the seam for
   Uniswap-Hooks-style pre-accept logic (e.g. credential-gated lending).
   *Expected extension:* M2/M3 RIs. *Trigger:* RI design begins.

---

## 6. Conclusion → Next Steps & Future Planning

M1 is building toward a small CIP-0112 settlement primitive with explicit,
decided semantics for the two controls that matter most to regulated
settlement: a fail-closed compliance seam (D1) and a concrete in-flight seizure
policy (§4.1, lock-and-sweep to a preset admin destination under single-admin
authority). By deciding the seizure and authority model now — grounded in the
already-implemented capability and locked-holding clawback patterns — M1 removes
the largest source of churn for downstream work, rather than leaving it open.

**Immediate next steps:**

1. Use the promotion ADR boundary for Splice source evidence and public API
   candidate scope, plus the import-gate note for current package/release
   evidence; do not import Splice DARs until the published-DAR or
   reproducible-build, DAR-checksum, license/NOTICE, DPM, release-source, and
   public API gates land.
2. Use the CIP-0086 / CIP-0103 / CIP-0104 acceptance note when describing
   middleware/indexer, wallet/dApp, or traffic-reward touch points; do not
   describe those surfaces as standalone M1 deliverables.
3. Keep D1's node-side attestation shape open until Q1 is resolved; the current
   hook remains only a fail-closed reference seam.
4. After the import gates land, implement the settlement facade per the
   promotion ADR and then build the deep settlement exemplar (Phase 3), without
   claiming stability until a later stability review accepts it.

**Foundation provided.** With settlement, compliance, seizure, and authority
decided and grounded in code, M1 becomes the reusable skeleton the M2 DEX, M3
lending, and M4 cross-chain stablecoin RIs inherit — each adding its modular
transfer hooks (§5.8) on top of the intended privacy-preserving settlement base
rather than re-litigating the core controls.

---

## Appendix: Source Index

- `[IMPLEMENTED]` `canton-contracts/experiments/cip112-settlement/daml/OpenZeppelin/Experimental/Settlement/Cip112.daml`
  — `TransferSide`/`TransferLegSide`, `D1ComplianceHook`, `D2SeizureHook`,
  `BurnerCapability`, `Allocation_MarkD2InFlightSeizure`,
  `Allocation_SweepD2InFlightSeizure`, `requireNoActiveD2InFlight`,
  `SettlementFactory_SettleBatch`.
- `[EVIDENCE]` `canton-token-template/simple-token/daml/SimpleToken/`
  — `Holding.daml` (`LockedSimpleHolding`, `LockedSimpleHolding_ForcedBurn`,
  `HoldingV1`/`HoldingV2` instances, embedded `Lock`), `Reporting.daml`
  (`SimpleEventLog`, `EventLog_HoldingsChange`), `TransferInstruction.daml`,
  `Allocation.daml`, `Admin/Capability.daml` (`RoleCapability`), `Admin/Roles.daml`.
- `[EVIDENCE]` `canton-token-template/docs/` — `CIP-0112-EXTENSION-PLAN.md`,
  `SCOPE.md`, `ADMIN-LAYER-PLAN.md`, `AUDIT.md`.
- `[UPSTREAM]` Splice V2 API — source evidence pin per
  [`cip0112-public-api-promotion-boundary.md`](./cip0112-public-api-promotion-boundary.md):
  `hyperledger-labs/splice` branch `token-standard-v2-upcoming` commit
  `1e34121b2b369c5dde357c098e2aaeb65250e736`. The older
  `canton-network/splice @ token-standard-v2-daml-preview b91de5d4…` reference
  remains historical local evidence only.
- Decisions / plan of record: root `PLAN.md` (Decision Log, gate table),
  `docs/decisions/D4_MULTISIG.md`,
  `canton-contracts/docs/experiments/cip112-settlement.md`,
  `canton-contracts/docs/experiments/multi-hosted-node-check.md`.
