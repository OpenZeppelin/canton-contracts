# Timelock API V1

A frozen Daml interface that puts a mandatory delay between the proposal of a
privileged operation and its execution.

| Field | Value |
|---|---|
| Package | `openzeppelin-api-timelock-v1` |
| Public module | `OpenZeppelin.Api.TimelockV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## Capabilities

Three interfaces and the functions around them:

- `Timelock`: the protected contract. Its view, `TimelockView`, carries the
  `authority` that applies operations, the `TimelockConfig` in force, and the
  `Pending` list of scheduled operations. Its choices, `Timelock_Apply` and
  `Timelock_Drop`, authenticate the actor and verify pending membership,
  shared authority, permissions, and time bounds. They archive the operation
  before calling the consumer's `apply` or `unschedule` method.
  The method creates the successor with the reduced pending list.
- `Operation`: a scheduled operation. Its view, `OperationView`, names the
  `executors` and `cancellers`. Its choices, `Operation_Execute`,
  `Operation_Cancel`, and `Operation_Cleanup`, forward the authenticated actor
  to the protected contract's lifecycle choice. `Operation` requires `Timelocked`.
- `Timelocked`: the schedule of an operation, `readyAt` and `expiresAt`, for
  the guards and for off-ledger readers.
- `TimelockConfig`, `isValidConfig`, and `requireValidConfig`: the delay
  policy, `minDelay` and an optional `gracePeriod`, and its validation. A
  policy is valid when `minDelay` is zero or greater and `gracePeriod`, when
  set, is positive.
- `Pending`, `addPending`, and `takePending`: the list of scheduled
  operations. The schedule choice adds to it; `Timelock_Apply` and
  `Timelock_Drop` take from it, so only operations the schedule choice created
  reach an effect. This binds the delay on the protected contract's own
  signatories, whose direct creations stay outside the list.
- `scheduleAt` and `scheduleAfter`: compute the view of a new operation from
  the policy, and refuse a delay shorter than `minDelay`.
- `requireReady`, `requireExpired`, `isReadyAt`, and `isExpiredAt`: the time
  guards and their pure forms, for a consumer that writes its own choices.
- `DropReason`: `CancelOperation` requires canceller permission;
  `CleanupOperation` requires expiry.
- Ten failure statuses, each a `FailureStatus` with a stable `errorId` under
  `openzeppelin.com/timelock-`, so an off-ledger client matches the id in the
  `DAML_FAILURE` error and your tests compare the whole value.

The package holds interfaces and functions; ledger state lives in the
consumer's templates. A scheduled operation is a contract of the consumer's
own template, with the typed parameters of the operation as fields committed
at scheduling time. The protected contract's `apply` reads them through
`fromInterface`, so the executor applies exactly the operation the proposer
scheduled.

## Usage

Adopting the timelock is four steps. The library supplies the execute, cancel,
and cleanup choices; you supply the templates, the schedule choice, and the
`apply` method.

**1. Implement `Timelock` on the protected template.** Add a `TimelockConfig`
field and a `Pending` field. The view names the signatory that applies
operations. `apply` dispatches on the operation's template with
`fromInterface`, reads its parameters, and creates the successor with the
reduced pending list the library passes in. `unschedule` creates the successor
with the reduced list alone:

```daml
template Treasury
  with
    admin : Party
    proposer : Party
    executor : Party
    limit : Decimal
    config : TimelockConfig
    pending : Pending
  where
    signatory admin
    observer proposer, executor

    interface instance Timelock for Treasury where
      view = TimelockView with authority = admin; config; pending

      apply op pending' = case fromInterface @LimitChange op of
        Some lc -> toInterfaceContractId <$>
          create this with limit = lc.newLimit, pending = pending'
        None -> failWithStatus eUnknownOperation

      unschedule pending' = toInterfaceContractId <$>
        create this with pending = pending'
```

**2. Write one operation template per operation kind.** Its fields are the
typed parameters plus the two the `Timelocked` view reads. Implement
`Timelocked` and `Operation`, and make the executors and cancellers
stakeholders, because the lifecycle choices run on the operation:

```daml
template LimitChange
  with
    admin : Party
    proposer : Party
    executor : Party
    newLimit : Decimal
    readyAt : Time
    expiresAt : Optional Time
  where
    signatory admin
    observer proposer, executor

    interface instance Timelocked for LimitChange where
      view = TimelockedView with readyAt, expiresAt

    interface instance Operation for LimitChange where
      view = OperationView with
        executors = Some [executor]
        cancellers = [proposer, admin]
