# Timelock Treasury Example

Minimal adoption of `Timelock`: a treasury whose spending limit and delay
policy change only through timelocked operations.

| Field | Value |
|---|---|
| Package | `timelock-treasury-example` |
| Module | `OpenZeppelin.Examples.Timelock.Treasury` |
| Tests | `OpenZeppelin.Examples.Timelock.TreasuryTest` in [`treasury-test`](../treasury-test) |
| Templates | `TreasuryTimelock`, `TreasuryConfig`, `Treasury`, `Payout`, `LimitChange`, `ConfigChange` |
| Consumes | `openzeppelin-api-timelock-v1` `0.1.0`, `openzeppelin-timelock-v1` `0.1.0` |

## What it shows

- Three contracts: `TreasuryTimelock` holds the delay policy and the pending
  operations, `TreasuryConfig` holds the spending limit, and `Treasury` holds
  the balance. Payments consume only the treasury, so they do not contend
  with governance.
- The `interface instance Timelock for TreasuryTimelock`: the view, the
  `apply` and `unschedule` methods, and the `applyImpl` and `dropImpl`
  methods, which call `applyOperation` and `dropOperation`.
- `LimitChange` and `ConfigChange`, one operation template per operation
  kind, each implementing `Operation` and `Timelocked`.
- `TreasuryTimelock_ScheduleLimit` and `TreasuryTimelock_ScheduleConfig`, the
  consumer-written schedule choices. They call `scheduleAt` and `addPending`.
- `TreasuryTimelock_Prune`, a recovery choice that removes pending entries of
  operations that `admin` archived directly.
- Self-administration: a change to the delay policy waits out the current
  delay.

`OpenZeppelin.Examples.Timelock.TreasuryTest`, in the sibling `treasury-test`
package, runs the lifecycle: a refused payment above the limit, a scheduled
limit raise that executes after its delay, a cancellation, an expiry cleanup,
and a policy change.

## Authority model

`admin` is the sole signatory of the three contracts and the `authority` of
the timelock. `proposer` schedules, `executor` executes, and `proposer` and
`admin` cancel. A sole signatory can create a config or a timelock outside
the lineage, so the delay binds the proposer and the executor but not
`admin`. Use several signatories to bind the delay on the signatories too.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/timelock/treasury dpm build
DAML_PACKAGE=examples/timelock/treasury-test dpm test --all
```
