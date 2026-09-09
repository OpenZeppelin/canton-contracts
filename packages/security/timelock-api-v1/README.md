# Timelock API V1

A frozen Daml interface that puts a mandatory delay between the proposal of a
privileged operation and its execution.

| Field | Value |
|---|---|
| Package | `openzeppelin-timelock-api-v1` |
| Public module | `OpenZeppelin.TimelockV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

One interface, `Timelocked`, which names no proposer, executor, or canceller
and declares no choice:

- `TimelockedView`: `readyAt` and `expiresAt`, the whole frozen data surface.
- `TimelockConfig`: the delay policy a protected template holds as a field,
  `minDelay` and an optional `gracePeriod`.
- `isValidConfig` and `requireValidConfig`: a policy is valid when `minDelay`
  is not negative and `gracePeriod`, when set, is positive. The schedule
  functions check the policy in force; a choice that proposes a new policy
  checks the new one.
- `scheduleAt` and `scheduleAfter`: compute the view of a new operation from
  the policy, and refuse a delay shorter than `minDelay`.
- `requireReady`: the guard an apply choice calls. It fails before `readyAt`
  and at or after `expiresAt`.
- `requireExpired`: the guard a cleanup choice calls on an operation that can
  no longer execute.
- `isReadyAt` and `isExpiredAt`: the same questions as pure functions of a
  time, for a choice or an off-ledger reader that branches rather than refuses.
- `eInvalidConfig`, `eDelayTooShort`, `eNotReady`, `eExpired`, and
  `eNotExpired`: the failure statuses. Each is a `FailureStatus` with a stable `errorId` under
  `openzeppelin.com/timelock-`, so an off-ledger client matches the id in the
  `DAML_FAILURE` error, and your tests compare the whole value.

The package defines no templates, so it carries no ledger state of its own. A
scheduled operation is a contract of the consumer's own template, with the
typed parameters of the operation as fields. Daml has no calldata and no
dynamic dispatch, so an operation is never an opaque payload that a timelock
forwards: the executor can execute exactly the operation the proposer
scheduled, and nothing else.

## Usage

Adopting the timelock is four steps.

**1. Hold the policy on the protected template.** Add a `TimelockConfig` field
to the template whose privileged choices the delay guards, and a stable
identity field that operations bind to. The contract id changes on every
consuming choice, so an operation must not bind to it:

```daml
template Treasury
  with
    admin : Party
    proposer : Party
    executor : Party
    treasuryId : Text
    limit : Decimal
    config : TimelockConfig
  where
    signatory admin
    observer proposer, executor
```

**2. Write one operation template per operation kind.** Its fields are the
typed parameters plus the two the view reads. Give it the interface instance,
and make the executor a stakeholder, because the apply choice fetches it:

```daml
template LimitChange
  with
    admin : Party
    proposer : Party
    executor : Party
    treasuryId : Text
    newLimit : Decimal
    readyAt : Time
    expiresAt : Optional Time
  where
    signatory admin
    observer proposer, executor

    interface instance Timelocked for LimitChange where
      view = TimelockedView with readyAt, expiresAt

    choice LimitChange_Cancel : ()
      controller proposer
      do pure ()
```

**3. Schedule from a choice on the protected template.** The choice's
controller is your proposer authority. `scheduleAt` refuses a `readyAt` closer
than `minDelay`, and the operation it creates carries the protected contract's
signature, so nobody can forge one:

```daml
    nonconsuming choice Treasury_ScheduleLimit : ContractId LimitChange
      with
        newLimit : Decimal
        readyAt : Time
      controller proposer
      do
        s <- scheduleAt config readyAt
        create LimitChange with
          admin; proposer; executor; treasuryId; newLimit
          readyAt = s.readyAt; expiresAt = s.expiresAt
```

**4. Apply from a choice on the protected template.** The choice's controller
is your executor authority. Bind the operation to this resource first, call
`requireReady` second, then archive the operation and apply its parameters:

```daml
    choice Treasury_ApplyLimit : ContractId Treasury
      with
        opCid : ContractId LimitChange
      controller executor
      do
        op <- fetch opCid
        unless (op.admin == admin && op.treasuryId == treasuryId)
          (failWithStatus eWrongTarget)
        requireReady op
        archive opCid
        create this with limit = op.newLimit
