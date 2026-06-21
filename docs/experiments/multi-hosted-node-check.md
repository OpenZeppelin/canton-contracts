# Multi-Hosted Party + Node-Side Check Experiment

Status: experimental, local harness-availability evidence, settlement-leg
refresh, non-public, and outside the committed M1 library surface.

This note records Tier 1 experiment 3 from root `PLAN.md` -> "Experimentation
Priorities": whether the local Canton 3.4.11 / DPM setup can exercise a
multi-hosted acting party through a D1 node-side compliance check. The
2026-06-16 refresh re-ran that question against the current experimental
CIP-0112 / CIP-112 settlement scaffold. The answer for this workspace remains a
harness-availability result, not multi-hosted interaction evidence: no
multi-hosted party was created, and no node-side compliance check was run
through multi-participant topology.

The substantive output of this refresh is the blocker/runbook request below,
not empirical topology evidence. It does not answer which node is
authoritative, how attestation routes, or whether arbitrary N-of-M thresholds
are locally available. Do not cite it as D4 progress beyond clarifying the
missing runbook needed before D4 can rely on Option B.

Root `PLAN.md` records D1 as no-cache, fail-closed, node-side compliance
checking. D2 routes seizure to a deployer-configurable custodian destination.
D3 is single-domain v1 with cross-domain identity deferred. D4 remains open;
this experiment does not choose on-ledger multi-sig or Canton-topology
multi-hosted-party authority.

## Settlement-Leg Refresh Scope

The refreshed target was the current settlement scaffold:

- package: `experiments/cip112-settlement`;
- module: `OpenZeppelin.Experimental.Settlement.Cip112`;
- tests: `test/daml/OpenZeppelin/Test/Cip112Settlement.daml`.

The scaffold's D1 extension point is `D1ComplianceHook` plus an optional
`d1ComplianceRef` passed to `SettlementFactory_SettleBatch` and
`Allocation_Settle`. The current tests prove only a Daml contract-side guard:
when this experiment-only hook requires a reference and none is supplied, the
settlement choice fails. That is deliberately not evidence for D1's accepted
node-side placement. It is not production KYC, sanctions, validator, node
attestation, participant routing, or compliance service logic.

D2 in-flight settlement handling remains open under S1. The scaffold
deliberately blocks settlement when a D2 in-flight seizure marker is present,
so this refresh does not finalize in-flight seizure routing or containment.

## Local Mechanism Evidence

Commands and source evidence inspected locally before this refresh:

- `git status --short` in `canton-contracts` showed a pre-existing dirty tree
  with prior experiment/scaffold changes before this note was added.
- `dpm version` reported installed SDKs `3.4.10` and active `3.4.11`.
- `dpm --help` exposes `build`, `test`, `script`, `sandbox`, and
  `canton-console`.
- `dpm sandbox --help` reports `Canton v3.4.11` and the sandbox command exposes
  one Ledger API port, one Admin API port, one JSON API port, sequencer ports,
  mediator ports, `--canton-port-file`, and `--dar`. It does not expose a
  multi-participant, shared-party, party-hosting, or threshold flag.
- `dpm script --help` accepts one `--ledger-host` and one `--ledger-port`, plus
  `--participant-config` for participant connection details. It does not expose
  topology administration or party-hosting controls.
- `dpm canton-console generate/run/daemon --help` rejected those subcommands as
  `Unknown argument`, so the DPM wrapper available here is not a general
  config-backed Canton `run` facility for this repo.
- `README.md` describes the M0 LocalNet proof as a single-participant sandbox
  proof. The referenced root `scripts/localnet-up.sh`,
  `scripts/localnet-hello-world-proof.sh`, and `scripts/localnet-down.sh` are
  not present in `/Users/x/cantonator` or `canton-contracts/scripts/` as of
  this spike.
- The same README also points at root `./scripts/check-all.sh`,
  `./scripts/test-all.sh`, and `./scripts/manual-workflow-tests.sh`, but the
  current `/Users/x/cantonator` root has no `scripts/` directory. The target
  repo has `scripts/manual-workflow-test.sh` singular plus repo-local checks,
  not the plural root workflow scripts named in the README. Treat that broader
  workflow-documentation drift as a precondition before re-running this
  experiment.
- `scripts/identity-hook-upgrade-smoke.sh` starts `dpm sandbox` with one Ledger
  API port and one JSON API port, then runs `dpm script --upload-dar true`
  against that single endpoint.
