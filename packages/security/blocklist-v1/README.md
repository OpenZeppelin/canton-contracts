# Blocklist V1

An account blocklist for Daml applications. A designated blocker party blocks
and unblocks parties, and the guards make a choice fail when it debits or
credits a blocked party.

| Field | Value |
|---|---|
| Package | `openzeppelin-blocklist-v1` |
| Public module | `OpenZeppelin.BlocklistV1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `Blocklist`: the template that holds the blocked set of one application.
  The admin signs it. The blocker observes it and exercises
  `Blocklist_Block` and `Blocklist_Unblock`, each of which changes a list of
  parties in one transaction. The admin exercises `Blocklist_SetBlocker` to
  give the blocker role to another party.
- `fetchBlocklist`: fetches a caller-supplied `Blocklist` and fails unless
  its admin and id are the ones your template expects.
- `whenNotBlocked`: the guard a choice calls for each party it debits or
  credits. `isBlocked` returns the same check as a `Bool`.
- `blockedKey`: the digest that represents a party in the blocked set.
- `blocklistContextKey`: the key `blocklist`, under which an application that
  passes `ExtraArgs` to its choices supplies the blocklist contract id.
- `eAccountBlocked`, `eAlreadyBlocked`, `eNotBlocked`, `eAdminNotBlockable`,
  `eNoAccounts`, `eBlocklistFull`, and `eWrongBlocklist`: the failure
  statuses. Each has a stable `errorId`
  under `openzeppelin.com/blocklist-`, so an off-ledger client matches the id
  in the `DAML_FAILURE` error, and your tests compare the whole value.

`OpenZeppelin.BlocklistV1.Internal` is not public API. Its contents can change
in any version, so do not import it.

## Usage

**1. Create the blocklist.** The admin creates one `Blocklist` per `id`, with
an empty set, the blocker party, and the largest set it accepts (see
[Size](#size)):

```daml
import qualified DA.Set as Set
import OpenZeppelin.BlocklistV1

blocklistCid <- create Blocklist with
  admin = issuer
  blocker = complianceParty
  id = "my-token"
  blocked = Set.empty
  maxEntries = 10000
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

The fetch needs the authority of a stakeholder of the blocklist, so call
`fetchBlocklist` from a choice on a contract that the admin signs. The
submitter is usually not a stakeholder: the admin gives the blocklist to it
as an explicit disclosure, the same way it gives other shared contracts.

**3. Block and unblock.** The blocker exercises the choices with one party
or with a list, such as one update of a screening list. A change is atomic:
when one listed party fails a check, no party changes state. Each change
replaces the contract, so clients take the successor id and disclosure:

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

A token standard interface choice takes no blocklist argument. The registry's
off-ledger API supplies the blocklist contract id in the choice context
(`ExtraArgs.context`) under `blocklistContextKey`, together with the contract
as a disclosure, and the choice body reads it from there. A context without the blocklist fails, so a
caller cannot skip the check by leaving it out.

The checks run at the time value moves:

| Path | Accounts checked |
|---|---|
| Transfer factory, one step or two steps, including a burn | Sender and receiver |
| Accept of a pending transfer, mint offer, or burn request | Sender and receiver |
| Allocation factory | Authorizer and the other side of every leg |
| Settlement factory | Sender and receiver of every leg, and the authorizer of every allocation |
| Withdraw of a transfer or an allocation, also after the settlement deadline, and owner unlock of an expired lock | The account that unlocks its own funds |
| Reject, cancel, admin expiry | None: each returns locked funds to the account that locked them |

An allocation committed before a block does not settle while the block holds.
CIP-0112 states the exception in section 4.3.8, item 4: "it's acceptable to
fail settlement if a trading account was added to a blocklist." The executors
can cancel such an allocation, and the admin can expire it, which returns the
funds to the authorizer's account.

A blocked account takes no action on its own holdings, so a blocked
authorizer cannot withdraw a committed allocation after its settlement
deadline either. Section 4.3.3 asks that the authorizer can withdraw then.
The funds still leave the lock at the deadline: the registry's allocation
expiry is never later than the settlement deadline, and the admin's expiry
returns them to the authorizer's account.
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
  one step. The blocker observes the contract and does not sign it, so the
  new blocker's consent adds no authority, and the admin corrects a wrong
  party with another `Blocklist_SetBlocker`. The blocked set carries over,
  and the previous blocker loses the role and its view of later changes.
- The choices read no pause flag, so block and unblock work while the
  application is paused.
- Block refuses an empty list, a party that is already blocked or listed
  twice, the admin, and a set larger than `maxEntries`. Unblock refuses an
  empty list and a party that is not blocked or is listed twice.

## Audit

Each change is a consuming exercise on the blocklist. The Ledger API update
carries the choice name, the argument (the parties and the `reason`), the acting
party, and the ledger effective time. An indexer that reads the update stream
of the admin or the blocker reconstructs who was blocked or unblocked, by
which blocker, and when. The contract itself holds the current set only.

## Size

A change archives the blocklist and creates it again, so its transaction
carries the set twice, about 150 bytes per entry. A guarded transaction
fetches it and carries it once. On a local Canton sandbox with the default
maximum request size of 10 MiB:

| Entries | Guarded transfer | Block |
|---|---|---|
| 1,000 | 0.42 s | 0.38 s |
| 10,000 | 0.38 s | 0.54 s |
| 25,000 | 0.58 s | 0.74 s |
| 50,000 | 0.85 s | 1.51 s |
| 75,000 | 0.92 s | refused: the view of 11,103,144 bytes exceeds the maximum request size |

Above that size an unblock fails too, so `Blocklist_Block` refuses a set
larger than `maxEntries`. Set `maxEntries` from the maximum request size of
your synchronizer, at no more than one entry per 200 bytes of it.

## Privacy

- The blocker observes the blocklist and nothing else. A guard reads the
  blocklist with a `fetch`, whose informees are the signatories and the
  acting parties, so the guarded transactions do not reach the blocker. The
  blocker needs no view of holdings or balances to block a party.
- Each party that submits a guarded transaction receives the blocklist by
  disclosure. The set holds `blockedKey` digests (SHA-256 of the party's text
  form), so such a party can test a party it knows, but cannot list the
  blocked parties.
- The `reason` of a change is in the exercise argument only, which the admin
  and the blocker see.

## Scope and security caveats

- A choice is guarded only by its own calls. Call `whenNotBlocked` for every
  party that a choice debits or credits, in every choice that moves value.
- There is no contract key, so `fetchBlocklist` accepts any active
  `Blocklist` with the expected admin and id. The admin is trusted to keep one
  active contract per id. The admin can also archive the blocklist and create
  it again with any set or blocker, outside the choices. Make the admin part
  of your compliance trust model.
- If the admin archives the blocklist, every guarded choice fails, because
  the fetch finds no active contract.
- Each change replaces the contract, so a guarded transaction that was
  prepared against the predecessor fails, and its submitter retries with the
  successor. Batch the changes of one list update into one block or unblock.
- Every guarded transaction carries the whole set. See [Size](#size).
- An admin who creates the blocklist directly can store a set larger than
  `maxEntries`. Only `Blocklist_Block` enforces the limit.
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
  - ../canton-contracts/packages/security/blocklist-v1/.daml/dist/openzeppelin-blocklist-v1-0.1.0.dar
```

```daml
import OpenZeppelin.BlocklistV1
```

[`examples/token/token-cip112-custom`](../../../examples/token/token-cip112-custom/)
is a CIP-0112 registry that checks every value-moving path against a
blocklist.
