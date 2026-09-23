---
stage: review
project: pausable
mode: extension
extends: packages/security/api-pausable-v1, packages/security/pausable-v1
status: draft
timestamp: 2026-09-23
author: nenad.misic
previous_stage: artifacts/06-docs.md
revision: 2
revised_from: post-core/basic-review.md at commit dbb12a6 (deleted in 7650e90)
revision_trigger: code
tags: [pausable, interface, security, review, utility-package, scu]
---

# Pausable - Basic Review Report

Reviewed at commit `2fc2ddf` on branch `pausable-proposal`. The previous
report (2026-09-08, commit `957f65d`) reviewed a single package with
`setPaused`, `pause`, `unpause`, `markPaused`, and `markUnpaused`. Since then
the component was split into `openzeppelin-api-pausable-v1` and
`openzeppelin-pausable-v1`, every flip helper and the interface method were
removed, and all failures moved to `failWithStatus`. Every previous finding
is re-evaluated under "Previous Findings" below.

## Revision Log

- **2026-09-23, MED-1 and MED-2 applied** in the working tree on `f73c79d`.
  MED-1: one sentence on the `whenNotPaused` doc comment, one caveat bullet
  in the `pausable-v1` README, the `SwitchedVault` fixture, and
  `test_guardOnSuppliedSwitchIsBypassed`. MED-2: a retrofit paragraph in the
  API README, the `UpgradedVault` fixture, `test_optionalFlagReadsNoneAsUnpaused`,
  and a v1/v2 package pair built under `upgrades:` in the session scratchpad.
  The pair fails by default with `template-has-new-interface-instance` and
  builds with `-Wtemplate-has-new-interface-instance`; the README names the
  flag.
- **Three commits landed after the review was written:** `806224a`,
  `328db18`, `f73c79d`. `artifacts/05-tests.md` now exists with its own
  INV-1 to INV-10 numbering, `test/pausable-v1` grew from 14 to 22 scripts
  before this revision's two, and both package READMEs lost the caveats this
  report cited for INV-9, INV-10, INV-12, and the privacy row. Those rows
  and findings are restated against `f73c79d`; other line numbers refer to
  `2fc2ddf`.

## Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Informational | 7 |

**Overall assessment: ready.** The production surface is one interface with
a one-field view, three guard functions, two failure statuses, and one
internal constructor. No production code path has a defect. The authority
model holds: the packages name no party, declare no template, choice, or
method, fetch nothing, and every guard reads the contract being exercised.
The package split matches the Canton SCU guidance for interfaces, and the
function package meets the documented definition of a utility package, which
makes its upgrade path simpler than the READMEs claim.

Both Medium findings are consumer-facing documentation gaps on the two risks
the research ranked highest: a guard over a caller-supplied switch (MED-1)
and the path for adopting the interface on a template that already has live
contracts (MED-2). Both are applied in this revision, see the Revision Log.

Verified on 2026-09-23 with SDK 3.4.11, `--target=2.1`:

| Check | Result |
|---|---|
| `dpm build --all` | 14 packages build |
| `scripts/check.sh` | OK |
| `dpm damlc lint` on the 8 Pausable packages | No hints |
| `test/api-pausable-v1` | 3 scripts pass |
| `test/pausable-v1` | 24 scripts pass (22 at `f73c79d` plus 2 from MED-1 and MED-2) |
| `examples/pausable/vault-test` | 11 scripts pass |
| `examples/pausable/registry-test` | 7 scripts pass |
| `dpm damlc docs` on `openzeppelin-pausable-v1` | Renders both modules with the MED-1 sentence |
| Scratchpad v1/v2 pair under `upgrades:` (MED-2) | Rejected by default; builds with `-Wtemplate-has-new-interface-instance` |

