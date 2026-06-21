# Decision memo: source of record for the Splice Token Standard V2 packages

Status: **Decided 2026-06-21 — Option D (defer import for M1; keep local
stand-ins).** This memo framed the one remaining blocker on the CIP-0112 import
gate; the decision is recorded at the bottom.

Date: 2026-06-21

Phase: Phase 2, Scope-Locked Library Foundation

Companion evidence:
[`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md),
[`cip0112-license-notice-packaging-plan.md`](./cip0112-license-notice-packaging-plan.md),
[`cip0112-dpm-wiring-spec.md`](./cip0112-dpm-wiring-spec.md).

## The decision

Which upstream source do we treat as the **authoritative origin** for the seven
Token Standard V2 API DARs that the M1 settlement facade will data-depend on
(`splice-api-token-metadata-v1` + the six `*-v2` packages)?

## Why it is the binding blocker

Everything else on the import gate is ready: DAR SHA-256 checksums, package
identity confirmed from the binaries, the license/NOTICE packaging plan, and the
drafted DPM wiring spec. They are all parameterized on "the accepted source." The
source choice determines which checksums we pin, the integrity/reproducibility
story, the license provenance, and whether the facade rests on a stable
dependency. Nothing more is learnable from evidence alone — this needs a call.

## Options

| Option | What it is | Available now? | Integrity story | Verdict |
| --- | --- | --- | --- | --- |
| **A. Moving branch** | Pin `token-standard-v2-upcoming` @ `1e34121…` and consume its checked-in DARs | Yes | We have DAR SHA-256 + package IDs at this commit | ⚠️ Risky — force-pushable branch, "upcoming"/pre-release, not locally reproducible (built against a 3.3.0-snapshot stdlib in Splice's pinned env) |
| **B. Tagged/published V2 release** | Wait for the Splice source repo to cut a release with individual V2 DARs | **No** | Best — citeable tag + (likely) published checksums | ✅ Cleanest *when it exists*; the new `0.6.9` tag does **not** carry the six `*-v2` packages, and the repo has no GitHub Releases |
| **C. DevNet bundle** | Extract DARs from `digital-asset/decentralized-canton-sync` `0.6.9-snapshot.20260615…` | Yes (pre-release) | Aggregate tarballs with SHA-256 digests; needs an accepted bundle→DAR extraction + package-ID verification | ⚠️ Usable but DevNet-only by upstream's own label; not a package-by-package contract |
| **D. Defer import; keep local stand-ins** | M1 facade stays on local stand-in types | Yes | N/A — no upstream artifact consumed | ✅ Matches M1's experimental/non-public posture; scaffold already passes 60/60 |

## Recommendation

**Adopt D for M1 now, with B as the import trigger; fall back to C only if a
specific consumer forces it. Avoid A.**

- **D now:** M1 is explicitly scope-locked, non-public, and experimental, and the
  scaffold already validates (60/60) against local stand-ins. Nothing about M1
  acceptance requires consuming upstream DARs today.
- **B as the trigger:** when upstream cuts a tagged/published V2 release with
  individual DARs, import in one slice using the ready DPM-wiring + license plans
  and re-record checksums for that source.
- **C only if forced:** if an exemplar genuinely needs real V2 interfaces before
  a stable release, take the DevNet bundle via a documented extraction path that
  verifies each DAR's SHA-256 and package ID, and carry the DevNet-only caveat.
- **Not A:** do not build a public-facing facade on a force-pushable branch whose
  artifacts we cannot reproduce locally; that imports instability into our surface.

## What is needed to decide

- **Upstream signal:** is `token-standard-v2-upcoming` intended to be tagged /
  released as individual DARs, and on what timeline? Is the DevNet bundle the
  intended consumer artifact or a stopgap?
- **OZ architecture:** does any M1 exemplar need real V2 interfaces *before* a
  stable upstream release exists (which would force option C)?
- **Mapping:** how does DevNet version `0.6.9-snapshot.20260615.3096.0.v27548d88`
  map back to the source commit and the V2 package IDs?

Surface these in the plan / PR and on the upstream channel; no single sign-off is
required to proceed — once the answer lands, record it as the decision below.

## Once decided (apply in one slice)

1. Pin the accepted source; re-record final DAR checksums + package IDs for it.
2. Apply the license/NOTICE packaging plan.
3. Apply the DPM wiring spec; run `dpm build --all` + `dpm test`.
4. Public API review of the OpenZeppelin facade.

## Decision

- **Chosen option:** **D — defer import for M1; keep local stand-ins** — with
  **B as the import trigger** (adopt published Token Standard V2 DARs once
  upstream publishes a tagged/released, individually-consumable set).
- **Date / who provided input:** 2026-06-21, Amar (library owner). No external
  sign-off required; recorded openly here and surfaced on the PR.
- **Rationale:** M1 is scope-locked, non-public, and experimental; the scaffold
  already validates (60/60) against local stand-ins, and the only stable-tagged
  upstream source (`0.6.9`) does not yet carry the six `*-v2` packages. Building a
  public-facing facade on a force-pushable branch (A) or a DevNet-only bundle (C)
  would import instability we do not need for M1.
- **Interim alignment policy (until the trigger fires):** keep the local
  stand-in types **aligned with the `token-standard-v2-upcoming` branch** so the
  eventual switch to real V2 DARs is a thin substitution. Re-check the branch pin
  (currently `1e34121…`) when revisiting this area; if upstream cuts a tagged V2
  release, that is the signal to execute the import via the ready
  [DPM wiring spec](./cip0112-dpm-wiring-spec.md) and
  [license/NOTICE plan](./cip0112-license-notice-packaging-plan.md), then public
  API review.
- **What this does NOT claim:** no stability, conformance, M1 acceptance, audit,
  production, or release readiness — D keeps the scaffold experimental.
