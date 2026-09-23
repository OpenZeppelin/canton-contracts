# Timelock API V1

A frozen Daml interface that puts a mandatory delay between the proposal of a
privileged operation and its execution.

| Field | Value |
|---|---|
| Package | `openzeppelin-api-timelock-v1` |
| Public module | `OpenZeppelin.Api.TimelockV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

Three interfaces, their views, and the failure statuses their choices raise:

- `Timelock`: the timelock contract. Its view, `TimelockView`, carries the
  `authority` that applies operations, the `TimelockConfig` in force, and the
  `Pending` list of scheduled operations. Its choices, `Timelock_Apply` and
  `Timelock_Drop`, authenticate the actor and verify pending membership,
  shared authority, permissions, and time bounds. They archive the operation
  before calling the consumer's `apply` or `unschedule` method.
  The method creates the successor with the reduced pending list.
- `Operation`: a scheduled operation. Its view, `OperationView`, names the
  `executors` and `cancellers`. Its choices, `Operation_Execute`,
  `Operation_Cancel`, and `Operation_Cleanup`, forward the authenticated actor
  to the timelock's lifecycle choice. `Operation` requires `Timelocked`.
- `Timelocked`: the schedule of an operation, `readyAt` and `expiresAt`, for
  the lifecycle choices and for off-ledger readers.
- `TimelockConfig`: the delay policy, `minDelay` and an optional
  `gracePeriod`.
- `Pending`: the list of scheduled operations. The schedule choice adds to
  it; `Timelock_Apply` and `Timelock_Drop` take from it, so only operations
  the schedule choice created reach an effect. This binds the delay on the
  timelock's own signatories, whose direct creations stay outside the list.
- `DropReason`: `CancelOperation` requires canceller permission;
  `CleanupOperation` requires expiry.
- Eight failure statuses, each a `FailureStatus` with a stable `errorId` under
  `openzeppelin.com/timelock-`, so an off-ledger client matches the id in the
  `DAML_FAILURE` error and your tests compare the whole value.

The schedule functions, the pending-list functions, the policy validation,
and the time guards for your own choices live in
[`openzeppelin-timelock-v1`](../timelock-v1/), which ships separately so that
a fix to them does not move this frozen package.

Ledger state lives in the consumer's templates. A scheduled operation is a contract of the consumer's
own template, with the typed parameters of the operation as fields committed
at scheduling time. The timelock's `apply` reads them through `fromInterface`,
so the executor applies exactly the operation the proposer scheduled.

## Usage

The recommended integration uses three contracts:

| Contract | Holds | Changes when |
|---|---|---|
| The timelock, which implements `Timelock` | The `TimelockConfig` and the `Pending` list | An operation is scheduled, applied, cancelled, or cleaned up |
| The governed config | The settings that matured operations change | An operation that changes a setting is applied |
| The business contract | The frequently updated state, for example a balance | The business choices run; each reads the governed config |

Scheduling consumes only the timelock, and applying consumes the timelock and
the config. The business contract never takes part in governance, so its
choices do not contend with it.

Adopting the timelock is five steps. This package supplies the execute,
cancel, and cleanup choices; `OpenZeppelin.TimelockV1` supplies the functions
the snippets call; you supply the templates, the schedule choices, and the
`apply` method.

**1. Write the governed config.** Give it no choices, so that only the
timelock replaces it. Make the executors observers, because the execute
transaction archives it:

```daml
template TreasuryConfig
  with
    admin : Party
    executor : Party
    limit : Decimal
  where
    signatory admin
    observer executor
    ensure limit >= 0.0