Reviewed inputs: `artifacts/06-docs.md`; `artifacts/01-research.md` and
`artifacts/02-design.md` as recovered from commit `1e0f754^`; the previous
review as recovered from commit `dbb12a6`; both production packages, both
test packages, both examples with their test packages; `README.md`,
`ARCHITECTURE.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `RELEASING.md`,
`AGENTS.md`, `multi-package.yaml`, `scripts/check.sh`,
`scripts/check-coverage.sh`, and the CI workflows. No invariants, code, or
tests stage artifact exists; the invariant list below is inferred from the
current source, the READMEs, and the recovered design.

## Invariant Verification

Locations are in `packages/security/pausable-v1/daml/OpenZeppelin/PausableV1.daml`
unless stated. `README` means `packages/security/pausable-v1/README.md`.

| Invariant | Enforced? | Location | Notes |
|---|---|---|---|
| INV-1 `whenNotPaused x` fails with `eEnforcedPause` iff the view reports `paused = True` | ✅ Yes | line 46 | `when (isPaused x) (failWithStatus eEnforcedPause)`; `test_whenNotPausedGuardsOperation`, `test_pauseWhenPausedFails` |
| INV-2 `whenPaused x` fails with `eExpectedPause` iff the view reports `paused = False` | ✅ Yes | line 60 | Mirror of INV-1; `test_whenPausedGuardsRecovery`, `test_unpauseWhenUnpausedFails` |
| INV-3 `isPaused` is pure and equals the view's `paused` | ✅ Yes | line 64 | `(view (toInterface @Pausable x)).paused`; no `Update`; `test_isPausedMatchesView` |
| INV-4 Each failure status has a stable, unique, DNS-prefixed `errorId` and a retry-after-state-change category | ✅ Yes | line 71-79; `Internal.daml` line 9-14 | `openzeppelin.com/pausable-enforced-pause` and `-expected-pause`, both `InvalidGivenCurrentSystemStateOther`; matches the `FailureStatus` convention in the Daml standard library reference; `test_pauseErrorsAreDistinct` |
| INV-5 The API package defines no template, choice, method, or party; the view is one `Bool` | ✅ Yes | `Api/PausableV1.daml` line 21-34 | `viewtype PausableView` and nothing else; `scripts/check.sh` rejects templates in `openzeppelin-api-*` packages; the coverage report lists 0 interface choices |
| INV-6 Visibility of the flag equals visibility of the implementing contract; no guard fetches | ✅ Yes | line 45-64 | All three functions are pure over the value; `test_viewReadableByObserver`, `test_viewHiddenFromStranger` |
| INV-7 No guard accepts a `ContractId`; each takes the value the choice runs on | ✅ Yes | signatures line 45, 59, 63 | `HasToInterface t Pausable => t`. `t = Pausable` is admissible, so a consumer can still `fetch` a caller-supplied `ContractId Pausable` and pass the result; the type system cannot exclude it. MED-1 (fixed) documents it and `test_guardOnSuppliedSwitchIsBypassed` demonstrates it |
| INV-8 A flip needs the implementing template's signatory authority; the interface offers no path | ✅ Yes | ledger model | No interface choice exists to exercise; `test_onlyTheConsumersControllerMayPause`, `test_customAuthorityGatesTheFlip` |
| INV-9 A flip leaves exactly one active contract | ⚠️ Partial | consumer code | Consuming choice or `archive self`. The README sentence stating it was removed in `f73c79d`; Usage step 2 shows consuming flips by example, and `test_nonconsumingFlipLeavesTwoContracts` shows the failure mode. Fail-open by design since `2fc2ddf`, see INFO-1 |
| INV-10 A pause flip creates the successor with `paused = True`, an unpause with `paused = False`, and the view reports the field | ⚠️ Partial | consumer code | The consumer's own `create` and `view`; nothing in the library checks either. The README caveat and its round-trip advice were removed in `f73c79d`; `test_pauseUnpauseRoundTrip` covers the fixtures. See INFO-1 |
| INV-11 Every gated choice calls a guard | ⚠️ Partial | consumer code; README line 135-137 | Unenforceable in Daml; documented. Examples gate deliberately per choice (`Vault_Redeem` is open by design) |
| INV-12 A flip keeps the fields that determine signatories and observers | ⚠️ Partial | consumer code | The README caveat and the Usage sentence were removed in `f73c79d`, so it is neither documented nor tested, see INFO-5 |
| INV-13 Guards evaluate no ledger time | ✅ Yes | line 45-64 | No `getTime`; `pauseUntil` in the registry example is reporting only and its README says so |
| INV-14 Origination-only semantics: committed work stands, a flip rejects in-flight readers | ✅ Yes | ledger model; README line 133-134 | A consuming exercise on the implementing contract |
| INV-15 The interface package is frozen, the function package is versionable, and the consumer's template keeps SCU with its instance retained | ✅ Yes | `daml.yaml` of both packages; `ARCHITECTURE.md` "Components without templates" | Matches the Canton SCU reference: interface definitions are non-upgradeable, instances may be added and never removed, instance bodies may change. See INFO-6 for the utility-package refinement |
| INV-16 A template that adopts the interface under SCU holds `paused : Optional Bool` and its view reads `None` as unpaused | ✅ Yes | `UpgradedVault` fixture; API README Usage | Added with MED-2. `test_optionalFlagReadsNoneAsUnpaused`; the v1/v2 pair builds under `upgrades:` with `-Wtemplate-has-new-interface-instance` |

For INV-9 to INV-12 the design accepts documentation and the consumer's tests
as the mechanism. The dev removed the fail-closed alternative for INV-9 in
`2fc2ddf`; this review records the residual, it does not reopen the decision.

## Findings

### Critical

None.

### High

None.

### Medium

#### MED-1: Consumer docs do not forbid guarding on a fetched, caller-supplied `Pausable`

**Location:** `packages/security/pausable-v1/README.md` Usage step 1 (line 32-34) and Scope and security caveats (line 131-144); `PausableV1.daml` doc comment on `whenNotPaused` (line 28-29)
**Invariant:** INV-7

**Issue:** `whenNotPaused : HasToInterface t Pausable => t -> Update ()`
accepts `t = Pausable`. A consumer can therefore write

```daml
choice Token_Transfer : ContractId Token
  with switchCid : ContractId Pausable
  controller owner
  do
    switch <- fetch switchCid
    Pausable.whenNotPaused switch
    ...