```

**3. Schedule from a consuming choice on the protected template.** The
choice's controller is your proposer authority. `scheduleAt` refuses a
`readyAt` closer than `minDelay`, and the successor records the operation as
pending:

```daml
    choice Treasury_ScheduleLimit : (ContractId Treasury, ContractId LimitChange)
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

**4. Execute, cancel, and clean up through the library's choices.** An
executor exercises `Operation_Execute` on the operation with the current
protected contract as `target`. `Timelock_Apply` authenticates the actor and
checks pending membership, shared authority, executor permission, and readiness.
It archives the operation before calling your `apply` method.
`Operation_Cancel` and `Operation_Cleanup` call `Timelock_Drop` with the
corresponding `DropReason`. That choice checks cancellation permission or expiry
before archiving the operation and calling `unschedule`:

```daml
exerciseCmd (toInterfaceContractId @Operation opCid)
  Operation_Execute with actor = executor, target = toInterfaceContractId treasuryCid
```

Direct calls to `Timelock_Apply` and `Timelock_Drop` enforce the same checks.
Both choices require the named `actor` as controller. Naming another party
in the argument does not authorize a submission on that party's behalf.
A failure restores the operation, target, and pending entry together.

The pending list binds operations within the protected contract's lineage.
Initialize it empty. Each schedule choice adds only the operation it creates.
Each successor preserves the remaining entries. Separate treasuries then have
separate operation lists, even when they share an admin and policy.
An active operation outside the target's list fails with `eNotPending`.
An archived operation fails when the ledger attempts to exercise or fetch it.

The `target` argument of the lifecycle choices names the current protected
contract. Its contract id changes on every schedule and every apply, so an
executor reads the current id from the ledger at execution time; a contract
id stored on the operation at scheduling time would go stale on the next
schedule.

## Authority and lifecycle

The consumer selects the proposer, executors, and cancellers.
The proposer controls the schedule choice. `OperationView` names the executors
and cancellers. Each target choice uses its actor as controller and checks the
operation's permission or expiry in its body. The target's signatories authorize
the consumer method's effects.

The declared `authority` must sign both the protected contract and the operation.
The lifecycle choices check this requirement and fail with `eInvalidAuthority`
when either signature is absent. An operation's signatories must be a subset
of the target's signatories so the target can archive it.
The target choice gets authority from its own signatories and its actor.
This prevents a substituted target from using the operation's signatory authority.

The pending list rejects operations created outside the schedule choices.
Signatories can still archive or recreate contracts, including a target with a
copied pending list. Applications must establish a canonical target lineage and
review every choice that creates successors. Multiple signatories can protect
against unilateral replacement when at least one signatory refuses it.

- A role credential fits in the schedule choice: the choice takes the caller
  and the credential as arguments and verifies them in its body, as
  `OpenZeppelin.PausableV1` describes for the pause authority. Executors and
  cancellers are party lists on the operation, fixed when it is scheduled.
- An open executor, the `address(0)` idiom of `TimelockController.sol`, is
  `executors = None`. Any party that holds the operation and the protected
  contract, by stake or by explicit disclosure, may execute.
- Cleanup is open to any actor once the operation has expired.
- Changing the policy is a privileged operation like any other. Schedule the
  new `TimelockConfig` under the current one, call `requireValidConfig` on it
  in the schedule choice, and apply it in `apply`. This is the `updateDelay`
  behavior of `TimelockController.sol`. A policy change to a shorter delay
  waits out the current delay, and the shorter delay then applies to every
  later schedule. The `minSetback` protection of `AccessManager` is the
  consumer's to add: once a change to `minDelay = 0` has matured and applied,
  the next operation is immediate, so give the policy change its own, longer
  delay where that matters.

The lifecycle of one operation:

| State | Meaning | Ends when |
|---|---|---|
| Waiting | Pending, with ledger time before `readyAt` | `readyAt` passes or cancellation succeeds |
| Ready | Pending, at or after `readyAt`, and before `expiresAt` if set | Execution, cancellation, or expiry |
| Expired | Pending, with ledger time at or after `expiresAt` | Cleanup or cancellation succeeds |
| Done | `Timelock_Apply` archives the operation and removes its pending entry | Final; the operation executes once |

The `Timelock_Apply` transaction node records execution, including direct calls.
Its choice argument identifies the actor. The transaction records its ledger time.
The operation's create and archive events bound its active lifetime.

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

## Off-ledger reads

`TimelockedView` is the whole data surface of the interface:

| Field | Type | Meaning |
|---|---|---|
| `readyAt` | `Time` | The earliest ledger time at which the operation may execute |
| `expiresAt` | `Optional Time` | The ledger time from which it may no longer execute, if any |

A dashboard, an executor automation, or an auditor reads it without knowing the
operation template. Query the Active Contract Service or the update stream with
an interface filter on `OpenZeppelin.Api.TimelockV1:Timelocked` and request the
interface view; every implementing contract visible to the querying party
returns a `TimelockedView`. In Daml Script:

```daml
Some v <- queryInterfaceContractId executor (toInterfaceContractId @Timelocked opCid)
v.readyAt
```

Visibility follows the implementing template and Daml disclosure rules.
An interface query can also return directly created operations that have no
pending entry. Match results against the canonical target's `TimelockView.pending`
before presenting them as scheduled operations. Reconcile archive events with
that list when building an executor or dashboard.

## Scope and security caveats

- The delay covers the privileged choices that demand a matured operation.
  Route every privileged choice through an operation; the library has no way
  to detect one that bypasses it.
- `Timelock_Apply` verifies the actor, shared authority, pending list, and schedule.
  It also checks that `apply` drops the operation.
  The consumer implements `apply` and must dispatch each operation correctly.
  Consumer methods define their own failures, such as `eUnknownOperation`.
- Interface choices are frozen with the package. `Operation_Execute`,
  `Operation_Cancel`, `Operation_Cleanup`, `Timelock_Apply`, and
  `Timelock_Drop` keep their names, arguments, and bodies for the life of
  `openzeppelin-api-timelock-v1`.
- Every choice that changes the pending list is consuming, so scheduling and
  applying contend on the protected contract. Two proposers scheduling in the
  same instant see one of them fail and resubmit against the successor.
- One operation is one contract and one apply choice. A batch is one operation
  template whose parameters list several effects, applied atomically in one
  choice body. Ordering between operations is a precondition on the protected
  contract's state.
- Pending operations are visible to the stakeholders of the operation
  template. Keep sensitive parameters off an operation that many parties
  observe.
- A `minDelay` of zero disables the delay. A `gracePeriod` of `None` keeps an
  operation executable until it is archived, as in `TimelockController.sol`.
  A negative `minDelay` or a `gracePeriod` of zero or less fails every schedule
  with `eInvalidConfig`, because such a policy would produce operations that
  are born expired.
- Cleanup is open to any actor after `expiresAt`.
  Signatories can also call the operation template's `Archive` choice directly.
  Direct archival leaves a pending reference that operation-based cleanup cannot
  remove. Consumers must define a recovery policy for these references.
- A ledger-time check is honored within the synchronizer's tolerance.

## Compatibility

The released API package is frozen. Daml interface definitions sit outside
Smart Contract Upgrade (SCU). The guards, choices, and failure statuses share
the interface's package ID and remain fixed with it.
A different API generation uses a sibling `openzeppelin-timelock-api-v2` package
with module `OpenZeppelin.TimelockV2`.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` declarations bind your
  templates to one package ID, and every participant that runs the lifecycle
  choices must have vetted that package ID.
- Your own templates stay upgradeable. The protected template and the
  operation templates are yours, so you add fields through Smart Contract
  Upgrade of your package while this package stays fixed. `TimelockConfig`
  as a field of your template is safe under Smart Contract Upgrade because the
  record is frozen and keeps its shape.
- Adopting a sibling API requires an explicit migration plan.
  SCU cannot remove an interface instance or replace a field's API-package type.
  Adding v2 instances leaves v1 interface choices available.
  Plan contract migration and retirement of vulnerable entry points before
  claiming that an application uses only the corrected API.
  See [SCU limitations](https://docs.canton.network/appdev/deep-dives/smart-contract-upgrade#limitations).

`0.1.0` is a pre-release for local evaluation. A tagged release records the
DAR in `dars/released/` and fixes its package ID; until then the package ID may
change between commits, and the package is unaudited. See
[`RELEASING.md`](../../../RELEASING.md).

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/security/api-timelock-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/api-timelock-v1/.daml/dist/openzeppelin-api-timelock-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Api.TimelockV1
```

## Examples

One runnable consumer project, building against this DAR through
`data-dependencies`:

- [`examples/timelock/treasury`](../../../examples/timelock/treasury): a
  treasury whose spending limit and delay policy change only through
  timelocked operations, with a proposer, an executor, cancellation, expiry
  cleanup, and self-administration of the delay.
