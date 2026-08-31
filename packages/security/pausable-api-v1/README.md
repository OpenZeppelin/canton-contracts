# Pausable API V1

Frozen Daml interfaces that give a template an emergency-stop switch, modelled
on OpenZeppelin's `Pausable.sol`.

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-api-v1` |
| Public module | `OpenZeppelin.PausableV1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Solidity analogue | `Pausable` |

## What it provides

Two interfaces. `Pausable` is the read side and carries no authority:

- `PausableView`: the flag.
- `Pausable_Paused`: the `paused()` getter, callable by any party that sees the
  contract.
- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: `paused()` as a pure function, for a choice that branches on the
  flag rather than refusing to run.

`PausableAdmin` is the optional write side, for a template whose pause authority
is a single party. It `requires Pausable`, so the compiler rejects an
implementation that omits the core interface:

- `PausableAdminView`: the pause authority.
- `PausableAdmin_Pause` and `PausableAdmin_Unpause`.
- `setPausedImpl`: the implementer's one obligation, which re-creates the
  contract with the new flag and every other field unchanged.

The package defines no templates, so it carries no ledger state of its own. The
flag lives on the implementing template, which is what binds the switch to the
resource it protects.

## Which interfaces to implement

Implement `Pausable` always. Implement `PausableAdmin` only when your pause
authority really is one party.

A single `Party` cannot express a role grant, an M-of-N approval, or a timelock,
and a Daml controller expression is pure, so it cannot fetch a credential to
decide who may act. Authority of that kind belongs in a choice body, which means
the choice needs the caller and the credential as arguments. Write your own
choice in that case:

```daml
choice TokenRules_Pause : ContractId TokenRules
  with caller : Party; grantCid : ContractId RoleGrant
  controller caller
  do
    grant <- fetch grantCid
    requireRole caller "PAUSER_ROLE" admin grant
    whenNotPaused this
    create this with paused = True
```

Do not implement `PausableAdmin` with a placeholder `pauser`. Its choices really
work for whatever party you name, so a misleading value publishes a false claim
about who holds the switch and opens a second path to it.

## Authority and lifecycle

- `Pausable` grants no authority and changes no state.
- `PausableAdminView.pauser` is the only party that may use
  `PausableAdmin_Pause` and `PausableAdmin_Unpause`.
- Both are consuming. They archive the current contract and create its successor
  through `setPausedImpl`.
- Pausing while paused fails, and unpausing while unpaused fails, matching
  `_pause` and `_unpause` in Solidity.
- A flip archives the contract, so outstanding contract IDs and disclosures for
  it go stale. Callers re-read the contract after a pause or an unpause.

## Scope and security caveats

- This is a switch per contract. Pausing several templates at once means one
  flag on each, or a single contract that all the protected operations are
  exercised on.
- Pause is origination control. A gated choice refuses to start while paused;
  transactions already committed are unaffected, and a flip rejects the
  concurrent operations that were reading the contract.
- The interfaces constrain the pause authority only. They do not restrict who
  may call the choices that `whenNotPaused` guards, and nothing forces a choice
  to call a guard at all.
- `PausableAdminView` publishes `pauser` to every party who can see the
  contract.
- CIP-0112's `pauseInfo` fields are deliberately absent. A registry that must
  serve `reason` and `until` on its metadata endpoint carries them as its own
  template fields beside `paused`, so the whole response still comes from one
  on-ledger contract without freezing those fields into a frozen interface.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/security/pausable-api-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/security/pausable-api-v1/.daml/dist/openzeppelin-pausable-api-v1-0.1.0.dar
```

```daml
import OpenZeppelin.PausableV1
```