```

and the caller picks which contract answers the guard. `ARCHITECTURE.md`
explains why a guard over a caller-supplied switch is unsound, and the
research named substitution as a top risk, but no consumer-facing document
says it. The README says the guard "takes the contract value the choice runs
on, so the caller supplies nothing", which describes the intended call and
does not rule out the other one.

**Impact:** A pause that a caller bypasses by presenting an unpaused decoy,
with no error and no signal in the consumer's own tests unless they wrote the
decoy test.

**Recommendation:** One caveat bullet in the README and one sentence on
`whenNotPaused`:

```daml
-- | Fail with `eEnforcedPause` unless the contract is unpaused. Pass `this`:
-- a `Pausable` value fetched from a contract id the caller supplies is the
-- caller's choice of switch, and the guard cannot tell the difference.
```

Optionally, a fixture in `test/pausable-v1` whose gated choice takes a
`switchCid` and a script in which the caller presents a second, unpaused
contract; the passing exercise is the executable statement of the caveat.

**Applied:** the sentence on `whenNotPaused` (line 28-31), the caveat
bullet in the README, the `SwitchedVault` fixture, and
`test_guardOnSuppliedSwitchIsBypassed`, which shows the same paused contract
refusing the caller who presents it and serving the caller who presents an
unpaused decoy.

**Status:** Fixed

#### MED-2: The SCU retrofit path for a template with live contracts is undocumented

**Location:** `packages/security/api-pausable-v1/README.md` Usage (line 24-41) and Compatibility (line 100-113)
**Invariant:** INV-15

**Issue:** The README's usage adds `paused : Bool` to the template, and its
Compatibility section says the consumer's template stays upgradeable through
SCU. Both are true for a new template. A template that already has active
contracts cannot add a `Bool` field under SCU: a new field must be
`Optional`. The Canton upgrading reference allows adding an interface
instance and a new dependency in a later version, so the retrofit is
possible, but the shape is

```daml
template Registry
  with
    admin : Party
    paused : Optional Bool   -- added in v2; None on v1 contracts
  where
    signatory admin

    interface instance Pausable for Registry where
      view = PausableView with paused = fromOptional False paused

    choice Registry_Pause : ContractId Registry
      controller admin
      do
        Pausable.whenNotPaused this
        create this with paused = Some True
