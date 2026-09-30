---
stage: review
project: timelock
mode: greenfield
extends: null
status: draft
timestamp: 2026-09-29
author: nenad.misic
previous_stage: timelock-design.md
tags: [timelock, interface, security, review, devex, scu, solidity-parity]
---

# Timelock - Basic Review Report

Reviewed at commit `b702402` on branch `timelock-proposal`, with the four
untracked root documents `timelock-research-doc.md`, `timelock-design.md`,
`timelock-proposal.md`, and `timelock-pr-description.md` as the prior
artifacts. No invariants, code, tests, or docs stage artifact exists; the
invariant list below is the design's seven candidates, the two more that the
tests reference (INV-8, INV-9), and six inferred from the source.
Line numbers in `packages/security/api-timelock-v1/README.md` refer to
`5a9028c`, which changes only that README's wording. All other line numbers
refer to `b702402`.

Focus requested for this pass: design gaps against `TimelockController.sol`
and the changes that close them, developer experience of integrating,
debugging, and testing an integration, security vulnerabilities, and footguns
with mitigations. The standard checklist ran as well.

Commitments this review built on, from the research, design, and proposal:

- Two packages split as Pausable is: a frozen API package with no logic and
  an upgradeable function package. Fixes ship in the function package.
- The operation is the consumer's typed template, signed by the timelock's
  signatories, created in a schedule choice on the timelock, and bound to the
  timelock lineage through the pending list.
- The lifecycle lives in interface choices whose bodies call consumer
  methods, and the consumer implements `applyImpl` and `dropImpl` with the
  lifecycle functions.
- Guards use ledger-time bounds; `scheduleAfter` is the one `getTime` reader.
- No roles, no predecessor, no batch DSL, no automatic execution. A policy
  change is an operation like any other.
- The lifecycle choices are nonconsuming since `b702402`, so the timelock's
  observers see the archive and the successor but not the effects of `apply`.

## Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 4 |
| Informational | 16 |

**Overall assessment: needs fixes before the API package freezes.** No
production code path lets a party apply an operation early, apply it twice,
apply it to a timelock that did not schedule it, or use the operation's
signatory authority from a foreign target. The authority model, the pending
list, the archive-before-apply order, and the successor check hold. The
suite is broad: 49 scripts on the interfaces, 16 on the functions, and a
runnable example.

The four Medium findings are design residuals, not bugs. Two of them change
the frozen API package (MED-1 tightens the authority rule and retires or
demotes the `authority` field; MED-3 passes the actor, the operation, and the
drop reason to `apply` and `unschedule`), so they must land before the first
release, because a frozen interface cannot take them later. The other two
can land any time: MED-4 adds a function to the upgradeable package, and
MED-2 adds a conformance script to the test package.

Verified on 2026-09-29 with SDK 3.4.11, `--target=2.1`, at `b702402`:

| Check | Result |
|---|---|
| `dpm build` on the six timelock packages | All six DARs build |
| `dpm damlc lint` on the six timelock packages | No hints |
| `test/api-timelock-v1` (`dpm test --all --show-coverage`) | 49 scripts pass |
| `test/timelock-v1` (`dpm test --all --show-coverage`) | 16 scripts pass |
| `examples/timelock/treasury-test` (`dpm test --all`) | 1 script passes, 43 transactions |

The coverage report lists the API package's five interface choices as
"0 external interface choices defined", so the CI coverage gate proves
nothing about either production package, as `CONTRIBUTING.md` already says
for template-free packages. The test packages are the whole evidence.

Reviewed inputs: the four root documents; `packages/security/api-timelock-v1`
and `packages/security/timelock-v1` with their READMEs; `test/api-timelock-v1`
and `test/timelock-v1`; `examples/timelock/treasury` and `treasury-test`;
`README.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`,
`AGENTS.md`, `multi-package.yaml`, `scripts/check.sh`,
`scripts/check-coverage.sh`; the commit `b702402` diff; and
`TimelockController.sol` at `master` for the comparison.

## Invariant Verification

Locations: `Api` is `packages/security/api-timelock-v1/daml/OpenZeppelin/Api/TimelockV1.daml`,
`Fn` is `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1.daml`,
`Int` is `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1/Internal.daml`.

| Invariant | Enforced? | Location | Notes |
|---|---|---|---|
| INV-1 A schedule with `readyAt < ledgerTime + minDelay` fails with `eDelayTooShort` | ✅ Yes | `Fn` 137-138, 153 | `isLedgerTimeLE (readyAt - minDelay)`; inclusive bound tested at exactly `minDelay`. Holds only when the consumer stores the returned view unchanged; see MED-4 |
| INV-2 An operation applies only at or after `readyAt`; before, `eNotReady` | ✅ Yes | `Fn` 180-181 via 83 | `isLedgerTimeGE`; `test_executeBeforeReadyFails`, `test_executeAtReadyAtSucceeds` |
| INV-3 With `expiresAt` set, apply only before it (`eExpired`); cleanup only at or after it (`eNotExpired`) | ✅ Yes | `Fn` 182-184, 188-195; 107 | Exclusive upper bound tested one minute either side |
| INV-4 An operation applies at most once | ✅ Yes | `Fn` 84, `Int` 35-38 | The archive of the operation is ledger-enforced; `requireSuccessorPending` catches a mis-wired method |
| INV-5 An operation applies only on the timelock lineage that scheduled it | ✅ Yes | `Fn` 79, `Int` 14-21 | Pending membership plus signatory subset. Residual: a sole signatory can recreate the lineage; documented in both READMEs |
| INV-6 The views are visible to exactly the operation's stakeholders | ✅ Yes | ledger model | `TimelockedView` carries no party; `test_viewVisibilityFollowsTheTemplate`. `TimelockView.pending` shows every pending cid to every timelock observer, see checklist 3.2 |
| INV-7 An invalid policy (negative `minDelay`, non-positive `gracePeriod`) fails every schedule with `eInvalidConfig` | ✅ Yes | `Fn` 117-125, 136, 152 | The library cannot refuse a timelock created with an invalid policy; the consumer's `ensure` does, as the fixtures and example show |
| INV-8 An operation outside the pending list (forged, sibling, already applied) fails with `eNotPending` | ✅ Yes | `Fn` 168-172 via 79, 102 | Tested for direct creation, sibling treasury, second execution |
| INV-9 Only named executors execute and only named cancellers cancel; `executors = None` is open | ✅ Yes | `Int` 24-31 | `test_onlyNamedExecutorsMayExecute`, `test_openExecutor`, `test_onlyNamedCancellersMayCancel` |
| INV-10 (inferred) The operation's signatories are signatories of the timelock, and `authority` signs both | ⚠️ Partial | `Int` 14-21 | Subset, not equality. An operation signed by a strict subset lets that subset archive it alone, a cancel without canceller permission, and strands the pending entry. See MED-1 |
| INV-11 (inferred) The successor holds exactly the reduced pending list | ⚠️ Partial | `Int` 35-38 | Checks the list of whatever cid the method returns; cannot tell that it is the contract the method created. Documented; consumer bug only, see INFO-6 |
| INV-12 (inferred) Every lifecycle choice runs the library checks | ⚠️ Partial | `Api` 146-163; consumer methods | Holds only when `applyImpl` and `dropImpl` call the lifecycle functions. The interface cannot enforce it. See MED-2 |
| INV-13 (inferred) Guards read ledger-time bounds, never `getTime`, except `scheduleAfter` | ✅ Yes | `Fn` 137, 154, 180, 183, 194 | Prepared-ahead executions stay valid |
| INV-14 (inferred) The outcome of an operation (executed, cancelled, cleaned up) is observable by its stakeholders | ❌ Missing | `Api` 146, 156, 183-207 | Since `b702402` the exercise nodes are nonconsuming, so contract observers are not informees of them and see only `Archive` and `Create`. See MED-3 |
| INV-15 (inferred) Every pending operation has an exit | ⚠️ Partial | consumer fields | `executors = Some []`, `cancellers = []`, `gracePeriod = None` has none; an operation archived directly strands its entry until a consumer recovery choice removes it. See MED-4 and footguns F5, F8 |

