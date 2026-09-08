---
stage: review
project: pausable
mode: greenfield
extends: null
status: draft
timestamp: 2026-09-08
author: nenad.misic@openzeppelin.com
previous_stage: artifacts/02-design.md
tags: [pausable, interface-only, frozen-api, lf-2.1, authority-agnostic, fail-open, scu]
---

# Pausable - Basic Review Report

Re-evaluated on 2026-09-08 against commit `957f65d`. Findings that the branch
has since resolved are removed; the remaining findings are restated against the
current tree.

## Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 4 |
| Informational | 5 |

**Overall assessment: ready, with pre-release decisions.** The production
module `OpenZeppelin.PausableV1` does what the design says. The authority
model holds: the package names no party, adds no signatory, observer, or
choice, fetches nothing, and every guard reads the contract being exercised.
The four runtime checks the design promises (`eEnforcedPause`,
`eExpectedPause`, `eFlagNotApplied`, `eImplementerTypeMismatch`) are present
and each has a passing negative test. Build, `scripts/check.sh`,
`scripts/check-examples.sh`, lint on all four packages, the 20 test scripts,
and both example demos pass on SDK 3.4.11 with `--target=2.1`.

No finding is a code defect in the production module. The Medium findings are
release-shape decisions that become permanent once the package is uploaded
(MED-1, MED-2, MED-3) and a value-creation bug in the consumer examples
(MED-4). The package is single-version for its whole life, helpers included, so
MED-1 and MED-3 must be decided before the first release, not after.

Reviewed inputs: `artifacts/01-research.md`, `artifacts/02-design.md`,
`packages/security/pausable-api-v1/`, `test/pausable-api-v1/`,
`examples/pausable/vault/`, `examples/pausable/registry/`, and the repository
documents the branch touches. No invariants, code, tests, or docs stage
artifact exists; the invariant list below is inferred from the design's
"ensure and Runtime Checks" table and its four stated limitations.

## Invariant Verification

Invariants inferred from `artifacts/02-design.md`. Locations are in
`packages/security/pausable-api-v1/daml/OpenZeppelin/PausableV1.daml` unless
stated.

| Invariant | Enforced? | Location | Notes |
|---|---|---|---|
| INV-1 `whenNotPaused x` fails iff the view reports `paused = True` | ✅ Yes | line 183-184 | `assertMsg eEnforcedPause (not (isPaused x))`; `isPaused` reads the interface view, so a `view` that disagrees with the field is caught by INV-5 on the next flip |
| INV-2 `whenPaused x` fails iff the view reports `paused = False` | ✅ Yes | line 188-189 | Mirror of INV-1 |
| INV-3 `pause`/`markPaused` fail with `eEnforcedPause` when already paused | ✅ Yes | line 237-238 | `whenNotPaused x` is the first statement, before the downcast |
| INV-4 `unpause`/`markUnpaused` fail with `eExpectedPause` when not paused | ✅ Yes | line 263-264 | Mirror of INV-3 |
| INV-5 `markPaused`/`markUnpaused` return a value whose flag is in the requested state or fail with `eFlagNotApplied` | ✅ Yes | line 241, 267 | Checked on the downcast value, so an implementer ignoring the argument is caught. A record update the caller applies afterwards is outside the check by design (design limitation 4) |
| INV-6 `setPaused` returns the implementing template or the flip fails with `eImplementerTypeMismatch` | ✅ Yes | line 239-240, 265-266 | `fromInterface` at the caller's `t`; a `Decoy` return yields `None` |
| INV-7 The package names no party and declares no signatory, observer, controller, or choice | ✅ Yes | interface `Pausable`, line 146-171 | `viewtype PausableView` with one `Bool`, one method, zero choices. `scripts/check.sh` additionally forbids templates in `-api-` packages |
| INV-8 Visibility of the flag equals visibility of the implementing contract (no extra disclosure, no fetch in the read path) | ✅ Yes | line 183-194 | Every guard is a pure function of the value; nothing is fetched. Positive test exists; the negative (stranger sees nothing) is untested, see INFO-2 |
| INV-9 No guard or flip accepts a `ContractId` (substitution defence) | ✅ Yes | all signatures | Every export takes `t` with `HasToInterface t Pausable`; `pause`/`unpause` additionally need `HasCreate t`, so they do not even type check on a bare `Pausable` |
| INV-10 A flip needs the implementing template's signatory authority; a party holding only a `ContractId Pausable` cannot change the flag | ✅ Yes | line 211, 249 (`>>= create`) | Ledger authorization. `test_pureMethodCannotFlipAnything` shows the pure method changes nothing. Wording in README overstates the mechanism, see INFO-1 |
| INV-11 The consumer's flip choice is consuming (exactly one active successor) | ⚠️ Partial | consumer code | Not enforceable by this API shape; documented on `pause`, in the README, and demonstrated by `test_nonconsumingFlipLeavesTwoContracts`. A fail-closed shape exists, see MED-1 |
| INV-12 `setPaused` preserves every field other than the flag | ⚠️ Partial | consumer code | Cannot be checked generically; documented in three places. `test_setPausedIsPure` checks it for the fixture `Vault` only |
| INV-13 Every gated choice calls a guard | ⚠️ Partial | consumer code | Unenforceable in Daml, documented. Examples gate deliberately per choice (`Vault_Redeem` is intentionally open) |
| INV-14 Guards evaluate no ledger time | ✅ Yes | line 183-194 | No `getTime`; `pauseUntil` in the registry example is reporting only, as documented |
| INV-15 Origination-only semantics: committed work unaffected, in-flight readers rejected by the flip | ✅ Yes | ledger model | A flip is a consuming exercise on the implementing contract. Documented in the module header and README |
| INV-16 A record update after `markPaused`/`markUnpaused` leaves the flag alone | ⚠️ Partial | consumer code | Introduced with `markPaused`. Documented as limitation 4 in the module header and in the README caveats; no test, because nothing in the library can observe it |