```

and nothing in the repository shows or tests it. The research identified
existing registries as the main adopters, and that is exactly the population
with live contracts.

**Impact:** An adopter either abandons SCU for a fresh deploy and an offline
migration, or discovers the `Optional` shape alone. A reader who follows the
README's `paused : Bool` under an `upgrades:` check gets a compile error and
no pointer.

**Recommendation:** Add a "Retrofit under SCU" paragraph to the API README
with the snippet above, and verify it with a v1/v2 package pair built under
`upgrades:` before publishing the text. The guards need no change because
they read the view.

**Applied:** the paragraph and snippet in the API README Usage section,
mirrored by the `UpgradedVault` fixture and
`test_optionalFlagReadsNoneAsUnpaused`. The v1/v2 pair in the session
scratchpad (`retrofit-vault` 1.0.0 without the interface, 2.0.0 with
`paused : Optional Bool`, the instance, and the guards, built with
`upgrades:` pointing at 1.0.0) is rejected by the Daml-LF typechecker:
"Implementation of interface Pausable by template UpgradedVault is defined
in this package, but not in the package that is being upgraded", gated by
`template-has-new-interface-instance`. With
`-Wtemplate-has-new-interface-instance` in `build-options` the pair builds
and the check reports the instance as a warning. The README states the flag
and that an interface read of an older contract resolves through the
package preference. The pair is not in the repository; see Open Questions.

**Status:** Fixed

### Informational

#### INFO-1: The consuming-flip and flag obligations are fail-open after the flip helpers were removed

**Location:** `packages/security/pausable-v1/README.md` Usage step 2; `test/pausable-v1/daml/OpenZeppelin/PausableV1TestFixtures.daml` line 150-167
**Invariant:** INV-9, INV-10

**Issue:** Commit `5675734` made `pause` and `unpause` archive `self`, so a
`consuming` caller failed closed; commit `2fc2ddf` removed the flips
entirely, and the consumer now writes the archive and the create. A
`nonconsuming` flip without `archive self` leaves two active contracts, and
a flip that creates with the wrong flag is a pause that does not pause.
The first is demonstrated by `LeakyVault`. The previous report's MED-1
asked for a fail-closed shape; the dev chose the smaller surface. Commit
`f73c79d` then removed the README sentences that stated both obligations
(the `archive self` sentence in Usage step 2 and the "pause that does not
pause" caveat), so the tests are now the only statement of them.

**Recommendation:** One sentence in Usage step 2 that the flip choice is
consuming or calls `archive self`, and one that the consumer's round-trip
test checks both properties: after a pause, the predecessor id returns
`None` from `queryContractId` and the successor's view reads
`paused = True`; after an unpause, the mirror. `test_flipArchivesThePredecessor`
and `test_pauseUnpauseRoundTrip` are the shape to point at.

**Status:** Acknowledged for the design (`2fc2ddf`); Open for the
documentation removed in `f73c79d`

#### INFO-2: The module header example names fixture symbols as if the package exported them

**Location:** `PausableV1.daml` line 8-20

**Issue:** The `RoleVault_Pause` example uses `PauseCredential`,
`eWrongCredentialIssuer`, and `eCredentialNotCallers`, which are defined in
`test/pausable-v1`. The rendered API reference shows them without saying
whose they are.

**Recommendation:** One clause before the block: "the credential template
and its two statuses are the consumer's own".

**Status:** Open

#### INFO-3: The vault example's recovery path pays the admin from the admin

**Location:** `examples/pausable/vault/daml/OpenZeppelin/Examples/Pausable/Vault.daml` line 63-71

**Issue:** `Vault_EmergencyDrain` creates `Payout with payer = admin,
recipient = admin`, an IOU from a party to itself, and zeroes the owner's
balance. As executable documentation it models "pause, then the admin takes
the balance", the centralization hazard the research flagged, and the
payout carries no economic content.

**Recommendation:** Pay a named `recovery : Party` or the `owner`, or zero
the balance with a comment that the recovery destination is the consumer's
decision. The `whenPaused` demonstration is unchanged either way.

**Status:** Open

#### INFO-4: The first-upload rule for the frozen interface package is recorded nowhere in the tree

**Location:** `RELEASING.md`; `packages/security/api-pausable-v1/README.md` line 115-116; `packages/security/pausable-v1/README.md` line 160-161

**Issue:** Both READMEs defer the release and package-ID policy to
`RELEASING.md`, which is a placeholder. The rule that the first uploaded
version of `openzeppelin-api-pausable-v1` is permanent, and that `0.1.0`
is never uploaded to a shared ledger, was recorded in the design artifact's
Open Question 4 and that artifact was deleted in `1e0f754`.

**Recommendation:** One paragraph in `RELEASING.md`, or under "Components
without templates" in `ARCHITECTURE.md`: a package that defines an
interface accepts no second version, so the first tagged release fixes the
surface and the version it ships under.

**Status:** Open

#### INFO-5: Test gaps, non-blocking

**Location:** `test/pausable-v1/daml/OpenZeppelin/PausableV1Test.daml`

- **INV-12.** A flip that drops an observer silently narrows visibility.
  The README caveat saying so was removed in `f73c79d`, and there is no
  executable statement. A
  `Registry_Pause` fixture that sets `observer = []` and a script showing
  the auditor's `queryInterfaceContractId` returning `None` afterwards
  would state it.
- **Archive is ungated.** `test_archiveIsSignatoryOnly` shows the
  signatory archives a paused contract. No README sentence says that a
  pause does not stop the implementing template's own `Archive`; add one
  to the caveats beside "A choice is gated only by its own guard call".
- **MED-1 decoy.** See MED-1.

**Status:** Open

#### INFO-6: The function package is a utility package, which changes two compatibility sentences

**Location:** `ARCHITECTURE.md` "Dependency policy" line 79-81; `packages/security/pausable-v1/README.md` Compatibility (line 151-158)

**Issue:** The Canton upgrading reference defines a utility package as one
with no template, interface, or exception definition and no serializable
data type. `openzeppelin-pausable-v1` defines functions and `FailureStatus`
values only, so it qualifies. The reference then says a new version of a
package "must have all the (non-utility-package) dependencies of the old
version". A consumer may therefore move to a fixed `openzeppelin-pausable-v1`
or drop it in its next SCU version, which is stronger than the README's
"your package picks it up by rebuilding" and contradicts the
`ARCHITECTURE.md` sentence that an SCU lineage "cannot later drop or
downgrade that dependency" for this class of package. The API package is
not a utility package and stays pinned as documented. The vetting sentence
in the README stands: the `UpdateVettedPackages` force flag
`ALLOW_UNVETTED_DEPENDENCIES` exists because dependencies are vetted by
default.

**Recommendation:** Qualify the `ARCHITECTURE.md` sentence with "other
than a utility package", and add one sentence to the README: a consumer's
next SCU version may depend on a newer version of this package because it
defines no types.

**Status:** Open

#### INFO-7: `Internal` is imported unqualified

**Location:** `PausableV1.daml` line 26

**Issue:** `import OpenZeppelin.PausableV1.Internal as Internal` brings
`pausableFailure` into scope unqualified as well. Nothing re-exports it, so
the public surface is unchanged.

**Recommendation:** `import qualified OpenZeppelin.PausableV1.Internal as Internal`.

**Status:** Open

## Previous Findings

Status of every finding in the 2026-09-08 report against the current tree.

| Finding | Status | Evidence |
|---|---|---|
| MED-1 consuming-choice obligation fails open; `self`-taking flips proposed | Superseded | `5675734` added the archive, `2fc2ddf` removed every flip helper; the residual is INFO-1 |
| MED-2 the whole package is single-version, helpers included | Resolved | `d8bec22` split the function package out; `ARCHITECTURE.md` and both READMEs state the freeze correctly; see INFO-6 for the utility-package refinement |
| MED-3 `assertMsg` text instead of stable error ids | Resolved | `dbb12a6`; `failWithStatus` with `openzeppelin.com/pausable-*` ids, tests compare the whole status |
| MED-4 vault examples accept non-positive amounts | Resolved | `c5b7a18`; `Vault_Withdraw` checks `amount > 0` and `amount <= balance`, `Vault` and `Payout` carry `ensure` |
| INFO-1 README overstates why a stranger cannot flip | Resolved | The README Authority section now says the interface exposes no choice, so a `ContractId Pausable` alone grants no flip |
| INFO-2 privacy negative, unpause failure routes, credential-holder branch, vacuous coverage | Resolved / Superseded | `test_viewHiddenFromStranger`; unpause routes gone with the helpers; `eCredentialNotCallers` branch tested; `CONTRIBUTING.md` documents the 0/0 report |
| INFO-3 registry example stores nothing | Resolved | `668430e`; `entries` field |
| INFO-4 `test/placeholder` | Resolved | `230ceee` |
| INFO-5 record update after `markPaused` can change stakeholder fields | Resolved, then the caveat was removed again in `f73c79d` | The helper itself is gone; the stakeholder-field caveat is INV-12 and INFO-5 of this report |

## Security Checklist Results

| Category | Result | Notes |
|---|---|---|
| 3.1 Authorization | Pass | No templates, choices, or controller expressions in either production package. Fixtures and examples: controllers are the named principals, flips are consuming, `Payout` is signed by `admin` whose authority every `Vault` choice carries. Non-stakeholder flip authority works through the choice body (`RoleVault_Pause`) and is tested with disclosure. No propose-accept, no stuck-contract path; the implementing template's `Archive` stays with its signatories. |
| 3.2 Privacy and disclosure | Pass | The view is one `Bool`, so cross-implementer divulgence is bounded to the flag. No guard fetches, so no party joins the read path. A non-stakeholder flip controller sees the payload at flip time; the README bullet saying so was removed in `f73c79d`, and `test_nonStakeholderFlipNeedsDisclosure` demonstrates the disclosure requirement. Disclosures held for the predecessor go stale on a flip; documented. Negative privacy test present. |
| 3.3 Integrity and runtime checks | Pass | No templates, so no `ensure`. Both checks raise `failWithStatus` with DNS-prefixed ids in the documented convention and the category a retrying client expects. No `assertMsg`, `error`, or `abort` on any consumer-reachable path in production code. No `agreement`, no user-defined exceptions. `Decimal` appears only in the vault example, guarded by `ensure balance >= 0.0` and two amount checks. |
| 3.4 Contract keys | n/a | LF 2.1; no key anywhere in the changeset. |
| 3.4a Admin layer (Pausable) | Pass with MED-1 | The flag is a field of the contract that is `self` of every gated choice, so no separate state contract exists to omit; the type signature still admits a fetched interface value, which MED-1 (fixed) documents and tests. Guard-at-every-chokepoint is the consumer's duty (INV-11); both examples gate deliberately and leave one escape hatch open on purpose. Unpause is reachable in every fixture and example. Ownership transfer and role capabilities are out of scope by design; composition is by reference in the consumer's choice body. |
| 3.5 Composability and contention | Pass | Guards are pure over `this`, so no assumption about the surrounding submission. A flip is a consuming exercise on the implementing contract and rejects concurrent readers; that is the committed origination-only semantics. No authority is assumed from the calling context. Adopting the interface changes no signatory set, so reassignment is unaffected. |
| 3.6 Economic security | Pass for the packages; INFO-3 for the example | The packages move no value. The vault example conserves value on withdraw and redeem; the drain pays the admin from itself, which is a modelling choice rather than a leak. |
| 3.7 Upgrade safety | Pass with INFO-6 | LF 2.1 supports SCU. The interface lives alone in `openzeppelin-api-pausable-v1`, as the SCU deep-dive requires. The function package is a utility package and is exempt from the dependency-retention rule; the READMEs understate this. No `daml.lock` exists because every dependency is a path-pinned DAR; package ids are deterministic per build. The breaking-change path (sibling `-v2` API package, both instances for life, offline migration to drop `-v1`) is stated in the API README and matches the reference. The retrofit path for live contracts is documented (MED-2, fixed); the compiler gates the added instance behind `-Wtemplate-has-new-interface-instance`. |

## Test Coverage Assessment

45 scripts pass across the four test packages: 3, 24, 11, and 7. Every ✅ invariant has a
positive test and, where a failure exists, a negative test that compares the
whole `FailureStatus`. Authorization failures use `AuthorizationError`
matching, which distinguishes them from body failures. The credential
pattern is covered end to end, including the wrong-issuer and
not-the-caller's branches and the disclosure the guardian needs.

The DPM coverage report is 0/0 for both production packages, as
`CONTRIBUTING.md` documents; the fixtures under "Modules internal to this
package" are the whole evidence. Every fixture template is created; the
only unexercised choices are the implicit `Archive` choices of fixtures and
of the example templates.

Gaps relative to findings:

- MED-1: done, `test_guardOnSuppliedSwitchIsBypassed`.
- MED-2: `test_optionalFlagReadsNoneAsUnpaused` covers the view; the SCU
  validity of the shape is proven only by the scratchpad pair, which is not
  in the repository.
- INFO-5: the observer-narrowing flip.

## Artifact Drift

All items are in `artifacts/06-docs.md`, written on 2026-09-22 before
commit `2fc2ddf` removed `setPaused` and the flip helpers.

- **Artifact:** `artifacts/06-docs.md` "Current behavior", first bullet →
  **Stale:** "`Pausable` has the view ... and the method `setPaused : Bool
  -> Pausable`. The only choice is the implicit `Archive`." → **Current:**
  the interface declares the view type and nothing else; the coverage
  report lists no interface choice → **Suggested update:** "`Pausable`
  has the view `PausableView { paused : Bool }` and no method or choice."
- **Artifact:** same section, third bullet → **Stale:** "`pause` runs
  `whenNotPaused`, calls `setPaused True`, fails with
  `eImplementerTypeMismatch` ... and with `eFlagNotApplied` ... `unpause`
  mirrors it." → **Current:** no `pause` or `unpause`; the consumer's
  choice guards and creates → **Suggested update:** drop the bullet.
- **Artifact:** same section, fourth bullet → **Stale:** "The four
  `errorId` values" → **Current:** two, `openzeppelin.com/pausable-enforced-pause`
  and `-expected-pause` → **Suggested update:** "two".
- **Artifact:** same section, sixth bullet → **Stale:**
  "`test_flipOnInterfaceValueChangesNothing`" → **Current:** the script
  was removed with the flips → **Suggested update:** drop the bullet.
- **Artifact:** "Current behavior (verified)" table → **Stale:**
  "`test/api-pausable-v1` 4 scripts", "`test/pausable-v1` 19 scripts" →
  **Current:** 3 and 14 → **Suggested update:** the new counts.
- **Artifact:** "Findings and corrections", API README table, rows on
  `setPaused` and "Split rationale" → **Stale:** corrections to text that
  no longer exists → **Current:** the README has no `setPaused` content →
  **Suggested update:** mark the rows as superseded.
- **Artifact:** "Findings and corrections", doc comments table, rows
  `setPaused` and `pause` → **Stale:** both symbols → **Current:** removed
  → **Suggested update:** mark superseded.
- **Artifact:** "Passed without change" → **Stale:** "`unpause`" in the
  list → **Current:** removed → **Suggested update:** drop it.
- **Artifact:** Dev Notes, second bullet → **Stale:** "writes
  `Pausable.pause` where the fixture writes `pause` unqualified" →
  **Current:** README line 119 writes `Pausable.whenNotPaused this` where
  the fixture line 114 writes `whenNotPaused this`; the qualification
  mismatch persists under the new name → **Suggested update:** rename in
  the note, or align the README block with the fixture.

Items in `artifacts/05-tests.md`, added in `328db18`:

- **Artifact:** `artifacts/05-tests.md` Test Plan, `test/api-pausable-v1`
  table → **Stale:** `test_interfaceIdGrantsNoAuthority`, marked "new" →
  **Current:** the package has three scripts and no such test; the coverage
  report lists no interface choice → **Suggested update:** drop the row and
  the INV-6 matrix reference, or add the test.
- **Artifact:** same file, Test Notes → **Stale:** "The API test package
  covers the interface `Archive` path on its own fixture" → **Current:** no
  test does → **Suggested update:** drop the sentence.
- **Artifact:** same file, INV-8 source → **Stale:** "`pausable-v1` README,
  Usage step 2" for the `archive self` rule → **Current:** the sentence was
  removed in `f73c79d` → **Suggested update:** cite
  `test_nonconsumingFlipLeavesTwoContracts` as the statement.
- **Artifact:** same file, INV-5 and INV-7 sources → **Stale:**
  "`pausable-v1` README, Authority" bullets on stale ids and on disclosure
  → **Current:** both bullets were removed in `f73c79d` → **Suggested
  update:** cite the tests.
- **Artifact:** same file, Out of Scope → **Stale:** SCU of an implementing
  template "not exercised here" → **Current:** `test_optionalFlagReadsNoneAsUnpaused`
  covers the `Optional` flag; the upgrade check itself ran only in the
  session scratchpad → **Suggested update:** narrow the item to the
  `upgrades:` build.

`artifacts/01-research.md` and `artifacts/02-design.md` are not in the tree,
so their drift is not listed. Both were read from git history for context.

## Extension Mode: Compatibility Check

Commit `2fc2ddf` removed an interface method and five exported functions.
Both packages are pre-release and have never been uploaded, `CHANGELOG.md`
carries only `Added` entries for them, and every consumer in the workspace
(two test packages, two examples) was updated in the same commit. No
compatibility obligation exists yet. Once `openzeppelin-api-pausable-v1`
is uploaded anywhere shared, a change of this kind becomes a sibling `-v2`
package.

## Recommendation

- **Overall verdict:** Ready for publishing as a pre-release. MED-1 and
  MED-2 are applied in the working tree.
- **Blocking issues:** None.
- **Suggested improvements:** INFO-1 to INFO-7, with INFO-1 now covering
  the sentences `f73c79d` removed; the INFO-5 tests; a repository home for
  the v1/v2 retrofit pair; update `artifacts/06-docs.md` and
  `artifacts/05-tests.md` per Artifact Drift or re-run those stages.

## Out of Scope

- `experiments/access/access-control-v1`, `experiments/access/ownable-v1`,
  `experiments/token/tokenCIP112-v1` and their test packages: not Pausable.
- `scripts/check-sandbox.sh`, `scripts/check-lint.sh`,
  `scripts/check-coverage.sh`, `scripts/check-examples.sh`, and the CI
  workflows: tooling, read for how coverage is gated, not reviewed.
- `dars/manifest.yaml` and the release procedure: downstream of this
  stage; INFO-4 names the one fact that must feed it.
- Off-ledger clients: the `InterfaceFilter` read path is described in the
  API README and exercised only through Daml Script's
  `queryInterfaceContractId`; no Ledger API client exists in the repository.
- Property-based or symbolic verification: the guards are two one-line
  functions and the negative tests are the proof. `/canton-daml-props`
  remains available for randomized consumer-side round-trip laws.
- Drift in the deleted research and design artifacts.

## Dev Notes

- **Stage-start drift check ran without confirmation.** The session was
  non-interactive, so these commitments were taken as current:
  1. Authority-in-path only; no shared-switch template ships.
  2. One frozen interface with a one-`Bool` view, no `Party`, no method, no
     choice, in `openzeppelin-api-pausable-v1`.
  3. Guards and failure statuses in `openzeppelin-pausable-v1`; the
     consumer writes every flip choice, consuming, with `whenNotPaused`
     or `whenPaused` first.
  4. `failWithStatus` with `openzeppelin.com/pausable-*` ids.
  5. LF 2.1, no keys, no dependency beyond `daml-prim`, `daml-stdlib`, and
     the API package.
  6. Both packages pre-release at `0.1.0`, never uploaded to a shared
     ledger before the first tagged release.
  If any of these has shifted, say so and the affected findings will be
  re-evaluated.
- **`artifacts/05-tests.md` was added in `328db18`** with its own INV-1 to
  INV-10, which differ from INV-1 to INV-16 here. No `03-invariants` or
  `04-code` artifact exists; the two lists together can seed
  `artifacts/03-invariants.md`.
- **Docs consulted:** Canton SCU deep-dive "Upgrading Interfaces" and
  "Separate Interfaces/Exceptions from Templates"; the upgrading reference
  "Packages" (utility package definition), "Dependencies", and "Interface
  Instances"; the `DA.Fail` reference for `FailureStatus.errorId`; the
  `UpdateVettedPackages` force flags.
- **Coverage note:** the `test/api-pausable-v1` package has 3 scripts, not
  the 4 that `artifacts/06-docs.md` records or the 4 that
  `artifacts/05-tests.md` lists; the fourth left with `setPaused`. After
  this revision the `test/pausable-v1` coverage report shows 7 fixture
  templates all created and 6 unexercised choices, all implicit `Archive`.

## Open Questions

1. Should `artifacts/03-invariants.md` be backfilled from INV-1 to INV-15
   so the next review runs against a list the dev owns?
2. Is the admin-to-admin `Payout` in `Vault_EmergencyDrain` the intended
   model for the recovery path (INFO-3), or a placeholder?
3. Where does the first-upload rule live: `RELEASING.md` when it is
   written, or `ARCHITECTURE.md` now (INFO-4)?
4. Should `artifacts/06-docs.md` be corrected in place per Artifact Drift,
   or should the docs stage re-run in revision mode against `2fc2ddf`?
5. Should the v1/v2 retrofit pair become a repository package pair so the
   README block and the `-Wtemplate-has-new-interface-instance` flag are
   exercised in CI? `scripts/check-examples.sh` requires every example to
   data-depend on a production DAR, which the v1 package would not.
6. `f73c79d` removed the README statements of the consuming-flip, flag, and
   stakeholder-field obligations (INV-9, INV-10, INV-12). Are the tests the
   intended sole home for them?
