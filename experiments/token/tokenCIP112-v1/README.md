# Token CIP-0112 V1

A CIP-0112-compliant token implementation built against the Token Standard V2
(TSv2) interfaces. It provides holdings, transfer instructions, allocations,
registry rules, and event logging.

| Field | Value |
|---|---|
| Package | `openzeppelin-tokenCIP112-v1` |
| Public module | `OpenZeppelin.TokenCIP112V1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
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
- `TokenAllocation` and `BatchSettlementAuthorization` (`Allocation`): ready-to-
  settle allocations backed by locked holdings, with exact-cover batch
  settlement and CIP-0112 iterated settlement.
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

## Standards conformance

The package implements Token Standard V2 (CIP-0112).

The V2 interface hierarchy is parallel to V1: the two share only
`splice-api-token-metadata-v1`, so V1 tooling cannot see this token. When a
deployment target requires V1 visibility, add the V1 interface instances to
the same templates: the V1 DARs are vendored under
[`dars/vendor/`](../../../dars/vendor/), and the vendored utils ship
`...V1...DefaultImplUsingV2` helpers for exactly this pattern.

## Build

From the repository root:

```sh
DAML_PACKAGE=experiments/token/tokenCIP112-v1 dpm build
```

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
  - ../canton-contracts/experiments/token/tokenCIP112-v1/.daml/dist/openzeppelin-tokenCIP112-v1-0.1.0.dar
```

```daml
import OpenZeppelin.TokenCIP112V1.Holding
```
