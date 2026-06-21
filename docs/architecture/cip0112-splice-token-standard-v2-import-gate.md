# CIP-0112 Splice Token Standard V2 Import Gate

Status: Phase 2 evidence-boundary result. This is not a Splice DAR import,
public API stability, conformance, M1 acceptance, audit-readiness,
production-readiness, or release-readiness claim.

Date: 2026-06-18 (evidence refresh 2026-06-21 — see "2026-06-21 Evidence Refresh")

Phase: Phase 2, Scope-Locked Library Foundation

Depends on:

- root `PLAN.md` Decision Log S2: D2 in-flight seizure is lock-and-sweep to the
  admin-preset custodian destination; D4 is single-admin capability authority.
- [`cip0112-public-api-promotion-boundary.md`](./cip0112-public-api-promotion-boundary.md):
  the local settlement scaffold stays experimental until upstream DAR/import and
  public API gates are accepted.

## Result

The current upstream evidence is sufficient to keep the M1 scaffold aligned to
Token Standard V2, but it is not sufficient to import Splice DARs into
`canton-contracts` or claim a stable public API.

**Source-of-record decided 2026-06-21 — Option D (defer import for M1; keep local
stand-ins), with a published tagged V2 release as the import trigger.** See
[`cip0112-import-source-of-record-decision.md`](./cip0112-import-source-of-record-decision.md).
The import gate is therefore not an open question blocking M1: the accepted M1
posture is to keep local stand-ins aligned with the `token-standard-v2-upcoming`
branch and execute the import (via the ready DPM-wiring and license plans) only
when upstream publishes consumable V2 DARs. The "do not change package/import
files" guidance below still holds — that is exactly what D mandates for M1.

Do not change Daml package or import files until a later slice accepts all of
the following as one import boundary:

- release source: the exact upstream release tag, branch, commit, and artifact
  source intended for Token Standard V2 consumers;
- artifact source: either individually published DARs or an accepted release
  bundle extraction path;
- package identity: package IDs for every imported DAR and its transitive
  dependency set;
- artifact integrity: SHA-256 checksums for the actual DAR files or DPM
  artifacts consumed locally;
- license and notice handling for Apache-2.0 upstream artifacts inside this
  MIT-licensed repo;
- DPM dependency wiring and local build/test evidence;
- public API review for the OpenZeppelin facade and SCU compatibility contract.

## 2026-06-21 Evidence Refresh

Re-verification of the upstream state, three days after the initial pass, plus
the first hard artifact-integrity evidence (DAR SHA-256 checksums). Still **not**
a DAR import, source acceptance, or stability claim. Method: files fetched read-
only via `raw.githubusercontent.com` at the pinned commit; no Daml package or
import file was changed.

- **Branch pin unchanged.** `git ls-remote … refs/heads/token-standard-v2-upcoming`
  still resolves to `1e34121b2b369c5dde357c098e2aaeb65250e736`.
- **New source tag `0.6.9` exists but does not carry the V2 API packages.** The
  source repo now has a `0.6.9` tag (`bc6a3587e7ea94230ba0c36c638945282c52b304`),
  absent from the 2026-06-18 evidence. Its `daml/dars.lock` contains only
  `splice-api-token-metadata-v1` (1 of the 7 boundary package IDs); the six
  `*-v2` API package IDs are **not** present at `0.6.9`. The Token Standard V2 API
  packages at the IDs in "Package Boundary" therefore remain **branch-only** on
  `token-standard-v2-upcoming`; the new tag is not a release-source-of-record for
  them.
- **DevNet bundle unchanged.** `digital-asset/decentralized-canton-sync` @
  `token-standard-v2-upcoming` is still version
  `0.6.9-snapshot.20260615.3096.0.v27548d88`, still marked pre-release.
- **No formal source releases.** `canton-network/splice` (the redirect target of
  `hyperledger-labs/splice`) still lists no GitHub Releases, so there is still no
  individual-DAR publication contract.
- **NOTICE still absent.** `/NOTICE`, `/NOTICE.txt`, and `/NOTICE.md` all return
  HTTP 404 at the pinned commit, corroborating the original license/notice
  finding.

### DAR Artifact Checksums (branch pin `1e34121…`, source `daml/dars/`)

