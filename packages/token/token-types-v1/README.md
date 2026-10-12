# Token CIP-0112 V1 types

The records a CIP-0112 (Token Standard V2) registry's templates store.

| Field | Value |
|---|---|
| Package | `openzeppelin-token-types-v1` |
| Public module | `OpenZeppelin.Token.TypesV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `RegistryConfig`: the instrument admin, the `maxTTL` storage bound, and the
  `lockGrace` a funding lock outlives its workflow contract by.
- `TransferInstructionState`: the payload of a pending transfer instruction.
- `AllocationState`: the payload of an allocation, with the registry's
  `maxTTL` and `lockGrace` snapshotted at allocation time.

The functions of `openzeppelin-token-utils` read and return these
records, and the templates of `openzeppelin-token-v1` store them. The
package defines no templates, interfaces, or functions.

## Compatibility

The package is the first release of the `openzeppelin-token-types-v1`
SCU lineage. A template that stores one of these records binds itself to that
lineage, so later versions only append `Optional` fields. A template that
stores the fields itself and builds the record per call keeps its payload
independent of this package.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/token/token-types-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/token/token-types-v1/.daml/dist/openzeppelin-token-types-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Token.TypesV1
```