```

The binding check is yours, because only you know what identifies your
resource. Without it, an operation scheduled on one treasury applies to
another treasury of the same admin.

## Authority and lifecycle

The interface ships no access control. Proposer, executor, and canceller are
the controllers of choices you write, and the authority to schedule and to
apply comes from the protected contract's signatories, because both choices
run on that contract:

- A role credential fits in the same slot as a fixed party. The choice takes
  the caller and the credential as arguments and verifies them in its body, as
  `OpenZeppelin.PausableV1` describes for the pause authority.
- An open executor, the `address(0)` idiom of `TimelockController.sol`, is a
  flexible controller: `with executor : Party` and `controller executor`. A
  non-stakeholder executor receives the operation and the protected contract
  by explicit disclosure.
- Cancelling is a choice on the operation template. Cleaning up an expired
  operation is a choice on the operation template that calls `requireExpired`.
- Changing the policy is a privileged operation like any other. Schedule the
  new `TimelockConfig` under the current one, call `requireValidConfig` on it
  in the schedule choice, and apply it after the delay. This is the
  `updateDelay` behavior of `TimelockController.sol`. A policy change to a
  shorter delay waits out the current delay, and the shorter delay then
  applies to every later schedule. There is no `minSetback` as in
  `AccessManager`: once a change to `minDelay = 0` has matured and applied,
  the next operation is immediate. Give the policy change its own, longer
  delay in the consumer if that matters.

The lifecycle of one operation:

| State | Meaning | Ends when |
|---|---|---|
| Waiting | The contract exists and the ledger time is before `readyAt` | `readyAt` passes, or a cancel choice archives it |
| Ready | `readyAt <= ledger time`, and `ledger time < expiresAt` when set | The apply choice archives it, a cancel archives it, or `expiresAt` passes |
| Expired | `expiresAt` is set and has passed | A cleanup choice archives it |
| Done | The apply choice archived it | Never; the operation executed once |

No `Done` marker remains on the ledger. The apply choice is a node in the
transaction tree, recorded with its actor and its ledger time, and the
operation's create and archive bound the interval during which it was pending.

## Time on Canton

A transaction carries a ledger time that Canton checks against the record time
within a tolerance the synchronizer configures, one minute by default. Two
consequences follow:

- The guards use ledger-time bounds, `isLedgerTimeGE` and `isLedgerTimeLT`,
  rather than `getTime`. A bound constrains only the side that matters, so an
  apply transaction prepared before `readyAt` stays valid once `readyAt`
  passes, which matters for externally signed transactions that are prepared
  well before submission. `scheduleAfter` is the one function that reads
  `getTime`; use `scheduleAt` when the proposer knows the target time.
- A submitter can move its ledger time anywhere inside the tolerance, so a
  proposer using `scheduleAt` shortens the effective delay by up to the whole
  tolerance. The enforceable minimum is `minDelay` minus the tolerance, not
  `minDelay`, and a `minDelay` at or below the tolerance is no delay. Use
  minutes at least, and days for governance. `scheduleAfter` reads `getTime`
  and is not shortened this way, at the cost of pinning the ledger time.
- `Time` arithmetic near the maximum representable time aborts the
  transaction. A `readyAt` that leaves no room for the grace period fails
  without creating an operation.

Nothing executes on its own. Canton has no scheduled execution, so once an
operation is ready, an executor must submit the apply choice. An automation
that watches pending operations and submits at `readyAt` is the consumer's
off-ledger responsibility, and it is the same pattern the Canton Network's
own governance uses.

## Reading pending operations off-ledger

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
it is a stakeholder of, and nobody else's.

## Scope and security caveats

- The delay is enforced only where the protected contract's privileged choice
  demands a matured operation. A privileged choice that does not go through an
  operation is not delayed, and nothing detects the omission.
- The binding check is the consumer's. An apply choice that skips it accepts
  an operation scheduled on another resource of the same admin.
- One operation is one contract and one apply choice. A batch is one operation
  template whose parameters list several effects, applied atomically in one
  choice body. There is no predecessor field; an operation that depends on
  another states the precondition it needs on the protected contract's state.
- Pending operations are visible to the stakeholders of the operation
  template. Keep sensitive parameters off an operation that many parties
  observe.
- A `minDelay` of zero disables the delay. A missing `gracePeriod` means an
  operation stays executable until it is archived, as in
  `TimelockController.sol`. A negative `minDelay` or a non-positive
  `gracePeriod` fails every schedule with `eInvalidConfig`, because such a
  policy would produce operations that are born expired.
- Every operation template needs a cleanup choice that calls
  `requireExpired`, or an expired operation stays on the ledger for good.
- A ledger-time check is honored within the synchronizer's tolerance, not to
  the microsecond.

## Compatibility

The whole package is frozen at its first upload. Daml interfaces are not
upgradeable through Smart Contract Upgrade, and a participant rejects a second
version of a package name whose first version defines an interface, so no
`openzeppelin-timelock-api-v1` above the uploaded version can ever be uploaded.
The guards and the failure statuses ship in the same DAR and run from the same
package ID, so they are frozen with the interface. Any change ships as a
sibling `openzeppelin-timelock-api-v2` package with module
`OpenZeppelin.TimelockV2`, and the two coexist.

For a consumer this means:

- Pin the exact DAR. Your `interface instance` binds your operation template
  to one package ID, and every participant that runs your apply choices must
  have vetted that package ID.
- Your own templates stay upgradeable. The protected template and the
  operation templates are yours, so you add fields through Smart Contract
  Upgrade of your package while this package does not move. `TimelockConfig`
  as a field of your template is safe under Smart Contract Upgrade because the
  record is frozen and can never change shape.
- There is no patch release. Adopting a fix means importing the sibling
  package, rebuilding, and swapping the `interface instance` through a Smart
  Contract Upgrade of your own package.

`0.1.0` is a pre-release and is not for upload to a shared ledger. Until a
tagged release records the DAR in `dars/released/`, the package ID may change
between commits, and no audit has been performed. See
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