SHA-256 over the checked-in DAR files at the pin, with the main package ID read
from each DAR's embedded `*.dalf` filename. **All seven embedded package IDs
match the "Package Boundary" table / `dars.lock` exactly** — independent
confirmation of package identity from the binaries, not just a re-read of the
lock file. These are artifact-integrity checksums for the **branch-pinned
checked-in DARs**; they do not by themselves accept that source for import
(reproducible build, release-source confirmation, license/NOTICE packaging, DPM
wiring, and public API review remain open).

| Package (DAR `…-1.0.0.dar`) | Size (bytes) | DAR SHA-256 | Embedded pkg id == boundary table |
| --- | --- | --- | --- |
| `splice-api-token-metadata-v1` | 260414 | `455eb160cb5abd4ae9918a6fbb9dad471f721adda39f0e5c76feef08d05637fc` | ✅ `4ded6b66…354f` |
| `splice-api-token-holding-v2` | 483164 | `156a5d78659abbf9664cac3ece97338afa9fd1c2a4a72588ea89fc09e78ebea9` | ✅ `26ba27db…8d84` |
| `splice-api-token-allocation-v2` | 542139 | `968a089eb5026b2317c3489f67feb000990a56c2202ab890b8386f6844003205` | ✅ `f0570f0d…c81f` |
| `splice-api-token-allocation-request-v2` | 534881 | `a30af9a1ba3cf3c79f96bac00541f1ae641637857d1cfc1b78939ab0acb696e0` | ✅ `94fad8bd…e962` |
| `splice-api-token-allocation-instruction-v2` | 546082 | `96f2768471fc92e24e4943359bf529072b111848d4bfa17196a17b2f6c836b00` | ✅ `1f76e53c…0314` |
| `splice-api-token-transfer-instruction-v2` | 520160 | `f3cb0ae308997167daf008b291854b3c948d695b1331f7f4e60810f25e83e694` | ✅ `5031d790…6d5a` |
| `splice-api-token-transfer-events-v2` | 498208 | `b865117fc61b1bdb46756dcaa2d2330822e62e7a925c9bec49805e71dd0bddda` | ✅ `5cdd2104…2fee` |

These are checksums of DARs committed to the **moving** `token-standard-v2-upcoming`
branch. A later import slice must re-pin to whatever source the
"Release-Source Confirmation" section settles on (tagged release, accepted
bundle extraction, or reproducible build) and re-record checksums for that
source — these values are evidence the pin is internally consistent today, not
an accepted import artifact set.

## Sources Checked

| Source | Current evidence |
| --- | --- |
| Splice source repo | `git ls-remote https://github.com/hyperledger-labs/splice.git refs/heads/token-standard-v2-upcoming` resolves to `1e34121b2b369c5dde357c098e2aaeb65250e736`. A sparse checkout at that commit was used for the files below. GitHub API responses for this repository redirect to `canton-network/splice`, but the `hyperledger-labs/splice` remote remains reachable. |
| Splice source releases/tags | `git ls-remote --tags --refs https://github.com/hyperledger-labs/splice.git` shows source tags through `0.6.8` plus `next-cilr`; the checked commit is not exactly tagged in the checkout. The GitHub releases API for the source repo returned an empty list. |
| Source package manifests | `token-standard/splice-api-token-*/daml.yaml` at the evidence commit declares SDK `3.4.11`, Daml target `2.1`, package `version: 1.0.0`, and Apache-2.0 SPDX headers for the relevant API packages. |
| Upstream package-id guard | `daml/dars.lock` at the evidence commit records package IDs for the checked-in DAR set. `CONTRIBUTING.md` says Splice commits current package IDs in `daml/dars.lock` and CI verifies them. |
| Upstream build path | `DEVELOPMENT.md` names `sbt damlBuild` for DAR creation, `sbt damlDarsLockFileUpdate` for the lock file, and `sbt updateDarResources` for generated DAR resources. `build.sbt` wires the Token Standard V2 Daml projects through Splice's SBT `DamlPlugin`. |
| DevNet release bundle | `token-standard/TOKEN_STANDARD_V2_DEVNET.md` points to `digital-asset/decentralized-canton-sync` release tag `token-standard-v2-upcoming`, version `0.6.9-snapshot.20260615.3096.0.v27548d88`. The GitHub release is a prerelease updated 2026-06-15 with `openapi.tar.gz` and `splice-node.tar.gz` assets and SHA-256 digests. It is not an individual-DAR publication contract by itself. |
| License/notice | The source repo root has `LICENSE` with Apache-2.0 text; no root `NOTICE` file was observed in the checked commit. Token Standard source files and manifests carry Apache-2.0 SPDX headers. |

