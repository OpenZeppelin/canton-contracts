---
stage: design
project: pausable
mode: greenfield
extends: null
status: draft
timestamp: 2026-09-01
author: nenad.misic@openzeppelin.com
previous_stage: artifacts/01-research.md
tags: [pausable, emergency-stop, interface-only, frozen-api, lf-2.1, cip-0112, authority-agnostic]
---

# Pausable - Design Document

## Summary

`openzeppelin-pausable-api-v1` is a single frozen Daml package that defines one
interface, one view record, and a set of pure guards and guarded flips. It
defines no templates: the pause flag is a field on the consumer's own template,
and the consumer writes the `interface instance` and the choice that decides who
may flip the switch. Keeping the flag on the contract that the gated operation
already exercises is what makes the guard sound - there is no separate state
contract for a caller to substitute or omit.

The design was verified against the compiler during the design conversation. The
module and both worked examples build on SDK 3.4.11 with `--target=2.1`, and the
consumer examples build across a `data-dependencies` boundary on the produced
DAR.

## Package Shape

**Shareable component package.** The deliverable is a behavior that other
packages' templates adopt, the Daml analogue of `Pausable.sol` as an abstract
mixin. The state lives on the consumer's template; this package contributes the
interface, the view, the guards, and the flips.

```text
openzeppelin-pausable-api-v1     one package, one DAR, frozen at 1.0
```

There is no sibling implementation package. `ARCHITECTURE.md` pairs
`<component>-api-v1` with `<component>-v1` only when there are templates to
hold, and here there are none; an empty sibling would add ceremony with no
upgrade or interoperability benefit.

What the split freezes, and why it matters:

- **The interface and its view are frozen for the life of the package.**
  Interface definitions are not SCU-upgradeable. Version 2 of a package fails to
  type check when it redeclares an interface, even unchanged, so the whole
  package is effectively single-version. A change means publishing a sibling
  `-v2` package beside `-v1`, with both live on the ledger and consumers
  migrating at their own pace.
- **The interface carries exactly one method and no choices.** It is the only
  part of the package that becomes a ledger artifact and the only part that pins
  a consumer to this exact package version, so it is kept as small as the design
  allows.
- **Everything else is compile-time only.** The guards, the flips, and the error
  constants never appear on the ledger and never affect a consumer's SCU
  surface. Being wrong about them costs a recompile; being wrong about the
  interface costs a migration.

## Module Structure

One module.

```text
openzeppelin-pausable-api-v1
└── OpenZeppelin.PausableV1     interface, view, guards, flips, error constants

dependencies:   daml-prim, daml-stdlib
build-options:  --target=2.1
```

The interface, its view, the guards, and the error constants have no meaning
apart from each other, and a consumer should import one name to use them. A
`.Types` or `.Errors` split would make every consumer import two modules to call
one guard. There is no `.Internal` module because there is no implementation
detail to hide.

No dependency on Splice, Daml Finance, or `daml-script`.

**Daml-LF target: 2.1, no contract keys.** Keys are load-bearing only for the
free-floating shared-switch shape that this design does not ship. In the
authority-in-path shape the flag sits on the contract the gated choice already
exercises, so the guard receives `this` and nothing is looked up. LF 2.3 keys
would not have rescued the other shape either - multiple contracts may share a
key and negative lookups are not validated, so canonical-instance selection
stays an operator responsibility. Moving to 2.3 would require Canton 3.5 and
protocol version 35, narrowing the deployments that can upload the DAR, which is
the wrong trade for a component intended for broad adoption.

## Core Types

```daml
module OpenZeppelin.PausableV1 where

import DA.Optional (fromSomeNote)

-- | The pause state of an implementing contract. Frozen at 1.0.
data PausableView = PausableView
  with
    paused : Bool
      -- ^ True while the contract refuses to originate gated operations.
  deriving (Eq, Show)

-- | The pause switch. Declares no choices and names no pause authority.
--   Adds no signatories, no observers and no disclosure: visibility of the
--   pause state is exactly the visibility of the implementing contract.
interface Pausable where
  viewtype PausableView

  -- | Implementer obligation: return this contract's own template value with
  --   the pause flag set to the argument, preserving every other field.
  --
  -- > setPaused b = toInterface (this with paused = b)
  setPaused : Bool -> Pausable
```