For INV-11 to INV-13 and INV-16 the design accepts documentation and tests as
the mechanism. INV-11 is the one where a stronger option exists, see MED-1.

## Findings

### Critical

None.

### High

None.

### Medium

#### MED-1: The consuming-choice obligation fails open, and a fail-closed API shape is available

**Location:** `PausableV1.daml` `pause` line 209-211, `markPaused` line 235-243, `unpause` line 247-249, `markUnpaused` line 261-269
**Invariant:** INV-11

**Issue:** `pause` creates the successor and archives nothing, and `markPaused`
returns a value for the consumer to create. If the consumer declares the flip
choice `nonconsuming`, the unpaused predecessor stays active beside the paused
successor and every gated choice on it keeps running. Nothing fails. The
library documents this in three places and the test suite demonstrates it, but
the failure direction is the one the research named as the top risk: a control
that looks like a control.

The design (decision 2, "ensure and Runtime Checks" item 2) states the library
cannot archive the predecessor "because an interface method sees `this` but not
`self`". That is true of an interface method. `pause` and `markPaused` are
top-level functions and can take `self`.

**Impact:** A consumer who writes `nonconsuming choice Vault_Pause` ships a
pause that does not pause and gets no signal from compiler, runtime, or tests
unless they wrote the specific two-contracts test themselves.

**Recommendation:** Add flip variants that take the contract id and archive it,
and steer the documentation toward them. With these, a `nonconsuming` caller
gets the archive, and a `consuming` caller fails loudly on the first test
because `self` is already inactive when `archive self` runs. Either mistake is
fail-closed.

```daml
pauseSelf
  : (HasToInterface t Pausable, HasFromInterface t Pausable, HasCreate t, HasArchive t)
  => ContractId t -> t -> Update (ContractId t)
pauseSelf self x = do
  y <- markPaused x
  archive self
  create y
```

Consumer side:

```daml
nonconsuming choice Vault_Pause : ContractId Vault
  controller admin
  do pauseSelf self this
```

The `markPaused` shape has no `self`-taking equivalent, because the consumer
owns the create; a consumer that needs sibling fields and a fail-closed archive
writes `archive self` beside `markPaused this` in its own choice body, and the
README should show that.

