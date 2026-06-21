# CIP-0112 DPM Dependency Wiring Spec (drafted — NOT applied)

Status: **Draft spec — not applied.** No `daml.yaml`, `multi-package.yaml`, DPM
package, or import file in this repo is changed by this document. It is the exact
wiring that *would* be applied in the import slice, written now so the change is
small, reviewed, and ready once the source of record is accepted. Applying it now
would violate the import gate (see
[`cip0112-splice-token-standard-v2-import-gate.md`](./cip0112-splice-token-standard-v2-import-gate.md)).

Date: 2026-06-21

Phase: Phase 2, Scope-Locked Library Foundation

## Preconditions (must all hold before applying)

1. Source of record accepted (tagged release, accepted bundle extraction, or
   reproducible build) — **currently open**; the V2 packages are branch-only.
2. Final DAR files + SHA-256 recorded for that accepted source.
3. License/NOTICE plan applied
   ([`cip0112-license-notice-packaging-plan.md`](./cip0112-license-notice-packaging-plan.md)).
4. Public API review of the facade scheduled.

## Dependency graph (the seven packages, build order)

From the import-gate "Package Boundary" manifest data-dependencies. A DAR that
lists all seven as `data-dependencies` resolves these transitively; the order
below is the topological sort (for clarity and for any per-package build path):

```
metadata-v1                      (no token deps)
└─ holding-v2                    (→ metadata-v1)
   ├─ allocation-v2              (→ metadata-v1, holding-v2)
   │  ├─ allocation-request-v2   (→ metadata-v1, holding-v2, allocation-v2)
   │  └─ allocation-instruction-v2 (→ metadata-v1, holding-v2, allocation-v2)
   ├─ transfer-instruction-v2    (→ metadata-v1, holding-v2)
   └─ transfer-events-v2         (→ metadata-v1, holding-v2)
```

## Package layout (thin facade, no mirroring)

- New facade package, e.g. `settlement/` (`oz-cip112-settlement`), that
  `data-depends` on the seven upstream DARs and holds **only** the OpenZeppelin
  D1/D2/D3/D4 extension points.
- Upstream types are imported **directly** through their Splice module names — not
  re-exported or mirrored under `OpenZeppelin.*` names.
- The existing `experiments/cip112-settlement` stays as-is (local stand-ins) until
  the facade replaces its stand-in types; do not edit it in the wiring slice.

## `daml.yaml` data-dependencies block (template — DO NOT APPLY YET)

`<DARS_DIR>` is the accepted local path (or DPM-resolved location) for the
accepted-source DARs; it is intentionally a placeholder until precondition 1/2.

```yaml
# settlement/daml.yaml  —  TEMPLATE, not applied
name: oz-cip112-settlement
version: 0.1.0
sdk-version: 3.4.11           # matches upstream package manifests
source: daml
dependencies:
  - daml-prim
  - daml-stdlib
data-dependencies:
  # order is irrelevant to DPM (resolved by package id); listed in dep order
  - <DARS_DIR>/splice-api-token-metadata-v1-1.0.0.dar              # 4ded6b66…354f
  - <DARS_DIR>/splice-api-token-holding-v2-1.0.0.dar               # 26ba27db…8d84
  - <DARS_DIR>/splice-api-token-allocation-v2-1.0.0.dar            # f0570f0d…c81f
  - <DARS_DIR>/splice-api-token-allocation-request-v2-1.0.0.dar    # 94fad8bd…e962
  - <DARS_DIR>/splice-api-token-allocation-instruction-v2-1.0.0.dar# 1f76e53c…0314
  - <DARS_DIR>/splice-api-token-transfer-instruction-v2-1.0.0.dar  # 5031d790…6d5a
  - <DARS_DIR>/splice-api-token-transfer-events-v2-1.0.0.dar       # 5cdd2104…2fee
```

Notes:
- Upstream packages go under `data-dependencies` (consumed by package id), **not**
  `dependencies` (which is for `daml-prim`/`daml-stdlib`/`daml-script`).
- Reconcile against Splice `build.sbt` before applying — especially the SBT wiring
  around `splice-api-token-allocation-request-v2`, which the import-gate flagged.
- Add the package to `multi-package.yaml` so `dpm build --all` includes it.

## Verification gate (run after applying, in the import slice)

```sh
dpm build --all                       # from canton-contracts
cd test && dpm test                   # from canton-contracts/test
```

Record: each emitted DAR's path + SHA-256, the resolved upstream package ids
(must equal the import-gate "Package Boundary" table), and the test count, in the
import slice's evidence doc.

## Explicitly out of scope for the wiring slice

- No mirroring of upstream types under OpenZeppelin names.
- No V1 / Amulet / wallet / app / SV / validator / examples packages.
- No change to `experiments/cip112-settlement` stand-ins until the facade lands.
- No stability, conformance, or M1-acceptance claim from wiring alone.