## Package Boundary

The import boundary for the M1 settlement facade remains the seven Token
Standard V2 API packages already named by the promotion ADR. The package IDs
below are from upstream `daml/dars.lock` at
`1e34121b2b369c5dde357c098e2aaeb65250e736`; they are package identity evidence,
not DAR file checksums.

| Package | DAR path observed upstream | Package ID from `daml/dars.lock` | Manifest data dependencies |
| --- | --- | --- | --- |
| `splice-api-token-metadata-v1` | `daml/dars/splice-api-token-metadata-v1-1.0.0.dar` | `4ded6b668cb3b64f7a88a30874cd41c75829f5e064b3fbbadf41ec7e8363354f` | none beyond `daml-prim`, `daml-stdlib` |
| `splice-api-token-holding-v2` | `daml/dars/splice-api-token-holding-v2-1.0.0.dar` | `26ba27db8af91bc5554780f3e66fd5e453f4ef2a862f4197817fa69ad6598d84` | metadata v1 |
| `splice-api-token-allocation-v2` | `daml/dars/splice-api-token-allocation-v2-1.0.0.dar` | `f0570f0d3d0be468504c662d464b445174a2809420aabfc8990526caecfac81f` | metadata v1, holding v2 |
| `splice-api-token-allocation-request-v2` | `daml/dars/splice-api-token-allocation-request-v2-1.0.0.dar` | `94fad8bd299003ef8b0b030d47ac17c36de3307c1d36b3d18a64ab5ce366e962` | metadata v1, holding v2, allocation v2 |
| `splice-api-token-allocation-instruction-v2` | `daml/dars/splice-api-token-allocation-instruction-v2-1.0.0.dar` | `1f76e53c4d6483fd87b85bef984132c928aeec768a49c4afbea657ca87510314` | metadata v1, holding v2, allocation v2 |
| `splice-api-token-transfer-instruction-v2` | `daml/dars/splice-api-token-transfer-instruction-v2-1.0.0.dar` | `5031d7905fc9ac39bb6f6e7b59c380112ed74c2d523b953835d8b4c18d946d5a` | metadata v1, holding v2 |
| `splice-api-token-transfer-events-v2` | `daml/dars/splice-api-token-transfer-events-v2-1.0.0.dar` | `5cdd2104ca9b799933970c8a44c16790489dda8c648d17a397709ff8aaf72fee` | metadata v1, holding v2 |

Out of boundary for this import gate: V1 packages, Amulet packages, wallet
packages, app/SV/validator infrastructure, examples, tests, CLI code, featured
app APIs, reward APIs, Splice utility packages, and RI-specific business logic.
Add any such package only through a later ADR.

## Published DAR Status

Current state:

- The Splice source commit contains checked-in DAR paths under `daml/dars/`.
- `daml/dars.lock` records package IDs for those DARs.
- The source repo does not currently expose a formal GitHub release with
  individual Token Standard V2 DAR assets.
- The separate `digital-asset/decentralized-canton-sync` DevNet prerelease
  exposes aggregate `openapi` and `splice-node` tarballs, not a documented
  package-by-package DAR import contract for this repo.

Therefore, `canton-contracts` must not consume upstream DARs yet. A later import
slice must choose one of these accepted sources:

- individually published Token Standard V2 DARs with upstream checksums and
  package IDs;
- an accepted release-bundle extraction path that identifies the exact DAR files
  inside the bundle and verifies their SHA-256 checksums and package IDs;
- a reproducible source build from the accepted upstream release tag/commit that
  reproduces the expected package IDs and records the generated DAR checksums.

## Reproducible Build Status

Splice documents a build path, but the initial (2026-06-18) slice did not run it
and does not accept it as reproducible for local import.

### 2026-06-21 local-rebuild attempt — result: package IDs do NOT reproduce locally