`PausableView` is a one-field record rather than a bare `Bool` because
`viewtype` requires a serializable record; the Ledger API exposes the view as a
record. The single field is the whole frozen data surface.

`reason` and `until` are deliberately absent. A consumer serving CIP-0112
`pauseInfo` holds them as its own template fields beside `paused`, so the whole
metadata response still derives from one on-ledger contract while the frozen
interface stays a single boolean. CIP-0112 may extend `PauseInfo`; this package
does not move when it does.

No `Party` field. The interface names no authority, matching the `internal`
visibility of Solidity's `_pause`. An earlier revision of the research artifact
carried a `pauser : Party` in the view and dropped it: a party field in a frozen
view is a standing invitation to name a placeholder, which publishes a false
claim about who holds the switch and opens a second live path to it.

### Correspondence with `Pausable.sol`

| `Pausable.sol` | `OpenZeppelin.PausableV1` |
|---|---|
| `bool private _paused` | `paused : Bool` on the consumer's template, read through `PausableView` |
| `function paused() view` | `isPaused` |
| `modifier whenNotPaused()` | `whenNotPaused` |
| `modifier whenPaused()` | `whenPaused` |
| `error EnforcedPause()` | `eEnforcedPause` |
| `error ExpectedPause()` | `eExpectedPause` |
| `function _pause() internal` | `pause`, `pauseWith` |
| `function _unpause() internal` | `unpause`, `unpauseWith` |
| `event Paused` / `Unpaused` | none - the archive-and-create pair is already a transaction-tree node carrying the actor and the timestamp, delivered to every stakeholder |
| constructor leaving `_paused = false` | none - the consumer's template sets the initial field value |

Daml has no `internal`, so `pause` is an exported function any module can name.
Its authority boundary is the ledger's rather than the compiler's: the create
needs the implementing contract's signatory authority, which exists only inside
a choice on that contract. The effective reach matches Solidity's `internal`.

## Public API

Fourteen exports. All are frozen, and all are API a consumer depends on -
including the error constants, which consumers assert on in their own tests.

```daml
-- | `paused()` as a pure function, for a choice that branches on the flag
--   rather than refusing. Total.
isPaused : (HasToInterface t Pausable) => t -> Bool

-- | The `whenNotPaused` modifier. Call first in every gated choice body.
--   Fails with eEnforcedPause.
whenNotPaused : (HasToInterface t Pausable) => t -> Update ()

-- | The `whenPaused` modifier, for an operation legal only while paused.
--   Fails with eExpectedPause.
whenPaused : (HasToInterface t Pausable) => t -> Update ()

-- | Guarded flip to paused. Call from a CONSUMING choice whose controller is
--   the consumer's pause authority. Fails with eEnforcedPause if already
--   paused, eFlagNotApplied if the flag did not change, and
--   eImplementerTypeMismatch if setPaused returned another template.
pause : (HasToInterface t Pausable, HasFromInterface t Pausable, HasCreate t)
     => t -> Update (ContractId t)

-- | Pause and update sibling fields in the same transaction. The lambda
--   touches the other fields; the flag is set by the library.
pauseWith : (HasToInterface t Pausable, HasFromInterface t Pausable, HasCreate t)
         => (t -> t) -> t -> Update (ContractId t)

-- | Guarded flip to unpaused. Fails with eExpectedPause if not paused,
--   eFlagNotApplied if the flag did not change.
unpause : (HasToInterface t Pausable, HasFromInterface t Pausable, HasCreate t)
       => t -> Update (ContractId t)

unpauseWith : (HasToInterface t Pausable, HasFromInterface t Pausable, HasCreate t)
           => (t -> t) -> t -> Update (ContractId t)

eEnforcedPause          : Text  -- "Pausable: the contract is paused"
eExpectedPause          : Text  -- "Pausable: the contract is not paused"
eFlagNotApplied         : Text  -- "Pausable: the flip did not change the paused flag"
eImplementerTypeMismatch : Text -- "Pausable: setPaused did not return the
                                --  implementing template"
```

Implementations:

```daml
isPaused x = (view (toInterface @Pausable x)).paused

whenNotPaused x = assertMsg eEnforcedPause (not (isPaused x))
whenPaused    x = assertMsg eExpectedPause (isPaused x)

pause   = pauseWith   identity
unpause = unpauseWith identity

pauseWith f x = do
  whenNotPaused x
  let flipped = fromSomeNote eImplementerTypeMismatch
        (fromInterface (setPaused (toInterface @Pausable x) True))
      y = f flipped
  assertMsg eFlagNotApplied (isPaused y)
  create y

unpauseWith f x = do
  whenPaused x
  let flipped = fromSomeNote eImplementerTypeMismatch
        (fromInterface (setPaused (toInterface @Pausable x) False))
      y = f flipped
  assertMsg eFlagNotApplied (not (isPaused y))
  create y
```

Every guard takes the contract value being exercised, never a `ContractId` the
caller supplies. This is the substitution defence: there is no separate switch
for an adversarial caller to swap or omit.

The interface declares **no choices**. An interface choice needs a controller
expression drawn from the view, and the view holds no party, so there is no
controller to name. That is a direct consequence of the authority-agnostic
decision, not a separate one. `pause` and `unpause` are therefore ordinary
top-level functions rather than choices, which is also what lets them be
polymorphic in the implementing template and return `ContractId t`.

## Party / Authorization Model

**This package names no party.** `PausableView` has no `Party` field, the
interface declares no choice, and the package therefore contains no controller
expression and no signatory clause.

**Visibility is entirely the implementing template's.** `paused` is a field on
the consumer's contract, so whoever can read that contract can read the pause
state, and nobody else. Adopting `Pausable` changes no signatory set, adds no
observer, and requires no disclosure. The view carries a single `Bool`, so there
is no cross-implementation leak and no `reason` text riding into every
transaction.

**The privacy cost the research flagged is not paid.** A separate pause-state
contract would make the pauser's participant node an informee of a `Fetch` node
in every gated operation, leaking traffic volume and timing and storing an event
per operation. This design fetches nothing: `whenNotPaused this` reads a field
of the contract already being exercised. The pauser's node observes flips only.

**Authority arithmetic for the flip.** A choice on contract `C` carries the
authority of `C`'s signatories plus that of its controllers. The successor
preserves the signatory set, so it needs exactly the authority the choice
already holds. The consequence is a wide degree of freedom: the pause authority
need not be a signatory, an observer, or a stakeholder. Any party the consumer
can name in a controller expression works, needing only the contract id - the
flexible-controller pattern from the Canton explicit-disclosure documentation.

Roles in an adopting deployment, all defined by the consumer:

| Role | Contract | Relationship |
|---|---|---|
| signatories of the implementing template | consumer's template | signatory; their authority is what the flip spends on the successor |
| pause authority | consumer's template | controller of the consumer's pause choice; no signatory or observer requirement |
| unpause authority | consumer's template | controller of the consumer's unpause choice; need not be the same party |
| any stakeholder | consumer's template | reads `paused` because it reads the contract; no extra disclosure |

**The one privacy cost.** A controller is an informee of the exercise node, and
an exercise node's informees see the input contract's payload. Naming a
non-stakeholder as pause authority discloses the template payload to them, at
flip time only. Prefer a signatory or observer where the payload is sensitive.
This is guidance, not a rule - narrowing it normatively would forbid the
role-based pattern below.

**Role-based, timelocked, or multi-party authority.** A Daml controller
expression is pure and cannot fetch a credential, so it can never say "whoever
holds the Pauser role". The caller and the credential arrive as choice arguments
and the body verifies them, which is the capability-contract pattern:

```daml
choice MyToken_Pause : ContractId MyToken
  with
    caller   : Party
    grantCid : ContractId RoleGrant
  controller caller
  do
    grant <- fetch grantCid
    requireRole caller "PAUSER_ROLE" admin grant
    pause this
```

`controller caller` makes the ledger require `caller`'s authority to submit, and
`requireRole`'s `grant.account == caller` check stops `caller` presenting
someone else's grant. The same slot takes a timelock, a party set, an `Ownable`
`Ownership` contract, or a hardcoded party.

Three consequences:

- **No dependency either way.** This package does not import access-control and
  access-control does not import it. Composition happens in the consumer's
  template, as `ARCHITECTURE.md`'s dependency policy requires.
- **A failed role check is an `assertMsg`, not an authorization failure.** A
  wrong role yields `eRoleMismatch`; only a missing `caller` signature yields a
  Daml authorization error. Two distinct failure classes for the Tests stage.
- **The role admin sees one `Fetch` node per flip.** Signatories of a fetched
  contract are informees. Flips are rare, so this is cheap - and it is exactly
  the cost the rejected free-floating design would have charged on every gated
  operation instead.

**Asymmetric authority and renunciation come free.** Pause and unpause are
separate consumer choices, so any guardian may pause while only the full board
may unpause, at no cost. Irrevocable surrender of the switch - XRPL's
"No Freeze" - is the consumer archiving their authority contract with no
successor; this package has no authority contract to stand in the way.

**Contention.** A flip is a consuming exercise on the implementing contract, so
it conflicts with every concurrent exercise and fetch of that contract and
rejects them. Committed work is unaffected and a gated choice refuses to start
while paused - origination-only semantics, as committed in research. Where a
consumer applies the guard inside a multi-step workflow is the consumer's
decision and belongs with that workflow.

## Integration Patterns

One `data-dependencies` entry on the released DAR and one import. Nothing
transitive.

```yaml
data-dependencies:
  - path/to/openzeppelin-pausable-api-v1-0.1.0.dar
```

### Primary example: minimal adoption

```daml
module MyApp.Vault where

import OpenZeppelin.PausableV1

template Vault
  with
    admin   : Party
    owner   : Party
    balance : Decimal
    paused  : Bool
  where
    signatory admin, owner

    interface instance Pausable for Vault where
      view = PausableView with paused
      setPaused b = toInterface (this with paused = b)

    -- A gated operation. One line.
    choice Vault_Withdraw : ContractId Vault
      with amount : Decimal
      controller owner
      do
        whenNotPaused this
        assertMsg "Vault: amount exceeds balance" (amount <= balance)
        create this with balance = balance - amount

    -- Escape hatch: redemption to the admin stays legal while paused, so a
    -- pause does not trap the holder. XRPL's individual-freeze precedent.
    choice Vault_RedeemToAdmin : ContractId Vault
      controller owner
      do create this with balance = 0.0

    -- Legal only while paused.
    choice Vault_EmergencyDrain : ContractId Vault
      controller admin
      do
        whenPaused this
        create this with balance = 0.0

    -- The pause authority. Must be consuming.
    choice Vault_Pause : ContractId Vault
      controller admin
      do pause this

    choice Vault_Unpause : ContractId Vault
      controller admin
      do unpause this
```

Adoption cost: one template field, a three-line `interface instance`, one
`whenNotPaused` per gated choice, and two authority choices. Which operations
are gated is a per-choice decision, which is how the escape hatch and the
paused-only choice both come for free.

### Second example: sibling fields set in the same transaction

A registry serving CIP-0112 `pauseInfo` records the reason in the same
transaction as the flip. The lambda touches only the sibling fields; the library
sets the flag.

```daml
template Registry
  with
    admin       : Party
    paused      : Bool
    pauseReason : Optional Text    -- CIP-0112 pauseInfo.reason
    pauseUntil  : Optional Time    -- CIP-0112 pauseInfo.until
  where
    signatory admin

    interface instance Pausable for Registry where
      view = PausableView with paused
      setPaused b = toInterface (this with paused = b)

    choice Registry_Pause : ContractId Registry
      with
        reason : Optional Text
        until  : Optional Time
      controller admin
      do pauseWith (\v -> v with pauseReason = reason, pauseUntil = until) this

    choice Registry_Unpause : ContractId Registry
      controller admin
      do unpauseWith (\v -> v with pauseReason = None, pauseUntil = None) this
```

The metadata endpoint serves `paused` and `pauseInfo{reason, until}` from one
on-ledger contract, and none of that vocabulary is frozen into the interface. If
CIP-0112 extends `PauseInfo`, the registry adds a field under SCU and this
package does not move.

### Off-ledger reading

