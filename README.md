# canton-contracts

Reusable Daml contracts library scaffold for the OpenZeppelin Canton ecosystem
workspace.

Status: M0 scaffold + the first reusable access-control primitives (slice AL-7,
see [Access Control Library](#access-control-library-al-7) below), plus a
non-public experimental CIP-0112 / Token Standard V2 settlement scaffold. The
M1 target is now CIP-112 settlement, not the superseded CIP-56 token foundation.
No stable M1 public API, CIP-0112 conformance, audit readiness, production
readiness, or release readiness is claimed.

## Scope

M1 target scope:

- CIP-0112 / Token Standard V2 interface-aligned settlement primitive.
- CIP-86 compatibility surface scoped to interoperate with the settlement work.
- CIP-103 dApp and wallet-provider support components scoped to the settlement
  surface.
- CIP-104 rewards support components scoped to the settlement surface.
- Documentation, tests, security notes, and compatibility evidence.

CIP-86 / CIP-103 / CIP-104 acceptance criteria are recorded as settlement
interop criteria, not standalone CIP-56-token deliverables:

- [`docs/architecture/cip0086-cip0103-cip0104-m1-acceptance.md`](docs/architecture/cip0086-cip0103-cip0104-m1-acceptance.md)

CIP-56 is background and migration evidence only. The experimental CIP-112
settlement scaffold lives under `experiments/cip112-settlement` and remains
outside the committed public-library surface until the promotion boundary ADR's
Splice DAR/import, license/NOTICE, package-ID/checksum, DPM wiring, and public
API gates land:

- [`docs/architecture/cip0112-public-api-promotion-boundary.md`](docs/architecture/cip0112-public-api-promotion-boundary.md)
- [`docs/architecture/cip0112-m1-ri-spec.md`](docs/architecture/cip0112-m1-ri-spec.md)
- [`docs/experiments/cip112-settlement.md`](docs/experiments/cip112-settlement.md)

Out of scope for this repo:

- DEX, lending, payments, or auction business logic.
- Production private integrations.
- Production KYC, sanctions, custody, validator, bridge, or relayer services.
- Full off-chain relayer infrastructure.
- Year 2 components before approval.

## Build Instructions

The M0 proof baseline accepts Daml SDK / Canton 3.4.11 through DPM only for the
hello-world compile/deploy proof. M1 public API and Splice DAR import pins
remain open until the CIP-112 promotion boundary gates are accepted.

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

## Access Control Library (AL-7)

The first reusable primitives land here as **three independent packages**, each
its own DAR with no dependency on the others — so a consumer imports only what it
needs (e.g. just `oz-pausable`). This is the Daml-idiomatic form of OpenZeppelin's
decoupled-module promise: independence is at the **package** boundary, since Daml
has no inheritance and the unit of reuse is the DAR. The full rationale, the
options weighed, and the Daml-specific genericity trade are documented in the
canton-token-template `docs/ARCHITECTURE.md` (slice AL-7).

| Package | Module | Mirrors | Notes |
|---|---|---|---|
| `oz-access-control` | `OpenZeppelin.AccessControl` | `AccessControl.sol` | `RoleGrant` / `RoleAdmin` + pure `requireRole` / `hasRole`. Roles are `Text` ids (the `bytes32` analogue) because Daml templates are monomorphic; a consumer layers a closed role sum on top via a `roleId : MyRole -> Text` wrapper. |
| `oz-ownable` | `OpenZeppelin.Ownable` | `Ownable2Step.sol` | `Ownership` + `OwnershipOffer`. Transfer is a two-step handshake **by necessity** — a new owner is a signatory and cannot be bound unilaterally. |
| `oz-pausable` | `OpenZeppelin.Pausable` | `Pausable.sol` | `PauseState` + `whenNotPaused` guard. Pause is origination control on a keyless ledger. |

Each library package is `daml-script`-free. Tests and the example-consumer
templates that demonstrate the usage pattern (`RoleCheck`, `PauseCheck`, the
typed-wrapper bridge) live in the separate `test/` package, which data-depends on
all three DARs.

Build and test the whole workspace in dependency order:

```sh
dpm build --all          # builds all packages, including the three libraries
cd test && dpm test      # runs the shared test package, including experiments
```

Latest local run (2026-06-21, SDK 3.4.11 / Java 21): `dpm build --all` builds all
packages and `dpm test` passes **60/60** scripts (14 AccessControl, 20
Cip112Settlement, 6 Ownable, 4 Pausable, 2 ComplianceShapeA, 6 ComplianceShapeB,
1 IdentityHookShapeA, 6 IdentityHookShapeB, 1 IdentityHookUpgrade).

Or build a single library standalone (proving its independence):

```sh
cd pausable && dpm build
```

Status: `0.1.0`, **unstable** — these are not yet public API (no stability ADR),
so DAR SHAs are intentionally not pinned here while the shape may still change.

## CIP-112 Settlement Experiment

The experimental settlement package models a Token Standard V2-aligned
request/instruction/allocation/settlement lifecycle with optional D1 and D2
extension points. Its source evidence pin is `hyperledger-labs/splice` branch
`token-standard-v2-upcoming` at
`1e34121b2b369c5dde357c098e2aaeb65250e736`; the older
`canton-network/splice` `token-standard-v2-daml-preview` branch is historical
evidence only.

The package intentionally uses local stand-ins and toy holdings. Do not import
or vendor Splice DARs from this repo until a later slice satisfies the promotion
boundary ADR's published-DAR or reproducible-build evidence, package
ID/checksum, Apache-2.0 license/NOTICE, and DPM dependency requirements.

## License

MIT. See `LICENSE`.
