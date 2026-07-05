# AGENTS.md - canton-contracts

## Role

This repo is the canonical **decoupled, ergonomic general Daml contracts
library** for the Canton workspace: small, independent, reusable packages that
applications import individually. Keep changes small, auditable, and tied to
library deliverables.

The OpenZeppelin Canton Reference Implementations — the CIP-0112 settlement RI
scaffold, the compliance/identity experiments, the CIP specs/architecture
reports, and the four Year-1 RI architectural overviews — live in
`OpenZeppelin/canton-specs`, which **consumes** this library. Keeping the RI out
of this repo is what keeps the library decoupled and ergonomic. **Do not add
RI-specific or experimental packages here**; a primitive is promoted from the RI
scaffold into this library only after it satisfies the CIP-0112
promotion-boundary ADR tracked in `canton-specs`.

The `settlement`, `token-standard-v2-mock`, and `interop` packages are exactly
such a promotion, in progress on the `cip-interop-m1` branch: the interop facades
are the promoted deliverable; `settlement` + `token-standard-v2-mock` come along
as their build dependencies and remain **gated/experimental** (the Token Standard
V2 import gate has not cleared) until that ADR step completes.

## Read Order

Before changing this repo:

1. Read root `../AGENTS.md`.
2. Read root `../PLAN.md`.
3. Read this file.
4. Read `README.md`.
5. Check the accepted SDK/CIP ADR before adding or changing `daml.yaml`.

## Boundaries

Do not add:

- Reference-implementation-specific business logic.
- Production private integrations.
- Full relayer infrastructure.
- Year 2 components before scope review approval.
- Public APIs without an ADR once implementation begins.

Hosted CI is accepted for this repo: `.github/workflows/ci.yml` provisions DPM,
builds every package, runs the script suites, and captures coverage reports
(`scripts/run-tests.sh`). This supersedes the prior "no `.github/workflows`"
boundary, per the CIP-0112 interop delivery decision.

## Daml Requirements

This repo is DPM-native. Use `dpm build`, `dpm test`, `dpm script`, and
`dpm init`; do not use legacy `daml ...` commands or stale SDK binaries unless
a superseding ADR or explicit temporary exception accepts them. Daml Assistant
absence is expected for the M0 proof path and must not be treated as a reason
to fall back from DPM.

Local scripts bootstrap DPM from PATH or `~/.dpm/bin/dpm`, require Java 21 for
the accepted DPM build/test/script path, and default DPM/DAML cache writes to
the repo-local ignored `.cache/` directory. The repo-local
`scripts/dpm-env.sh` is intentionally duplicated with the coordinating root
helper so standalone checkouts remain buildable; update both copies together
until an accepted vendoring step replaces the duplication.

Every template or interface must document:

- Signatories
- Observers
- Controllers
- Choices
- Disclosed parties
- Privacy expectations
- Authorization assumptions
- Archival behavior
- Failure modes
- Upgrade and migration assumptions

If any item is unclear, document the uncertainty before implementation.

## Validation

Use repo-local scripts for standalone validation:

```sh
scripts/check-scaffold.sh
scripts/run-tests.sh
scripts/manual-workflow-test.sh
```

The accepted M0 proof baseline uses DPM with SDK 3.4.11. Because `daml.yaml`
exists, missing DPM or Java 21 tooling is a validation failure, not a green
skip. Use `OZ_DAML_TOOLCHAIN=dpm` for the M0 proof baseline; Daml Assistant
requires a superseding ADR or explicit exception.

GitHub Actions / hosted CI is accepted here (`.github/workflows/ci.yml`): it
provisions DPM, builds every package, runs the script suites via
`scripts/run-tests.sh`, and captures coverage. The repo-local manual validation
entrypoint remains `scripts/manual-workflow-test.sh`.