A rebuild was attempted from the pinned source, isolated outside the repo (no
package/import file changed). The seven boundary packages are plain Daml declaring
`sdk-version: 3.4.11` / `--target=2.1`; `splice-api-token-metadata-v1` (which
depends only on `daml-prim`/`daml-stdlib`) was rebuilt with local `dpm` 3.4.11,
source `daml.yaml` unmodified.

**Result: the rebuilt package ID does not match upstream.**
`metadata-v1` rebuilt to `25952a7cee7b1b68560fd5fe202085b68f4a6bc7e2db28bdb9b6330a7dbf9e5a`
vs. the upstream `4ded6b66…354f`.

**Root cause (precise): a `daml-stdlib`/`daml-prim` baseline mismatch, not source.**
Comparing the DALFs bundled in each DAR:

| Dependency | Upstream checked-in DAR | Local dpm 3.4.11 rebuild |
| --- | --- | --- |
| `daml-stdlib` (main) | `daml-stdlib-3.3.0.20250502.13767.0` (`9d1a644e…`) | `daml-stdlib-3.4.11` (`3b25c9b0…`) |
| `daml-prim` (main) | `54f85ebf…c274` | `7cff38e3…14ef` |
| split stdlib modules (`DA.*.Types`) | identical | identical |

A package ID is a hash over its dependency closure, so a different stdlib/prim
baseline changes every dependent ID; the identical split modules isolate the
cause to the main stdlib/prim **version**, not the package source. This cascades
to all seven boundary packages (each depends transitively on `daml-stdlib` and/or
on `metadata-v1`).

**Implication.** The `daml.yaml` declares `sdk-version: 3.4.11`, but the published
DARs were built against a **3.3.0 snapshot** stdlib — i.e. the nominal
`sdk-version` label does not pin the toolchain that produced the artifacts;
Splice's pinned `nix`/`direnv` build environment does. A faithful reproducible
build therefore requires that exact upstream environment, **not** a local `dpm`
that merely shares the `3.4.11` label. Local package-ID reproduction with `dpm`
alone is not achievable. The accepted import must consequently rest on either
upstream-published DAR artifacts with checksums, or a build performed inside
Splice's pinned environment — re-recording checksums for that result.

A future reproducible-build import must record:

- upstream repository URL, release tag or branch, commit, and whether GitHub has
  redirected the repository identity;
- required SDK, Daml target, SBT, Java, Node/OpenAPI, and cache inputs;
- exact command sequence, at minimum reconciling Splice's `sbt damlBuild`,
  `sbt damlDarsLockFileUpdate`, and `sbt updateDarResources` flow with local
  DPM-only consumption in `canton-contracts`;
- resulting DAR file paths, SHA-256 checksums, main package IDs, dependency
  package IDs, and versions;
- proof that those results match `daml/dars.lock` and any accepted release
  manifest.

## DPM Dependency Wiring Requirements

No local `daml.yaml`, DPM package, or import file should change before the gate
above is accepted.

When accepted, the DPM wiring should be narrow:

- add only the seven API DARs above as data dependencies for the settlement
  facade package;
- keep upstream types imported directly through Splice package modules rather
  than mirrored under OpenZeppelin names;
- keep OpenZeppelin-specific D1, D2, D3, and D4 extension points in a thin local
  facade package;
- reconcile manifest data dependencies with Splice `build.sbt` before editing
  local package files, especially the upstream SBT wiring around
  `splice-api-token-allocation-request-v2`;
- run `dpm build --all` from `canton-contracts` and `dpm test` from
  `canton-contracts/test` after any package/import change.

The exact wiring (template `daml.yaml` data-dependencies block, dependency graph,
facade layout, verification gate) is drafted but **not applied** in
[`cip0112-dpm-wiring-spec.md`](./cip0112-dpm-wiring-spec.md).

## License And NOTICE Handling

`canton-contracts` is MIT. The upstream Token Standard V2 API packages are
Apache-2.0.

Before vendoring source, redistributing DARs, or publishing a local package that
contains upstream artifacts, add a packaging plan that:

- preserves the upstream Apache-2.0 `LICENSE`;
- preserves SPDX headers in any copied source;
- includes upstream `NOTICE` content if a future accepted upstream source has
  one, and records that no root `NOTICE` was observed at the current evidence
  commit;
- documents the mixed MIT/Apache-2.0 distribution posture in local release
  notes or package metadata;
- avoids implying that local MIT licensing relicenses upstream Apache-2.0
  artifacts.

