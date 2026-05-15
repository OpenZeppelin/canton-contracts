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

The M0 proof baseline accepts Daml SDK / Canton 3.4.11 through DPM only for the
hello-world compile/deploy proof. M1 public API pins remain open until the
required 3.5 re-evaluation.

For the M0 proof baseline:

1. Install or expose DPM.
2. Run `dpm install 3.4.11`.
3. Run the accepted build command:

```sh
OZ_DAML_TOOLCHAIN=dpm dpm build
```

Current M0 proof DAR:

- Path: `.daml/dist/oz-daml-contracts-hello-world-0.0.0.dar`
- SHA-256:
  `5d59960e83c4724958880c481d5309f7117e32e9998874a1299ec1a5f52caecc`
- Main package ID:
  `14ad46dfe5e89f3be7be0f4de8209f49e5b26dc0471069101184c71d9f5f2007`

The root and scaffold scripts use `OZ_DAML_TOOLCHAIN=auto` by default. Auto
selection prefers `dpm` when available, otherwise `daml`. Set
`OZ_DAML_TOOLCHAIN=dpm` in CI for the accepted M0 proof baseline. Daml
Assistant use requires a superseding ADR or explicit exception.

From the workspace root, run:

```sh
./scripts/check-all.sh
./scripts/test-all.sh
```

Because `daml.yaml` is committed, missing DPM tooling is a hard failure. Daml
Assistant is not an accepted M0 proof path.

## LocalNet Proof

The M0 LocalNet proof uses the root Canton sandbox config and Daml Script over
the Ledger API gRPC endpoint. DAR upload uses `dpm script --upload-dar true`;
the sandbox participant vets the uploaded packages for this single-participant
proof. Party allocation uses `allocatePartyByHint` inside
`HelloWorld.Proof:helloWorldProof`.

From the workspace root:

```sh
./scripts/localnet-up.sh
./scripts/localnet-hello-world-proof.sh
./scripts/localnet-down.sh
```

`localnet-up.sh` requires `tmux`, starts Canton in a detached session, and waits
for the Ledger API port to be reachable before returning. This makes the default
up/proof/down sequence reproducible in non-interactive validation shells.

## Hello-World Scaffold

`daml/HelloWorld/HelloWorld.daml` is a minimal Daml source file for the M0
compile proof. It records its signatory, observer, controller, privacy, archive,
failure, and migration assumptions in the source comments.

`daml/HelloWorld/Proof.daml` is a disposable M0 LocalNet proof script. It is not
public API and must not be carried forward as an M1 library dependency without a
separate package split or ADR.

## License

MIT. See `LICENSE`.
