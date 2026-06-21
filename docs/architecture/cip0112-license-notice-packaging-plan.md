# CIP-0112 License / NOTICE Packaging Plan

Status: **Plan only — not applied.** No license, NOTICE, or packaging file in
this repo is changed by this document. It is the concrete plan that satisfies the
"License And NOTICE Handling" requirement in
[`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md),
to be applied **only** in the import slice that also accepts the source of record.

Date: 2026-06-21

Phase: Phase 2, Scope-Locked Library Foundation

## Why this is needed (the technical trigger)

A Daml DAR is self-contained: it bundles the main package's DALF **plus every
transitive dependency DALF**. So if `canton-contracts` ever publishes a
settlement-facade DAR that data-depends on the Splice Token Standard V2 packages,
that published DAR **redistributes** the upstream Apache-2.0 DALFs. Redistribution
— not mere local building — is what triggers Apache-2.0 §4 obligations. This plan
therefore assumes redistribution and is conservative.

Until such a publication happens, the experiment stays local/experimental and
**no packaging change is required** (the current state).

## License facts (evidence)

- `canton-contracts` is **MIT** (`LICENSE`).
- The seven Token Standard V2 API packages are **Apache-2.0**: the Splice repo
  root `LICENSE` is Apache-2.0, and the `token-standard/splice-api-token-*`
  sources/manifests carry Apache-2.0 SPDX headers.
- **No upstream root `NOTICE`** exists at the evidence commit
  `1e34121b2b369c5dde357c098e2aaeb65250e736` (`/NOTICE`, `/NOTICE.txt`,
  `/NOTICE.md` all return HTTP 404, re-confirmed 2026-06-21).
- We consume the packages **unmodified** (wrap, do not edit upstream source).

## Apache-2.0 §4 obligations, mapped to concrete repo actions

| Obligation (Apache-2.0 §4) | Action in this repo |
| --- | --- |
| (a) Give recipients a copy of the License | Add the upstream Apache-2.0 license text under `third_party/splice-token-standard/LICENSE` (verbatim). |
| (b) Mark modified files | None expected — we do **not** modify upstream packages. Record "used unmodified" explicitly; if that ever changes, mark the modified files. |
| (c) Retain attribution/copyright/SPDX notices from source | We do not copy upstream source, so there are no upstream SPDX headers to retain in our tree; the bundled DALFs retain their own identity. Record this reasoning. |
| (d) Include NOTICE contents if a NOTICE exists | None exists at the evidence commit — record that fact. Re-check at the accepted source; if a NOTICE appears there, vendor its contents into our NOTICE. |
| Trademark use (§6) | Do not use "Splice"/"Canton"/Digital Asset/Hyperledger marks except nominatively to identify the upstream packages. |

## Files to add at import time (not now)

1. `NOTICE` (repo root) — a third-party attributions file stating, for the seven
   packages: name, `version 1.0.0`, package id, Apache-2.0, source repo +
   **accepted** commit/tag, "used unmodified as data-dependencies," and "no
   upstream NOTICE existed at the source commit."
2. `third_party/splice-token-standard/LICENSE` — verbatim upstream Apache-2.0
   text.
3. `third_party/splice-token-standard/README.md` — provenance: the seven package
   ids, DAR SHA-256s (from the import-gate "DAR Artifact Checksums" table), the
   accepted source, and a pointer to the import-gate evidence doc.
4. Release-notes / package-metadata note documenting the **mixed MIT/Apache-2.0**
   distribution posture.

## Scope boundaries (do not over-reach)

- This plan covers **only** the seven boundary API packages. V1, Amulet, wallet,
  app/SV/validator, examples, and RI business-logic packages are out of scope and
  must not be vendored or attributed here.
- MIT applies to **OpenZeppelin-authored code only**. This plan must not imply
  that MIT relicenses the upstream Apache-2.0 artifacts; the two licenses
  coexist, each governing its own files.
- SPDX headers in OZ facade source stay MIT; we add no SPDX headers to (and copy
  no source from) the upstream packages.

## When to apply

Apply this plan in the same slice that:

1. accepts the source of record (see import-gate "Release-Source Confirmation"),
2. records the final DAR checksums for that accepted source, and
3. wires the DPM data-dependencies (see
   [`cip0112-dpm-wiring-spec.md`](./cip0112-dpm-wiring-spec.md)).

Applying it earlier would attach license artifacts to a source we have not yet
accepted (currently a moving pre-release branch), which would misstate provenance.
