# Blocklist V1 tests

Daml Script tests for
[`openzeppelin-blocklist-v1`](../../packages/security/blocklist-v1/). The
package is never released.

| Module | Runs under | Covers |
|---|---|---|
| `OpenZeppelin.BlocklistV1Test` | `dpm test` | Every choice and guard, the `ensure` clause, the role controls, the context form, and the privacy and audit properties, through the consumer `Asset` in `OpenZeppelin.BlocklistV1TestFixtures` |
| `OpenZeppelin.BlocklistV1SandboxTest` | `OZ_SANDBOX_SUITE=blocklist scripts/check-sandbox.sh` | The same tests against a Canton sandbox over the Ledger API |
| `OpenZeppelin.BlocklistV1ExternalBlockerTest` and `canton/*.canton` | `OZ_SANDBOX_SUITE=external-blocker scripts/check-sandbox.sh` | A blocker that is an external party with a two-of-three signing-key threshold |

## External blocker suite

The suite runs seven steps against the script-managed sandbox:

1. `canton/onboard-external-blocker.canton` generates three Ed25519 key pairs
   and onboards a party whose `PartyToParticipant` mapping needs two of the
   three keys.
2. `setupExternalBlocker` creates a blocklist whose blocker is that party.
3. `canton/block-as-external-blocker.canton` blocks a party through
   interactive submission. A submission without signatures, with one
   signature, and with two signatures by the same key are each refused, and
   the suite requires the reason that the participant reports for each.
4. Two signatures by distinct keys block the party.
5. `checkExternalBlocker` checks the blocked set and that the guard refuses
   the blocked party.

The suite validates that the topology enforces the signing threshold on the
blocker's submissions. It imports the three key pairs into the participant,
so that the participant can sign the onboarding topology transactions, and
writes the private keys to the suite's log directory under `.cache/`. It
does not validate key custody away from the participant: a production
external party keeps its keys outside the participant and signs the
onboarding transactions itself.

The suite drives the sandbox with `dpm canton-console`, which connects to the
default sandbox ports, so it runs only on the script-managed sandbox.