If the dev prefers to keep the current shape as the primary, at least ship the
`self`-taking variants alongside it. They cannot be added later in place, see
MED-2. This is a design decision, so the dev chooses; the review's position is
that a fail-closed default is worth the extra argument.

**Status:** Open

#### MED-2: The whole package is single-version, helpers included; the design and README understate this

**Location:** `packages/security/pausable-api-v1/daml.yaml` `version: 0.1.0`; `artifacts/02-design.md` "Package Shape" line 38 and 58-61; `packages/security/pausable-api-v1/README.md` "Compatibility" line 249-251
**Invariant:** n/a (upgrade safety)

**Issue:** The Canton SCU documentation states that an interface definition
present in v1 of a package "must be removed from all subsequent versions of
that package", and that any package using an interface from a dependency "can
never upgrade that dependency to a new version". Since this package defines
`Pausable`, no `openzeppelin-pausable-api-v1` at a version above the first
uploaded one can ever be uploaded. That covers the guards, the flips, and the
error constants too, because they ship in the same DAR and are executed from
that package id at runtime.

Two documents still say otherwise:

- The design says the helpers are "compile-time only" and that "being wrong
  about them costs a recompile". A bug in `markPaused` after release costs a
  new package name (`-api-v2`), a new DAR upload, a consumer import change, a
  consumer recompile, and a consumer SCU release that swaps the interface
  instance. The design also says "frozen at 1.0" while `daml.yaml` says
  `0.1.0`.
- The README's new Compatibility section says "a patch release of this
  package, if one ever ships, changes documentation or metadata only ... and
  it is a new package ID that consumers adopt by rebuilding." A participant
  treats a second version of the same package name as an upgrade of the first
  and rejects it because the interface is present. There is no patch release;
  the sentence should say so.

Design Open Question 4 (release version) is unresolved. `ARCHITECTURE.md` now
records the interface-only model and the freeze rule, which closes the part of
this finding that concerned that file.

**Impact:** Any decision deferred past the first upload becomes permanent, and
two of the documents that guide that decision say the opposite.

**Recommendation:**

- Correct the design claim and replace the README's patch-release sentence
  with: the package cannot be re-versioned after upload, so the exported
  functions are frozen with the interface.
- Resolve Open Question 4 before the first upload. Releasing as `1.0.0` states
  the truth: the surface is final on upload. Releasing `0.1.0` signals
  instability the ledger will not permit. Change the README `Status` row in
  the same commit.
- Decide MED-1 and MED-3 before that upload.

**Status:** Open

#### MED-3: Failures are `assertMsg` text; off-ledger clients cannot match a stable error id

**Location:** `PausableV1.daml` line 184, 189, 239-241, 265-267, 274-292
**Invariant:** INV-1 to INV-6

**Issue:** The research's core motivation is CIP-0112: wallets and clients that
learn a pause "other than via attempted but failed transfers". A wallet that
submits a gated choice against a paused registry today receives an
`UNHANDLED_EXCEPTION` whose only distinguishing content is the message text
`"Pausable: the contract is paused"`. The exported constants help Daml tests,
not Ledger API or JSON API consumers, who must substring-match.

SDK 3.4 ships `failWithStatus` in `DA.Fail`, which surfaces as `DAML_FAILURE`
with a caller-chosen `errorId`, category, and metadata. The standard library
documentation now marks exceptions as deprecated in favour of `failWithStatus`.
The design chose `assertMsg` to match `AccessControlV1` and `OwnableV1`, both
of which are `experiments/` packages scheduled for redesign.

Because of MED-2, this choice is permanent for the package lineage.

**Impact:** Every wallet and registry client integrating against this
interface does string matching on an error message forever.

**Recommendation:**

```daml
import DA.Fail

enforcedPause : FailureStatus
enforcedPause = FailureStatus with
  errorId = "OPENZEPPELIN_PAUSABLE_ENFORCED_PAUSE"
  category = InvalidGivenCurrentSystemStateOther
  message = "Pausable: the contract is paused"
  meta = mempty

whenNotPaused : (HasToInterface t Pausable) => t -> Update ()
whenNotPaused x = unless (not (isPaused x)) (failWithStatus enforcedPause)
```