## Findings

### Critical

None.

### High

None.

### Medium

#### MED-1: The authority rule accepts an operation signed by a strict subset of the timelock's signatories

**Location:** `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1/Internal.daml` lines 14-21;
`packages/security/api-timelock-v1/daml/OpenZeppelin/Api/TimelockV1.daml` line 69
**Invariant:** INV-10

**Issue:** `requireAuthority` requires `authority` to sign both contracts and
every signatory of the operation to sign the timelock. It does not require
every signatory of the timelock to sign the operation. A timelock signed by
`admin1, admin2` accepts an operation signed by `admin1` alone, as long as
`authority = admin1`.

**Impact:** `admin1` can exercise the operation template's `Archive` choice
alone. That cancels the operation without being a canceller and leaves a
pending entry that the lifecycle functions cannot remove, because they fetch
the operation. The API README's security caveats already ask the consumer to
give the operation the timelock's full signatory set and to add a recovery
choice; the library can enforce the first half, which makes the second half
unnecessary when the timelock has more than one signatory (INFO-5). The
`authority` field then does no work: with equal signatory
sets, a spoofed `authority` in a false target's view is caught by the
equality check, and the field's remaining use is display.

**Recommendation:** Compare the two signatory sets as sets and drop
`authority` from `TimelockView` before the API package freezes.

```daml
-- Internal.daml
requireAuthority : Timelock -> Operation -> Update ()
requireAuthority target op =
  unless (sort (dedup (signatory target)) == sort (dedup (signatory op)))
    (failWithStatus eInvalidAuthority)
```

If a display field is wanted, keep it out of the check. Add a fixture with a
two-signatory timelock and an operation signed by one of them, and assert
`eInvalidAuthority` on execute, cancel, and cleanup. The current
`CosignedChange` fixture covers only the extra-signatory direction.

**Status:** Open

#### MED-2: The interface choices give every observer an entry point whose safety depends on two consumer-written method bodies

**Location:** `packages/security/api-timelock-v1/daml/OpenZeppelin/Api/TimelockV1.daml` lines 136-163
**Invariant:** INV-12

**Issue:** `Timelock_Apply` and `Timelock_Drop` have `controller actor`,
where `actor` is any party that can see the timelock, and their bodies call
`applyImpl` and `dropImpl`. Every check runs inside the consumer's method. A
consumer who writes `applyImpl _ arg = do op <- fetch arg.op; apply this op
pending` has a timelock that any observer executes at once. Pausable adds no
choice to the consumer's template, so it adds no attack surface; this
component adds five choices, and the frozen bodies guarantee nothing.

The decision is deliberate (design decision 15, `ARCHITECTURE.md`
"Components without templates"), it matches the Splice token standard, and
it keeps the checks fixable. This finding does not reopen it. It asks for
the safety net that the decision needs.

**Impact:** A timelock bypass by any observer, triggered by a consumer
customization rather than by an attacker. The README states the requirement
in prose; nothing catches a violation before deployment.

**Recommendation:** Two changes, the first recommended and the second
optional.

1. Ship a conformance script. Add a module `OpenZeppelin.TimelockV1.Conformance`
   to `test/api-timelock-v1` (or a documented copy in the README) that takes
   a consumer's schedule action and a target and runs the eight assertions a
   correct wiring must satisfy: `eNotReady` before `readyAt`, `eNotExecutor`
   for a non-executor, `eNotCanceller` for a non-canceller, `eNotExpired`
   before expiry, `eNotPending` for a forged operation, `eInvalidAuthority`
   for a false target, one execution only, and an empty pending list after
   execution. The example's `treasury-test` should run it. The test package
   cannot ship in a production DAR, so the README points at the module and
   the consumer copies it.

   ```daml
   conformance : (HasToInterface o Operation, HasToInterface t Timelock)
     => Party -> Party -> Party -> ContractId t
     -> (ContractId t -> Time -> Script (ContractId t, ContractId o))
     -> Script ()
   ```

2. Optional floor in the frozen bodies. Pending membership, executor
   membership, and the time bounds need only `daml-stdlib`. Putting them in
   the choice body as well as in the function package gives a fail-closed
   floor that no consumer method can remove, while the function package
   keeps the fixable copy. The cost is that a too-strict frozen check can
   only be fixed by a `-v2` package. The team decided against logic in the
   frozen package; this review records the trade-off and recommends option 1
   as sufficient for a pre-release.

**Status:** Open

#### MED-3: Since `b702402`, the timelock's observers cannot tell an executed operation from a cancelled or cleaned-up one

**Location:** `packages/security/api-timelock-v1/daml/OpenZeppelin/Api/TimelockV1.daml` lines 125, 131, 146, 156, 183-207;
`packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1.daml` lines 84-86, 108-110
**Invariant:** INV-14

**Issue:** The Canton ledger model makes contract observers informees of
creates and consuming exercises only. `Operation_Execute`, `Operation_Cancel`,
`Operation_Cleanup`, `Timelock_Apply`, and `Timelock_Drop` are all
nonconsuming with `controller actor`. A proposer who observes the operation
and the timelock, but is not the actor and not a signatory, receives three
events for every outcome: `Archive` of the operation, `Archive` of the
timelock, `Create` of the successor with the entry removed. The exercise
node that names the choice and the `DropReason` is not in their projection.
In the example the proposer does not observe `TreasuryConfig`, so they do
not see the config change either. `TimelockController.sol` emits
`CallExecuted` and `Cancelled` to everyone.