```

**2. Implement `Timelock` on the timelock template.** Add a `TimelockConfig`
field, a `Pending` field, and the id of the current governed config. Check the
policy with `isValidConfig` in the `ensure` clause, so that the template
refuses a policy that cannot schedule operations. The view names the
signatory that applies operations. `apply` dispatches on the operation's
template with `fromInterface`, replaces the governed config, and creates the
successor with the new config id and the reduced pending list. `unschedule`
creates the successor with the reduced list alone:

```daml
template TreasuryTimelock
  with
    admin : Party
    proposer : Party
    executor : Party
    config : TimelockConfig
    pending : Pending
    target : ContractId TreasuryConfig
  where
    signatory admin
    observer proposer, executor
    ensure isValidConfig config

    interface instance Timelock for TreasuryTimelock where
      view = TimelockView with authority = admin; config; pending

      apply op pending' = case fromInterface @LimitChange op of
        Some lc -> do
          current <- fetch target
          archive target
          target' <- create current with limit = lc.newLimit
          toInterfaceContractId <$>
            create this with target = target', pending = pending'
        None -> failWithStatus eUnknownOperation

      unschedule pending' = toInterfaceContractId <$>
        create this with pending = pending'
```

**3. Write one operation template per operation kind.** Its fields are the
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

**4. Schedule from a consuming choice on the timelock template.** The
choice's controller is your proposer authority. Validate the parameters,
then call `scheduleAt`, which refuses a `readyAt` closer than `minDelay`. The
successor records the operation as pending:

```daml
    choice TreasuryTimelock_ScheduleLimit : (ContractId TreasuryTimelock, ContractId LimitChange)
      with
        newLimit : Decimal
        readyAt : Time
      controller proposer
      do
        assertMsg "the limit must be zero or greater" (newLimit >= 0.0)
        s <- scheduleAt config readyAt
        op <- create LimitChange with
          admin; proposer; executor; newLimit
          readyAt = s.readyAt; expiresAt = s.expiresAt
        t <- create this with pending = addPending op pending
        pure (t, op)
```

**5. Read the governed config in the business choices.** Take the config id
as a choice argument, fetch it, and check its signatory:

```daml
    choice Treasury_Pay : (ContractId Treasury, ContractId Payout)
      with
        configCid : ContractId TreasuryConfig
        recipient : Party
        amount : Decimal
      controller admin
      do
        cfg <- fetch configCid
        assertMsg "the config belongs to another admin" (cfg.admin == admin)
        assertMsg "amount exceeds the spending limit" (amount <= cfg.limit)
        payout <- create Payout with payer = admin, recipient, amount
        t <- create this with balance = balance - amount
        pure (t, payout)
```

### Execute, cancel, and clean up

An executor exercises `Operation_Execute` on the operation with the current
timelock as `target`. `Timelock_Apply` authenticates the actor and checks
pending membership, shared authority, executor permission, and readiness. It
archives the operation before calling your `apply` method.
`Operation_Cancel` and `Operation_Cleanup` call `Timelock_Drop` with the
corresponding `DropReason`. That choice checks cancellation permission or
expiry before archiving the operation and calling `unschedule`:

```daml
exerciseCmd (toInterfaceContractId @Operation opCid)
  Operation_Execute with actor = executor, target = toInterfaceContractId timelockCid