A reader queries the ACS or the update stream with an `InterfaceFilter` on
`OpenZeppelin.PausableV1:Pausable`, requesting the interface view. Every
implementing contract it can see returns a `PausableView`, whatever template or
registry produced it. One query shape across the ecosystem, which is the reason
the frozen interface earns its cost. The same applies on the HTTP JSON API via
interface filters.

A flip is an archive plus a create, so an ACS-delta subscriber sees the state
change with no event template and no `LEDGER_EFFECTS` subscription.

### Effects alongside a flip

The lambda is pure at `t -> t`. A consumer needing an effect uses their own
choice body, which sequences normally:

```daml
choice Vault_Pause : ContractId Vault
  controller admin
  do
    create PauseAudit with admin, reason
    pause this
```

### Atomic unpause-operate-pause needs one choice body

Canton has no PTB equivalent, and no value flows between commands in a single
Ledger API submission (`CreateAndExercise` is the only bridge on LF 2.1). A
maintenance window that must not be observable as unpaused has to be a single
choice that calls `unpause`, does the work, and calls `pause`. Three separate
commands are three windows.

## ensure and Runtime Checks

No `ensure` clauses - the package defines no templates.

| Condition | Mechanism | Constant |
|---|---|---|
| gated operation attempted while paused | `assertMsg` in `whenNotPaused` | `eEnforcedPause` |
| paused-only operation attempted while unpaused | `assertMsg` in `whenPaused` | `eExpectedPause` |
| `pause` when already paused | `whenNotPaused` inside `pauseWith` | `eEnforcedPause` |
| `unpause` when not paused | `whenPaused` inside `unpauseWith` | `eExpectedPause` |
| implementer ignored the flag argument, or the lambda clobbered it | `assertMsg` in `pauseWith` / `unpauseWith` | `eFlagNotApplied` |
| implementer returned another template | `fromSomeNote` in `pauseWith` / `unpauseWith` | `eImplementerTypeMismatch` |
| pause authority not authorized | ledger authorization - not expressible as a check | none |

`assertMsg` throughout rather than `failWithStatus`: the constants are exported
so consumers assert on them in their own tests, and this matches the existing
convention in `AccessControlV1` and `OwnableV1`. No user-defined exceptions -
Daml 3 deprecates them - so no `try` / `catch` and no rollback nodes.

**Three things nothing checks.** These are the design's known limitations and
they belong in the package README as well as in the Invariants stage.

1. **The guard is not mandatory.** No Daml construct forces a consumer's gated
   choice to call `whenNotPaused`, and a forgotten guard fails silently in the
   permitting direction. Documentation and tests carry this guarantee, not the
   type system. Solidity has the same limitation and at least makes the missing
   modifier visible in the signature; Daml offers no equivalent marker.
2. **The consumer's flip choice must be consuming.** `pauseWith` creates the
   successor and cannot archive the predecessor, because an interface method
   sees `this` but not `self`. A nonconsuming flip leaves two active contracts
   with different flags and no error. This is the Daml Finance `acquireImpl`
   pattern and carries the same obligation.
3. **Field preservation in `setPaused`.** The flag is verified by
   `eFlagNotApplied`; that every other field survived is not, and cannot be.

## Ledger Observability

No event template, and none is justified. A flip is an archive and a create on
the implementing contract, already a transaction-tree node carrying the actor
and the timestamp, delivered to every stakeholder. Nothing is transient, so an
ACS-delta subscriber sees the state change without a `LEDGER_EFFECTS`
subscription.

The audit record research asked for exists, but as state rather than as
rejections. A contract with `paused = True` was active over an interval bounded
by its create and its archive, and that is what establishes a pause was in force
at a given time. A refused operation commits nothing, so "operation X was
refused at time T" is not on the ledger and cannot be. State this plainly in the
README rather than leaving a reader to assume otherwise.

Transaction history is prunable, so flip events age out while the active
contract's state does not. A consumer needing durable pause history keeps their
own record.

A flip is visible to stakeholders of the implementing contract plus the
controller. Where the pause authority is a non-stakeholder, they see the
template payload at flip time.

## Design Decisions Log