- `find /Users/x/cantonator -maxdepth 3 -type f -path '*/scripts/*'` found
  only repo-local scripts in sibling repos; it found no shared LocalNet wrapper
  that configures multiple participants or shared-party topology for
  `canton-contracts`.
- `/Users/x/.local/bin/canton` is a local launcher for the DPM-installed
  `canton-enterprise-3.4.11.jar`, and `canton --version` reports Canton and
  Daml Libraries `3.4.11`. That wrapper is available as toolchain evidence, but
  this repo's accepted validation path remains DPM-native and there is no
  repo-local multi-participant Canton config to run through it.
- Prior local planning evidence in
  `/Users/x/cantonator/canton-token-template/docs/SCOPE.md` says Canton topology
  supports shared parties as multiple participants backing one logical party.
  `/Users/x/cantonator/canton-token-template/docs/ADMIN-LAYER-PLAN.md` records
  "Multisig owner" as a multi-hosted Canton party with no Daml change. Those are
  useful architectural references, not executable threshold evidence in this
  repo.

Refreshed command evidence for the settlement-leg slice:

- `git -C canton-contracts status --short` still showed a pre-existing dirty
  tree before this refresh, including modified scaffold files and untracked
  `docs/`, `experiments/`, and settlement/compliance/identity test files. This
  refresh preserves that state.
- `dpm version` reported installed SDKs `3.4.10` and active `3.4.11`.
- `dpm build --all` passed against the current scaffold. It built or reused all
  packages including `experiments/cip112-settlement` and `test`.
- `cd test && dpm test` passed. The `Cip112Settlement` scripts included the
  happy settlement path, `test_cip112Settlement_missingD1ReferenceFails`, and
  `test_cip112Settlement_d2InFlightSeizureBlocksSettlement`. This proves the
  local Daml settlement-leg hook behavior, not topology routing.
- `dpm sandbox --help` still reports `Canton v3.4.11` and exposes one Ledger
  API port, one Admin API port, one JSON API port, sequencer ports, mediator
  ports, `--canton-port-file`, and `--dar`; it does not expose a flag for
  multiple participants, shared-party hosting, threshold selection, or topology
  transactions.
- `dpm script --help` still accepts either one `--ledger-host` / `--ledger-port`
  endpoint or `--participant-config` JSON. It does not create participants or
  shared-party topology by itself.
- `dpm canton-console --help` maps to sandbox-console help, but
  `dpm canton-console run --help`, `dpm canton-console generate --help`, and
  `dpm canton-console daemon --help` each printed `Error: Unknown argument`.
  The DPM wrapper available in this repo therefore still does not expose the
  full config-backed Canton `run` / `generate` / `daemon` workflow.
- `canton --version` reports Canton and Daml Libraries `3.4.11`.
- `canton --help` exposes full Canton `daemon`, `run`, `generate`, `sandbox`,
  and `sandbox-console` commands, but those paths require an explicit config or
  the built-in sandbox defaults.
- Inspecting the installed `canton-enterprise-3.4.11.jar` built-in
  `sandbox/sandbox.conf` showed one participant only:
  `canton.participants.sandbox`. The built-in `sandbox/bootstrap.canton`
  connects only that participant with
  `sandbox.synchronizers.connect_local(sequencer1, "mysynchronizer")`.
- `canton generate remote-config` failed with
  `Error: at least one config has to be defined either as files (-c), as
  key-values (-C) or as sandbox's default config`, confirming the direct
  Canton path needs a concrete config before it can be used as a local
  multi-participant runbook.
- `find /Users/x/cantonator -maxdepth 4 \( -type f -name '*.conf' -o -type f
  -name '*.canton' -o -type f -name '*topology*' \) -print` returned no
  workspace config, bootstrap, or topology files.
- `find /Users/x/cantonator -maxdepth 3 -type f -path '*/scripts/*' -print`
  found repo-local validation scripts, including
  `canton-contracts/scripts/identity-hook-upgrade-smoke.sh`, but no script that
  configures multiple participants, creates/imports a shared party, or runs a
  settlement script through multiple participant endpoints.

## Result

True multi-hosted-party topology still could not be exercised locally through
the accepted `canton-contracts` DPM/Canton path. The settlement scaffold can be
built and tested locally, and the settlement-leg experiment has a contract-side
missing-reference failure. That is single-runner Daml evidence inherited from
the settlement scaffold; it is not evidence of node-side D1 enforcement. It
does not answer which participant is authoritative for a no-cache node-side
compliance check when an acting party is shared across participants.

