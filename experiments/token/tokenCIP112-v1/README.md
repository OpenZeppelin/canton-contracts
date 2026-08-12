# Token CIP-0112 V1

A CIP-0112-compliant token implementation built against the Token Standard V2
(TSv2) interfaces. It provides holdings, transfer instructions, allocations,
allocation requests, registry rules, event logging, and the D1/D2 compliance
hooks (node attestation and lawful-process seizure).

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
  settlement.
- `TokenAllocationRequest` (`AllocationRequest`): the app-side request that a
  wallet turns into an allocation.
- `TokenRules` (`Registry`): the registry rules contract implementing the TSv2
  transfer, allocation, and settlement factories.
- `TokenEventLog` (`Base`): the holdings-change event-log host.
- `TrustedAttesterRegistry`, `ComplianceAttestation`, and `SeizureOrder` (`D1`):
  D1 node-compliance attestation and the D2 lawful-process seizure authority.

Each public module implements the matching upstream `Splice.Api.Token.*V2`
interfaces. The package defines no Daml interfaces or exceptions of its own, so
it ships as a single implementation package.

## Authority and lifecycle

- The instrument admin and the account parties jointly maintain holdings.
- Wallets act through the TSv2 interface choices; the choice bodies validate
  identity, funding, and expiry before they move value.
- The admin configures D1 attestation and D2 seizure through registry hooks;
  a seizure sweep requires a non-admin `SeizureOrder` authority.
- The consuming application selects and discloses the canonical `TokenRules`
  contract for its instrument.

## Build

From the repository root:

```sh
DAML_PACKAGE=experiments/token/tokenCIP112-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/experiments/token/tokenCIP112-v1/.daml/dist/openzeppelin-tokenCIP112-v1-0.1.0.dar
```

```daml
import OpenZeppelin.TokenCIP112V1.Holding
```