Before `b702402` the consuming exercise informed the observers of the whole
subtree, which leaked every effect of `apply` to them. The commit traded
that leak for this blind spot and documented the first half of the trade.

**Impact:** A proposer, auditor, or dashboard party that is not the actor
cannot reconstruct the operation's outcome from its own event stream. A
vetoed proposal and an executed proposal look the same. The consumer cannot
repair it either: `unschedule : Pending -> Update (ContractId Timelock)`
receives neither the operation nor the `DropReason`, so a consumer who wants
to create a receipt on cancellation has nothing to record.

**Recommendation:** Give the consumer the data to emit the outcome, and say
in the docs that they must if their observers need it. Change the method
signatures before the freeze:

```daml
  apply : Party -> Operation -> Pending -> Update (ContractId Timelock)
    -- ^ actor, the operation, the reduced pending list
  unschedule : Party -> Operation -> DropReason -> Pending -> Update (ContractId Timelock)
    -- ^ actor, the operation, why it is dropped, the reduced pending list
```

`applyOperation` and `dropOperation` already hold `actor`, `opValue`, and
`reason` when they call the methods. With these arguments the example's
`unschedule` can create an `OperationDropped` receipt observed by the
proposer, and `apply` an `OperationApplied` receipt. An alternative is a
choice observer drawn from the view, for example `observer (view this).authority`
if MED-1 keeps that field, but that re-informs a fixed party of the whole subtree and reintroduces the
leak for that party; the method-argument route lets the consumer choose what
to reveal. Add one sentence to the "nonconsuming" caveat in the API README:
observers do not learn which choice archived the operation.

**Status:** Open

#### MED-4: The schedule path is assembled by the consumer from four pieces, and nothing checks the assembly

**Location:** `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1.daml` lines 134-172;
`examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 138-150
**Invariant:** INV-1, INV-15

**Issue:** A correct schedule choice calls `scheduleAt`, copies both fields
of the result onto the operation, creates the operation with the timelock's
signatories and the executors and cancellers as observers, and records it
with `addPending`. Each step is a line the consumer writes, and the library
verifies none of them at apply time: `requireReady` trusts the stored
`readyAt`, `requireExecutor` trusts the stored list, and `takePending`
trusts that the entry was added. The mistakes are silent until an executor
tries: `readyAt = now` stored by hand bypasses the delay; `expiresAt = None`
stored by hand disables expiry; a missing `addPending` makes the operation
unexecutable with `eNotPending`; an executor who is not an observer fails
with `CONTRACT_NOT_FOUND`; `executors = Some []` with no cancellers and no
grace period is a permanent pending entry.

**Impact:** Delay bypass or a stuck operation, caused by an integration
mistake that the library could refuse at scheduling time.

**Recommendation:** Add one function to the upgradeable package that does
the assembly and refuses the mistakes, and make it the documented path.
`scheduleAt` and `addPending` stay for consumers who need the pieces.

```daml
-- | Validate, create, and record an operation. Fails with `eInvalidConfig`,
-- `eDelayTooShort`, `eInvalidAuthority` (operation signatories differ from
-- the timelock's), `eInvalidSchedule` (the operation's `Timelocked` view is
-- not the computed schedule), or `eNoExecutor` (`executors = Some []`).
scheduleOperation
  : (Template t, HasToInterface t Operation, HasToInterface t Timelocked)
  => Timelock -> Time -> (TimelockedView -> t) -> Update (ContractId t, Pending)
scheduleOperation target readyAt mk = do
  s <- scheduleAt (view target).config readyAt
  let op = mk s
      v = view (toInterface @Timelocked op)
      ov = view (toInterface @Operation op)
  unless (v == s) (failWithStatus eInvalidSchedule)
  unless (sort (dedup (signatory op)) == sort (dedup (signatory target)))
    (failWithStatus eInvalidAuthority)
  when (ov.executors == Some []) (failWithStatus eNoExecutor)
  cid <- create op
  pure (cid, addPending cid (view target).pending)
