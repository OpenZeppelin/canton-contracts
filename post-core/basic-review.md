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
contracts (MED-2). Neither blocks a merge; MED-1 should land before the first
tagged release because it closes the one misuse the type signature permits.

Verified on 2026-09-23 with SDK 3.4.11, `--target=2.1`:

| Check | Result |
|---|---|
| `dpm build --all` | 14 packages build |
| `scripts/check.sh` | OK |
| `dpm damlc lint` on the 8 Pausable packages | No hints |
| `test/api-pausable-v1` | 3 scripts pass |
| `test/pausable-v1` | 14 scripts pass |
| `examples/pausable/vault-test` | 11 scripts pass |
| `examples/pausable/registry-test` | 7 scripts pass |

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
| INV-7 No guard accepts a `ContractId`; each takes the value the choice runs on | ✅ Yes | signatures line 45, 59, 63 | `HasToInterface t Pausable => t`. `t = Pausable` is admissible, so a consumer can still `fetch` a caller-supplied `ContractId Pausable` and pass the result; the type system cannot exclude it, see MED-1 |
| INV-8 A flip needs the implementing template's signatory authority; the interface offers no path | ✅ Yes | ledger model | No interface choice exists to exercise; `test_onlyTheConsumersControllerMayPause`, `test_customAuthorityGatesTheFlip` |
| INV-9 A flip leaves exactly one active contract | ⚠️ Partial | consumer code; README line 82-83 | Consuming choice or `archive self`; documented, and `test_nonconsumingFlipLeavesTwoContracts` shows the failure mode. Fail-open by design since the `self`-taking flips were removed in `2fc2ddf`, see INFO-1 |
| INV-10 A pause flip creates the successor with `paused = True`, an unpause with `paused = False`, and the view reports the field | ⚠️ Partial | consumer code; README line 138-141 | The consumer's own `create` and `view`; nothing in the library checks either. `test_pauseUnpauseRoundTrip` covers the fixtures. See INFO-1 |
| INV-11 Every gated choice calls a guard | ⚠️ Partial | consumer code; README line 135-137 | Unenforceable in Daml; documented. Examples gate deliberately per choice (`Vault_Redeem` is open by design) |
| INV-12 A flip keeps the fields that determine signatories and observers | ⚠️ Partial | consumer code; README line 142-144 | Documented; untested, see INFO-5 |
| INV-13 Guards evaluate no ledger time | ✅ Yes | line 45-64 | No `getTime`; `pauseUntil` in the registry example is reporting only and its README says so |
| INV-14 Origination-only semantics: committed work stands, a flip rejects in-flight readers | ✅ Yes | ledger model; README line 133-134 | A consuming exercise on the implementing contract |
| INV-15 The interface package is frozen, the function package is versionable, and the consumer's template keeps SCU with its instance retained | ✅ Yes | `daml.yaml` of both packages; `ARCHITECTURE.md` "Components without templates" | Matches the Canton SCU reference: interface definitions are non-upgradeable, instances may be added and never removed, instance bodies may change. See INFO-6 for the utility-package refinement |

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

**Status:** Open

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

**Status:** Open

### Informational

#### INFO-1: The consuming-flip and flag obligations are fail-open after the flip helpers were removed

**Location:** `packages/security/pausable-v1/README.md` line 82-83 and 138-141; `test/pausable-v1/daml/OpenZeppelin/PausableV1TestFixtures.daml` line 150-167
**Invariant:** INV-9, INV-10

**Issue:** Commit `5675734` made `pause` and `unpause` archive `self`, so a
`consuming` caller failed closed; commit `2fc2ddf` removed the flips
entirely, and the consumer now writes the archive and the create. A
`nonconsuming` flip without `archive self` leaves two active contracts, and
a flip that creates with the wrong flag is a pause that does not pause.
Both are documented and the first is demonstrated by `LeakyVault`. The
previous report's MED-1 asked for a fail-closed shape; the dev chose the
smaller surface. This entry records the residual for the audit trail.

**Recommendation:** Extend the caveat's test advice so the consumer's
round-trip test states both properties: after a pause, the predecessor id
returns `None` from `queryContractId` and the successor's view reads
`paused = True`; after an unpause, the mirror. `test_flipArchivesThePredecessor`
and `test_pauseUnpauseRoundTrip` are the shape to point at.

**Status:** Acknowledged (design decision in `2fc2ddf`)

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

- **INV-12.** The README caveat that a flip which drops an observer
  silently narrows visibility has no executable statement. A
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
| INFO-1 README overstates why a stranger cannot flip | Resolved | README line 123-125 now names signatory authority and the absence of an interface choice |
| INFO-2 privacy negative, unpause failure routes, credential-holder branch, vacuous coverage | Resolved / Superseded | `test_viewHiddenFromStranger`; unpause routes gone with the helpers; `eCredentialNotCallers` branch tested; `CONTRIBUTING.md` documents the 0/0 report |
| INFO-3 registry example stores nothing | Resolved | `668430e`; `entries` field |
| INFO-4 `test/placeholder` | Resolved | `230ceee` |
| INFO-5 record update after `markPaused` can change stakeholder fields | Resolved | README line 142-144; the helper itself is gone |