1. **LF 2.1, no contract keys.** Keys are load-bearing only for the
   free-floating shape that is not shipped; in the authority-in-path shape the
   guard receives `this` and nothing is looked up. LF 2.3 would require Canton
   3.5 and protocol version 35, narrowing deployment reach, and would not have
   fixed canonical-instance selection anyway.

2. **Flag on the exercised contract, not archive-and-restore.** The dev proposed
   pausing by archiving the contract and restoring it on unpause. It was
   evaluated and rejected. It does solve the fail-open risk completely - an
   inactive contract rejects every exercise and fetch, with no guard to forget,
   and the ledger's activeness lookup is a positive check rather than an
   unprovable absence claim. It was rejected because: the wrapper template
   cannot be generic (Daml templates are monomorphic, `AnyTemplate` is not
   serializable, and a `Text` blob has no generic parser), so every consumer
   hand-writes a mirror template and keeps it in SCU lockstep; the pause leaves
   the ACS, breaking the CIP-0112 reporting duty that was research's most
   important finding, and reintroducing canonical-instance selection for
   whoever must find the wrapper; no escape hatch is possible, since nothing is
   exercisable; and the blast radius exceeds the committed origination-only
   semantics by killing unrelated read-only fetches. Daml Finance faced the same
   fork and put `lock` on `Account` rather than archiving it. The archive route
   is documented in the README as a pattern a consumer can build unaided, for
   the case that needs an absolute stop and no reporting.

3. **One module, not two.** The split into an interface module and a guards
   module was proposed, accepted, then reversed. The whole package is frozen, so
   the split is a readability boundary rather than an evolution boundary, and it
   would cost every consumer a second import to call one guard.

4. **Zero interface choices.** An interface choice needs a controller drawn from
   the view, and the view holds no party. This follows from the authority-free
   view rather than being an independent decision. It also means `pause` and
   `unpause` are ordinary functions, which is what allows them to be polymorphic
   in `t`.

5. **Removed the `Pausable_Paused` read choice** that the pre-design prototype
   carried. It had a flexible controller (`controller actor`), and informees of
   an exercise node see the input contract, so any party who learned a contract
   id could divulge the entire template payload to themselves - not just the
   flag. That is deliberate in the Canton documentation's `PriceQuotation_Fetch`,
   which exists to be read by non-stakeholders, but frozen into a
   general-purpose interface it is a hole every adopter inherits and, because
   interface choices are not upgradeable, can never remove. It also buys
   nothing: `isPaused this` answers the same question purely with no ledger
   node, and an off-ledger reader gets the flag from the interface view through
   an `InterfaceFilter` with no transaction at all. The only case the choice
   uniquely served was reading the flag of a contract the caller is not
   exercising, which is the free-floating shape that is not shipped. A consumer
   who wants such a getter adds it to their own template with a controller they
   choose.

6. **`setPaused : Bool -> Pausable`, pure, over a type class.** Three shapes
   were built and compiled. (A) the caller's lambda sets the flag and the
   library asserts it did; (B) a `class HasPausedField t where setPaused : Bool
   -> t -> t`, leaving the interface method-free; (C) a pure interface method
   returning the interface value, with `fromInterface` converting back. A spike
   proved typeclass definitions and instances survive a `data-dependencies`
   boundary on SDK 3.4.11 / LF 2.1, so B carried no toolchain risk. C was chosen
   on two grounds: one abstraction mechanism instead of two, everything the
   consumer writes inside a single `interface instance` block; and it matches
   the shape Daml Finance already established with `Lockable.acquire` /
   `releaseImpl`. The costs accepted are that B's compile-time proof becomes C's
   trust in an implementer law, and that a view-only adopter must supply a
   write path it never calls.

7. **`fromSomeNote`, not `case` / `abort` and not bare `fromSome`.** The
   `Optional` is inherent to C - an interface cannot name `t`, so
   `setPaused` must return `Pausable`, and any implementing template
   satisfies that type. This was confirmed against the compiler: a template
   whose `setPaused` returns a different implementer's value compiles
   cleanly. The failure is unreachable by a third party and is caught by the
   consumer's first test, so `fromSome` would be safe but uninformative at
   exactly the moment a developer has made the mistake. One exported constant
   buys the diagnosis.

