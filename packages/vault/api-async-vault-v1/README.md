# Async Vault API V1

A Daml interface for a deposit gate: a contract an asynchronous vault asks
before it accepts a deposit request.

| Field | Value |
|---|---|
| Package | `openzeppelin-api-async-vault-v1` |
| Public module | `OpenZeppelin.Api.AsyncVaultV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

The interface uses the account and extra-argument types of the Token Standard
V2 interface DARs under [`dars/vendor/`](../../../dars/vendor/).

## What it provides

- `DepositGate`: the interface your template declares an instance of.
- `DepositGate_Check`: the choice a vault exercises when a requester opens a
  deposit request. The gate accepts by returning and refuses by failing.
- `DepositGateView`: the admin of the vaults the gate answers to.
- `DepositGate_CheckResult`: what the gate reports about a request it
  accepts.

The function that calls a gate from a vault, `checkDepositGate`, lives in
[`openzeppelin-async-vault-utils`](../async-vault-utils/). The `Vault`
template of [`openzeppelin-async-vault-v1`](../async-vault-v1/) names a gate
in its `depositGate` field.
[`openzeppelin-async-vault-permits-v1`](../async-vault-permits-v1/) is a gate
that admits the parties a validator enabled.

## Usage

Hold the rule on your own template and implement one method:

```daml
import OpenZeppelin.Api.AsyncVaultV1

template AllowList
  with
    admin : Party
    listed : [Party]
  where
    signatory admin

    interface instance DepositGate for AllowList where
      view = DepositGateView with admin
      depositGate_checkImpl _self arg = do
        unless (arg.requester.owner `elem` map Some listed) (failWithStatus eNotListed)
        pure DepositGate_CheckResult with meta = emptyMetadata
```

The method receives the vault's id, the requesting account, the amount, and
the extra arguments the requester passed for the vault. Put the vault's admin
in the view, and name the contract as the vault's gate.

## Authority and lifecycle

- `DepositGate_Check` is controlled by the admin in the gate's view. A vault
  exercises it from its request choice, where the admin's authority comes
  from the vault contract.
- The method runs with the authority of that admin and of the gate's
  signatories, and with nobody else's. It cannot act for the requester.
- The choice is nonconsuming, so any number of requests ask one gate at
  once.
- A requester must see the gate to open a request. The admin provides it by
  explicit disclosure, with the vault.

## Scope and security caveats

- A gate can fetch a contract only when the admin or one of the gate's
  signatories is a stakeholder of it. Evidence a requester presents must be
  signed by, or visible to, one of them.
- A vault calls a gate through the choice and never through the method. A
  method called directly runs with the authority of the choice that calls
  it, which in a vault's request choice includes the requester's.
- A vault must check that a gate's view names its own admin before it
  exercises the gate. A gate that named the requester would otherwise be
  exercised with the requester's authority. `checkDepositGate` makes that
  check.
- The admin lends its own authority to the gate's code, so the admin names
  only a gate whose template it trusts.
- A vault takes the gate's contract id from its own contract. A gate id
  supplied by the requester can be replaced by the requester.
- The interface covers deposit requests. It gives a gate no say over
  redemption requests, prices, or batches, and a gate cannot change an
  amount.
- The gate's signatories can archive it. A vault whose gate is gone opens no
  deposit request until its admin names another.

## Compatibility

The package builds with the workspace SDK declared in
[`multi-package.yaml`](../../../multi-package.yaml) and targets Daml-LF 2.1.
It defines interfaces and no templates. Daml interfaces are not upgradeable,
so a change to the interface is a sibling `-v2` package.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/vault/api-async-vault-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/vault/api-async-vault-v1/.daml/dist/openzeppelin-api-async-vault-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Api.AsyncVaultV1
```
