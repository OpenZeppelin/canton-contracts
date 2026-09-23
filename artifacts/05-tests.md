---
stage: tests
project: pausable
mode: extension
extends: test/api-pausable-v1, test/pausable-v1
status: draft
timestamp: 2026-09-23
author: nenad.misic
previous_stage: null
tags: [pausable, interface, security, daml-script]
---

# Pausable - Test Suite

## Summary

Standalone tests pass over `openzeppelin-api-pausable-v1` and
`openzeppelin-pausable-v1`, run without an invariants artifact. The
invariants below are extracted from the two package READMEs,
`ARCHITECTURE.md`, and the doc comments, then checked against the existing
Daml Script suites in `test/api-pausable-v1` and `test/pausable-v1`. The pass
kept every existing test verbatim and added tests where an invariant or a
documented caveat had no test: the stable `errorId` strings, the stale
predecessor id, the per-contract scope of the switch, the unpause and
recovery authority, the disclosure requirement for a non-stakeholder flip
controller, and the interface's lack of any flipping choice.

## Invariants

Extracted for this pass; no `03-invariants.md` exists for the component.

| ID | Invariant | Source |
|---|---|---|
| INV-1 | A choice that calls `whenNotPaused this` runs while `paused = False` and fails with exactly `eEnforcedPause` while `paused = True`. | `OpenZeppelin.PausableV1` doc comments |
| INV-2 | A choice that calls `whenPaused this` runs while `paused = True` and fails with exactly `eExpectedPause` while `paused = False`. | `OpenZeppelin.PausableV1` doc comments |
| INV-3 | `isPaused` is pure and agrees with `PausableView.paused`. | `OpenZeppelin.PausableV1` doc comments |
| INV-4 | `eEnforcedPause.errorId` is `openzeppelin.com/pausable-enforced-pause` and `eExpectedPause.errorId` is `openzeppelin.com/pausable-expected-pause`; the two are distinct and stable across versions. | `pausable-v1` README, Compatibility |
| INV-5 | The guard reads the flag from the contract being exercised. A caller supplies nothing the guard trusts, and a stale predecessor id does not run a gated choice against the old flag. | `ARCHITECTURE.md`, Components without templates; `pausable-v1` README, Authority |
| INV-6 | Pause authority is the controller and body of the consumer's flip choice. A party that is not it is refused before any guard runs, and a `ContractId Pausable` alone grants no flip. | `api-pausable-v1` README, Authority and lifecycle |
| INV-7 | The view is exactly as visible as the implementing contract: observers read it, strangers read nothing, and a non-stakeholder flip controller receives the contract only through disclosure. | `api-pausable-v1` README; `pausable-v1` README, Authority |
| INV-8 | A consuming flip leaves one contract behind and archives the predecessor. A nonconsuming flip without `archive self` leaves two. | `pausable-v1` README, Usage step 2 |
| INV-9 | The switch is per contract. A pause on one contract leaves a sibling open, and a refused choice writes nothing. | `api-pausable-v1` README, Scope and security caveats |
| INV-10 | A flip sets other fields of the template in the same create as the flag, and the unpause clears them. | `pausable-v1` README, Usage step 2 |

## Test Plan

Tests marked "existing" were in the suite before this pass and are unchanged.
Tests marked "new" were added by this pass.

### `test/api-pausable-v1`

| Test Name | Invariant | Type | Status | What It Verifies |
|---|---|---|---|---|
| `test_viewReadableByObserver` | INV-7 | Privacy | existing | An observer reads `PausableView` off-ledger through the interface |
| `test_viewHiddenFromStranger` | INV-7 | Privacy | existing | A stranger's `queryInterfaceContractId` returns `None` |
| `test_viewTracksTheFlag` | INV-3 | Happy path | existing | The view reads `True` after the consumer's flip |
| `test_interfaceIdGrantsNoAuthority` | INV-6 | Authorization | new | `Archive` through `ContractId Pausable` is refused to a non-signatory observer, the view is unchanged, and the signatory archives |

### `test/pausable-v1`

