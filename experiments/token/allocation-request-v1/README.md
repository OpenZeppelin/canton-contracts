# Allocation Request V1

An app-side allocation request for Token Standard V2 (TSv2) settlement
workflows: a settlement app asks a single authorizer to create allocations for
a settlement. No token registry is involved; accepting is a signal, and
creating the actual allocations is a separate step against the authorizer's
token registry, which wallets may batch into the accepting transaction.

| Field | Value |
|---|---|
| Package | `openzeppelin-allocation-request-v1` |
| Public module | `OpenZeppelin.AllocationRequestV1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Standard | [CIP-0112](https://github.com/global-synchronizer-foundation/cips) / Token Standard V2 |

> [!WARNING]
> The Token Standard V2 interfaces are devnet-stage upstream. The vendored DARs
> under [`dars/vendor/`](../../../dars/vendor/) are local builds from a pinned
> splice commit; every package ID changes when upstream cuts a release. See
> [`dars/manifest.yaml`](../../../dars/manifest.yaml) for provenance.

## What it provides

- `TokenAllocationRequest`: implements the TSv2
  `Splice.Api.Token.AllocationRequestV2.AllocationRequest` interface with
  accept, reject, and withdraw.

## Authority and lifecycle

- The settlement executors sign the request; the authorizer's account parties
  observe it.
- Accept and reject consume the whole request, so a request speaks for exactly
  one authorizer account; apps create one request per authorizer. A request
  spanning several authorizers is rejected at creation.
- Any single account party of the authorizer accepts or rejects; the executors
  jointly withdraw. Accept, reject, and withdraw disclose the outcome to the
  request's observers.
- Temporal coherence is enforced at creation: a request must not ask for
  allocations whose settlement deadline precedes the request itself or the
  expected settlement time, which no authorizer could ever satisfy.
- Accepting archives the request and creates nothing else. The consuming
  application defines how the accepted request becomes allocations on its
  token registry.

## Build

From the repository root:

```sh
DAML_PACKAGE=experiments/token/allocation-request-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/experiments/token/allocation-request-v1/.daml/dist/openzeppelin-allocation-request-v1-0.1.0.dar
```

```daml
import OpenZeppelin.AllocationRequestV1
```
