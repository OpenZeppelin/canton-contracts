# Blocklist V1

An account blocklist for Daml applications. A designated blocker party blocks
and unblocks parties, and the guards make a choice fail when it moves value
from or to a blocked party.

| Field | Value |
|---|---|
| Package | `openzeppelin-blocklist-v1` |
| Public module | `OpenZeppelin.BlocklistV1` |
| Version | `0.1.0` |
| Depends on | `splice-api-token-metadata-v1` `1.0.0` (the `ChoiceContext` type) |
| Status | Pre-release; unaudited |

## What it provides

- `Blocklist`: the template that holds the blocked set of one application.
  The admin signs it. The blocker observes it and exercises
  `Blocklist_Block` and `Blocklist_Unblock`, each of which takes a list of
  parties. The admin exercises `Blocklist_SetBlocker` to give the blocker
  role to another party.
- `fetchBlocklist`: fetches a caller-supplied `Blocklist` and fails unless
  its admin and id are the ones your template expects.
- `fetchBlocklistFromContext`: the same check for a blocklist contract id
  that arrives in a Splice `ChoiceContext` under `blocklistContextKey`
  (`blocklist`).
- `whenNotBlocked`: the guard a choice calls for each party it debits or
  credits. `isBlocked` returns the same check as a `Bool`.
- `blockedKey`: the digest that represents a party in the blocked set.
- `eAccountBlocked`, `eAdminNotBlockable`, `eBlocklistFull`,
  `eWrongBlocklist`, and `eBlocklistMissing`: the failure statuses. Each has
  a stable `errorId` under `openzeppelin.com/blocklist-`, so an off-ledger
  client matches the id in the `DAML_FAILURE` error, and your tests compare
  the whole value.

`OpenZeppelin.BlocklistV1.Internal` is not public API. Its contents can change
in any version, so do not import it.

## Usage