## Security Checklist Results

| Category | Result | Notes |
|---|---|---|
| 3.1 Authorization | Pass | No templates, choices, or controller expressions in either production package. Fixtures and examples: controllers are the named principals, flips are consuming, `Payout` is signed by `admin` whose authority every `Vault` choice carries. Non-stakeholder flip authority works through the choice body (`RoleVault_Pause`) and is tested with disclosure. No propose-accept, no stuck-contract path; the implementing template's `Archive` stays with its signatories. |
| 3.2 Privacy and disclosure | Pass | The view is one `Bool`, so cross-implementer divulgence is bounded to the flag. No guard fetches, so no party joins the read path. A non-stakeholder flip controller sees the payload at flip time; README line 126-127 says so. Disclosures held for the predecessor go stale on a flip; documented. Negative privacy test present. |
| 3.3 Integrity and runtime checks | Pass | No templates, so no `ensure`. Both checks raise `failWithStatus` with DNS-prefixed ids in the documented convention and the category a retrying client expects. No `assertMsg`, `error`, or `abort` on any consumer-reachable path in production code. No `agreement`, no user-defined exceptions. `Decimal` appears only in the vault example, guarded by `ensure balance >= 0.0` and two amount checks. |
| 3.4 Contract keys | n/a | LF 2.1; no key anywhere in the changeset. |
| 3.4a Admin layer (Pausable) | Pass with MED-1 | The flag is a field of the contract that is `self` of every gated choice, so no separate state contract exists to omit; the type signature still admits a fetched interface value, which is a documentation gap (MED-1). Guard-at-every-chokepoint is the consumer's duty (INV-11); both examples gate deliberately and leave one escape hatch open on purpose. Unpause is reachable in every fixture and example. Ownership transfer and role capabilities are out of scope by design; composition is by reference in the consumer's choice body. |
| 3.5 Composability and contention | Pass | Guards are pure over `this`, so no assumption about the surrounding submission. A flip is a consuming exercise on the implementing contract and rejects concurrent readers; that is the committed origination-only semantics. No authority is assumed from the calling context. Adopting the interface changes no signatory set, so reassignment is unaffected. |
| 3.6 Economic security | Pass for the packages; INFO-3 for the example | The packages move no value. The vault example conserves value on withdraw and redeem; the drain pays the admin from itself, which is a modelling choice rather than a leak. |
| 3.7 Upgrade safety | Pass with INFO-6 | LF 2.1 supports SCU. The interface lives alone in `openzeppelin-api-pausable-v1`, as the SCU deep-dive requires. The function package is a utility package and is exempt from the dependency-retention rule; the READMEs understate this. No `daml.lock` exists because every dependency is a path-pinned DAR; package ids are deterministic per build. The breaking-change path (sibling `-v2` API package, both instances for life, offline migration to drop `-v1`) is stated in the API README and matches the reference. The retrofit path for live contracts is missing (MED-2). |

## Test Coverage Assessment

35 scripts pass across the four test packages. Every ✅ invariant has a
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

- MED-1: the decoy-switch fixture and script.
- MED-2: a v1/v2 pair under `upgrades:` that adds `paused : Optional Bool`
  and the instance.
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

- **Overall verdict:** Ready for publishing as a pre-release. Two
  documentation fixes recommended before the first tagged release.
- **Blocking issues:** None for merging this branch. MED-1 before the first
  tagged release, because it closes the one misuse the type signature
  permits and the research ranked it highest.
- **Suggested improvements:** MED-2 with a compiled retrofit pair; INFO-1
  to INFO-7; the INFO-5 tests; update `artifacts/06-docs.md` per Artifact
  Drift or re-run the docs stage.

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
- **No `03-invariants`, `04-code`, or `05-tests` artifact exists.** INV-1
  to INV-15 above can seed `artifacts/03-invariants.md`.
- **Docs consulted:** Canton SCU deep-dive "Upgrading Interfaces" and
  "Separate Interfaces/Exceptions from Templates"; the upgrading reference
  "Packages" (utility package definition), "Dependencies", and "Interface
  Instances"; the `DA.Fail` reference for `FailureStatus.errorId`; the
  `UpdateVettedPackages` force flags.
- **Coverage note:** the `test/api-pausable-v1` package has 3 scripts, not
  the 4 that `artifacts/06-docs.md` records; the fourth left with `setPaused`.

## Open Questions

1. Should `artifacts/03-invariants.md` be backfilled from INV-1 to INV-15
   so the next review runs against a list the dev owns?
2. Is the admin-to-admin `Payout` in `Vault_EmergencyDrain` the intended
   model for the recovery path (INFO-3), or a placeholder?
3. Where does the first-upload rule live: `RELEASING.md` when it is
   written, or `ARCHITECTURE.md` now (INFO-4)?
4. Should `artifacts/06-docs.md` be corrected in place per Artifact Drift,
   or should the docs stage re-run in revision mode against `2fc2ddf`?