Export the `FailureStatus` values (or the `errorId` texts) as the constants
consumers assert on; `tryFailureStatus` in Daml Script reads them back. If the
dev keeps `assertMsg` for convention, record the reasoning in the design and
README so the choice is visibly deliberate.

**Status:** Addressed. Every failure is a `FailureStatus` raised with
`failWithStatus`; the exported constants carry `openzeppelin.com/pausable-*`
error ids, and the tests compare the whole status via `FailureStatusError`.

#### MED-4: The vault examples accept non-positive withdrawal amounts and create value

**Location:** `examples/pausable/vault/daml/MyApp/Vault.daml` line 43-50; `test/pausable-api-v1/daml/OpenZeppelin/PausableV1TestSupport.daml` line 36-42
**Invariant:** n/a (economic security in consumer examples)

**Issue:** `Vault_Withdraw` checks `amount <= balance` only. A negative
`amount` passes and the successor's balance grows. Neither `Vault` has an
`ensure balance >= 0.0` clause. Since commit `42f26a4` the example also creates
a `Payout` for the whole balance on redemption and drain, so an inflated
balance becomes an inflated payout. The examples are the library's executable
documentation and the first thing an adopter copies.

**Impact:** An adopter who copies the example inherits a value-from-thin-air
bug that has nothing to do with pausing and reflects on the library.

**Recommendation:**

```daml
template Vault
  ...
  where
    signatory admin, owner
    ensure balance >= 0.0

    choice Vault_Withdraw : ContractId Vault
      with amount : Decimal
      controller owner
      do
        Pausable.whenNotPaused this
        assertMsg "Vault: amount must be positive" (amount > 0.0)
        assertMsg "Vault: amount exceeds balance" (amount <= balance)
        create this with balance = balance - amount
```

Apply the same two lines to the `Int` fixture in the test package, and give
`Payout` an `ensure amount > 0.0`.

**Status:** Open

### Informational

#### INFO-1: The README overstates why a stranger cannot flip the flag

**Location:** `packages/security/pausable-api-v1/README.md` line 174-177; `PausableV1.daml` line 131-135

**Issue:** The README says creating the successor "needs the implementing
template's signatory authority, which only a choice on that template carries,
so a choice on an unrelated contract cannot flip another template's flag."
The first clause is the real guarantee. The second is not: any choice that
carries the signatories' authority (for example a choice on another contract
signed by `admin`, with a flexible controller) can fetch a visible `Vault`
and call `pause` on it. The defence is authority, not template locality.

**Recommendation:** Reword to "Creating the successor needs the implementing
template's signatory authority. A party without that authority cannot flip the
flag, whatever contract its choice runs on." The security property is
unchanged; the explanation becomes accurate.

**Status:** Open

#### INFO-2: Test gaps

**Location:** `test/pausable-api-v1/daml/OpenZeppelin/PausableV1Test.daml`

- **Privacy negative (INV-8).** `test_viewReadableByObserver` shows the
  observer can read the view. No test shows a non-stakeholder's
  `queryInterfaceContractId` returns `None`. Add one with a fresh party.
- **`markUnpaused` failure routes (INV-5, INV-6).** `eFlagNotApplied` and
  `eImplementerTypeMismatch` are tested through the pause direction only. An
  unpause path on `BrokenIgnoresFlag` and `BrokenWrongTemplate` (create them
  paused) closes it.
- **Credential holder check.** `RoleVault_Pause` asserts both
  `cred.admin == admin` and `cred.account == caller`. The test exercises the
  wrong-issuer branch only. Add: `stranger` presents `guardian`'s credential
  (disclosed) and fails on the second assert.
- **Coverage gate is vacuous here.** The production DAR has zero templates and
  zero choices, so `scripts/check-coverage.sh` passes on 0/0 and proves
  nothing about this package. The test suite is the whole evidence; state
  this in `CONTRIBUTING.md` or the test package so nobody reads the badge as
  coverage of `PausableV1`.

**Status:** Open

#### INFO-3: The registry example's gated operation stores nothing

**Location:** `examples/pausable/registry/daml/MyApp/Registry.daml` line 55-62

