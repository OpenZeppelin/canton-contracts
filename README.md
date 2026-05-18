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

The production package is the repo root DPM package. It intentionally has no
`daml-script` dependency. Disposable script/test code lives in the separate
`proof/` DPM package, which depends on the production DAR and owns
`daml-script`.

Current M0 production DAR:

- Path: `.daml/dist/oz-daml-contracts-0.0.0.dar`
- SHA-256:
  `54741b03baadcc9b0ac4ddeb7abb4128edec52d0c553f53298c35234cd9b62c5`
- Main package ID:
  `8a4ff09828c0cb27ec9291721524aa6ec88958dd4aac2b9ee725e180ad338a60`

Current M0 proof DAR:

- Path: `proof/.daml/dist/oz-daml-contracts-hello-world-proof-0.0.0.dar`
- SHA-256:
  `d3a4d14d4ebccf3b2594ff2ae6ffce4a115d52adf48adf28776345bdd9ff7887`
- Main package ID:
  `9b11bf9f0d678e581c846772196bc5dd79b263e4b6dc75c234c52bfe6e0649f3`

The root and scaffold scripts use `OZ_DAML_TOOLCHAIN=auto` by default. Auto
selection requires DPM and does not fall back to Daml Assistant. The scripts
make `~/.dpm/bin/dpm` visible for non-interactive shells when present and
default DPM/DAML cache writes to the repo-local ignored `.cache/` directory.
The scaffold check uses `scripts/dpm-env.sh` inside this repo so standalone
manual validation does not depend on the coordinating workspace root. Set
`OZ_DAML_TOOLCHAIN=dpm` when manually validating the accepted M0 proof baseline.
Daml Assistant use requires a superseding ADR or explicit exception.

The repo-local `scripts/dpm-env.sh` is intentionally kept byte-for-byte in sync
with the coordinating root helper until an accepted vendoring step replaces the
duplication. Root `./scripts/check-all.sh` fails if the two helper copies drift.
Manual validation machines should install or expose DPM and Java 21 before
running `scripts/manual-workflow-test.sh` or `scripts/check-scaffold.sh`.

From the workspace root, run:

```sh
./scripts/check-all.sh
./scripts/test-all.sh
./scripts/manual-workflow-tests.sh
```

Because `daml.yaml` is committed, missing DPM tooling is a hard failure. Daml
Assistant is not an accepted M0 proof path.

## LocalNet Proof

The M0 LocalNet proof uses the root Canton sandbox config and Daml Script over
the Ledger API gRPC endpoint from the separate `proof/` package. DAR upload
uses `dpm script --upload-dar true`; the sandbox participant vets the uploaded
packages for this single-participant proof. Party allocation uses
`allocatePartyByHint` inside `HelloWorld.Proof:helloWorldProof`.

From the workspace root:

```sh
./scripts/localnet-up.sh
./scripts/localnet-hello-world-proof.sh
./scripts/localnet-down.sh
```

`localnet-up.sh` requires `tmux`, starts Canton in a detached session, and waits
for the Ledger API port to be reachable before returning. The proof script
performs the same DPM bootstrap as the build/test scripts, so the default
up/proof/down sequence works in non-interactive validation shells when DPM is
installed on `PATH` or at `~/.dpm/bin/dpm`.

## Hello-World Scaffold

`daml/HelloWorld/HelloWorld.daml` is a minimal Daml source file for the M0
compile proof. It records its signatory, observer, controller, privacy, archive,
failure, and migration assumptions in the source comments.

`proof/daml/HelloWorld/Proof.daml` is a disposable M0 LocalNet proof script. It
is not public API and keeps the Daml Script dependency out of the production
package.

## License

MIT. See `LICENSE`.
