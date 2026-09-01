# Pausable API V1

A frozen Daml interface that gives a template an emergency-stop switch, modelled
on OpenZeppelin's `Pausable.sol`.

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-api-v1` |
| Public module | `OpenZeppelin.PausableV1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Solidity analogue | `Pausable` |

## What it provides

One interface, `Pausable`, which names no pause authority:

- `PausableView`: the flag.
- `Pausable_Paused`: the `paused()` getter, callable by any party that sees the
  contract.
- `whenNotPaused` and `whenPaused`: the guards a gated choice calls.
- `isPaused`: `paused()` as a pure function, for a choice that branches on the
  flag rather than refusing to run.
- `pause` and `unpause`: the `_pause()` and `_unpause()` analogues. Each checks
  the guard and re-creates the contract with the new flag.
- `setPausedImpl`: the implementer's one obligation, which re-creates the
  contract with the new flag and every other field unchanged.

The package defines no templates, so it carries no ledger state of its own. The
flag lives on the implementing template, which is what binds the switch to the
resource it protects.

## Authority and lifecycle

The interface ships no access control, exactly as `_pause()` and `_unpause()`
are `internal` in Solidity. You write the choice that decides who may flip the
switch, and the interface supplies the flip and the guard:

```daml
interface instance Pausable for Vault where
  view = PausableView with paused
  setPausedImpl newPaused =
    toInterfaceContractId <$> create this with paused = newPaused

choice Vault_Pause : ContractId Pausable
  controller admin
  do
    pause this
```

Any authority model fits, because the check runs in the choice body rather than
in a controller expression. A Daml controller expression is pure, so it cannot
fetch a credential to decide who may act; a role, an M-of-N approval, or a
timelock therefore takes the caller and the credential as choice arguments:

```daml
choice TokenRules_Pause : ContractId Pausable
  with caller : Party; grantCid : ContractId RoleGrant
  controller caller
  do
    grant <- fetch grantCid
    requireRole caller "PAUSER_ROLE" admin grant
    pause this
```

- Your pause choice must be **consuming**. `pause` creates the successor
  contract but archives nothing, because only the consuming choice archives the
  contract it runs on. A `nonconsuming` pause choice leaves the unpaused
  contract live beside its paused copy.
- Pausing while paused fails with `eEnforcedPause`, and unpausing while unpaused
  fails with `eExpectedPause`, matching `_pause` and `_unpause` in Solidity.
- A flip archives the contract, so outstanding contract IDs and disclosures for
  it go stale. Callers re-read the contract after a pause or an unpause.
- `setPausedImpl` is a public interface method, but it creates the successor
  contract and so needs the implementing template's signatory authority. A
  choice on an unrelated contract does not carry that authority, so it cannot
  flip another template's flag.

## Scope and security caveats

- This is a switch per contract. Pausing several templates at once means one
  flag on each, or a single contract that all the protected operations are
  exercised on.
- Pause is origination control. A gated choice refuses to start while paused;
  transactions already committed are unaffected, and a flip rejects the
  concurrent operations that were reading the contract.
- The interface does not restrict who may call the choices that `whenNotPaused`
  guards, and nothing forces a choice to call a guard at all.
- `setPausedImpl` must preserve every field other than the flag. Nothing in the
  type checks this, so a wrong implementation silently rewrites contract state
  on every pause.
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
