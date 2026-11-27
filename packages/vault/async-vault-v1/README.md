# Async Vault V1

Ready-to-use templates for an asynchronous vault, which takes deposit and
redemption requests and settles them in batches, at one price per batch. The
templates store the records of `openzeppelin-async-vault-types-v1` and
delegate their choice bodies to `openzeppelin-async-vault-utils`, which a
consumer who owns their own templates reuses directly.

| Field | Value |
|---|---|
| Package | `openzeppelin-async-vault-v1` |
| Public module | `OpenZeppelin.AsyncVaultV1` |
| Depends on | `openzeppelin-async-vault-types-v1`, `openzeppelin-async-vault-utils`, `openzeppelin-api-async-vault-v1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

The templates call registries through the Token Standard V2 interface DARs
under [`dars/vendor/`](../../../dars/vendor/).

## What it provides

- `Vault`: the vault's rules, which are its identity, the registries its
  requests are made on, and an optional deposit gate. Requesters open deposit
  and redemption requests on it.
- `VaultLedger`: what the vault records, which is its reserves, its shares
  outstanding, the price of the last batch, and the batch number, together
  with the price band and the batch size the operator is held to. Batches
  settle on it.
- `DepositRequest` and `RedeemRequest`: a pending request, whose funds are
  escrowed in an allocation of the Token Standard.
- `VaultLedger_SettleBatchResult`: the ledger after a batch and what each
  request received.
- `ledgerSignatories`: the parties that sign a vault's ledger.

Every choice body is a function of `openzeppelin-async-vault-utils` applied to
these templates. The templates add signatories, observers, controllers,
`ensure` clauses, the price band, and the batch size. The package defines no
Daml interfaces or exceptions.

## Authority and lifecycle

| Party | What it does |
|---|---|
| Admin | Signs the rules, every request, and the ledger. Sets the price band and the batch size. One of the two executors of the vault's settlement. |
| Operator | Settles batches at a price it chooses within the band, records the reserves, rejects requests, and drops expired ones. The other executor. |
| Share instrument's admin | Signs the ledger, so a batch can issue and burn shares. |
| Custodian's account parties | Sign the ledger, so a batch can move the pool. |
| Requester | Opens its own requests and cancels them. |

One party can hold several of these roles. When the vault's admin is also the
share instrument's admin and the custodian, the ledger has one signatory.

- **Request.** A requester exercises `Vault_RequestDeposit` or
  `Vault_RequestRedeem` alone, with the `Vault` and the registries' allocation
  factories disclosed to it. The choice escrows the funds in the requester's
  own holdings and creates the request. Both choices are nonconsuming and
  read no price, so requests contend neither with each other nor with a
  batch. A request spends only the requester's own holdings: the custodian's
  holdings are spent by `VaultLedger_SettleBatch` alone, so no requester
  contends on the pool.
- **Decide who may deposit.** A `Vault` with a `depositGate` asks that
  contract before it opens a deposit request, and the gate refuses by
  failing. The gate is any contract that implements the `DepositGate`
  interface of
  [`openzeppelin-api-async-vault-v1`](../api-async-vault-v1/), and the
  requester receives it by explicit disclosure. The request's `vault` extra
  arguments reach the gate, so that is where a requester shows a credential.
  [`openzeppelin-async-vault-permits-v1`](../async-vault-permits-v1/) is a
  gate that admits the parties a validator enabled. Redemption requests ask
  no gate.
- **Settle.** The operator exercises `VaultLedger_SettleBatch` alone, with
  one price, the requests it settles, and the custodian's holdings that fund
  the payouts. In one transaction every request is filled at that price, the
  tokens of both instruments move, every request is consumed with its fill,
  and the ledger is replaced by one that records the price and counts the
  batch. A batch that cannot settle whole settles nothing. The next batch
  settles at its own price within the band.
- **End a request without settling it.** The requester cancels with
  `DepositRequest_Cancel` or `RedeemRequest_Cancel`, and the operator rejects
  with `DepositRequest_Reject` or `RedeemRequest_Reject`. Either releases the
  escrow to the requester in the same transaction. From a request's deadline
  on, the operator drops it with `DepositRequest_Expire` or
  `RedeemRequest_Expire`, which releases nothing: the requester withdraws the
  allocations on their registries.
- **Record the reserves.** The operator exercises
  `VaultLedger_RecordReserves` with the custodian's holdings, and the ledger
  records their sum.
- **Hold the operator to a band.** The admin exercises
  `VaultLedger_SetPriceBand` and `VaultLedger_SetMaxBatchSize`. A batch
  settles at a price up to `maxDeviation` above or below `referencePrice`.
  The band stays where the admin put it, whatever prices batches settle at.
  With a `maxDeviation` of zero the operator settles at the reference price
  only, and the admin decides every price by moving the reference.

Every choice that changes the ledger consumes it and creates its successor,
so the ledger has one writer at a time. A batch built on a ledger that has
since been replaced fails and is submitted again.

Visibility:

- A requester sees its own requests and what each was filled with. It sees
  no other requester's request and not the ledger.
- The operator observes the rules, every request, and the ledger.
- A wallet that shows the vault's reserves or its last price receives the
  `VaultLedger` by explicit disclosure from one of its signatories.

## Security caveats

- A `Vault` without a `depositGate` is open to every depositor. With one,
  who may deposit is whatever that contract decides. The vault exercises the
  gate with its admin's authority alone, so the gate's code cannot act for
  the requester, and it refuses a gate whose view does not name its admin.
  The admin lends the gate its own authority, so it names only a gate whose
  template it trusts.
- A gate that its signatories archive blocks every deposit request until the
  admin replaces the `Vault` with one that names another gate.
- The operator chooses the price of every batch within the band. A wide band
  is wide discretion: with a `maxDeviation` of one, a batch settles at any
  price from nothing to twice the reference. Each requester bounds its own
  fill with the minimum in its terms, and holders who are not in a batch rely
  on the band alone.
- The operator also chooses when a request settles, up to the request's
  deadline, and so which batch's price it is filled at. A gain or a loss the
  custodian has had outside a batch is in no price until the operator's
  price counts it. A requester chooses no price and settles nothing; it
  bounds its fill with its minimum and its deadline, and cancels at any
  time.
- A redemption is paid only when the operator settles the batch that names
  it, and a request is opened only on a `Vault` the admin keeps active.
  Nothing on the ledger makes the operator settle a request or the admin
  keep the rules, so a holder relies on both for an exit. A pending request
  depends on neither: its requester cancels it alone, with no contract
  disclosed, and has the escrow back in the same transaction.
- The ledger's signatories can archive it and create another that records any
  reserves, any share total, and any price. What the ledger records is what
  they state, and its history is the sequence of choices exercised on it.
- No contract is the one `Vault` or the one `VaultLedger` of a vault id. The
  admin can create several of either, so a requester or a wallet takes the
  contracts to use from the admin.
- `Vault` and `VaultLedger` each name the registries. A ledger whose
  registries are not the ones the requests were made on settles no batch.
- A request is opened with the requester's authority on the allocation
  factories the `Vault` names. A requester checks that they are the ones the
  instruments' registries publish before submitting.
- The admin and the operator together can consume a request through
  `DepositRequest_Fill` or `RedeemRequest_Fill` outside a batch. That moves
  nothing, and the escrow stays the requester's to withdraw on its registry.
  As the two executors of the settlement they can also settle an escrow to
  the custodian without issuing shares, as the
  [utils `README.md`](../async-vault-utils/README.md) describes.
- A ledger settles only requests that name its vault's admin, operator, and
  id. A request carries the admin's signature, so one that passes was opened
  through a `Vault` of that admin or created by the admin directly.
- The recorded reserves are a lower bound of what the custodian held when
  they were last recorded, and follow only batches since. The
  [utils `README.md`](../async-vault-utils/README.md) states what counts as a
  holding and what the record does not prove.

## What it does not solve

- The package has no fee, no partial fill, and no valuation of the vault's
  assets. A price is correct as far as the operator who supplies it and the
  band that admits it make it so.
- The rules cannot be changed in place, the gate included. The admin
  archives the `Vault` and creates another; requests already open are
  unaffected, because they name the vault by its admin, operator, and id.
- A request that its requester cancels, or the operator rejects, while a
  batch that names it is on its way fails that batch.
- Nothing bounds how many requests a party has open, how often it opens
  one, or how small a request is. A gate can refuse a deposit by its amount;
  no gate is asked about redemptions.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/vault/async-vault-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/vault/api-async-vault-v1/.daml/dist/openzeppelin-api-async-vault-v1-0.1.0.dar
  - ../canton-contracts/packages/vault/async-vault-types-v1/.daml/dist/openzeppelin-async-vault-types-v1-0.1.0.dar
  - ../canton-contracts/packages/vault/async-vault-utils/.daml/dist/openzeppelin-async-vault-utils-0.1.0.dar
  - ../canton-contracts/packages/vault/async-vault-v1/.daml/dist/openzeppelin-async-vault-v1-0.1.0.dar
```

```daml
import OpenZeppelin.AsyncVault.TypesV1
import OpenZeppelin.AsyncVaultV1
```

[`examples/vault/async-vault-fund-test`](../../../examples/vault/async-vault-fund-test/)
runs these templates end to end with a deposit gate and the
`openzeppelin-token-cip112-v1` registry for both instruments.
