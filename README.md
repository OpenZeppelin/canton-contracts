# oz-daml-contracts

Reusable Daml contracts library scaffold for the OpenZeppelin Canton ecosystem
workspace.

Status: M0 scaffold only. This repo does not implement CIP-56, CIP-86,
CIP-103, CIP-104, or reference implementation logic yet.

## Scope

M1 target scope:

- CIP-56 token foundation.
- CIP-86 compatibility surface.
- CIP-103 dApp and wallet-provider support components.
- CIP-104 rewards support components.
- Documentation, tests, security notes, and compatibility evidence.

Out of scope for this repo:

- DEX, lending, payments, or auction business logic.
- Production private integrations.
- Full off-chain relayer infrastructure.
- Year 2 components before approval.

## Build Instructions

The Daml SDK/Canton version pin is not accepted yet, so `daml.yaml` is
intentionally not committed.

After `../../docs/decisions/2026-05-15-sdk-cip-version-pinning.md` is accepted:

1. Install or expose the selected Daml/DPM toolchain.
2. Replace `daml.yaml.placeholder` with a real `daml.yaml` using the accepted
   SDK version and package manager path.
3. Run the accepted build command:

```sh
dpm build
# or, only for an accepted Daml Assistant transition:
daml build
```

The root and scaffold scripts use `OZ_DAML_TOOLCHAIN=auto` by default. Auto
selection prefers `dpm` when available, otherwise `daml`. Set
`OZ_DAML_TOOLCHAIN=dpm` or `OZ_DAML_TOOLCHAIN=daml` in CI if the accepted ADR
requires one exact command.

From the workspace root, run:

```sh
./scripts/check-all.sh
./scripts/test-all.sh
```

Until the pin is accepted, root checks report the Daml compile as skipped. Once
`daml.yaml` exists, missing DPM/Daml tooling is a hard failure.

## Hello-World Scaffold

`daml/HelloWorld/HelloWorld.daml` is a minimal Daml source file for the future
compile proof. It records its signatory, observer, controller, privacy, archive,
failure, and migration assumptions in the source comments.

## License

MIT. See `LICENSE`.
