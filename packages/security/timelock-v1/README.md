# Timelock V1

The schedule functions, the pending-list functions, and the time guards for
the interfaces in [`openzeppelin-api-timelock-v1`](../api-timelock-v1/).

| Field | Value |
|---|---|
| Package | `openzeppelin-timelock-v1` |
| Public module | `OpenZeppelin.TimelockV1` |
| Version | `0.1.0` |
| Depends on | `openzeppelin-api-timelock-v1` `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `scheduleAt` and `scheduleAfter`: compute the `TimelockedView` of a new
  operation from the policy, and refuse a delay shorter than `minDelay`.
- `isValidConfig` and `requireValidConfig`: the policy validation. A policy
  is valid when `minDelay` is zero or greater and `gracePeriod`, when set, is
  positive.
- `addPending` and `takePending`: add a new operation to the pending list,
  and remove one or fail with `eNotPending`.
- `requireReady`, `requireExpired`, `isReadyAt`, and `isExpiredAt`: the time
  guards and their pure forms, for a consumer that writes its own choices.
- `eInvalidConfig` and `eDelayTooShort`: the failure statuses of the schedule
  functions. Each has a stable `errorId` under `openzeppelin.com/timelock-`.

## Usage

The [`openzeppelin-api-timelock-v1` README](../api-timelock-v1/README.md)
shows the whole integration. The functions appear in three places:

- The timelock template's `ensure` clause checks `isValidConfig config`.
- Each schedule choice calls `scheduleAt` or `scheduleAfter`, creates the
  operation with the returned fields, and records it with `addPending`.
- The choice that schedules a policy change calls `requireValidConfig` on the
  proposed policy.

```daml
import OpenZeppelin.Api.TimelockV1
import OpenZeppelin.TimelockV1

    choice TreasuryTimelock_ScheduleLimit : (ContractId TreasuryTimelock, ContractId LimitChange)
      with
        newLimit : Decimal
        readyAt : Time
      controller proposer
      do
        s <- scheduleAt config readyAt
        op <- create LimitChange with
          admin; proposer; executor; newLimit
          readyAt = s.readyAt; expiresAt = s.expiresAt
        t <- create this with pending = addPending op pending
        pure (t, op)
```

## Time on Canton

Canton checks ledger time against record time within a synchronizer-configured
tolerance, one minute by default.

- The guards use `isLedgerTimeGE` and `isLedgerTimeLT` bounds.
  These bounds support advance preparation when the complete transaction avoids
  `getTime`. Preparation age, contract activity, and expiry still limit validity.
- Both scheduling and execution can have clock skew. With tolerance `T`, the
  guaranteed record-time delay is at least `max(0, minDelay - 2*T)`.
  This bound assumes the same tolerance at both transactions.
  A two-minute minimum can therefore provide no record-time reaction window
  with a one-minute tolerance. Include both tolerances in the configured delay.
- The expiry side has the same skew. A party that cleans up can choose a
  ledger time at `expiresAt` while the record time is up to `T` earlier. The
  record-time window between `readyAt` and the earliest cleanup is therefore
  at least `gracePeriod - T`. Cleanup is open to any party, so a
  `gracePeriod` of `T` or less can let another party remove an operation
  before an executor can run it. `isValidConfig` accepts any positive
  `gracePeriod`; choose one well above `T` plus the executor's submission
  latency.
- `scheduleAfter` computes `readyAt` from the scheduling transaction's ledger time.
  Its `getTime` call fixes that timestamp during preparation.
  It does not eliminate clock skew or guarantee an exact record-time delay.
  Use `scheduleAt` for workflows that need a longer preparation window.
- `Time` arithmetic near the representable bounds can abort the transaction.
  A schedule that overflows fails before an operation is created.

See [Time on Daml Ledgers](https://docs.digitalasset.com/overview/3.4/explanations/ledger-model/time.html)
and [Implementing Time Constraints](https://docs.digitalasset.com/build/3.4/sdlc-howtos/smart-contracts/develop/patterns/implementing-time-constraints.html).

Execution is a submission. Once an operation is ready, an executor submits the
apply choice. An automation that watches pending operations and submits at
`readyAt` is the consumer's off-ledger component, the same pattern the Canton
Network's own governance uses.

## Compatibility

Daml-LF `2.1`, built with the SDK that
[`multi-package.yaml`](../../../multi-package.yaml) declares.

The package holds functions and values, so a fix ships as a new version under
the same name, and your package picks it up by rebuilding against the new
DAR. The `errorId` of every failure status is stable across versions. The
interface package stays at its frozen version. The lifecycle choices in the
interface package apply the same time bounds as `requireReady` and
`requireExpired`.

Your package binds to one package ID of this package at build time, and your
schedule choices run its code, so every participant that runs them vets that
package ID beside the interface package ID.

`0.1.0` is a pre-release: the package ID may change between commits, and no
audit has been performed. See [`RELEASING.md`](../../../RELEASING.md).

## Build

From the repository root, after building `openzeppelin-api-timelock-v1`:

```sh
DAML_PACKAGE=packages/security/api-timelock-v1 dpm build
DAML_PACKAGE=packages/security/timelock-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/api-timelock-v1/.daml/dist/openzeppelin-api-timelock-v1-0.1.0.dar
  - ../canton-contracts/packages/security/timelock-v1/.daml/dist/openzeppelin-timelock-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Api.TimelockV1
import OpenZeppelin.TimelockV1
```

Runnable consumer projects live under [`examples/timelock/`](../../../examples/timelock/).
