# Identity Hook Shape Experiment

Status: experimental, non-public, and outside the committed M1 library surface.

This note records experiment 2 from root `PLAN.md` -> "Experimentation
Priorities": two candidate forward-compatible identity hook shapes for the D3
one-pager. Root `PLAN.md` records D3 as single-domain v1 with cross-domain
identity deferred, while preserving a possible later ONCHAINID / ERC-734 /
ERC-735 / trusted-issuer-registry layer. D1 remains no-cache, fail-closed, and
node-side; this identity spike does not replace the transfer-compliance
decision. D2 routes seizure to a deployer-configurable custodian destination,
but this spike does not implement seizure. D4 remains open; the toy registry
admin remains a plain Daml party and does not choose between on-ledger multi-sig
and Canton-topology multi-hosted party authority.

## Candidate A: Opaque Attestation Argument

Package: `experiments/identity-hook-shape-a`

Shape A models the smallest hook: `ToyHolding_Transfer` accepts an
`OpaqueIdentityAttestation` value and checks only that its `envelope` is
non-empty. The contract does not inspect subject, issuer, freshness, registry
membership, proof type, or transcript fields.

Audit surface:

- Smallest Daml surface: one attestation record, toy registry, toy holding, and
  a non-empty envelope check.
- The audited behavior is limited to feature-flag enforcement, positive amount
  minting, self-transfer rejection, and "some opaque material was supplied."
- Identity correctness, issuer trust, and freshness move almost entirely to the
  node/operator layer.

Failure modes:

- Stale envelopes are accepted on-ledger.
- Wrong-subject envelopes are accepted on-ledger.
- Wrong-issuer or untrusted-issuer envelopes are accepted on-ledger.
- Replay and uniqueness are not modeled. The envelope is a value argument, not a
  signed or archived Daml contract.
- The shape is viable only if the D3 one-pager says the Daml library remains
  deliberately oblivious to identity-proof semantics.

Forward-compatibility:

- Easy to keep stable because the public-looking Daml type is almost empty.
- Weak bridge to an ONCHAINID-shaped future: later typed claims would need a new
  hook shape or an opaque envelope convention that auditors cannot inspect in
  Daml.
- Best fit if v1 treats identity as participant/node precondition rather than a
  contract-verifiable field set.

## Candidate B: Typed KYC_VALIDATED Claim

Package: `experiments/identity-hook-shape-b`

Shape B models a typed `KYC_VALIDATED` claim and a minimal trusted-issuer
registry snapshot. `TrustedIssuerRegistry_Mint` mints a toy holding with a
snapshot of trusted issuers. `ToyHolding_Transfer` is jointly controlled by the
current owner and the new owner, fetches the new owner's `KycClaim`, and checks:

- the Daml signer matches the claim's declared issuer;
- the declared issuer is in the holding's trusted-issuer snapshot;
- the claim subject is the new owner;
- the claim kind is `KYC_VALIDATED`;
- ledger time is not later than `validUntil`.

Audit surface:

- Larger Daml surface than Shape A: typed claim kind, signer/declared-issuer
  binding, trusted-issuer membership, recipient subject binding, and expiry.
- The recipient must co-authorize the toy transfer so the transfer can fetch the
  recipient's private KYC claim. This is an important ergonomic and privacy
  consequence for the D3 one-pager.
- The registry is a snapshot only. Mutable trust lists, revocation registries,
  issuer rotation, and cross-domain trust frameworks are intentionally out of
  scope.

Failure modes:

- Stale, wrong-subject, signer/declared-issuer mismatch, untrusted issuer, and
  wrong claim kind fail on-ledger.
- A compromised trusted issuer can still create valid-looking claims.
- A stale trusted-issuer snapshot can keep accepting an issuer that the admin
  would remove in a production registry.
- Claims are reusable until expiry. This matches credential semantics but does
  not provide one-transfer replay containment.
- `claimId` is non-enforcing metadata. It is useful for fixture readability but
  does not provide uniqueness, lookup, revocation, or replay protection.
- Recipient co-authorization changes the transfer UX relative to a purely
  sender-controlled token transfer.

Forward-compatibility:

- Better fit for the ONCHAINID / ERC-734 / ERC-735 story because the Daml hook
  already names a typed claim, a subject, an issuer, and a trusted issuer set.
- Gives the D3 one-pager concrete audit language: "the v1 hook can be typed
  around a KYC claim and a trusted issuer registry without implementing
  cross-domain identity."
- Still single-domain. There is no bridge, oracle, cross-domain claim sync,
  Chainlink CCID integration, or production identity resolver.

## D3 One-Pager Implications

Candidate A supports a conservative one-pager: v1 is single-domain and identity
checks remain outside the Daml contract. It minimizes contract surface but gives
Amar and Pepe little on-ledger evidence that the later ONCHAINID-style layer can
attach without a breaking hook change.

Candidate B supports a more concrete forward-compatibility statement: v1 can
reserve a typed identity hook that expects a `KYC_VALIDATED` claim from a
trusted issuer registry, while leaving actual cross-domain identity deferred.
The cost is a larger audit surface and a real transfer-flow decision: recipient
co-authorization is needed if the recipient's private claim is fetched by the
contract.

The one-pager should not cite this experiment as D3 closure. It should cite it
as feasibility evidence and keep the accepted D3 boundary from root `PLAN.md`:
single-domain v1, cross-domain identity deferred, forward-compatible design as
an open feasibility question for Amar and Pepe.

## Recommendation

Recommend Candidate B as the D3 one-pager's forward-compatible shape, provided
OZ architecture accepts recipient co-authorization for typed identity-gated
transfers and accepts that the registry semantics stay experimental until D3 is
reopened. Candidate B gives auditors and reviewers a concrete minimum field set
for stale, wrong-subject, wrong-issuer, and untrusted-issuer risks.

Flip to Candidate A if the intended M1 transfer hook must remain completely
oblivious to identity semantics, or if recipient co-authorization is rejected as
too invasive for the v1 token UX. In that case, the D3 one-pager should avoid
claiming typed ONCHAINID-style compatibility and should instead say that a later
typed identity layer may require a hook revision.

Do not commit either shape to public M1 surface until:

- D3 forward-compatibility is reviewed by Amar and Pepe;
- D1 attestation/no-caching clarifications are separated from identity-claim
  freshness language;
- D2 implementation clarifications are resolved for final seizure wording, if
  identity gating is later coupled to seizure workflows;
- D4 has an owner and reviews registry-admin and issuer-control implications.

## Appendix: Discarded Sub-Paths

- Cryptographic signature verification inside Daml: discarded. The experiment
  uses Daml signatory authority as the signature model and avoids production
  crypto-library or key-management commitments.
- Production ONCHAINID resolver: discarded. The package names ONCHAINID-shaped
  fields only as future compatibility pressure, not as an implementation.
- Mutable trusted-issuer registry: discarded. Shape B snapshots trusted issuers
  into the toy holding so the experiment stays focused on hook shape, not
  registry update and revocation semantics.
- Cross-domain claim transport: discarded. D3 is deferred, and this experiment
  remains single-domain.
- Archiving KYC claims on transfer: discarded. A KYC claim behaves like a
  reusable credential until expiry, unlike a one-use compliance attestation.
- Shared identity toy token package: discarded to keep each candidate package
  standalone and independently buildable.

## Appendix: Teardown Checklist

Because the shared `test` package data-depends on both identity experiment DARs
and `multi-package.yaml` includes both experiment packages, removing the spike
later requires reverting both package entries and the two `test/daml.yaml`
data-dependencies. Otherwise the reusable library tests will keep expecting the
experimental DARs.