8. **`pause` / `unpause` return `ContractId t`.** `create` returns the
   consumer's own template cid directly, so no coercion appears at the call
   site. This is why `HasFromInterface t Pausable` and `HasCreate t` are in the
   constraints. `setPaused` cannot do this - an interface declaration has no
   type variable for its implementer - which is the asymmetry that puts the
   flips in top-level functions.

   A consequence discovered while updating the tests, and not anticipated when
   this was chosen: `HasCreate t` means `pause` cannot be applied to a bare
   `Pausable` interface value at all, only to a concrete template. The previous
   shape compiled for a stranger holding a `ContractId Pausable` and failed at
   runtime for want of the target's signatory authority; now it does not
   compile. This forecloses nothing real. A flip needs the authority of the
   target's signatories, which only a choice on the target carries, and Daml has
   no way to `create` from an interface value in any case, so every flip has to
   reach a concrete template regardless. The read side stays fully generic -
   `isPaused` and `whenNotPaused` both accept a bare `Pausable`, verified
   against the compiler. Reads are polymorphic, writes are concrete, and the
   constraint states in the signature what the authorization model already
   required.

9. **`pauseWith` / `unpauseWith` for sibling fields.** Without them, a registry
   setting `reason` in the same transaction has to bypass the guarded flip
   entirely and hand-write `whenNotPaused` plus its own `create`. With them the
   case we care most about goes through the library rather than around it. The
   lambda is pure at `t -> t`; effects belong in the consumer's choice body.

10. **`eFlagNotApplied` assert.** Because the library sets the flag by calling
    the implementer's method, an implementer that ignores the argument
    (`setPaused _ = toInterface this`) compiles and yields a pause that
    silently does not pause - research's top risk, a control that only looks
    like a control. The lambda can clobber the flag the same way. One pure
    assert after both steps closes both holes.

11. **One `eFlagNotApplied` rather than `ePauseNotApplied` /
    `eUnpauseNotApplied`.** The flip direction is evident from the choice the
    consumer called, and the frozen surface stays smaller.

12. **Guards read the exercised contract, never a caller-supplied cid.** A guard
    over a separately-fetched state contract is unsound: an adversarial caller
    substitutes or omits it. No guard in this package accepts a `ContractId`.

13. **Authority freedom stated widely, not narrowed.** The README says any
    nameable party works, with the payload-disclosure caveat as guidance. A
    normative "must be a signatory or observer" would forbid the role-based
    pattern, where `caller` is neither.

14. **`whenPaused` and `eExpectedPause` kept.** `unpause` needs the check, and a
    named exported constant lets a consumer's tests assert on the failure rather
    than matching a string. An emergency-withdrawal-only or recovery choice is a
    standard shape, not a speculative one.

15. **The implementer method is named `setPaused`, not `setPausedImpl`.** The
    `...Impl` suffix is not the Daml convention for an interface method. Daml
    Finance names methods plainly - `Lockable.acquire`, `Fungible.I.split`,
    `Account.I.credit` - and reserves `...Impl` for the shared default
    implementation helpers in its util package, which an instance body
    delegates to. The suffix would have said something useful here, since
    unlike `acquire` this method is not the caller-facing path, but it sat
    beside an exported function also called `setPaused` and the pair was
    confusing. The exported `setPaused` was removed and its two-line downcast
    inlined into `pauseWith` and `unpauseWith`, which drops the surface from
    fifteen exports to fourteen and leaves one name meaning one thing.

16. **Verified against the compiler during design.** The module and both worked
    examples build on SDK 3.4.11 with `--target=2.1`, and the examples build
    across a `data-dependencies` boundary on the produced DAR.

## Out of Scope

- **Bounded pause and `until` evaluation.** Publishing `until` is reporting;
  enforcing it is a separate feature that raises who may extend a pause and
  whether expiry needs its own transaction. Keeping ledger time out of the guard
  leaves both questions unasked. A consumer wanting an expiring pause writes it.
- **Targeted per-holder freeze and issuer forced actions.** Every RWA standard
  surveyed bundles these with pause, and every one keeps them as separate
  capabilities with separate authority. Scoped out as separate components; this
  design only ensures the interface does not foreclose them.
