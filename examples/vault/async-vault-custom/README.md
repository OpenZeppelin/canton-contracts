# Custom async vault example

A lending pool that owns every template it deploys (`Pool`, `PoolLedger`,
`PoolDepositRequest`, `PoolRedeemRequest`) and reuses the choice bodies of the
asynchronous vault unchanged. It depends on
`openzeppelin-async-vault-types-v1` and `openzeppelin-async-vault-utils`
only, never on the default templates.

What it adds, and where each addition lives:

| Addition | Mechanism |
|---|---|
| A smallest deposit | A field of `Pool`, checked in the policy's `authorizeDeposit`, which `requestDepositImpl` runs before it locks anything |
| A price that never falls and rises by a bounded step per batch | A field of `PoolLedger` and the pure `checkPriceStep`, passed as the policy's `checkPrice`, which `settleBatchImpl` runs against the price the ledger records |
| A limit on what one batch pays out to redemptions | A field of `PoolLedger`, checked in `PoolLedger_SettleBatch` on the fills `settleBatchImpl` returns. A batch above the limit fails whole |
| The admin moving the step and the limit | `PoolLedger_SetLimits`, a choice of the pool's own |

Every other choice is one call into `openzeppelin-async-vault-utils`: opening
a redemption request, cancelling, rejecting, and expiring a request, and
recording the reserves. No choice body of that package changes.

## What the rules mean

- The price bound follows the price. Each batch settles at most
  `maxPriceStep` above the last one, so over many batches the operator
  raises the price by any amount. The default `VaultLedger` holds the
  operator to a band that stays where the admin put it.
- The price never falls. A pool that must record a loss has no choice for
  it: its signatories archive the ledger and create another.
- The redemption limit counts what a batch pays out, whatever the batch
  takes in. The operator settles the redemptions that fit and leaves the
  others for a later batch. A single redemption above the limit settles only
  after the admin raises the limit, or after its lender cancels it and asks
  again for less.
- The smallest deposit bounds deposits only. The pool asks no rule about a
  redemption request, so a lender can always ask to redeem.

## Build and test

[`async-vault-custom-test`](../async-vault-custom-test/) checks each addition
and the request lifecycle the pool's templates inherit, with
`openzeppelin-token-cip112-v1` as the registry of both instruments.

From the repository root:

```sh
DAML_PACKAGE=examples/vault/async-vault-custom dpm build
DAML_PACKAGE=examples/vault/async-vault-custom-test dpm test --all
```
