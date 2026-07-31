# Pausable V1

A pauser-controlled state contract and guard functions for temporarily blocking
application operations.

| Field | Value |
|---|---|
| Package | `openzeppelin-pausable-v1` |
| Public module | `OpenZeppelin.Pausable.V1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Solidity analogue | `Pausable` |

> [!WARNING]
> `PauseState` is not intrinsically bound to an application resource and the
> package cannot enforce that a presented state is the unique current state.
> Applications must define canonical-state selection, resource binding, and
> disclosure for every protected operation.

## What it provides

- `PauseState`: a pauser-signed state contract.
- `PauseState_Set`: archives the current state and creates its replacement.
- `PauseState_Get`: reads the current flag.
- `whenNotPaused` and `isPaused`: guards for fetched state values.

The package is deliberately keyless for Daml-LF 2.1. A consuming choice should
receive or discover the current `PauseState` contract ID, fetch it, and apply the
guard. It should not retain a stale contract ID across state transitions.

## Authority and lifecycle

- The pauser signs and controls `PauseState`.
- A state change consumes the old contract and returns a new contract ID.
- Redundant transitions fail.
- Direct archival is controlled by the pauser and leaves no replacement state.
- The consuming application is responsible for binding the state to the correct
  resource and making the authoritative contract visible to the caller.

## Build and test

From the repository root:

```sh
dpm build --all
cd test/pausable-v1
dpm test
```

The test package is not a release artifact and must not be uploaded to a
production participant.

## Consume a local build

```yaml
data-dependencies:
  - /absolute/path/to/canton-contracts/packages/security/pausable-v1/.daml/dist/openzeppelin-pausable-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Pausable.V1
```