- **The free-floating shared-switch template.** A single switch shared across
  several templates is not shipped. A consumer needing one builds it on
  `Pausable`: a single-field template implementing the interface, fetched and
  guarded by the protected operations, with their own binding check that the
  switch presented is the expected one. The README carries the caveats -
  canonical-instance selection is the operator's responsibility, and the pauser
  becomes an informee of every read.
- **The archive-and-restore shape.** Rejected as a package (decision 2),
  documented as a pattern.
- **CIP-0112 field mirroring in the view.** The view carries `paused` only. A
  registry holds `reason` and `until` as its own fields.
- **Pause authority.** No `Ownable`, `AccessControl`, timelock, or M-of-N
  authority ships here. Composition happens in the consumer, by reference, not
  by dependency.
- **An on-ledger record of refused operations.** A rejected transaction commits
  nothing. The ledger records the pause state over an interval, not the
  individual refusals.
- **Contract keys.** Not compiled on LF 2.1, and they would not provide the
  uniqueness that would make them useful here.
- **Test design.** `test/pausable-api-v1` was brought into conformance with this
  design and its fixtures now cover the whole surface (see Dev Notes), but
  choosing what a complete suite must prove is the Tests stage's job. The
  invariant-to-test mapping does not exist yet.
- **The DAR release surface.** `daml.yaml` version and manifest identity, and
  the `dars/manifest.yaml` entry, are downstream of this stage.

## Dev Notes

The design was produced greenfield at the dev's explicit instruction, ignoring
the `packages/security/pausable-api-v1` and `test/pausable-api-v1` directories
that already existed on disk and were listed in `multi-package.yaml`. Those
predate this design. After the artifact was written, the dev asked for the
existing package and its test package to be brought into conformance with it;
those edits are a consequence of this design, not an input to it.

Both packages now conform. `dpm build --all` succeeds, `scripts/check.sh`
reports OK, both packages lint with no hints, and all 21 scripts in
`test/pausable-api-v1` pass. The test fixtures cover the full surface, including
the three routes to `eFlagNotApplied`, the `eImplementerTypeMismatch` path, the
unenforceable consuming-choice obligation, and the sibling-field flips.

Two things the coverage report flags that are expected: `Decoy` is never created
on the ledger because it is only constructed inside `BrokenWrongTemplate`'s
`setPaused`, and the three deliberately broken choices show as never exercised
because their submissions abort before any exercise commits.

`test/pausable-api-v1` carries a pre-existing deprecation warning on
`submitWithDisclosuresMustFail`, inherited from the prototype test suite and
left in place. The Tests stage should move to `submitMustFail` with `disclosures`
supplied separately.

Verification spikes from the design conversation are in the session scratchpad
under `spike/` and `final/`. They are not part of the repository.

## Open Questions

1. **The three unchecked properties need INV entries and negative tests.** The
   guard being optional, the consuming-choice obligation, and field preservation
   in `setPaused`. The first two are the ones that can silently produce a
   pause that does not hold.

2. **Resolved: the deliberately wrong implementers live in the test package.**
   `test/pausable-api-v1` carries `BrokenIgnoresFlag`, which ignores
   `setPaused`'s argument, and `BrokenWrongTemplate`, which returns a `Decoy`
   instead of itself. Both compile, and both fail at runtime with
   `eFlagNotApplied` and `eImplementerTypeMismatch` respectively. `Registry`
   additionally carries a choice whose lambda clobbers the flag, covering the
   third route to `eFlagNotApplied`. The Tests stage inherits these fixtures
   rather than deciding whether to build them.

3. **Resolved: the nonconsuming-flip bug is asserted executably.** `LeakyVault`
   has a `nonconsuming` pause choice, and
   `test_nonconsumingFlipLeavesTwoContracts` shows the original and the
   successor both active, one unpaused and one paused, with no error. It
   asserts a defect in consumer code rather than a property of this package,
   which is the point - the obligation is unenforceable, so the test is the
   only executable statement of it. It stays in the test suite and is also
   documented on `pauseWith` and in the README.

4. **Package version and release identity.** `0.1.0` and unstable, or a version
   that signals the frozen surface is final? The interface cannot change after
   the first release that consumers build against, so the point at which the
   package claims stability matters more here than for a template package.