```

The consumer's choice becomes three lines:

```daml
      do
        (op, pending') <- scheduleOperation (toInterface @Timelock this) readyAt \s ->
          LimitChange with admin; proposer; executor; newLimit; readyAt = s.readyAt; expiresAt = s.expiresAt
        t <- create this with pending = pending'
        pure (t, op)
```

A stakeholder check for executors and cancellers
(`` all (`elem` stakeholder op) (fromOptional [] ov.executors <> ov.cancellers) ``)
fits the same place and turns the `CONTRACT_NOT_FOUND` at execute time into
a named failure at schedule time.

**Status:** Open

### Informational

#### INFO-1: Role changes are not delayed in the example, and the pattern has no place for them

**Location:** `examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 95-106, 184-202

**Issue:** `proposer` and `executor` are fields of `TreasuryTimelock` and of
every operation. No operation kind changes them, so the only way to replace
a proposer is a new timelock outside the lineage. In `TimelockController.sol`
the timelock holds `DEFAULT_ADMIN_ROLE` on itself, so a role grant is a
scheduled operation.

**Recommendation:** Add a `RolesChange` operation kind to the example whose
`apply` creates the successor with the new `proposer` and `executor`, and a
sentence in the API README's authority section: role changes are operations
too. See the first row of the comparison table.

**Status:** Open

#### INFO-2: No pure state function for dashboards and tests

**Location:** `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1.daml` lines 199-209

**Issue:** `isReadyAt` and `isExpiredAt` answer two yes-or-no questions. A
dashboard wants one answer per operation, and `TimelockController.sol` has
`getOperationState`.

**Recommendation:** Add to the function package:

```daml
data OperationState = Waiting | Ready | Expired deriving (Eq, Show)

operationStateAt : HasToInterface t Timelocked => Time -> t -> OperationState
operationStateAt now x
  | isExpiredAt now x = Expired
  | isReadyAt now x = Ready
  | otherwise = Waiting
```

`Done` is not representable from the ACS; see the comparison section.

**Status:** Open

#### INFO-3: Every consumer writes the same `ConfigChange` template

**Location:** `examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 163-179, 205-223;
`test/api-timelock-v1/daml/OpenZeppelin/Api/TimelockV1TestFixtures.daml` lines 124-136, 181-198

**Issue:** The fixture and the example each define a `ConfigChange` template
and a `Treasury_ScheduleConfig` choice with identical bodies. Every consumer
will too, because the policy is a frozen type and the self-administration
pattern is fixed.

**Recommendation:** `ARCHITECTURE.md` allows templates in the implementation
package. Ship `OpenZeppelin.TimelockV1.ConfigChange` with fields
`signatories : [Party]`, `observers : [Party]`, `executors`, `cancellers`,
`newConfig`, `readyAt`, `expiresAt`, plus `applyConfigChange : ConfigChange -> TimelockConfig`
for the `apply` branch. If the team prefers no templates in the function
package, keep the example as the reference and say so in the README.

**Status:** Open

#### INFO-4: The example validates consumer-visible preconditions with `assertMsg`

**Location:** `examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 81-82, 144;
`packages/security/api-timelock-v1/README.md` Usage steps 4 and 5

**Issue:** `Treasury_Pay` and `TreasuryTimelock_ScheduleLimit` refuse bad
input with `assertMsg`, which reaches the client as `UNHANDLED_EXCEPTION`
with no `errorId`. The library's own failures are all `failWithStatus`, and
the README copies the `assertMsg` form into the integration guide.

**Recommendation:** Use `failWithStatus` with an example-scoped status in
both places, as `eUnknownOperation` already does.

**Status:** Open

#### INFO-5: The prune choice can orphan a live operation

**Location:** `examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 152-161

**Issue:** `TreasuryTimelock_Prune` removes any entries `admin` names. The
comment says removing a live entry cancels the operation. It does not
archive it, so the operation contract stays active, keeps answering
`Timelocked` interface queries, and can never be applied or dropped through
the lifecycle again (`eNotPending`). Only a direct `Archive` removes it.

The choice cannot check the entries it removes. Daml has no way to ask
whether a contract is archived: `fetch` on an archived contract aborts the
transaction instead of returning an answer. So no code can accept stale
entries and refuse live ones. The caller must be trusted to name only stale
entries.

**Recommendation:** Prevent stale entries, and keep the recovery choice for
the single-signatory case.

1. Prevention: MED-1. With set equality in `requireAuthority`, an operation
   carries every signatory of the timelock, so with several signatories no
   single party can archive it directly. A stale entry then needs all
   signatories to create.
2. Recovery: keep `TreasuryTimelock_Prune`, controlled by a party that is a
   canceller of every operation the timelock schedules, so that the choice
   grants no new power. Fix the comment: removing a live entry orphans the
   operation and does not cancel it. To cancel a live operation, use
   `Operation_Cancel`.
3. Detection: add a Script helper to `examples/timelock/treasury-test` that
   runs `queryContractId` on each `pending` entry and collects the ones that
   return `None`. This is the list an operator passes to the prune choice.
   The current test passes a stale id it already knows, which a real
   operator cannot do.

A library helper for the prune itself adds nothing: the removal is one
`filter`, and the library cannot check the entries either.

**Status:** Open

#### INFO-6: The successor check cannot see which contract the method created

**Location:** `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1/Internal.daml` lines 35-38

**Issue:** `requireSuccessorPending` fetches the cid the method returned and
compares its pending list. A method that returns the cid of an unrelated
`Timelock` contract with an equal list passes. The README says so. It is a
consumer bug with no attacker, so no change is recommended beyond keeping the
caveat.

**Status:** Acknowledged

#### INFO-7: Failure statuses carry no metadata

**Location:** `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1/Internal.daml` lines 112-117

**Issue:** Every status has `meta = TextMap.empty`. A client that receives
`eNotReady` has to query the operation again to learn `readyAt`; a client
that receives `eNotPending` does not learn which timelock it should have
targeted. The tests compare whole `FailureStatus` values, which works only
while `meta` is static.

**Recommendation:** Consider `meta` entries for `readyAt` and `expiresAt` on
`eNotReady` and `eExpired`, and for the operation cid on `eNotPending`, and
switch the tests to compare `errorId`, which is what the README tells
clients to match. This is a function-package change and can wait.

**Status:** Open

#### INFO-8: A troubleshooting table is missing for the failures that are not `FailureStatus` values

**Location:** `packages/security/api-timelock-v1/README.md`, "Execute, cancel, and clean up" and "Contract ids"

**Issue:** An integrator will hit three errors that carry no `errorId`, and
the README explains each cause in a different section: `CONTRACT_NOT_FOUND`
when the executor is neither a stakeholder of the operation nor given a
disclosure; `CONTRACT_NOT_ACTIVE` when `target` is a superseded timelock or
the operation was archived directly; an authorization failure when the
consumer's `apply` touches a contract the timelock's signatories cannot
archive. A fourth, `eUnknownOperation` when `apply` lacks a branch, is a
consumer-defined status that the library does not list.

**Recommendation:** One table in the README: symptom, cause, fix.

**Status:** Open

#### INFO-9: The suite lacks a two-signatory timelock

**Location:** `test/api-timelock-v1/daml/OpenZeppelin/Api/TimelockV1TestFixtures.daml`

**Issue:** Every timelock fixture and the example's timelock have one
signatory. The README's
central security claim is that several signatories bind the delay because
one refuser blocks a contract outside the lineage, and MED-1 concerns an
operation signed by a subset. Neither is exercised.

**Recommendation:** Add a `JointTreasury` fixture signed by two admins with
operations signed by both, and tests for: a direct config create by one admin
fails; a full lifecycle succeeds; an operation signed by one admin is refused
(after MED-1) or can be archived by that admin alone (before MED-1).

**Status:** Open

#### INFO-10: The API README misstates what the package contains

**Location:** `packages/security/api-timelock-v1/README.md` lines 15, 296

**Issue:** "What it provides" opens with "Three interfaces and their views",
and the list below it has six entries. `TimelockConfig`, `Pending`, and
`DropReason` are types, not interfaces. "Off-ledger reads" says
`TimelockedView` "is the whole data surface of the interface". `TimelockView`
and `OperationView` are also readable off-ledger, and the same section tells
readers to match results against `TimelockView.pending`.

**Recommendation:** Open the list with "Three interfaces, their views, and
three supporting types". Replace the "whole data surface" sentence with one
that names all three views and says which reader needs which.

**Status:** Open

#### INFO-11: The lifecycle table has no end state for a cancelled or cleaned-up operation

**Location:** `packages/security/api-timelock-v1/README.md` lines 287-292

**Issue:** The table ends with `Done`, which covers `Timelock_Apply` only.
The "Ends when" column sends Waiting, Ready, and Expired operations to
cancellation or cleanup, but no row says what state they reach.

**Recommendation:** Add a `Dropped` row: `Timelock_Drop` archives the
operation and removes its pending entry, and the state is final. If MED-3
lands, say which receipt, if any, records each final state.

**Status:** Open

#### INFO-12: The API README states the same facts in two to four places

**Location:** `packages/security/api-timelock-v1/README.md`

**Issue:** At 443 lines the README is three times the length of the
function package's README, for a package with no logic. Much of the length
is repetition:

| Fact | Lines |
|---|---|
| The lifecycle function archives the operation before `apply` | 24, 205, 332 |
| An operation outside the pending list has no effect | 35-38, 220-223, 243, 313-315 |
| Cleanup is open to any actor | 39-40, 267, 367 |
| Scheduling and applying contend on the timelock | 62-64, 344-348 |
| Execution order is a precondition on governed state | 281-283, 349-352 |
| A fix ships in `openzeppelin-timelock-v1`; this package stays frozen | 42-45, 335-339, 382-386 |

The `Timelock` bullet at lines 17-25 also walks through what
`applyOperation` does, which "Execute, cancel, and clean up" repeats.

**Recommendation:** State each fact once, in the section a reader would
look for it, and cut the `Timelock` bullet to what the interface declares.
The additions that MED-3, INFO-1, and INFO-8 request make this cut more
pressing.

**Status:** Open

#### INFO-13: The API README carries content that `AGENTS.md` places elsewhere

**Location:** `packages/security/api-timelock-v1/README.md` lines 264-276,
328-334, 357, 363, 383, 387-388, 400-405, 407-410

**Issue:** `AGENTS.md` asks package READMEs not to restate standard Daml
semantics or repository release policy, not to describe planned work, and
to keep design rationale in `ARCHITECTURE.md`. The README has:

- Release policy restated from `RELEASING.md` (lines 407-410: `dars/released/`,
  package IDs changing between commits).
- A hypothetical `openzeppelin-api-timelock-v2` (lines 387-388), and a
  migration bullet (lines 400-405) that plans for it and mostly restates SCU
  limitations.
- Standard semantics: "Every stakeholder of an operation sees its
  parameters" (line 357) and "Daml interface definitions sit outside SCU"
  (line 383).
- Solidity comparisons (`TimelockController.sol`, `address(0)`,
  `updateDelay`, `AccessManager` `minSetback`) at lines 264-276 and 363.
  These are design rationale.
- The internals of `requireSuccessorPending` (lines 328-334): what it reads
  and what it cannot tell. That belongs in the function package's README.

**Recommendation:** Replace lines 407-410 with the status line and the link
to `RELEASING.md`. Remove the v2 sentences and the migration bullet. Remove
the two standard-semantics sentences. Move the Solidity mapping to
`ARCHITECTURE.md`, or keep one sentence that maps the Solidity names to
this component. For `minSetback`, state the current behavior in Canton
terms, as the comparison row "`AccessManager.minSetback`" asks, without the
Solidity name. For lines 328-334, keep the consumer's half, which INFO-6
asks to keep: `apply` must dispatch each operation correctly and return
the successor it created. Move the description of the check to the
`openzeppelin-timelock-v1` README.

**Status:** Open

#### INFO-14: The authority section mixes usage guidance into an unrelated list

**Location:** `packages/security/api-timelock-v1/README.md` lines 250-283

**Issue:** "Authority and lifecycle" has two consecutive bullet lists. The
second one is not a set of parallel items: it covers role credentials, open
executors, cleanup, policy changes, and execution order. Policy changes and
execution order are usage guidance, not authority.

**Recommendation:** Keep role credentials and open executors under
authority. Move policy changes and execution order to a "Changing the
policy" subsection under Usage. Cleanup is already stated elsewhere
(INFO-12).

**Status:** Open

#### INFO-15: A delay reduction waits the current delay and nothing longer

**Location:** `packages/security/timelock-v1/daml/OpenZeppelin/TimelockV1.daml` lines 134-141;
`examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 167-179;
`packages/security/api-timelock-v1/README.md` lines 268-280

**Issue:** A policy change is scheduled under the policy in force, so a
reduction waits the current `minDelay`. From the moment it is scheduled, no
operation can use the shorter delay until the old delay has passed. This
already gives the setback of `AccessManager`, as the comparison row says.
`AccessManager` waits `max(old - new, minSetback)`. The current rule waits
`old`, which is at least `old - new`. It is shorter only when `minSetback` is
longer than the current delay.

That case is real. A timelock with a one-hour delay can reduce it to zero
one hour after the change is scheduled. After the change applies, the next
operation executes at once. A consumer who wants a longer floor for
reductions, for example one week, has to write the check in their own
schedule choice. The library has no helper for it, and the README calls it
"the consumer's to add" without showing how.

The README also asks the consumer to cancel pending operations that do not
meet a stricter policy (F14). The library cannot check this, because an
operation does not store when it was scheduled.

**Recommendation:** Add a schedule function for policy changes to the
upgradeable package. It needs no change to the frozen package.

```daml
-- | Compute the schedule of a policy change from `current` to `proposed`.
-- Fails as `scheduleAt` does, with `eInvalidConfig` when `proposed` is
-- invalid, and with `eDelayTooShort` when `proposed` lowers `minDelay` and
-- `readyAt` is closer than `minSetback`.
scheduleConfigAt : TimelockConfig -> TimelockConfig -> RelTime -> Time -> Update TimelockedView
scheduleConfigAt current proposed minSetback readyAt = do
  requireValidConfig proposed
  s <- scheduleAt current readyAt
  when (proposed.minDelay < current.minDelay) do
    early <- isLedgerTimeLE (addRelTime readyAt (negate minSetback))
    unless early (failWithStatus eDelayTooShort)
  pure s
```

Use it in `TreasuryTimelock_ScheduleConfig`, and test that a reduction to
zero fails before `minSetback` and succeeds at it. In the README, replace
the `minSetback` sentence with the current rule in Canton terms and a pointer
to `scheduleConfigAt`. Keep F14 as documentation.

**Status:** Open

#### INFO-16: The only runnable example shows a setup where the delay protects no one outside the roles

**Location:** `examples/timelock/treasury/daml/OpenZeppelin/Examples/Timelock/Treasury.daml` lines 22-26, 50-57, 65-70, 95-105, 184-194, 205-215;
`packages/security/api-timelock-v1/README.md` lines 250-252

**Issue:** The example is the only runnable consumer project, so it is the
shape integrators copy. It has two gaps that the module header and the
README describe but the code does not fix.

- `admin` is the sole signatory of all three contracts. `admin` alone can
  create a `TreasuryConfig` with any limit, or a second `TreasuryTimelock`,
  and skip the delay. The example binds only `proposer` and `executor`.
- No party outside the roles can see a pending change. `Treasury` has no
  observers, and `TreasuryTimelock`, `LimitChange`, and `ConfigChange` are
  visible only to `proposer` and `executor`. A timelock exists so that
  affected parties see a change before it takes effect and can react. In
  the example, no depositor or counterparty gets that warning.

The example teaches the mechanics well: the three-contract split, the
dispatch in `apply`, and the schedule-then-execute flow. As a reference
integration, it shows a setup that the README itself calls non-binding, and
the warning is lost when the code is copied.

**Recommendation:** Make the example binding.

- Sign all three contracts and every operation with two parties, `admin`
  and `guardian`. Create the initial contracts through a propose-and-accept
  template, or with `actAs [admin, guardian]` in the test.
- Add a `watcher` party, for example a depositor, as an observer of the
  timelock and of every operation. Choose the observers of `TreasuryConfig`
  with the same rule, so that the watcher also sees the applied change.
- Add tests to `examples/timelock/treasury-test`: `admin` alone fails to
  create a `TreasuryConfig` or a `TreasuryTimelock`; the watcher sees a
  pending `LimitChange` and its `readyAt` before it matures; a full
  lifecycle succeeds with both signatories.
- Keep the single-signatory code only as the README snippets, which explain
  the wiring. Update the example's module header and the README bullet at
  lines 250-252 to describe the new example.

This finding complements INFO-9, which adds a two-signatory fixture to the
test suite. INFO-9 tests the library; this finding changes what integrators
copy.

**Status:** Open

## Comparison with `TimelockController.sol`

Capabilities of the Solidity contract, what the component offers, and the
change that closes each gap that matters on Canton.

| `TimelockController.sol` | This component | Gap | Change |
|---|---|---|---|
| `PROPOSER_ROLE`, `EXECUTOR_ROLE`, `CANCELLER_ROLE` granted and revoked through `AccessControl`, with the timelock as its own `DEFAULT_ADMIN_ROLE`, so role changes are delayed | Proposer is the schedule choice's controller; executors and cancellers are party lists fixed on each operation at scheduling | Role changes are neither uniform nor delayed unless the consumer writes an operation for them; the example has none (INFO-1) | Add a `RolesChange` operation kind to the example and the README. Consider a `roles` record on `TimelockView` before the freeze so dashboards read roles in one shape and schedule choices copy them onto operations |
| Open executor via `address(0)` | `executors = None` plus explicit disclosure | None | - |
| Optional deployer admin for bootstrap, to be renounced | The signatories can never be renounced; a sole signatory recreates any contract | Inherent to Daml, documented in both READMEs and the example header | Keep the multi-signatory guidance prominent; add the two-signatory fixture (INFO-9) so the claim is tested |
| `getMinDelay`, `updateDelay` callable only by the timelock itself | `TimelockConfig.minDelay`; a `ConfigChange` operation scheduled under the current policy | None in behavior; every consumer writes the same template (INFO-3) | Ship a reference `ConfigChange` |
| `AccessManager.minSetback` (a delay reduction waits) | A policy change waits out the current `minDelay` before it applies | None in effect while `minSetback` is at most the current delay: from the moment a reduction is scheduled, no operation can use the shorter delay until the old delay has elapsed once. No floor longer than the current delay (INFO-15) | Close the proposal's open question 5 and state this in the README; add `scheduleConfigAt` for a longer floor (INFO-15) |
| `hashOperation` id, precomputable off-ledger, duplicate schedule refused (`Unset` check), `salt` | The contract id; two schedules with equal parameters are two operations | No dedup and no precomputable id | Document. A schedule choice that wants dedup compares parameters against the pending operations it can fetch |
| `predecessor` | None; a precondition on the governed state | Designed out (decision 2) | - |
| `scheduleBatch`, `executeBatch` | One operation template whose fields hold several effects | Designed out (decision 3) | - |
| `OperationState` (`Unset`, `Waiting`, `Ready`, `Done`), `isOperationX`, `getTimestamp` | `isReadyAt`, `isExpiredAt`, the `Timelocked` view | No single state function; `Done` has no ACS representation | Add `operationStateAt` (INFO-2). For `Done`, let `apply` create a receipt (MED-3 gives it the data) |
| Events `CallScheduled`, `CallExecuted`, `Cancelled`, `MinDelayChange`, visible to all | The transaction tree; since `b702402` the outcome is visible to signatories and the actor only | Observers cannot distinguish outcomes (MED-3) | Method arguments for `actor`, the operation, and `DropReason` |
| Reentrancy guard `_afterCall` re-checks `Ready` | Archive before `apply`, then `requireSuccessorPending` | None | - |
| No expiry | `gracePeriod`, `requireExpired`, cleanup by anyone | Superset, from `AccessManager` and the Sui port | - |
| Public state and payloads | Only stakeholders see an operation | Superset | - |
| Receives ETH, ERC-721 and ERC-1155 | Not applicable; a Daml timelock holds no assets | - | - |

## Developer Experience

### Integration

The integration is five steps and the README carries all five with code. The
boilerplate per operation kind is a template with the parameters, two time
fields, and every role party; two interface instances; a schedule choice of
about twelve lines; and a branch in `apply`. The timelock adds a view, four
methods, an `ensure`, and a recovery choice.

- `applyImpl self arg = applyOperation (toInterface @Timelock this) self arg`
  and its `dropImpl` twin are pure ceremony, but the no-logic rule for the
  frozen package leaves no alternative, and Daml interfaces have no default
  method bodies. The doc comments give the exact line. Keep them.
- The schedule choice is where the mistakes live (MED-4). `scheduleOperation`
  cuts it to three lines and turns four silent errors into named failures.
- A reference `ConfigChange` (INFO-3) removes one template from every
  integration.
- The same party lists appear on the timelock's observers, each operation's
  observers, each `OperationView`, and the governed config's observers. A
  checklist in the README ("who must observe what") would prevent the
  `CONTRACT_NOT_FOUND` surprise that design decision 8 records from the
  first test run.
- Three contract-id types for one operation contract (`ContractId LimitChange`,
  `ContractId Timelocked`, `ContractId Operation`) mean `toInterfaceContractId`
  on most lines of Daml-side client code. Ledger API clients pass raw ids
  and are unaffected. The fixtures' `asOp`, `opOf`, `targetOf` helpers are
  the right answer; publish them.

### Debugging

- Ten stable `errorId` values under `openzeppelin.com/timelock-` are the
  strongest DevEx feature of the component. The `FailureCategory` choices
  are right: retryable states use `InvalidGivenCurrentSystemStateOther`,
  permanent ones use `InvalidIndependentOfSystemState`.
- The check order in `applyOperation` is good for diagnosis: pending
  membership fails before visibility, authority before permission,
  permission before time.
- The failures that are not `FailureStatus` values need one table (INFO-8).
- Empty `meta` costs a round trip per failure (INFO-7).
- The example test at `examples/timelock/treasury-test` is a runnable
  walkthrough; `dpm test` on it is the fastest way to see every path.

### Testing an integration

- Daml Script with `passTime` and the ledger-time bounds gives deterministic
  tests; the suites show the pattern for every guard and both bounds.
- The fixture helpers `execute`, `tryExecute`, `cancel`, `cleanup`,
  `expectFailure`, and `isFailureWith` are exactly what a consumer needs and
  are not visible to them. Publish them as a copyable module, or as the
  conformance script of MED-2.
- A consumer cannot test the privacy property of `b702402` in Daml Script,
  because `query` reflects stakeholders, not informees. Say so in the
  README's testing guidance and describe the expected projection instead.
- Coverage: `dpm test --show-coverage` cannot see into the function package,
  so the consumer's own tests are the evidence, as `CONTRIBUTING.md` says
  for Pausable.

## Footgun Register

| # | Footgun | Consequence | Current mitigation | Proposed |
|---|---|---|---|---|
| F1 | `applyImpl` or `dropImpl` does not call the lifecycle function | Any observer applies or drops at will | Doc comments, README requirement | Conformance script (MED-2) |
| F2 | Schedule choice stores its own `readyAt` or `expiresAt`, or skips `addPending` | Delay bypass, no expiry, or `eNotPending` forever | README code | `scheduleOperation` verifies the view and records the entry (MED-4) |
| F3 | Operation template lists fewer signatories than the timelock | One signatory archives it alone; stranded pending entry | README caveat, example `Prune` | Set equality in `requireAuthority` (MED-1) |
| F4 | Executors or cancellers are not stakeholders of the operation, the timelock, or the governed config | `CONTRACT_NOT_FOUND` at execute time | README steps 1 and 3 | Stakeholder check in `scheduleOperation`; troubleshooting table (INFO-8) |
| F5 | `executors = Some []` with `cancellers = []` and `gracePeriod = None` | Permanent pending entry | None | Refuse `Some []` in `scheduleOperation`; document `[]` cancellers |
| F6 | Executor submits with a superseded `target` id | `CONTRACT_NOT_ACTIVE`; retry | README "Contract ids" | Automation guidance: read the current id from the `Timelock` interface filter before each submit |
| F7 | `TimelockConfig` with `minDelay = 0` | No delay, no error | Documented; same as Solidity | None |
| F8 | Recovery choice removes a live entry | Orphan operation visible in interface queries | Comment | Cannot be checked on-ledger; prevent stale entries with MED-1, fix the comment, and find stale entries off-ledger (INFO-5) |
| F9 | `minDelay` or `gracePeriod` within twice the ledger-time tolerance | Effective delay or window collapses to zero | "Time on Canton" section | Keep; add a recommended minimum in the README, such as one hour |
| F10 | `addPending` called twice for one operation | One stale entry after apply; harmless | None | Document |
| F11 | Consumer's `apply` archives `this` | Double archive, transaction fails | None | One sentence in the `apply` doc comment: the lifecycle function has archived the timelock |
| F12 | `apply` returns a foreign `Timelock` cid with an equal pending list | Successor check passes | README caveat | None (INFO-6) |
| F13 | Observer relies on events to learn the outcome | Cannot distinguish execute, cancel, cleanup | Partial caveat | MED-3 |
| F14 | Stricter policy applied while lenient operations are pending | They execute at their original `readyAt` | README bullet | Keep as documentation; the library cannot check it (INFO-15) |

## Security Checklist Results

| Category | Result | Notes |
|---|---|---|
| 3.1 Authorization | Pass | No production template. Interface choices have `controller actor`; authority for archives comes from the timelock's signatories, and `requireAuthority` keeps operation signatories inside that set. Authorization is not transitive: `test_falseTargetCannotUseOperationAuthority` confirms a false target cannot spend the operation's authority. Withdraw paths exist (cancel, cleanup) except in the F5 configuration |
| 3.2 Privacy | Pass with notes | Views carry no party except `OperationView` and `TimelockView.authority`, visible to stakeholders only. `TimelockView.pending` shows every pending cid to every timelock observer, a count-and-timing metadata leak between operations with different stakeholder sets; acceptable, document. The actor of `Timelock_Apply` sees the whole `apply` subtree; documented. The `b702402` change removes the observers' leak and creates the MED-3 blind spot |
| 3.3 Integrity | Pass | Every library failure is `failWithStatus` with a DNS-prefixed, unique, stable id and the right category. `isValidConfig` covers the policy; operation templates have no `ensure` and rely on schedule-time checks. The example uses `assertMsg` in two consumer-visible places (INFO-4). No `agreement`, no user-defined exceptions, no `Decimal` arithmetic in the library |
| 3.4 Contract keys | Not applicable | LF 2.1, no keys. Binding is by pending membership; `Operation_Execute` takes the current `target` id explicitly, and a stale id fails closed |
| 3.4a Admin layer | Pass | No Ownable, AccessControl, or Pausable in the component. The pending list is carried on the contract being exercised, never on a caller-supplied context, so it is not spoofable. Policy changes are gated by the same delay |
| 3.5 Composability and contention | Pass | Every list change archives the timelock; two proposers contend; the three-contract layout keeps business choices out of it. Check-effects order: archive operation and timelock, then `apply`, then verify successor. Reassignment: no signatory set changes in the lifecycle |
| 3.6 Economic security | Not applicable | No value flows in the library. The example's `Treasury_Pay` is limit-checked and refuses non-positive payouts via `Payout`'s `ensure` |
| 3.7 Upgrade safety | Pass | API package has no templates; function package has no templates or interfaces; consumer templates upgrade under SCU with the instance retained. No `daml.lock` in the repository; `dars/manifest.yaml` and `RELEASING.md` carry package identity instead. MED-1 and MED-3 change the API package and must land before the freeze |

## Test Coverage Assessment

The suites cover both bounds of both time checks, every failure status, the
pending-list binding across the lineage, direct and forwarded calls, false
targets in both authority directions, mis-wired `apply` and `unschedule`,
the open executor and open cleanup through disclosure, atomicity of a failed
`apply`, and self-administration including the zero-delay case.

Gaps relative to the findings:

- No two-signatory timelock (INFO-9, MED-1), and no example test in which a
  party outside the roles sees a pending change (INFO-16).
- No test that an executor who is not a stakeholder fails at execute time
  (F4), the case design decision 8 records.
- No test of `TreasuryTimelock_Prune` on a live entry (INFO-5).
- No test of a schedule choice that stores a `readyAt` different from the
  computed one (MED-4); the library has no check for the test to hit.
- `test/timelock-v1` does not cover `applyOperation` and `dropOperation`
  directly; they are covered through `test/api-timelock-v1`. Acceptable, say
  so in the test module header.
- The privacy property of `b702402` is untestable in Daml Script; the README
  should state the expected projection.

## Artifact Drift

The four root documents predate the package split, the lifecycle interfaces,
and `b702402`. Drift is grouped by document.

- **Artifact:** `timelock-design.md` → **Stale:** one package
  `openzeppelin-timelock-api-v1`, module `OpenZeppelin.TimelockV1`, "No
  sibling implementation package", "Sixteen exports", nine failure statuses,
  "Zero interface choices, zero methods" (decision 7), consumer apply choice
  "bind, guard, archive, apply", `treasuryId`, `eWrongTarget`, 40 scripts,
  `TreasuryDemo.daml`, "Every list change is consuming", correspondence rows
  for `execute` and `cancel` → **Current:** two packages
  `openzeppelin-api-timelock-v1` (`OpenZeppelin.Api.TimelockV1`) and
  `openzeppelin-timelock-v1` (`OpenZeppelin.TimelockV1`); five interface
  choices and four methods; `applyOperation` and `dropOperation`; ten
  statuses; binding by pending list only; 49 plus 16 scripts;
  `TreasuryTest.daml`; nonconsuming choices with `archive self` →
  **Suggested update:** rewrite Package Shape, Public API, Integration
  Patterns, and the correspondence table; keep the decisions log as history
  and add decisions for the split, `applyImpl`/`dropImpl`, and `b702402`.
- **Artifact:** `timelock-proposal.md` → **Stale:** `openzeppelin-timelock-api-v1`
  with module `OpenZeppelin.TimelockV1`; "nine `FailureStatus` values";
  consumer sketch without `applyImpl`, `dropImpl`, `ensure isValidConfig`;
  example paths at `5f2d550` and `packages/security/timelock-api-v1`;
  "40 scripts"; `TreasuryDemo.daml`; "Invariants summary: not written yet";
  open question "shrinks the frozen surface to twelve exports" (`scheduleAfter`
  is in the upgradeable package now) → **Current:** as above →
  **Suggested update:** refresh section 3 and 4 against `b702402`; point
  section 5 at the invariant table in this report until an invariants
  artifact exists.
- **Artifact:** `timelock-research-doc.md` → **Stale:** Recommendation
  section describes a `Timelocked`-only interface with schedule functions
  and guards, and "Ship a frozen `openzeppelin-timelock-api-v1` package" →
  **Current:** three interfaces with lifecycle choices in the API package
  and functions in a second package → **Suggested update:** one paragraph
  noting the design moved the lifecycle into interfaces; the research
  findings themselves are current.
- **Artifact:** `timelock-pr-description.md` → **Stale:** the "Changes"
  and "Security review" lists end before `b702402` → **Current:** the
  lifecycle choices are nonconsuming and the lifecycle functions archive the
  timelock → **Suggested update:** add `b702402` to the changes list and
  mention the observer projection it changes. The test counts (49 and 16)
  are correct.

## Recommendation

- **Overall verdict:** Needs fixes before the API package freezes. Ready for
  merge as a pre-release with the Medium findings tracked.
- **Blocking before the first tagged release:**
  - MED-1: signatory set equality in `requireAuthority`; retire
    `TimelockView.authority` or demote it to display.
  - MED-3: `apply` and `unschedule` receive `actor`, the operation, and (for
    `unschedule`) the `DropReason`; README states that observers do not learn
    which choice archived the operation.
  - INFO-9: the two-signatory fixture. It changes only the test package, but
    it tests the README's main security claim and MED-1.
- **Suggested improvements (function package, examples, docs; any time):**
  - MED-4 `scheduleOperation`; MED-2 conformance script; INFO-1 `RolesChange`
    in the example; INFO-2 `operationStateAt`; INFO-3 reference
    `ConfigChange`; INFO-4 `failWithStatus` in the example; INFO-5 `Prune`
    comment fix and stale-entry detection; INFO-7 `meta`; INFO-8
    troubleshooting table; INFO-16 a binding example with a watcher party.
  - API README: INFO-10 corrections; INFO-11 `Dropped` state; INFO-12
    deduplication; INFO-13 content moved or removed per `AGENTS.md`; INFO-14
    authority section split.
  - Close the proposal's open question 5 (`minSetback`): the current rule already provides
    it up to the current delay; document, and add `scheduleConfigAt` for a
    longer floor (INFO-15).
  - Keep `scheduleAfter` (the proposal's open question 1): it lives in the upgradeable
    package, so it costs nothing frozen.

## Out of Scope

- `TimelockController.sol` features that depend on calldata forwarding or
  contract ownership (`predecessor`, batches, ETH and token receipt): the
  research and design rejected them with reasons this review accepts.
- The Pausable, Access Control, Ownable, and Token CIP-0112 packages: not in
  this changeset; touched only where the timelock docs reference them.
- CI workflow files under `.github/`: reviewed for what they enforce, not
  changed or audited.
- Formal verification and property tests: separate post-core skills.
- Performance of the pending list beyond the documented unbounded growth.

## Dev Notes

- `timelock-pr-description.md` ends with a "Generated with Claude Code"
  line. The repository owner's global instructions forbid that line in any
  PR description; remove it before opening the PR.
- The last commit, `b702402`, is the only one in the branch by a second
  author and it changes the frozen package's choice kinds. MED-3 is a direct
  consequence; whoever owns that decision should read MED-3 first.
- No invariants artifact exists. The INV numbering in this report extends
  the design's candidates and the tests' references; if an invariants stage
  runs later, it should adopt INV-1 to INV-9 as they stand and decide on
  INV-10 to INV-15.
- SDK 3.4.11 was not installed under DPM on the review machine and had to
  be installed to build; `CONTRIBUTING.md` covers this with `dpm install`.

## Open Questions

1. MED-1: keep `authority` as a display-only field, or remove it from
   `TimelockView`? Removal is cleaner; keeping it costs one frozen field.
2. MED-2 option 2: does the team want a fail-closed floor in the frozen
   choice bodies, accepting that a too-strict check needs a `-v2`?
3. MED-3: method arguments (recommended) or a choice observer from the view?
4. INFO-3: templates in `openzeppelin-timelock-v1`, or examples only?
5. Should `TimelockView` carry a `roles` record before the freeze, so that
   role changes have a uniform shape (INFO-1)?
6. Carried from the proposal: `scheduledAt` or the proposer on a view for
   dashboards. This review recommends neither; the create event has both,
   and MED-3 gives the consumer a receipt path.

## Verification

Commands run from the repository root on 2026-09-29, after `dpm install 3.4.11`:

```sh
for p in packages/security/api-timelock-v1 packages/security/timelock-v1 \
         test/api-timelock-v1 test/timelock-v1 \
         examples/timelock/treasury examples/timelock/treasury-test; do
  DAML_PACKAGE=$p dpm build
  DAML_PACKAGE=$p dpm damlc lint
done
DAML_PACKAGE=test/api-timelock-v1 dpm test --all --show-coverage
DAML_PACKAGE=test/timelock-v1 dpm test --all --show-coverage
DAML_PACKAGE=examples/timelock/treasury-test dpm test --all
```

Results: six DARs built; lint reports "No hints" for all six; 49, 16, and 1
scripts pass with exit code 0. Coverage notes: the fixtures' `Archive`
choices and `Probe_RequireValidConfig` are reported as never exercised
(failed submissions do not count), and both production packages report zero
external templates and zero external interface choices.

---

## Manual review

The wording is heavily AI-influenced, and is thus harder to parse. 
Writing style should be simple technical English, with a natural sentence construction, making it easier not just for AI, but for humans to parse them.
