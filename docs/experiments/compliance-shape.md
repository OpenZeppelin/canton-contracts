# Compliance-Check Shape Experiment

Status: experimental, non-public, and outside the committed M1 library surface.

This note records experiment 1 from root `PLAN.md` -> "Experimentation
Priorities": two candidate transfer-restriction hook shapes for the D1
implementation clarification in root `PLAN.md` -> "June Decision Gate".

Root `PLAN.md` records D1 as no-cache, fail-closed, node-side compliance
checking. The remaining implementation question is whether the Daml contract is
oblivious to the check outcome or verifies a node attestation at exercise time.
D2 routes seizure to a deployer-configurable custodian destination in v1, but
the toy seizure path here is composition-only. D4 remains open; this experiment
does not choose between on-ledger multi-sig and Canton-topology multi-hosted
party authority.

## Candidate A: Off-Ledger Result Token

Package: `experiments/compliance-shape-a`

Shape A models a provider-signed `OffLedgerComplianceResult` token with an
allow/deny decision. The toy holding transfer consumes the token and checks only
`decision == Allow`. It deliberately does not verify subject, signer, expiry, or
an off-ledger transcript.

Audit surface:

- Smallest Daml surface: result token, toy registry, toy holding, and a single
  allow/deny gate.
- The main audited behavior is that deny blocks transfer and consumed tokens
  cannot be replayed exactly.
- Most compliance correctness moves out of Daml and into node/operator process.

Failure modes:

- Wrong-context allow token is accepted on-ledger.
- Stale token is accepted on-ledger.
- A compromised or over-permissive provider can issue reusable-looking allow
  material; the toy flow consumes one token but cannot detect duplicate
  off-ledger issuance.
- `opaqueResultId` is descriptive only. It is not read on-ledger, and a second
  provider-signed result with the same id is still a distinct valid contract if
  it carries `Allow`.
- Issuer-system outage still fails closed only if the off-ledger node layer
  refuses to create or submit an allow token.

Mint/burn composition:

- `ToyRegistry_Mint` creates a holding under an explicit experimental feature
  flag.
- `ToyHolding_Burn` is owner-controlled and consumes the holding.
- The compliance hook is transfer-only; mint and burn are not compliance
  checks in this toy package.

Seizure-path composition:

- `ToyRegistry` stores a `seizureDestination`, and `ToyHolding_Seize` moves the
  holding to that destination.
- This matches the D2 direction at a high level, but it is not a D2
  implementation. Lawful-process fields, two-person control, mutability of the
  destination, and in-flight seizure behavior remain out of scope.

## Candidate B: Node Attestation

Package: `experiments/compliance-shape-b`

Shape B models a node-signed `NodeAttestation` contract. The toy transfer
computes an opaque transfer subject from issuer, sender, recipient, and amount,
then verifies the attestation's minimum field set at exercise time:

- `signer` equals the expected issuer node.
- the Daml signatory `node` equals `signer`;
- `subjectParty` equals the current owner;
- `subject` equals the computed toy transfer subject;
- `decision == Allow`;
- ledger time is not later than `validUntil`.

Audit surface:

- Larger Daml surface than Shape A: transfer subject construction, signer
  binding, expiry, subject party binding, and negative tests for expiry and
  wrong subject.
- The contract now carries part of the compliance evidence story, so auditors
  can inspect which minimum fields were enforced.
- The node/operator process still owns the actual compliance decision and key
  management.

Failure modes:

- Wrong subject, wrong signer, deny, or expired attestation fail on-ledger.
- A compromised issuer-node signer can still produce valid attestations.
- The subject string must remain stable and precisely specified before any
  public surface exists.
- `nonce` is descriptive only. It is not checked for uniqueness on-ledger, and a
  second node-signed attestation with the same nonce is still a distinct valid
  contract if the checked fields pass.
- Very short validity windows reduce replay risk but increase operational
  coupling to node availability and clock behavior.

Mint/burn composition:

- The toy registry records both issuer and expected issuer node.
- Mint and burn stay independent of the compliance hook.
- The attestation shape gives mint/burn documentation a clearer separation:
  issuer authority controls supply actions; issuer-node authority attests
  transfer checks.

Seizure-path composition:

- Seizure remains issuer-controlled and routes to the configured destination.
- The transfer attestation does not authorize seizure and does not replace the
  D2 two-person-control question.
- If the final D2 path needs seizure-time compliance evidence, it should be a
  distinct attestation subject, not reuse the transfer subject.

## Comparison

Shape A is cheaper to audit in Daml but pushes the most important correctness
properties off-ledger. It is a good fit only if the accepted D1 interpretation is
that the participant/node layer enforces compliance before a transfer command
can reach the contract, and that M1 audit scope should not include attestation
field verification.

Shape B creates a clearer on-ledger audit trail and catches the obvious stale,
wrong-subject, wrong-signer, and deny cases. It costs more contract surface and
requires the D1 clarification to allow a short-lived per-transfer attestation
without treating that as prohibited caching. It also requires a stable subject
schema and signer rotation story.

Both candidates compose with the same toy mint, burn, and seizure shape. Neither
candidate implements production KYC, sanctions, validator services, custody,
bridge, relayer, institution-specific logic, or public token behavior.

## D4 Interaction

D4 is still open per root `PLAN.md` -> "June Decision Gate" and
`docs/decisions/D4_MULTISIG.md`. This experiment keeps issuer authority as a
plain Daml party and does not choose between:

- Option A: on-ledger multi-sig contract; or
- Option B: Canton-topology multi-hosted party.

Shape A has the least direct D4 coupling because the contract mostly sees an
opaque allow/deny token. The D4 question moves to who can operate the off-ledger
provider or submit the checked transfer.

Shape B makes the D4 interaction sharper. The final authority model must say
who controls the `issuerNode` signer, how signer rotation is approved, and which
participant is authoritative when an issuer or admin party is multi-hosted.
Those are useful review questions, but they are not resolved here.

## Recommendation

Recommend Shape B as the provisional M1 hook direction if OZ architecture wants
on-ledger evidence that each transfer carried a node attestation and if the D1
"no caching" clarification permits a per-transfer, short-lived attestation.
Shape B gives auditors a concrete field set to inspect and narrows stale or
wrong-context transfer risk.

This lean does not resolve D1's decided node-vs-contract boundary. If "the node
applies the compliance check, not the contract itself" means no Daml-level
attestation verification, Shape B is incompatible and Shape A is the only
candidate left in this experiment.

Flip to Shape A if architecture confirms that D1 means the contract must remain
oblivious and that compliance enforcement lives entirely in participant/node
infrastructure. In that case, M1 should avoid a partial attestation API and
document the node/operator evidence outside the Daml library audit surface.

Do not commit either shape to public M1 surface until:

- the D1 attestation/no-caching clarification is accepted;
- the D4 authority owner is assigned and reviews signer/control implications;
- D2 implementation clarifications are resolved for final seizure wording.

## Appendix: Discarded Sub-Paths

- Cryptographic signature verification inside Daml: discarded for this spike.
  The experiment uses Daml signatory authority as the signature model and avoids
  production key-management or crypto-library commitments.
- Shared common toy token package: discarded to keep each candidate package
  standalone and independently buildable.
- Non-consuming compliance tokens: discarded because exact-token replay would
  distract from the intended comparison.
- Public transfer-restriction interface: discarded because the experiment must
  remain feature-flagged and outside the committed M1 surface.
- Full seizure authority model: discarded because D2 and D4 still have
  implementation clarifications; the seizure path here is composition evidence
  only.

## Appendix: Teardown Checklist

Because the shared `test` package data-depends on both experiment DARs and
`multi-package.yaml` includes both experiment packages, removing the spike later
requires reverting both package entries and the two `test/daml.yaml`
data-dependencies. Otherwise the reusable library tests will keep expecting the
experimental DARs.
