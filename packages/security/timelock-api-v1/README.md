# Timelock API V1

A frozen Daml interface that puts a mandatory delay between the proposal of a
privileged operation and its execution.

| Field | Value |
|---|---|
| Package | `openzeppelin-timelock-api-v1` |
| Public module | `OpenZeppelin.TimelockV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## Capabilities

Three interfaces and the functions around them:

- `Timelock`: the protected contract. Its view, `TimelockView`, carries the
  `authority` that applies operations, the `TimelockConfig` in force, and the
  `Pending` list of scheduled operations. Its choices, `Timelock_Apply` and
  `Timelock_Drop`, verify the pending list and call the two methods the
  consumer implements: `apply`, which dispatches on the operation's template
  and creates the successor, and `unschedule`, which creates the successor
  without applying.
- `Operation`: a scheduled operation. Its view, `OperationView`, names the
  `executors` and `cancellers`. Its choices, `Operation_Execute`,
  `Operation_Cancel`, and `Operation_Cleanup`, verify the actor and the
  schedule, exercise the protected contract's choice, and archive the
  operation. `Operation` requires `Timelocked`.
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
- Nine failure statuses, each a `FailureStatus` with a stable `errorId` under
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
protected contract as `target`. The choice verifies the actor and the
schedule, exercises `Timelock_Apply`, which verifies the pending list and
calls your `apply`, and archives the operation. `Operation_Cancel` and
`Operation_Cleanup` go through `Timelock_Drop` and your `unschedule`:

```daml
exerciseCmd (toInterfaceContractId @Operation opCid)
  Operation_Execute with actor = executor, target = toInterfaceContractId treasuryCid
```

The pending list is the binding. An operation reaches an effect only through
the protected contract whose pending list holds it, and only the schedule
choice adds to that list. An operation the admin creates directly, an
operation scheduled on another protected contract, and an operation already
applied or cancelled all fail with `eNotPending`.

## Authority and lifecycle

Access control is the consumer's. The proposer is the controller of the
schedule choice you write; executors and cancellers are the parties your
operation template names in its `OperationView`; and the authority to apply
comes from the protected contract's signatories, because the operation
carries their signature and `Timelock_Apply` runs under it. The pending list
binds the signatories themselves: a signatory who creates an operation
contract directly holds a contract that `Timelock_Apply` refuses, because
only the schedule choice adds to the list. A signatory can still replace the
protected contract wholesale; guarding against that is the role of
multi-party signatories or of an off-ledger canonical-instance check on the
protected contract, and lies outside this package.

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
| Waiting | Listed as pending, and the ledger time is before `readyAt` | `readyAt` passes, or `Operation_Cancel` archives it |
| Ready | Listed as pending, `readyAt <= ledger time`, and `ledger time < expiresAt` when set | `Operation_Execute` archives it, `Operation_Cancel` archives it, or `expiresAt` passes |
| Expired | Listed as pending, `expiresAt` is set and has passed | `Operation_Cleanup` archives it |
| Done | `Operation_Execute` archived it and the successor dropped it from the list | Final; the operation executed once |

The record of execution is the `Operation_Execute` node in the transaction
tree, with its actor and its ledger time, and the operation's create and
archive bound the interval during which it was pending.

## Time on Canton

A transaction carries a ledger time that Canton checks against the record time
within a tolerance the synchronizer configures, one minute by default. Two
consequences follow:

- The guards use ledger-time bounds, `isLedgerTimeGE` and `isLedgerTimeLT`.
  A bound constrains one side and leaves the ledger time free within it, so an
  apply transaction prepared before `readyAt` stays valid once `readyAt`
  passes, which matters for externally signed transactions that are prepared
  well before submission. `scheduleAfter` reads `getTime`; use `scheduleAt`
  when the proposer knows the target time.
- A submitter chooses its ledger time anywhere inside the tolerance, so a
  proposer using `scheduleAt` shortens the effective delay by up to the whole
  tolerance. The enforceable minimum is `minDelay` minus the tolerance, so
  choose a `minDelay` well above it: minutes at least, and days for
  governance. `scheduleAfter` fixes the ledger time with `getTime` and keeps
  the delay exact.
- `Time` arithmetic near the maximum representable time aborts the
  transaction. A `readyAt` that leaves no room for the grace period fails
  before any operation is created.

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
an interface filter on `OpenZeppelin.TimelockV1:Timelocked` and request the
interface view; every implementing contract visible to the querying party
returns a `TimelockedView`. In Daml Script:

```daml
Some v <- queryInterfaceContractId executor (toInterfaceContractId @Timelocked opCid)
v.readyAt
```

Visibility is the implementing template's. A party sees the pending operations
it is a stakeholder of.

## Scope and security caveats

- The delay covers the privileged choices that demand a matured operation.
  Route every privileged choice through an operation; the library has no way
  to detect one that bypasses it.
- `Timelock_Apply` verifies the pending list, the schedule, and that `apply`
  dropped the operation. `apply` itself is the consumer's: an `apply` that
  reads the wrong fields or skips an operation kind is a consumer defect the
  library reports only as `eUnknownOperation`-style failures the consumer
  defines.
- Interface choices are frozen with the package. `Operation_Execute`,
  `Operation_Cancel`, `Operation_Cleanup`, `Timelock_Apply`, and
  `Timelock_Drop` keep their names, arguments, and bodies for the life of
  `openzeppelin-timelock-api-v1`.
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
- `Operation_Cleanup` is open to any actor after `expiresAt`, so expired
  operations leave the ledger and the pending list.
- A ledger-time check is honored within the synchronizer's tolerance.

## Compatibility

The whole package is frozen at its first upload. Daml interfaces sit outside
Smart Contract Upgrade, and a participant accepts exactly one version of a
package name whose first version defines an interface, so the uploaded
`openzeppelin-timelock-api-v1` is the only version. The guards and the failure
statuses ship in the same DAR and run from the same package ID, so they are
frozen with the interface. Any change ships as a sibling
`openzeppelin-timelock-api-v2` package with module `OpenZeppelin.TimelockV2`,
and the two coexist.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` declarations bind your
  templates to one package ID, and every participant that runs the lifecycle
  choices must have vetted that package ID.
- Your own templates stay upgradeable. The protected template and the
  operation templates are yours, so you add fields through Smart Contract
  Upgrade of your package while this package stays fixed. `TimelockConfig`
  as a field of your template is safe under Smart Contract Upgrade because the
  record is frozen and keeps its shape.
- A fix ships as the sibling package. Adopting it means importing that
  package, rebuilding, and swapping the `interface instance` through a Smart
  Contract Upgrade of your own package.

`0.1.0` is a pre-release for local evaluation. A tagged release records the
DAR in `dars/released/` and fixes its package ID; until then the package ID may
change between commits, and the package is unaudited. See
[`RELEASING.md`](../../../RELEASING.md).

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/security/timelock-api-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/timelock-api-v1/.daml/dist/openzeppelin-timelock-api-v1-0.1.0.dar
```

```daml
import OpenZeppelin.TimelockV1
```

## Examples

One runnable consumer project, building against this DAR through
`data-dependencies`:

- [`examples/timelock/treasury`](../../../examples/timelock/treasury): a
  treasury whose spending limit and delay policy change only through
  timelocked operations, with a proposer, an executor, cancellation, expiry
  cleanup, and self-administration of the delay.