| Test Name | Invariant | Type | Status | What It Verifies |
|---|---|---|---|---|
| `test_isPausedMatchesView` | INV-3 | Happy path | existing | `isPaused` on the queried payload equals the interface view |
| `test_whenNotPausedGuardsOperation` | INV-1 | Happy path, Failure | existing | Gated choice runs unpaused, fails with `eEnforcedPause` paused |
| `test_whenPausedGuardsRecovery` | INV-2 | Happy path, Failure | existing | Recovery choice fails with `eExpectedPause` unpaused, runs paused |
| `test_pauseUnpauseRoundTrip` | INV-1, INV-2, INV-3 | Happy path | existing | Pause then unpause; every other field survives |
| `test_flipArchivesThePredecessor` | INV-8 | Lifecycle | existing | The consuming flip leaves the old id inactive |
| `test_nonconsumingFlipLeavesTwoContracts` | INV-8 | Lifecycle, defect | existing | A nonconsuming flip without `archive self` leaves both contracts |
| `test_pauseWhenPausedFails` | INV-1 | Failure | existing | Second pause fails with `eEnforcedPause` |
| `test_unpauseWhenUnpausedFails` | INV-2 | Failure | existing | Second unpause fails with `eExpectedPause` |
| `test_onlyTheConsumersControllerMayPause` | INV-6 | Authorization | existing | Non-controller pause is an authorization failure |
| `test_pauseErrorsAreDistinct` | INV-4 | Failure | existing | The two statuses differ |
| `test_archiveIsSignatoryOnly` | INV-6 | Authorization | existing | Only the signatory archives the protected contract |
| `test_pauseSetsSiblingFields` | INV-10 | Happy path | existing | The flip sets `pauseReason` in the same create |
| `test_unpauseClearsSiblingFields` | INV-10 | Happy path | existing | The unpause clears `pauseReason` |
| `test_customAuthorityGatesTheFlip` | INV-6, INV-7 | Authorization, Privacy | existing | Credential checks in the body; wrong issuer and wrong account are refused; disclosure carries the contract to the guardian |
| `test_errorIdsAreStable` | INV-4 | Contract | new | The literal `errorId` strings and `InvalidGivenCurrentSystemStateOther` category of both statuses |
| `test_refusedChoiceWritesNothing` | INV-9 | Failure | new | After `eEnforcedPause` the contract is active with balance and flag unchanged |
| `test_guardRunsBeforeConsumerChecks` | INV-1 | Ordering | new | While paused, a request that is also invalid on its own terms fails with `eEnforcedPause`, not the consumer's status |
| `test_contractCreatedPausedIsPaused` | INV-1, INV-5 | Boundary | new | A contract created with `paused = True` refuses the gated choice from its first transaction and unpauses normally |
| `test_staleIdCannotBypassPause` | INV-5, INV-8 | Non-spoofability | new | A gated choice on the archived unpaused predecessor fails as `ContractNotFound` |
| `test_pauseIsPerContract` | INV-9 | Composability | new | A sibling stays open; a batch touching the paused and the open vault is refused whole and the sibling is untouched |
| `test_onlyTheConsumersControllerMayUnpauseOrRecover` | INV-6 | Authorization | new | Non-controller unpause and recovery are authorization failures; the flag stays set |
| `test_nonStakeholderFlipNeedsDisclosure` | INV-7 | Privacy | new | The right credential with no disclosure fails as `ContractNotFound`; with disclosure the flip lands |

## Coverage Matrix

