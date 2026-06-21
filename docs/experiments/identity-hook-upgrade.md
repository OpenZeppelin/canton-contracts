# Identity Hook Upgrade Experiment

Status: experimental, non-public, and outside the committed M1 library surface.

This note records Tier 2 experiment 7 from root `PLAN.md` -> "Experimentation
Priorities": a Daml Smart Contract Upgrades spike for the D3 forward-compatible
identity hook. Root `PLAN.md` records D3 as single-domain v1 with cross-domain
identity deferred. This spike does not implement cross-domain identity and does
not close D3; it demonstrates the narrower claim that a shipped single-domain
identity hook can gain a typed-claim extension later without breaking old
on-ledger holdings or the baseline transfer choice.

D1 remains no-cache, fail-closed, and node-side; this spike does not decide
whether a final transfer hook verifies node attestations. D2 routes seizure to a
deployer-configurable custodian destination, but this spike does not implement
seizure. D4 remains open; issuer and claim-issuer parties here are plain Daml
parties and do not choose between on-ledger multi-sig and Canton-topology
multi-hosted party authority.

## SCU Mechanism Evidence

Toolchain evidence:

- `dpm --version`: DPM `1.0.10`.
- `dpm version`: project SDK `3.4.11`.
- `dpm build --help`: exposes `--upgrades UPGRADE_DAR` and
  `--typecheck-upgrades` with default enabled.
- `dpm upgrade-check`: exposes `--compiler`, `--participant`, and `--both`.

Official 3.4 documentation evidence:

- [Smart Contract Upgrade](https://docs.digitalasset.com/build/3.4/sdlc-howtos/smart-contracts/upgrade/smart-contract-upgrades.html)
  describes SCU compatibility as checked at compile time, DAR upload time, and
  runtime.
- The same guide shows `daml.yaml` using a scalar `upgrades:
  ../../v1/my-pkg/.daml/dist/my-pkg-1.0.0.dar`, not a list, and says `dpm
  build` validates v2 against the DAR in that field.
- The [smart contract upgrading reference](https://docs.digitalasset.com/build/3.4/reference/smart-contract-upgrades.html)
  describes participant upload validation against previously uploaded package
  versions with the same package name.

Local wiring:

```yaml
sdk-version: 3.4.11
name: oz-experimental-identity-hook-upgrade
version: 0.2.0
upgrades: ../identity-hook-upgrade-v1/.daml/dist/oz-experimental-identity-hook-upgrade-0.1.0.dar
```

Local command evidence:

- `cd experiments/identity-hook-upgrade-v2 && dpm build` passed, which exercises
  the compiler-side `upgrades:` check.
- `dpm upgrade-check --both experiments/identity-hook-upgrade-v1/.daml/dist/oz-experimental-identity-hook-upgrade-0.1.0.dar experiments/identity-hook-upgrade-v2/.daml/dist/oz-experimental-identity-hook-upgrade-0.2.0.dar`
  passed, including participant-style upgrade validation.
- `dpm script --upload-dar true` against a sandbox uploaded and ran the v1
  fixture script, then uploaded and ran the v2 migration script against the
  same v1-created holding.
- `./scripts/identity-hook-upgrade-smoke.sh` repeats the sandbox proof from the
  repo root. It builds both experiment versions and script packages, starts a
  local sandbox, creates a v1 holding with a unique run id, and exercises the
  unchanged baseline transfer through v2.

## Versioned Packages

Package name for both versions:
`oz-experimental-identity-hook-upgrade`.

Version directories:

- `experiments/identity-hook-upgrade-v1` (`0.1.0`)
- `experiments/identity-hook-upgrade-v2` (`0.2.0`)
- `experiments/identity-hook-upgrade-v1-script`
- `experiments/identity-hook-upgrade-v2-script`

The script packages are isolated drivers. They avoid importing both versions of
`OpenZeppelin.Experimental.Identity.Upgrade` into the same package, because
Daml 3.4 reports that as an ambiguous module import.

## Upgrade-Safe Pattern

v0.1.0 baseline:

- `ToyRegistry` mints `ToyHolding`.
- `ToyHolding_Transfer` takes `newOwner` and `OpaqueIdentityAttestation`.
- The attestation is opaque and single-domain. The contract checks only that an
  envelope is present.

v0.2.0 additive upgrade:

- Preserves `ToyHolding_Transfer` argument and return type.
- Adds `IdentityClaimKind`, `IdentityExtensionConfig`, and `KycClaim`.
- Appends `identityExtension : Optional IdentityExtensionConfig` to
  `ToyRegistry` and `ToyHolding`.
- Adds `ToyHolding_TransferWithClaim` as a new typed-claim transfer choice.
- Old v1 contracts upgrade with `identityExtension = None`; new v2 holdings can
  opt into typed-claim transfer by minting from a registry configured with
  `Some IdentityExtensionConfig`.

The upgrade-safe rule for a future M1 hook is: do not mutate the existing
transfer choice to require new identity inputs. Keep the old choice stable and
add typed identity behavior through optional appended fields, new serializable
types, and new choices.

## Migration Evidence

The repeatable migration proof is:

```sh
cd /Users/x/cantonator/canton-contracts
./scripts/identity-hook-upgrade-smoke.sh
```

`scripts/manual-workflow-test.sh` also invokes that smoke script after the
scaffold check, so the cross-version proof is part of the repo-local manual
workflow entrypoint.

The smoke script refuses to start if the configured Ledger API or JSON API port
is already bound, starts the sandbox in its own process group, and terminates
that process group on exit. This keeps repeat runs from silently attaching to a
foreign or leaked sandbox.

The v1 fixture script creates a v0.1.0 holding and writes:

```json
{
  "issuer": "...",
  "alice": "...",
  "bob": "...",
  "holding": "..."
}
```

The v2 migration script takes that fixture and exercises
`ToyHolding_Transfer` from the v0.2.0 package. The script asserts:

- the successor owner is `bob`;
- the amount remains `125`;
- `identityExtension` is `None`.

This proves a v1-created holding remains transferable under v2 using the
unchanged baseline transfer choice. It also shows an operational caveat: the old
DAR must be uploaded or otherwise present on the participant before a script can
select or operate on old package IDs.

The v1 fixture script accepts a `runId` for live sandbox runs. That run id is
used in party hints so rerunning the proof against a persistent participant does
not collide with previously allocated parties.

## Breaking Boundary

The isolated scratch control copied v2 to:

```txt
/private/tmp/identity-hook-upgrade-breaking-control
```

Then it changed the existing `ToyHolding_Transfer` choice argument by adding a
required field:

```daml
requiredMemo : Text
```

`dpm build` failed with:

```txt
The upgraded input type of choice ToyHolding_Transfer on template ToyHolding
has added new fields, but the following new fields are not Optional:
  Field 'requiredMemo' with type Text
```

The failing control is not included in `multi-package.yaml` and is not part of
`dpm build --all`.

## D3 One-Pager Implications

The feasibility answer is yes, but constrained:

- A single-domain v1 hook can be upgraded later to add a typed identity claim
  path without breaking existing holdings if the old transfer choice remains
  stable.
- The typed path can be additive, but it is a new opt-in behavior. It does not
  retroactively make old transfers enforce typed identity claims.
- Source packages that directly construct upgraded records under v2 must supply
  new optional fields. Old v1-compiled consumers remain viable through SCU and
  package selection as long as upgraded optional fields are `None`.
- Cross-domain identity remains deferred. This spike names a typed claim and
  trusted issuer extension point only; it does not implement ONCHAINID,
  ERC-734/735, Chainlink CCID, bridges, or identity transport.

## Refined A-vs-B Recommendation

The prior `identity-hook-shape.md` recommendation favored candidate B because a
typed `KYC_VALIDATED` claim gives auditors concrete subject, issuer, freshness,
and trust-list fields.

This upgrade spike refines that recommendation:

- Keep candidate B as the preferred forward-compatible typed target.
- Avoid changing the baseline transfer choice into candidate B in place.
- If M1 starts with an A-like opaque hook, reserve the SCU path by keeping the
  old choice stable and adding the B-like typed behavior as a new choice plus
  optional extension config.

That gives the D3 one-pager a stronger claim: the typed path can layer on later
without breaking existing holdings, provided M1 accepts these upgrade
constraints and does not promise that old transfers automatically gain typed
claim enforcement.

Do not cite this as D3 closure. Cite it as local feasibility evidence for Amar
and Pepe, still subject to the D3 one-pager and any later production issuer,
legal, compliance, and counsel review.

## Teardown Checklist

Removing this spike later requires:

- deleting the four `experiments/identity-hook-upgrade-*` package directories;
- removing their entries from `multi-package.yaml`;
- deleting `scripts/identity-hook-upgrade-smoke.sh` and removing its call from
  `scripts/manual-workflow-test.sh`;
- removing the v2 DAR from `test/daml.yaml`;
- deleting `test/daml/OpenZeppelin/Test/IdentityHookUpgrade.daml`;
- deleting this note or replacing it with the accepted D3 one-pager reference;
- deleting any leftover local scratch directories such as
  `/private/tmp/identity-hook-upgrade-breaking-control` and repo-local sandbox
  logs under `.cache/identity-hook-upgrade-sandbox/`.
