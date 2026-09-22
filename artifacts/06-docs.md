---
stage: docs
project: pausable
mode: extension
extends: packages/security/api-pausable-v1, packages/security/pausable-v1
status: draft
timestamp: 2026-09-22
author: nenad.misic
previous_stage: null
tags: [pausable, interface, security, docs-audit]
---

# Pausable - Documentation

## Summary

Standalone docs pass over every Pausable file: the two production packages,
their two isolated test packages, the two example packages with their test
packages, and the root documents that describe them. The pass verified
current behavior by building the workspace, running all four test packages,
linting, and rendering the reference with `dpm damlc docs`, then checked each
document against the docs rules and corrected what failed. The rules that
drove the corrections: one home per fact, affirmative framing, no rationale
or history in consumer docs, every code block mirrors compiled code, and at
most one code example per symbol.

Audience: Daml developers adopting the two packages, and operators who vet
the package IDs. Detail level: package README plus generated reference; the
component needs no `integration-guide.md`.

## Current behavior (verified)

| Check | Result |
|---|---|
| `dpm build --all` | 14 packages build |
| `test/api-pausable-v1` | 4 scripts pass |
| `test/pausable-v1` | 19 scripts pass |
| `examples/pausable/vault-test` | 11 scripts pass |
| `examples/pausable/registry-test` | 7 scripts pass |
| `dpm damlc lint` on both production packages and `test/pausable-v1` | No hints |
| `scripts/check.sh` | OK |
| `dpm damlc docs --format md` on both production packages | Renders both modules |

Behavior the docs describe, as the source and tests establish it:

- `Pausable` has the view `PausableView { paused : Bool }` and the method
  `setPaused : Bool -> Pausable`. The only choice is the implicit `Archive`.
- `whenNotPaused` fails with `eEnforcedPause` while paused; `whenPaused`
  fails with `eExpectedPause` while unpaused; `isPaused` is pure.
- `pause` runs `whenNotPaused`, calls `setPaused True`, fails with
  `eImplementerTypeMismatch` when `fromInterface` yields another template,
  and with `eFlagNotApplied` when the flag stayed unchanged. `unpause`
  mirrors it.
- The four `errorId` values are `openzeppelin.com/pausable-enforced-pause`,
  `-expected-pause`, `-flag-not-applied`, and
  `-implementer-type-mismatch`.
- A consuming flip choice leaves one contract; a nonconsuming flip without
  `archive self` leaves two (`test_nonconsumingFlipLeavesTwoContracts`).
- `pause` on an interface value yields a value and changes nothing on the
  ledger (`test_flipOnInterfaceValueChangesNothing`).
- A non-stakeholder flip controller receives the contract through explicit
  disclosure (`test_customAuthorityGatesTheFlip`).
- The view is visible to observers and hidden from strangers
  (`test_viewReadableByObserver`, `test_viewHiddenFromStranger`).

## Documents

| Document | Purpose | Audience |
|---|---|---|
| `packages/security/api-pausable-v1/README.md` | Adopt the interface, read the flag off-ledger, authority, caveats, compatibility | Daml developers, operators |
| `packages/security/pausable-v1/README.md` | Adopt the guards and flips, assert on failure statuses, authority, caveats, compatibility | Daml developers |
| Doc comments in `OpenZeppelin.Api.PausableV1` and `OpenZeppelin.PausableV1` | The reference that `dpm damlc docs` renders | Daml developers |
| `examples/pausable/vault`, `examples/pausable/registry` and their READMEs | Runnable adoption examples | Daml developers |
| `CHANGELOG.md` | Unreleased entries for both packages | Existing users |

No `api-reference.md` and no `integration-guide.md`: the reference is
generated, and the README holds every adoption fact.

## Findings and corrections

### `packages/security/api-pausable-v1/README.md`

| Finding | Rule | Correction |
|---|---|---|
| Field table for `PausableView` | README does not restate fields | Removed; the generated reference renders it |
| Split rationale and "declares no choice, because..." paragraphs | Rationale lives in `ARCHITECTURE.md`; affirmative framing | Removed; `ARCHITECTURE.md` already holds the rationale |
| "names no pause authority", "defines no templates", "runs no guard and creates nothing", "There is no event template", "There is no patch release" | Affirmative framing | Reworded to what the interface, the flip, and the consumer do |
| "CIP-0112 `pauseInfo` fields are deliberately absent" | No design narration | Caveat now states what `PausableView` carries and points to `examples/pausable/registry` |
| Ledger API filter named as `OpenZeppelin.Api.PausableV1:Pausable` and archive/create event narration | Ledger semantics the reader knows | Reduced to the `InterfaceFilter` sentence and the Daml Script block that mirrors the tests |
| Compatibility restated the interface-freeze rule and its reasoning | One home; rationale in `ARCHITECTURE.md` | Kept the policy and the three consumer consequences; added Daml-LF target |
| No "Authority and lifecycle" section | `AGENTS.md` requires the authority and lifecycle model in every package README | Added a four-sentence section |
| "Examples" section duplicated `examples/README.md` | Root docs repeat nothing from package docs and vice versa | One pointer sentence under "Consume a local build" |

### `packages/security/pausable-v1/README.md`