| Invariant | Happy Path | Boundary | Failure | Additional |
|---|---|---|---|---|
| INV-1 | `test_whenNotPausedGuardsOperation` | `test_contractCreatedPausedIsPaused` | `test_pauseWhenPausedFails` | `test_guardRunsBeforeConsumerChecks` |
| INV-2 | `test_whenPausedGuardsRecovery` | `test_pauseUnpauseRoundTrip` | `test_unpauseWhenUnpausedFails` | - |
| INV-3 | `test_isPausedMatchesView` | `test_viewTracksTheFlag` | - | `test_pauseUnpauseRoundTrip` |
| INV-4 | `test_errorIdsAreStable` | - | `test_pauseErrorsAreDistinct` | - |
| INV-5 | `test_contractCreatedPausedIsPaused` | - | `test_staleIdCannotBypassPause` | - |
| INV-6 | `test_customAuthorityGatesTheFlip` | - | `test_onlyTheConsumersControllerMayPause`, `test_onlyTheConsumersControllerMayUnpauseOrRecover` | `test_interfaceIdGrantsNoAuthority`, `test_archiveIsSignatoryOnly` |
| INV-7 | `test_viewReadableByObserver` | - | `test_viewHiddenFromStranger`, `test_nonStakeholderFlipNeedsDisclosure` | `test_customAuthorityGatesTheFlip` |
| INV-8 | `test_flipArchivesThePredecessor` | `test_nonconsumingFlipLeavesTwoContracts` | `test_staleIdCannotBypassPause` | - |
| INV-9 | `test_pauseIsPerContract` | - | `test_refusedChoiceWritesNothing` | - |
| INV-10 | `test_pauseSetsSiblingFields`, `test_unpauseClearsSiblingFields` 
INV-3, INV-4, and INV-10 have no failure test of their own. `isPaused` is a
pure read of the view, so its only failure mode is a compile error. A wrong
`errorId` fails `test_errorIdsAreStable` directly. The sibling-field create
is the consumer's own code, with no library check to fail.

## Test Notes

- Both production packages define no templates, so `dpm test --all` reports
  zero external templates and choices for them. The fixtures under `Modules
  internal to this package` are the whole evidence, as `CONTRIBUTING.md`
  states.
- The coverage report lists the four fixture `Archive` choices as never
  exercised. The API test package covers the interface `Archive` path on its
  own fixture.
- Authorization failures match `Left (AuthorizationError _)` and status
  failures match the whole `FailureStatus` value through `submitMustFailWith`,
  so a test that fails for the wrong reason fails the test.
- A stranger exercising a contract it does not see fails as `ContractNotFound`
  with `NotVisible` debugging info, not as an authorization error. The two
  new tests that depend on this match `ContractNotFound _ _`.
- `Commands` is applicative only. The batch test sequences two exercises with
  `*>`.
- The skill's "omit the pause contract from context" non-spoofability test
  has no direct equivalent here: the flag lives on the contract being
  exercised and the guard takes `this`, so there is no separate contract to
  omit or substitute. `test_staleIdCannotBypassPause` is the closest
  property: the only other contract that ever held an unpaused flag is
  archived by the flip.
- No test uses `passTime` or `setTime`. The only time field in the component
  is `pauseUntil` in `examples/pausable/registry`, and it is reporting data
  that no choice reads.

## Out of Scope

- Ledger API and JSON Ledger API `InterfaceFilter` reads of `PausableView`:
  Daml Script's `queryInterfaceContractId` stands in; the filter shape needs
  an off-ledger client against a running participant.
- The `DAML_FAILURE` error envelope carrying `errorId` to a gRPC client: the
  script sees `FailureStatusError` directly. `test_errorIdsAreStable` pins the
  string the envelope carries.
- Smart Contract Upgrade of an implementing template that adds a field or a
  second interface instance: needs two package versions and `dpm
  upgrade-check`; the compatibility claims in the API README are structural
  and not exercised here.
- Multi-synchronizer reassignment of a paused contract: needs a Canton stack.
- Contract keys: the component defines none, so the non-unique-key and
  uniqueness-guard categories do not apply.
- Property tests over the guard: the guard is a two-state function of one
  `Bool`; enumeration in the existing tests covers both states.

## Dev Notes

- Test naming follows the existing suite's `test_camelCase` convention rather
  than the skill's `test_{what}_{condition}` pattern, because the repository
  convention wins.
- The `DA.Fail` import in `test/pausable-v1` widened from `FailureStatus` to
  `FailureCategory (..), FailureStatus (..)` for the `errorId` and `category`
  field reads in `test_errorIdsAreStable`. No other existing line changed.

## Open Questions

- `artifacts/06-docs.md` describes `setPaused`, `pause`, `unpause`,
  `eFlagNotApplied`, and `eImplementerTypeMismatch`, which commit `2fc2ddf`
  removed. The current READMEs and doc comments match the code, so only the
  docs artifact is stale. Decide whether to re-run `canton-docs` on the
  current code or mark the artifact superseded.