```

Direct calls to `Timelock_Apply` and `Timelock_Drop` enforce the same checks.

### Contract ids

The pending list binds operations to the timelock's lineage. Initialize it
empty, add only the operation that the schedule choice creates, and keep the
remaining entries in every successor. An operation outside the list fails
with `eNotPending`.

The timelock's contract id changes on every schedule and every apply, so an
executor reads the current id from the ledger at execution time. The governed
config's id changes only when an operation replaces it. The timelock records
the current config id, so a business client reads it from the timelock, and a
business choice that receives an archived config fails and is resubmitted.

## Authority and lifecycle

The consumer selects the proposer, executors, and cancellers. The proposer
controls the schedule choice. `OperationView` names the executors and
cancellers.

The declared `authority` must sign both the timelock and the operation, and
the operation's signatories must be signatories of the timelock. The lifecycle
choices fail with `eInvalidAuthority` otherwise. The choices take authority
from the timelock's signatories and the actor only, so a substituted timelock
cannot use the operation's signatory authority.

The pending list rejects operations created outside the schedule choices.
Signatories can still archive or recreate contracts, including a timelock with
a copied pending list and a governed config with other settings. A business
choice that checks only the config's signatory accepts such a config.
Applications must establish a canonical timelock and config lineage and review
every choice that creates successors. Multiple signatories can protect against
unilateral replacement when at least one signatory refuses it.

- A role credential fits in the schedule choice: the choice takes the caller
  and the credential as arguments and verifies them in its body, as
  `OpenZeppelin.PausableV1` describes for the pause authority. Executors and
  cancellers are party lists on the operation, fixed when it is scheduled.
- An open executor, the `address(0)` idiom of `TimelockController.sol`, is
  `executors = None`. Any party that holds the operation, the timelock, and
  the governed config, by stake or by explicit disclosure, may execute.
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

## Off-ledger reads

`TimelockedView` is the whole data surface of the interface:

| Field | Type | Meaning |
|---|---|---|
| `readyAt` | `Time` | The earliest ledger time at which the operation may execute |
| `expiresAt` | `Optional Time` | The ledger time from which it may no longer execute, if any |

A dashboard, an executor automation, or an auditor reads it without knowing the
operation template: query with an interface filter on
`OpenZeppelin.Api.TimelockV1:Timelocked` and request the interface view. In
Daml Script:

```daml
Some v <- queryInterfaceContractId executor (toInterfaceContractId @Timelocked opCid)
v.readyAt
```

An interface query also returns operations that were created directly and
have no pending entry. Match the results against the canonical timelock's
`TimelockView.pending` before presenting them as scheduled operations.

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
  applying contend on the timelock. Two proposers scheduling in the same
  instant see one of them fail and resubmit against the successor. Keep the
  business state on a separate contract, so that business choices stay
  outside this contention.
- One operation is one contract and one apply choice. A batch is one operation
  template whose parameters list several effects, applied atomically in one
  choice body. Ordering between operations is a precondition on the governed
  state.
- Every stakeholder of an operation sees its parameters. Keep sensitive
  parameters off an operation that many parties observe.
- A `minDelay` of zero disables the delay. A `gracePeriod` of `None` keeps an
  operation executable until it is archived, as in `TimelockController.sol`.
  A negative `minDelay` or a `gracePeriod` of zero or less fails every schedule
  with `eInvalidConfig`, because such a policy would produce operations that
  are born expired.
- Cleanup is open to any actor after `expiresAt`.
  Signatories can also call the operation template's `Archive` choice directly.
  Direct archival leaves a pending reference that operation-based cleanup cannot
  remove. Consumers must define a recovery policy for these references.
- The time bounds hold within the synchronizer's ledger-time tolerance, so the
  effective delay can be shorter than `minDelay`. Size the delay as
  [Time on Canton](../timelock-v1/README.md#time-on-canton) describes.

## Compatibility

The released API package is frozen. Daml interface definitions sit outside
Smart Contract Upgrade (SCU). The choices and failure statuses share the
interface's package ID and remain fixed with it.
A different API generation uses a sibling `openzeppelin-api-timelock-v2` package
with module `OpenZeppelin.Api.TimelockV2`.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` declarations bind your
  templates to one package ID, and every participant that runs the lifecycle
  choices must have vetted that package ID.
- Your own templates stay upgradeable. The timelock, config, and operation
  templates are yours, so you add fields through Smart Contract
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

## Examples

One runnable consumer project, building against both DARs through
`data-dependencies`:

- [`examples/timelock/treasury`](../../../examples/timelock/treasury): a
  treasury whose balance, spending limit, and delay policy live on three
  contracts. The limit and the policy change only through timelocked
  operations, with a proposer, an executor, cancellation, expiry cleanup, and
  self-administration of the delay.