| Finding | Rule | Correction |
|---|---|---|
| `TokenRules_Pause` example using `requireRole` and `RoleGrant` from `experiments/` | Every code block mirrors code that `dpm build` compiles | Replaced with `RoleVault_Pause` from `test/pausable-v1` fixtures |
| "archive nothing / consuming archives / nonconsuming calls `archive self`" stated three times, plus once in each example README | One home per fact; consuming-choice semantics belong nowhere | Stated once in Usage step 2 |
| Double-flip failure statuses stated in Usage step 3 and again in Authority bullets | One home; the function doc comments hold them | Removed the Authority bullet |
| "A Daml controller expression is pure, so it cannot fetch a credential" and "Daml Script hands it back as a `FailureStatusError`" | Daml semantics the reader knows | Removed; the instruction and the code block remain |
| `setPaused` other-fields caution duplicated from the API README | One home; a second mention names the holder | Replaced with a pointer to the API README caveat |
| Stale contract IDs stated in Authority and again as contention in caveats | One home | Merged into one Authority bullet |
| "ships no access control", "cannot fetch", "never fails", "cannot flip the flag" | Affirmative framing | Reworded |
| Missing disclosure expectation for a non-stakeholder flip controller | `AGENTS.md` requires disclosure and privacy expectations | Added one Authority bullet, backed by `test_customAuthorityGatesTheFlip` |
| Compatibility lacked the Daml-LF target | README Compatibility states SDK and LF | Added Daml-LF `2.1` with a pointer to `multi-package.yaml` for the SDK |
| "Examples" section duplicated `examples/README.md` | As above | One pointer sentence |

### Doc comments

| Symbol | Finding | Correction |
|---|---|---|
| `OpenZeppelin.Api.PausableV1` header | Five paragraphs; split rationale; "no extra fetch, no extra disclosure, and no extra authority" | Four paragraphs describing where the state lives, what the consumer writes, and how the consumer flips |
| `PausableView` and its field | Same sentence twice | Type: the view of a `Pausable` contract. Field: `True` while paused |
| `Pausable` | Two sentences | One sentence |
| `setPaused` | Fact about `pause` verifying the result, whose home is the `pause` comment | Kept the code example and the imperative caller rule |
| `OpenZeppelin.PausableV1` header | `TokenRules_Pause` example not compiled anywhere; "holds no interface and no template" compatibility paragraph | `RoleVault_Pause` from the fixtures; compatibility stays in the README |
| `pause` | Two code examples | One example plus the imperative rule for the record update |
| `test_pauseWhenPausedFails`, `test_unpauseWhenUnpausedFails`, `test_pauseErrorsAreDistinct` | Named `_pause`, `_unpause`, `EnforcedPause`, `ExpectedPause` from another library | Reworded on the component's own terms |

### Example READMEs, root docs

| File | Finding | Correction |
|---|---|---|
| `examples/pausable/vault/README.md` | "The library ships none"; "carries no guard"; a paragraph on a hypothetical non-signatory controller not present in the code; archive-nothing duplicate | Reworded; hypothetical removed, its privacy fact moved to the `pausable-v1` README |
| `examples/pausable/registry/README.md` | "Reporting, not enforcement" section framed as what the example does not do; "does not move"; "controls no choice"; archive-nothing duplicate | Section renamed "The deadline" and stated affirmatively; duplicates removed |
| `README.md` | "completed its design review", "tested in CI" | Internal review context and CI belong outside the consumer landing page; sentence now states the package split and status |
| `ARCHITECTURE.md` | Package layout block still read `<component>-api-v1` and `openzeppelin-rbac-api-v1`, predating the rename to `openzeppelin-api-<component>-vN` | Corrected to the current naming rule |
| `CONTRIBUTING.md` | Docs command shown with one file; a multi-module package renders only the files passed | Added the sentence to pass every source file |

### Passed without change

- `Internal.daml`, the four failure-status comments, `whenNotPaused`,
  `whenPaused`, `isPaused`, `unpause`: one sentence per fact, `errorId` on
  the constant, one example at most.
- `CHANGELOG.md`: the two Pausable entries are user-visible changes to
  production packages.
- `examples/README.md`, `packages/README.md`: list the packages and repeat
  nothing from them.
- Both example modules and all four test modules: doc comments state what
  each fixture and script does; the two defect fixtures name their defect in
  one sentence.
- Every remaining README code block mirrors a compiled example or fixture:
  `Vault` and `Vault_Withdraw` from `examples/pausable/vault`,
  `Vault_Pause`, `Vault_Unpause`, `Registry_Pause`, and `RoleVault_Pause`
  from `test/pausable-v1`, and the `queryInterfaceContractId` and
  `FailureStatusError` patterns from the test scripts.

## Out of Scope

- Docs of `experiments/` packages (`access-control-v1`, `ownable-v1`,
  `tokenCIP112-v1`): the request covers Pausable only. Their READMEs carry a
  "Solidity analogue" row that the docs rules forbid; left for their own
  pass.
- `RELEASING.md`: future-tense stub, referenced from both Pausable READMEs;
  it is a release-process document, not a Pausable doc.
- The Ledger API filter shape in code (`CumulativeFilter` and
  `InterfaceFilter` JSON): kept to one sentence because no off-ledger client
  drives the component in this repository.
- Heading names: the READMEs keep the repository's "Usage", "Scope and
  security caveats", and "Consume a local build" rather than the skill's
  "Adopt it", "Security caveats", and "Depend on it", because repository
  conventions win.

## Dev Notes

- Both package READMEs state the version `0.1.0` twice (table and the
  pre-release paragraph) and the DAR filename once. A version bump touches
  three places per README.
- The `pausable-v1` README's `RoleVault_Pause` block writes `Pausable.pause`
  where the fixture writes `pause` unqualified; the README's own import
  convention is qualified.

## Open Questions

- The `ARCHITECTURE.md` "Components without templates" section repeats the
  split rationale that both READMEs previously carried. It is the right home,
  and nothing further points there from the READMEs. Add a link from the
  READMEs' Compatibility sections if readers ask why the split exists.
- `RELEASING.md` is a placeholder. Both READMEs link to it for the release
  and package-ID policy; decide whether the links stay until the document
  exists.