The concrete plan satisfying the above — Apache-2.0 §4 obligations mapped to
specific files to add, and the technical trigger (a published Daml DAR bundles
its dependency DALFs, so distribution = redistribution) — is in
[`cip0112-license-notice-packaging-plan.md`](./cip0112-license-notice-packaging-plan.md)
(plan only, not applied).

## Release-Source Confirmation Requirements

**Decided 2026-06-21 — Option D (defer for M1; keep local stand-ins; import on a
published tagged V2 release).** See
[`cip0112-import-source-of-record-decision.md`](./cip0112-import-source-of-record-decision.md).
The confirmations below remain the checklist for the *future* import slice when
the trigger fires.

Before import, confirm with upstream evidence or maintainer approval:

- whether `hyperledger-labs/splice`/`canton-network/splice`
  `token-standard-v2-upcoming` is still the intended source of record;
- whether the accepted import source is a source tag in the Splice repo, the
  `digital-asset/decentralized-canton-sync` DevNet prerelease bundle, a future
  non-prerelease release, or a DPM/package registry artifact;
- how the DevNet release version
  `0.6.9-snapshot.20260615.3096.0.v27548d88` maps back to the source commit
  used for Token Standard V2 API package IDs;
- whether consumers should rely on `daml/dars.lock`, `DarResources`, release
  asset digests, a separate manifest, or a package registry for package
  identity and artifact integrity.

## Public API Review Requirements

After the import evidence is accepted, public API review must still approve:

- the OpenZeppelin settlement facade over upstream Token Standard V2 types;
- SCU-safe upgrade posture: optional fields, metadata, or new choices for D1,
  D2, D3, and D4 extensions, with no mutation of required public fields or
  existing choice arguments;
- D1 no-cache, fail-closed, node-side semantics without finalizing the
  Daml-visible attestation shape in this import slice;
- D2 lock-and-sweep to the preset admin-set custodian destination and D4
  single-admin capability authority as the M1 defaults;
- D3 single-domain v1 wording, with the tech-ops one-pager still pending;
- no stability, conformance, M1 acceptance, audit, production, or release claim
  before the later review accepts the facade.

## Effect On The Existing Experiment

The existing `experiments/cip112-settlement` scaffold remains a local,
experimental witness only.

This gate lets the experiment continue to use local stand-ins for:

- Token Standard V2 records and interfaces;
- toy holdings and receipts;
- D1 reference hooks;
- D2 in-flight lock-and-sweep state;
- D4 single-admin capability witness behavior.

The experiment must not be described as conformant or stable. It can only
promote after the accepted import source, package IDs, DAR checksums,
license/NOTICE handling, DPM wiring, and public API review land.

## Remaining Blockers

With the source-of-record decided as **D (defer import for M1)**, these are no
longer M1 blockers — they are the prerequisite checklist for the *future* import
slice, to be satisfied when the trigger (a published tagged V2 release) fires.

- No accepted individual-DAR publication source. (Re-confirmed 2026-06-21: the
  source repo still has no GitHub Releases, and the new `0.6.9` source tag does
  not carry the six `*-v2` API packages — they remain branch-only.)
- No accepted release-bundle extraction path for Token Standard V2 DARs.
- No accepted reproducible-build transcript from the release source. (Attempted
  2026-06-21: a local `dpm` 3.4.11 rebuild does **not** reproduce the package IDs —
  upstream DARs were built against `daml-stdlib 3.3.0.20250502.13767.0`, not
  dpm's 3.4.11 stdlib. Faithful reproduction needs Splice's pinned `nix`/`direnv`
  environment; see "Reproducible Build Status".)
- ~~No local DAR SHA-256 list for the exact artifacts to consume.~~ Partially
  addressed 2026-06-21: SHA-256 recorded for the branch-pinned checked-in DARs
  (see "DAR Artifact Checksums"), with embedded package IDs confirmed against
  `dars.lock`. Still pending: checksums tied to an **accepted** release-source or
  reproducible build, since the pin is a moving branch.
- No local DPM dependency edit or validation evidence.
- No Apache-2.0 license/NOTICE packaging change in this MIT repo.
- No public API review for the OpenZeppelin facade.
- D1 Daml-visible attestation shape remains open.
- D3 tech-ops one-pager remains pending.