**1. Create the blocklist.** The admin creates one `Blocklist` per `id`, with
an empty set, the blocker party, and the largest set it accepts (see
[Privacy and cost](#privacy-and-cost)):

```daml
import qualified DA.Set as Set
import OpenZeppelin.BlocklistV1

blocklistCid <- create Blocklist with
  admin = issuer
  blocker = complianceParty
  id = "my-token"
  blocked = Set.empty
  maxEntries = 5000
```

**2. Guard every choice that moves value.** The choice takes the blocklist
contract id from its caller, pins it with `fetchBlocklist`, and calls
`whenNotBlocked` for the party it debits and the party it credits, before the
state change. Take the expected admin and id from the contract the choice
runs on, never from the caller:

```daml
    choice Asset_Transfer : ContractId Asset
      with
        newOwner : Party
        blocklistCid : ContractId Blocklist
      controller owner
      do
        blocklist <- fetchBlocklist issuer "my-token" blocklistCid
        whenNotBlocked blocklist owner
        whenNotBlocked blocklist newOwner
        create this with owner = newOwner
```

A choice that receives `ExtraArgs` calls
`fetchBlocklistFromContext issuer "my-token" extraArgs.context` instead.

The fetch needs the authority of a stakeholder of the blocklist, so call it
from a choice on a contract that the admin signs. The submitter is usually
not a stakeholder: the admin gives the blocklist to it as an explicit
disclosure, the same way it gives other shared contracts.

**3. Block and unblock.** The blocker exercises the choices with a list of
parties. A party that is already in the target state, or that the list names
twice, is skipped, so a synchronization job can send the whole screening list
each time. When the set changes, the call archives the contract and returns
the successor; otherwise the contract stays active and the call returns its
id. A call is atomic: when one listed party fails a check, no party changes
state.

```daml
blocklistCid' <- exercise blocklistCid Blocklist_Block with
  accounts = [alice, bob]
  reason = "case-1"
```

**4. Assert on the failure statuses in your tests.** A guarded choice that
debits or credits a blocked party fails with `eAccountBlocked` for that
party:

```daml
Left (FailureStatusError status) <-
  trySubmit (actAs alice <> discloseMany [blocklistDisclosure]) do
    exerciseCmd asset Asset_Transfer with newOwner = bob; blocklistCid
status === eAccountBlocked alice
```

## CIP-0112 integration

The key is a party. A CIP-0112 account has an `owner`, an optional
`provider`, and an `id`. Check the owner and the provider of each account:
the owner chooses the `id` freely, so a block on an account `id` does not
hold, and a blocked provider blocks every account it provides. The CIP-0112
mint and burn accounts have neither, so a mint or a burn checks the holder's
side only.

A token standard interface choice takes no blocklist argument. The
registry's off-ledger API supplies the blocklist contract id in the choice
context under `blocklistContextKey`, together with the contract as a
disclosure, and the choice body reads it with `fetchBlocklistFromContext`. A
context without the blocklist fails with `eBlocklistMissing`, so a caller
cannot skip the check by leaving it out.

The checks run when value moves between accounts:

| Path | Accounts checked |
|---|---|
| Transfer factory, one step or two steps, including a burn | Sender and receiver |
| Accept of a pending transfer, mint offer, or burn request | Sender and receiver |
| Allocation factory | Authorizer and the other side of every leg |
| Settlement factory | Every leg and every authorizer |
| `Allocation_Settle`, from the factory or direct | Authorizer and the other side of every leg |
| Withdraw, reject, cancel, admin expiry, owner unlock | None |

The last row returns locked funds to the account that locked them, so it
stays open for a blocked account. The funds stay in that account, and every
later transfer from it is refused.

An allocation committed before a block does not settle while the block holds.
CIP-0112 states the exception in section 4.3.8, item 4: "it's acceptable to
fail settlement if a trading account was added to a blocklist." The
authorizer can withdraw the allocation after its settlement deadline, as
section 4.3.3 asks, and the executors can cancel it before then.

The settlement factory passes the blocklist to each allocation's settle
through the context argument of `settleBatchImpl` in
`openzeppelin-token-cip112-utils`.
[`examples/token/token-cip112-custom`](../../../examples/token/token-cip112-custom/)
implements every row of the table.

## Authority and lifecycle

- The blocker blocks and unblocks. Any party can hold the role, including an
  external party whose submissions need a threshold of its signing keys. The
  topology enforces the threshold, so the template has no multi-signature
  logic. The `external-blocker` suite of `scripts/check-sandbox.sh` checks a
  blocker that needs two of three keys.
- A key rotation of the blocker is a topology change of that party and
  leaves the blocklist unchanged.
- The admin gives the role to another party with `Blocklist_SetBlocker`, in
  one step, with a `reason` for the audit trail. The blocker observes the
  contract and does not sign it, so the new blocker's consent adds no
  authority, and the admin corrects a wrong party with another
  `Blocklist_SetBlocker`. The blocked set carries over, and the previous
  blocker loses the role and its view of later changes.
- The choices read no pause flag, so block and unblock work while the
  application is paused.
- Block refuses the admin and a set larger than `maxEntries`. The `ensure`
  clause holds both rules on every contract, also one that the admin creates
  directly.

## Audit

Each block, unblock, or role change is an exercise on the blocklist. The
Ledger API update carries the choice name, the argument (the parties and the
`reason`), the acting party, and the ledger effective time. A call that
changes the set also archives the contract and creates its successor. An
indexer that reads the update stream of the admin or the blocker
reconstructs who was blocked or unblocked, by which blocker, and when. The
contract itself holds the current set only.

## Privacy and cost

The set holds `blockedKey` digests: the unsalted SHA-256 of each party's text
form. A digest keeps the party id out of the contract payload. It does not
keep a party's blocked status confidential.

| Party | What it can learn |
|---|---|
| Admin | The set, its history with parties and reasons, and every guarded transaction that it signs |
| Blocker | The blocklist and its history, with parties and reasons. A guard reads the blocklist with a `fetch`, whose informees are the signatories and the acting parties, so the guarded transactions do not reach the blocker |
| A submitter of a guarded transaction, and every other informee of the view that holds the fetch | The digest set at that time: its size, and the blocked status of every party id that it knows. Successive disclosures show which digests were added and removed, and when |
| A holder of the digest set and a list of party ids, such as a participant's party list or the topology state | Which of those parties are blocked: the digest is unsalted |
| A reader of the blocklists of two applications | Which parties both block: a party has the same digest in every blocklist |

A change archives the blocklist and creates it again, so its transaction
carries the set twice. A guarded transaction fetches it and carries it once.
Each copy is about 74 bytes per entry: a block of 75,000 entries produced a
view of 11,103,144 bytes. A guarded transaction therefore grows by about 74
bytes per entry, and its sequencer traffic grows with it. On a local Canton
sandbox with the default maximum request size of 10 MiB:

| Entries | Guarded transfer | Block |
|---|---|---|
| 1,000 | 0.42 s | 0.38 s |
| 10,000 | 0.38 s | 0.54 s |
| 25,000 | 0.58 s | 0.74 s |
| 50,000 | 0.85 s | 1.51 s |
| 75,000 | 0.92 s | refused: view too large |

Set `maxEntries` from both limits:

- Request size: at most one entry per 200 bytes of the synchronizer's
  maximum request size. Above that size no change fits, not even an unblock.
- Traffic: each guarded transaction pays about 74 bytes per entry. At 1,000
  entries that is about 74 KB per transfer; at 10,000 entries, about 740 KB.
  Choose the largest set whose cost per transfer your traffic budget accepts.

## Scope and security caveats

- A choice is guarded only by its own calls. Call `whenNotBlocked` for every
  party that a choice debits or credits, in every choice that moves value.
- There is no contract key, so `fetchBlocklist` accepts any active
  `Blocklist` with the expected admin and id. The admin is trusted to keep one
  active contract per id. The admin can also archive the blocklist and create
  it again with any set or blocker, outside the choices. Make the admin part
  of your compliance trust model.
- The admin cannot be blocked, so an account that the admin owns, such as a
  treasury or fee account, cannot be blocked either. The blocker's authority
  ends at the admin: the admin is trusted with the accounts it owns.
- If the admin archives the blocklist, every guarded choice fails, because
  the fetch finds no active contract.
- Each change replaces the contract, so a guarded transaction that was
  prepared against the predecessor fails, and its submitter retries with the
  successor. Send the changes of one list update in one call.
- Every guarded transaction carries the whole set. See
  [Privacy and cost](#privacy-and-cost).
- The blocklist restricts value movement only. Moving the funds of a blocked
  party to another account is out of scope.

## Compatibility

Daml-LF `2.1`, built with the SDK that
[`multi-package.yaml`](../../../multi-package.yaml) declares. The package
defines no interface or exception, so it is one Smart Contract Upgrade (SCU)
lineage. A later version can add `Optional` fields to `Blocklist` and change
the guards. The `errorId` of every failure status is stable across versions.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/security/blocklist-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/dars/vendor/splice-api-token-metadata-v1-1.0.0.dar
  - ../canton-contracts/packages/security/blocklist-v1/.daml/dist/openzeppelin-blocklist-v1-0.1.0.dar
```

```daml
import OpenZeppelin.BlocklistV1
```

[`examples/token/token-cip112-custom`](../../../examples/token/token-cip112-custom/)
is a CIP-0112 registry that checks every value-moving path against a
blocklist.

## License

The package source is licensed under the repository's MIT
[`LICENSE`](../../../LICENSE). The DAR bundles `splice-api-token-metadata-v1`
from [`dars/vendor/`](../../../dars/vendor/) as a compiled DALF, licensed under
the Apache License 2.0
([`LICENSES/Apache-2.0.txt`](../../../LICENSES/Apache-2.0.txt)).
[`RELEASING.md`](../../../RELEASING.md) describes the license files that a
release attaches.
