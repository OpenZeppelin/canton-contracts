# Async Vault Fund Example

End-to-end integration of the asynchronous vault: a fund whose investors ask
to deposit and to redeem, and whose operator settles their requests in
batches, at one price per batch. The ready-made vault templates, the permits
deposit gate, and the CIP-0112 token registry run together, with no template
of the example's own.

| Field | Value |
|---|---|
| Package | `async-vault-fund-example-test` |
| Modules | `OpenZeppelin.Examples.AsyncVault.Fund` |
| Consumes | `openzeppelin-async-vault-v1` `0.1.0`, `openzeppelin-async-vault-permits-v1` `0.1.0`, `openzeppelin-token-cip112-v1` `0.1.0`, `openzeppelin-scoped-authorization-grant-v1` `0.1.0` |

## What it shows

- Launching a vault: the admin creates the permit rules, a `Vault` that names
  them as its deposit gate, and an empty `VaultLedger` with a price band.
- Both instruments on `TokenRules` registries: the issuer's for the
  underlying, and the vault admin's own for the shares. The vault calls them
  through the Token Standard V2 interfaces only.
- Who may deposit: the admin appoints a validator, and the validator enables
  one party at a time. Under the same-namespace rule it enables a party of
  its own participant and is refused for a party of another.
- A request made alone: the investor submits with its permit and the
  contracts it is shown, and the assets stay locked in its own holdings until
  the batch. A party without a permit is refused.
- A batch settled alone by the operator, at a price it chooses. A price
  outside the admin's band is refused, and so is a price that gives a
  requester less than the minimum in its request.
- A new price: the pool earns outside any batch, the operator records the
  reserves, and one batch settles a deposit and a redemption together, the
  deposit paying the redemption.
- Withdrawing a validator: the admin revokes its appointment, the party it
  enabled can no longer deposit, and that party still redeems every share.
- Tracking the pool: the admin has the ledger name the custodian's holdings
  behind its reserves, each batch is funded from them and leaves the
  holdings the registry returned, and a gain paid in outside a batch joins
  the pool when the operator records the reserves.

`OpenZeppelin.Examples.AsyncVault.Fund` carries four scripts:
`demoPermittedDeposit` runs the gate and a first batch,
`demoPriceChangeAndRedemption` runs a batch at a new price,
`demoAccessWithdrawn` runs the withdrawal of a validator, and
`demoTrackedPool` runs a ledger that tracks its pool.

## Authority model

| Party | Role |
|---|---|
| `issuer` | Admin of the underlying's registry. |
| `admin` | The vault's admin. Also the admin of the share instrument's registry and the owner of the custodian account, so it signs the vault's ledger alone. |
| `operator` | Chooses each batch's price within the admin's band and settles the batch. |
| `validator` | Appointed by the admin to enable depositors. |
| `alice`, `bob` | Investors the validator enables. |

Every submission has one submitter. What a submitter does not see as a
stakeholder it receives by explicit disclosure, and the scripts build each
disclosure by querying as a signatory:

| Submitter | Is shown |
|---|---|
| Validator, to enable a party | The permit rules. |
| Investor, to ask for a deposit | The vault, both registries, the permit rules, and the validator's appointment. It observes its own permit. |
| Investor, to ask for a redemption | The vault and both registries. |
| Operator, to settle a batch | Both registries, the locked holdings behind every escrow, and the custodian's holdings that fund the payouts. |

A registry's admin is the only lock holder of an escrow's funding, so each
registry serves the locked holdings of its own instrument.

## Ledgers

The scripts run on the in-memory ledger of `dpm test` and on a Canton sandbox
with two participants. On Canton the vault's parties and both registries are
on one participant, and the validator and its investors on the other, so the
same-namespace rule is checked against the party ids Canton assigns. Where a
script reads on one participant what was submitted on the other, it waits for
the transaction to arrive.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/vault/async-vault-fund-test dpm build
DAML_PACKAGE=examples/vault/async-vault-fund-test dpm test --all
OZ_SANDBOX_SUITE=vault-fund scripts/check-sandbox.sh
```