**Issue:** `Registry_Register with entry` validates `entry` and then
`create this`, dropping it. The demo therefore shows a refused no-op.

**Recommendation:** Add `entries : [Text]` and `create this with entries =
entry :: entries`, so the refused registration is visibly a refused state
change and the unpaused one visibly lands.

**Status:** Open

#### INFO-4: `test/placeholder` has served its purpose

**Location:** `test/placeholder/daml.yaml` line 1-2

**Issue:** The manifest says "Delete this package when real tests arrive."
`test/pausable-api-v1` has arrived. The build also warns that the placeholder's
data-dependency on `openzeppelin-ownable-v1` is unused. Not touched by this
branch; noted for the dev.

**Status:** Open

#### INFO-5: The record update after `markPaused` can change stakeholder fields

**Location:** `PausableV1.daml` `markPaused` line 213-243; `packages/security/pausable-api-v1/README.md` "Usage" step 3 and "Scope and security caveats"

**Issue:** The value `markPaused` returns is an ordinary template value, and
the consumer's `create r with ...` is unconstrained. A record update that
changes a signatory field makes the create require the new signatory's
authority, which fails unless present; one that drops an observer succeeds and
silently narrows who sees the paused contract. Both are consumer errors. The
documentation now says to leave `paused` alone in that update (limitation 4)
and says nothing about the stakeholder fields.

**Recommendation:** Add one sentence to the `markPaused` comment and to README
Usage step 3: the record update must not change fields that determine
signatories or observers.

**Status:** Open

## Security Checklist Results

