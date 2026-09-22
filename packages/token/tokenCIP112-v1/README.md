# Token CIP-0112 V1

A CIP-0112-compliant token implementation built against the Token Standard V2
(TSv2) interfaces. It provides holdings, transfer instructions, allocations,
registry rules, and event logging.

| Field | Value |
|---|---|
| Package | `openzeppelin-tokenCIP112-v1` |
| Public module | `OpenZeppelin.TokenCIP112V1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |
| Standard | [CIP-0112](https://github.com/global-synchronizer-foundation/cips) / Token Standard V2 |

> [!WARNING]
> The Token Standard V2 interfaces are devnet-stage upstream. The vendored DARs
> under [`dars/vendor/`](../../../dars/vendor/) are local builds from a pinned
> splice commit; every package ID changes when upstream cuts a release. See
> [`dars/manifest.yaml`](../../../dars/manifest.yaml) for provenance.

## What it provides

- `TokenHolding` (`Holding`): an asset holding maintained jointly by the
  instrument admin and the account parties, with optional locks.
- `TokenTransferInstruction` (`Transfer`): the TSv2 transfer-instruction
  lifecycle, including accept, reject, withdraw, and expiry paths.
- `TokenAllocation` (`Allocation`): ready-to-settle allocations backed by
  locked holdings, with exact-cover batch settlement and CIP-0112 iterated
  settlement.
- `TokenRules` (`Registry`): the registry rules contract implementing the TSv2
  transfer, allocation, and settlement factories.
- `TokenEventLog` (`Base`): the holdings-change event-log host.

Each public module implements the matching upstream `Splice.Api.Token.*V2`
interfaces. The package defines no Daml interfaces or exceptions of its own, so
it ships as a single implementation package.

## Authority and lifecycle

- The instrument admin and the account parties jointly maintain holdings.
- Wallets act through the TSv2 interface choices; the choice bodies validate
  identity, funding, and expiry before they move value.
- An allocation created with `nextIterationFunding` set enables iterated
  settlement: the executors supply extra transfer legs per settlement
  iteration, bounded by the locked reserve plus incoming credits, and may
  reserve funding for a successor allocation created in the same transaction.
  A settle with no reservation ends the chain and releases all proceeds
  unlocked. Successors carry the original settlement deadline and commitment,
  clear the leg set, and bump the storage expiry using the registry
  configuration snapshotted at allocation time. The authorizer withdraws a
  successor like any other allocation.
- The consuming application selects and discloses the canonical `TokenRules`
  contract for its instrument.
- Only regular (owned) accounts author allocations and hold balances. The
  special mint and burn accounts appear in events as the other side of supply
  changes and nowhere else; supply changes go through `TokenRules_Mint` and
  `TokenRules_Burn`.

For multi-participant deployment, disclosure, and wallet integration, see
[`integration-guide.md`](integration-guide.md).

## Standards conformance

The package implements Token Standard V2 (CIP-0112).

The V2 interface hierarchy is parallel to V1: the two share only
`splice-api-token-metadata-v1`, so V1 tooling cannot see this token. When a
deployment target requires V1 visibility, add the V1 interface instances to
the same templates: the V1 DARs are vendored under
[`dars/vendor/`](../../../dars/vendor/), and the vendored utils ship
`...V1...DefaultImplUsingV2` helpers for exactly this pattern.

## Compatibility

The package builds with the workspace SDK declared in
[`multi-package.yaml`](../../../multi-package.yaml) and targets Daml-LF 2.1.
It is the first release of the `openzeppelin-tokenCIP112-v1` SCU lineage:
templates upgrade in place, and the vendored interface DARs are pinned until
upstream cuts a release (see the warning above).

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/token/tokenCIP112-v1 dpm build
```

## Security caveats

- The exact-cover check runs only inside `SettlementFactory_SettleBatch`. A
  direct `Allocation_Settle` by the admin plus the executors bypasses it and
  can create or destroy value, so the admin's authority must never co-sign a
  settle outside the factory. Operate the admin party so that it signs settles
  only through the settlement factory. See `ideas.md` on reintroducing the
  on-ledger guard that removes this trust assumption.
- The vendored settlement-factory default does not validate a
  `FinalizedAllocation.nextIterationFunding`; the check in
  `allocation_settleImpl` is the effective guard. Registry forks that replace
  that choice body must keep an equivalent check.
- `maxTTL` and `lockGrace` are only required to be positive. A `lockGrace` too
  short for the admin's cleanup automation to act in leaves expiry to the
  owner-recovery path; size it to the automation's reaction time (minutes to
  hours), and size `maxTTL` to the longest workflow the registry accepts.
- Recovering an expired-lock holding through `TokenHolding_OwnerUnlock` needs
  every account party. On accounts with a distinct provider, an unresponsive
  provider blocks recovery until it cooperates; single-party accounts avoid
  this.
- An allocation's view advertises the withdraw action statically. For a
  committed allocation the choice still fails until the settlement deadline
  passes; wallets should treat the advertised action as "who", not "when".

## Sandbox validation

`dpm test` runs the test suite on an in-memory ledger. The sandbox gate runs
token creation, transfer, querying, and burn against a real static-time
Canton sandbox over the Ledger API. From the repository root:

```sh
scripts/check-sandbox.sh
```

The script requires:

- `dpm` on the `PATH`
- Java 21 or newer
- `lsof`
- A free Ledger API port (`6865` by default; override with `OZ_LEDGER_PORT`)

Logs are written under `.cache/sandbox-token/`. To target a running ledger
instead of the script-managed sandbox, set `OZ_USE_EXTERNAL_LEDGER=1`,
`OZ_LEDGER_HOST`, and `OZ_LEDGER_PORT`. The external ledger must run in
static-time mode with its clock at or before 2026-01-01T00:10Z: the scripts
pin the clock with `setTime`, and a static-time ledger only moves its clock
forward.

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/token/tokenCIP112-v1/.daml/dist/openzeppelin-tokenCIP112-v1-0.1.0.dar
```

```daml
import OpenZeppelin.TokenCIP112V1.Holding
```
