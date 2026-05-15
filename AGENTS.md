# AGENTS.md - oz-daml-contracts

## Role

This repo is the canonical reusable Daml contracts library for the Canton
workspace. Keep changes small, auditable, and tied to M1 library deliverables.

## Read Order

Before changing this repo:

1. Read root `../../AGENTS.md`.
2. Read root `../../SCOPE.md`.
3. Read root `../../PLAN.md`.
4. Read this file.
5. Read `README.md`.
6. Check the accepted SDK/CIP ADR before adding or changing `daml.yaml`.

## Boundaries

Do not add:

- Reference-implementation-specific business logic.
- Production private integrations.
- Full relayer infrastructure.
- Year 2 components before scope review approval.
- Public APIs without an ADR once implementation begins.

## Daml Requirements

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

Use root scripts when available:

```sh
../../scripts/check-all.sh
../../scripts/test-all.sh
../../scripts/fmt-all.sh
```

Until the SDK pinning ADR is accepted, Daml builds are expected to be skipped.
After `daml.yaml` exists, missing DPM/Daml tooling is a validation failure, not
a green skip. Use `OZ_DAML_TOOLCHAIN=dpm` or `OZ_DAML_TOOLCHAIN=daml` when the
accepted ADR requires one exact command; otherwise scripts auto-select DPM
first, then Daml Assistant.