| Category | Result | Notes |
|---|---|---|
| 3.1 Authorization | Pass | No templates, no choices, no controller expressions in the production package. Flips spend the implementing template's signatory authority only (INV-10). Examples: controllers are the named principals; every example flip choice is consuming. `Payout` in the vault example is signed by `admin`, whose authority the choice carries as a `Vault` signatory. No propose-accept, no stuck-contract risk (the implementing template's own `Archive` remains available to signatories). |
| 3.2 Privacy and Disclosure | Pass | View is one `Bool`, so cross-implementer divulgence is bounded to the flag. No fetch in any guard, so no party enters the read path (the research's main privacy cost is not paid). Controller-as-informee cost at flip time is documented. Negative privacy test missing (INFO-2). |
| 3.3 Integrity / Runtime Checks | Pass with note | No templates, so no `ensure`. Six `assertMsg`/`fromSomeNote` checks, each with an exported constant and a negative test. No `agreement`, no user-defined exceptions. `assertMsg` versus `failWithStatus` is MED-3. `Decimal` appears only in examples; MED-4 covers boundary handling there. |
| 3.4 Contract Keys | n/a | LF 2.1, no keys anywhere in the changeset. The design records why keys would not help. |
| 3.4a Admin Layer (Pausable) | Pass | Flag lives on the contract that is `self` of every gated choice; no separate state contract exists to omit. Guard-at-every-chokepoint is the consumer's duty (INV-13) and the examples gate deliberately. Unpause is reachable in every example; permanent lock-out is possible only if the consumer's pause authority is lost, which is the consumer's authority model. Indefinite pause is out of scope by design. |
| 3.5 Composability and Contention | Pass | Guards are pure over `this`, so no cross-command assumptions. A flip is a consuming exercise and rejects concurrent readers; this is the committed origination-only semantics and is documented. No authority is assumed from calling context. Reassignment: adopting the interface changes no signatory set. `markPaused` removes the transient-contract cost a consumer would otherwise pay to set sibling fields. |
| 3.6 Economic Security | Pass for the package; MED-4 for examples | The package moves no value. The example vaults accept negative withdrawals. |
| 3.7 Upgrade Safety | Partial | LF 2.1 supports SCU. Interface package with no templates, as required. Package is single-version by construction; `ARCHITECTURE.md` now says so, the design and one README sentence do not (MED-2). No `daml.lock` is produced or committed by this workspace; test and example packages pin the DAR by path, so package ids are deterministic per build. Migration path for a breaking change (sibling `-api-v2`) is stated in the design, module header, and README. |

## Test Coverage Assessment

20 scripts pass. Every ✅ invariant above has at least one positive and, where
a failure exists, one negative test. The two routes to `eFlagNotApplied` and
the `eImplementerTypeMismatch` route are covered in the pause direction. The
unenforceable INV-11 is demonstrated executably (`LeakyVault`). The credential
pattern is covered end to end including disclosure.

The previous revision's `test_lambdaClobberingTheFlagFails` was removed with
`pauseWith`; the behaviour it covered no longer exists in the library, and its
replacement (INV-16) is unobservable from the library.

Gaps relative to findings:

- MED-1: if `self`-taking flips are added, test both the `nonconsuming`
  success path and the `consuming` fail-closed path.
- MED-3: if `failWithStatus` is adopted, switch the assertions from
  `isInfixOf` on `show e` to `tryFailureStatus` and `errorId` equality.
- MED-4: add a negative-amount `submitMustFail` to the vault demo or the
  fixture.
- INFO-2: privacy negative, `markUnpaused` failure routes, credential-holder
  branch.

The production coverage report is 0/0 for this package and cannot regress.

## Artifact Drift

- **Artifact:** `artifacts/01-research.md` Open Question 3 (line 717) →
  **Stale:** "the frozen surface is one boolean plus one party" →
  **Current:** `PausableView` has one `Bool` and no `Party` → **Suggested
  update:** "one boolean".
- **Artifact:** `artifacts/01-research.md` Dev Notes (line 680) → **Stale:**
  "`setPausedImpl` moved onto `Pausable`" → **Current:** the method is
  `setPaused` (design decision 15) → **Suggested update:** rename in the note.
- **Artifact:** `artifacts/02-design.md` Package Shape (line 38) → **Stale:**
  "one package, one DAR, frozen at 1.0" → **Current:** `daml.yaml`
  `version: 0.1.0`, README "Version 0.1.0" → **Suggested update:** resolve
  with Open Question 4 and MED-2.
- **Artifact:** `artifacts/02-design.md` Package Shape (line 58-61) →
  **Stale:** "Everything else is compile-time only ... Being wrong about them
  costs a recompile" → **Current:** the SCU rules make the helpers as frozen
  as the interface (MED-2) → **Suggested update:** state that the package is
  single-version in full.
- **Artifact:** `artifacts/02-design.md` Design Decision 2 (line 559) →
  **Stale:** "The archive route is documented in the README as a pattern a
  consumer can build unaided" → **Current:** the package README has no
  archive-and-restore section → **Suggested update:** either add the section
  to the README or drop the sentence.
- **Artifact:** `artifacts/02-design.md` Out of Scope, shared-switch item
  (line 705-706) → **Stale:** "The README carries the caveats -
  canonical-instance selection is the operator's responsibility, and the
  pauser becomes an informee of every read" → **Current:** the package README
  says only that pausing several templates means one flag on each or a single
  contract they all exercise; neither caveat appears → **Suggested update:**
  add a short "Sharing one switch across templates" caveat to the README.
- **Artifact:** `artifacts/02-design.md` Dev Notes (line 746-749) →
  **Stale:** "The Tests stage should move to `submitMustFail`" → **Current:**
  done in commit 3197f54 → **Suggested update:** mark resolved.
- **Artifact:** `artifacts/02-design.md` Integration Patterns (line 345) →
  **Stale:** examples import `OpenZeppelin.PausableV1` unqualified →
  **Current:** both examples use `import qualified OpenZeppelin.PausableV1 as
  Pausable` (commit de7f064) → **Suggested update:** cosmetic; align if the
  design is revised for other reasons.

## Extension Mode: Compatibility Check

Not applicable. Greenfield.

## Recommendation

- **Overall verdict:** Needs fixes, none in the production module's logic. Ready
  for publishing once the three permanent-shape decisions are made and the
  example vaults stop accepting negative amounts.
- **Blocking issues:** MED-2 (decide the release version and correct the two
  documents before first upload); MED-1 and MED-3 as decisions, because either
  choice is permanent after upload; MED-4 (an example must not create value).
- **Suggested improvements:** INFO-1 through INFO-5; the INFO-2 tests; the two
  README caveat sections the design says exist.

## Out of Scope

- `experiments/access/access-control-v1`, `experiments/access/ownable-v1`,
  `experiments/token/tokenCIP112-v1` and their test packages: not in this
  changeset.
- `scripts/check-sandbox.sh`, `scripts/check-lint.sh`,
  `scripts/check-coverage.sh`, and the CI workflows beyond the
  `check-examples.sh` step this branch adds: tooling, not component behaviour.
- `dars/manifest.yaml` and the release procedure in `RELEASING.md`: the design
  places release identity downstream of this stage; MED-2 states the one fact
  that must feed it.
- Formal or property-based verification of the guards: the module is small
  enough that the negative tests are the proof; `/canton-daml-props` remains
  available if the dev wants randomized implementer laws.

## Resolved since the first revision

Kept for traceability; none of these is a finding any more.

- **MED-5 (repository documentation):** the root README and
  `packages/README.md` list the package (commit 4c3c700), `CHANGELOG.md` has
  the `Added` entry (ea461b2), and `ARCHITECTURE.md` records the
  interface-only model (8f95470).
- **INFO-6 (status label):** the README row now reads "Pre-release;
  unaudited" (2da8090). The remaining question, which version the first upload
  carries, is part of MED-2.
- **Vault example semantics:** `Vault_RedeemToAdmin` zeroed the balance and
  moved nothing; `Vault_Redeem` and `Vault_EmergencyDrain` now create a
  `Payout` (42f26a4). MED-4 still applies to the amount check.
- **`pauseWith` lambda findings:** `pauseWith` and `unpauseWith` were replaced
  by `markPaused` and `markUnpaused` (12dd70b). The lambda-specific parts of
  INV-5, INFO-2, and INFO-5 are restated above against the new shape.
- **API documentation rendering:** a `-- |` comment on the interface method
  made `damlc docs` reject the module; the method now carries a trailing
  `-- ^` comment (3e926e7) and `CONTRIBUTING.md` documents the command.

## Dev Notes

- **Stage-start drift check ran without confirmation.** The session was
  non-interactive, so the commitments below were taken as current. If any has
  shifted, say so and the affected findings will be re-evaluated.
  1. Authority-in-path only; no free-floating switch template.
  2. One frozen interface, one `Bool` in the view, no `Party`, no choices.
  3. `setPaused : Bool -> Pausable` as the single implementer method; flips as
     top-level functions, `pause`/`unpause` returning `ContractId t` and
     `markPaused`/`markUnpaused` returning `t`.
  4. `assertMsg` with exported text constants.
  5. LF 2.1, no keys, no dependency beyond `daml-prim` and `daml-stdlib`.
  6. Consumer writes every flip choice; it must be consuming.
- **No 03-invariants, 04-code, 05-tests, or 06-docs artifact exists.** The
  INV-1 to INV-16 list here is the review's inference and can seed
  `artifacts/03-invariants.md` if the dev backfills the core stages.
- **Verification performed on 2026-09-08 at `957f65d`:** `dpm build --all`
  (clean, one unrelated unused-dependency warning in `test/placeholder`),
  `scripts/check.sh` OK, `scripts/check-examples.sh` OK, `dpm damlc lint` "No
  hints" on the four Pausable packages, the 20 test scripts pass with
  `--all --show-coverage`, both example demos pass, `dpm damlc docs` renders
  the module.
- **Docs consulted:** Canton SCU deep-dive "Upgrading Interfaces" and the
  upgrading reference "Interface and Exception Definitions" (MED-2); the
  `DA.Fail` standard-library page and the `DAML_FAILURE` error code (MED-3).

## Open Questions

1. **MED-1:** Adopt `self`-taking flips as the primary, add them as variants, or
   keep the current shape and accept the fail-open obligation? Must be decided
   before first upload.
2. **MED-3:** `failWithStatus` with stable error ids, or `assertMsg` for
   convention with the experimental packages? Must be decided before first
   upload.
3. **Design Open Question 4:** release version. The review recommends `1.0.0`
   at first upload with the `Status` row changed in the same change.
4. Should the core pipeline artifacts 03 to 06 be backfilled so the next
   revision of this review runs in revision mode against an invariants list the
   dev owns?
