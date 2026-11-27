# Async Vault V1 types

The records an asynchronous vault's templates store. An asynchronous vault
takes deposit and redemption requests and settles them in batches, at one
price per batch.

| Field | Value |
|---|---|
| Package | `openzeppelin-async-vault-types-v1` |
| Public module | `OpenZeppelin.AsyncVault.TypesV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `VaultConfig`: the vault's `admin` and `operator`, its `vaultId`, the
  `underlying` and `share` instruments, and the `custodian` account that holds
  the pool.
- `VaultRegistries`: the allocation and settlement factories of the two
  instruments' registries, as the vault's admin chooses them.
- `SharePrice`: a price as a ratio, `priceAssets` units of the underlying
  for `priceShares` shares.
- `VaultState`: what a vault records, rewritten once per batch and whenever
  its reserves are recorded again: the `reserves` it counts as held by its
  custodian, the `totalShares` outstanding, the `price` the last batch
  settled at, and the number of batches settled.
- `DepositTerms` and `RedeemTerms`: what a requester asks for: the account,
  a label, the amount, an optional minimum, and a deadline.
- `DepositRequestState` and `RedeemRequestState`: the payload of a pending
  request, which is its terms, the vault it is for, and the two allocations
  that escrow the funds and authorize the receipt of the proceeds.
- `RequestArgs`: the extra arguments a request passes along, one set for each
  registry and one for the vault's policy.
- `Fill` and `SettledBatch`: what each request received when its batch
  settled, and the state to record after it.

The functions of `openzeppelin-async-vault-utils` read and return these
records. The package defines no templates, interfaces, or functions.

The instrument, account, and allocation types are those of the Token Standard
V2 interface DARs under [`dars/vendor/`](../../../dars/vendor/).

## What it does not solve

- The records are data. Naming a party as `admin` or `operator` gives it no
  authority; signatories, observers, and controllers are for the template
  that stores the record to declare.
- A `vaultId` does not identify one contract. Nothing in the package keeps two
  contracts from carrying the same config, so a consumer decides which one is
  the vault.
- A `VaultState` is a record. On its own it does not prove that the
  custodian holds the `reserves`, and its `price` is the price a batch was
  settled at, not a valuation of the vault's assets.
- The allocation ids in a request are not checked. A record does not prove
  that an id points at an allocation of an accepted implementation, that the
  allocation has the terms the field comments describe, or that it is still
  active.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/vault/async-vault-types-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/vault/async-vault-types-v1/.daml/dist/openzeppelin-async-vault-types-v1-0.1.0.dar
```

```daml
import OpenZeppelin.AsyncVault.TypesV1
```