No toy Daml substitute was added. A Daml template or Daml Script can model an
admin party, an attestation contract, or a list of approvers, but it cannot prove
which participant hosts a Canton party, which participant is authoritative for a
node-side check, or which threshold modes are executable in the Canton topology
available to this repo. Treating such a model as this experiment's result would
overstate the evidence.

No local settlement-leg topology harness was added. A bounded harness would need
at minimum a real multi-participant Canton config, a bootstrap that creates or
imports the shared party, package-vetting/upload steps for the settlement DAR on
each participant, and a Daml Script participant-config that submits the
settlement leg through the intended participant endpoint. Those ingredients are
not present in the workspace.

## Observations

- In the only runnable local DPM path, the sandbox has one participant endpoint.
  That single participant is therefore the only observable authority for a
  node-side check in local scripts. This observation is not a D4 answer because
  it is not a shared-party topology.
- No empirical multi-hosted answer was obtained for "which participant/node is
  authoritative" when the acting party spans participants. That remains a D4
  review question.
- No empirical routing answer was obtained for settlement-leg node-side check
  evidence under a multi-hosted party. The earlier compliance-shape
  experiment's Shape B attestation contract and the CIP-112 scaffold's
  `d1ComplianceRef` are useful Daml design evidence, but neither proves
  participant-node routing.
- No empirical threshold answer was obtained. The local DPM command surface did
  not make arbitrary N-of-M or N-of-N shared-party topology locally executable.
  This is not evidence that Canton lacks either capability; it only means this
  repo cannot validate those semantics today.
- The D2 in-flight seizure marker remains intentionally blocking in the
  settlement scaffold. Do not use this experiment to infer an accepted
  in-flight seizure policy.

## Canton Runbook Request

To turn this from harness-availability evidence into interaction evidence, the
Canton stakeholder/runbook request is:

1. Provide a Canton 3.4.11-compatible LocalNet config for `canton-contracts`
   with at least two participant nodes on one synchronizer.
2. Provide the bootstrap/topology commands that create or import one shared /
   multi-hosted acting party across those participants.
3. State whether the supported topology is arbitrary N-of-M, N-of-N only, or
   some other participant-authorization threshold model, and show the topology
   transaction evidence for the configured threshold.
4. Provide package-vetting/upload steps for the experimental
   `oz-experimental-cip112-settlement-0.1.0.dar` on every participant that must
   submit or validate the settlement leg.
5. Provide a `dpm script --participant-config` shape, or an equivalent accepted
   Canton command sequence, that submits a CIP-112 settlement leg as the shared
   acting party and records which participant endpoint accepted the command.
6. Specify which participant/node is authoritative for the D1 no-cache,
   fail-closed compliance check when the acting party is shared, how any
   Daml-visible `d1ComplianceRef` or node-attestation evidence should route,
   and what happens when one hosting participant denies the check or is
   unavailable.

This runbook should remain about topology, routing, and evidence collection. It
should not introduce production KYC/sanctions services or resolve the D2
in-flight policy.

## D4 Impact

This refresh does not move D4 toward acceptance. It leaves the proposed Option
B default unaccepted until real topology evidence is collected. It does not
disprove multi-hosted-party authority or make a claim about Canton's full
topology feature set, but it shows that the current `canton-contracts` local
proof surface still cannot validate the D4 threshold and node-side-check
questions on the settlement-leg path.

Before M1 authority-model wording relies on Option B, obtain one of:

- a repo-local DPM-native multi-participant LocalNet harness that creates or
  imports a shared party and exercises the CIP-112 settlement-leg D1 check
  path; or
- an accepted Canton topology runbook from the Canton stakeholders that names
  the participant authoritative for the check, evidence routing, and threshold
  semantics.

Until then, D4 remains open. Do not write M1 docs that assume the
multi-hosted-party path supports arbitrary thresholds or that a specific hosted
participant performs the D1 check.

Also resolve the local README/script drift before re-running the experiment:
either restore the documented root LocalNet/manual workflow scripts or update
the README to point at the current repo-local DPM scripts and the actual
singular `scripts/manual-workflow-test.sh` entrypoint.

## Touched Daml Surface

None. No Daml template or interface was added or changed.

## Appendix: Teardown Checklist

This note is documentation-only. Removing it later requires deleting this file
and removing the related link from root `docs/decisions/D4_MULTISIG.md`.
