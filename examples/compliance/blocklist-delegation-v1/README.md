# Blocklist delegation V1

An issuer runs a CIP-0112 token with an account blocklist and lets several
compliance parties block and unblock accounts. Each party acts alone. The
issuer decides who holds the right, for which operation, and for how long, and
takes the right back at any time.

The package uses `openzeppelin-blocklist-v1` and
`openzeppelin-scoped-authorization-grant-v1` as they are, through
`data-dependencies`.
[`Policy.daml`](daml/Example/BlocklistDelegationV1/Policy.daml) defines the
operations and the grant scope of each.
[`BlocklistDelegationV1.daml`](daml/Example/BlocklistDelegationV1.daml) defines
the `BlockerDelegation` template, its `HasAuthorizationPolicy` instance, and
its choices. The token is the blocklist-integrated token of
[`examples/token/token-cip112-custom`](../../token/token-cip112-custom/).

## Blocker models

| Model | Who acts | How | Use it when |
|---|---|---|---|
| Delegation (this example) | Each delegate alone | The blocker signs one `BlockerDelegation`. The admin issues a scoped grant to each delegate for each operation. | Several independent teams or providers each need to act on their own, and the issuer adds and removes them over time. |
| Threshold blocker | One party, jointly | The blocker is an external party whose submissions need k of its n signing keys. The topology enforces the threshold. | Every change needs the agreement of several key holders. |

The two models combine: a threshold blocker signs the delegation once, with
k of its keys, and the delegates then act without those keys. The
[external-blocker suite](../../../test/blocklist-v1-test/README.md#external-blocker-suite)
shows a threshold blocker.

## Roles

| Role | Party | Signs | Does |
|---|---|---|---|
| Admin | The issuer, the instrument admin of the token | `Blocklist`, every `AuthorizationGrant` | Creates the blocklist, issues and revokes grants, terminates the delegation, gives the blocker role to another party, and discloses contracts to the delegates |
| Blocker | A party the issuer names on the `Blocklist` | `BlockerDelegation` | Signs the delegation once. Still blocks and unblocks directly with `Blocklist_Block` and `Blocklist_Unblock` |
| Delegate | A compliance team, a compliance provider, or another party | Nothing | Blocks or unblocks with its own grant |
| Token holder | An account owner or provider | Its holdings | Sends and receives the token while it is not blocked |

The admin issues the grants:

- The admin already controls the blocker role through `Blocklist_SetBlocker`,
  so issuing the delegates' grants keeps every decision about who changes the
  blocklist with one party.
- The admin signs the `Blocklist`, so a grant that it signs adds no new
  confirming participant to a delegated change.
- The admin revokes one grant with one submission, without the blocker. With a
  threshold blocker, a grant issued by the blocker would need k of its keys for
  each issue and each revocation.

The blocker consents once, when it signs the delegation. The admin gets no
power beyond the blocker role, which it controls through
`Blocklist_SetBlocker`.

## Workflow

Each step names the party that submits it and the contracts that it needs.

1. **Create the blocklist.** The admin creates the `Blocklist` with
   `admin`, `blocker`, `id`, and `maxEntries`, as for the custom token.
2. **Sign the delegation.** The blocker creates
   `BlockerDelegation with blocker; admin; blocklistId`, where `blocklistId`
   is the `id` of the blocklist. A threshold blocker submits this create
   through interactive submission with k of its keys.
3. **Issue grants.** The admin exercises `BlockerDelegation_Grant` once for
   each delegate and operation, with `operation = Block` or
   `operation = Unblock` and an optional `validFrom` and `validUntil`. The
   choice derives the scope from the delegation, so the grant matches this
   delegation contract and this operation only.
4. **Find a grant.** The delegate observes its grants. Its backend reads the
   active `AuthorizationGrant` contracts with `grantee` equal to the delegate
   through its participant's Ledger API or PQS.
5. **Get the disclosures.** The delegate is not a stakeholder of the
   `BlockerDelegation` or of the `Blocklist`. The admin's backend serves both
   as disclosed contracts, the same way that it serves the `Blocklist` to
   wallets. The delegate attaches both to its submission.
6. **Block.** The delegate exercises `BlockerDelegation_Block` on the
   delegation:

   ```daml
   exerciseCmd delegationCid BlockerDelegation_Block with
     authorization = SAG.Authorization with actor = delegate; grantCid = blockGrant
     blocklistCid = currentBlocklist
     accounts = [account]
     reason = "case-1"
   ```

   The choice checks the grant, pins the blocklist to the admin and the id,
   and exercises `Blocklist_Block` with the blocker's authority. It returns
   the successor `Blocklist`, whose disclosure replaces the previous one.
7. **Unblock.** The delegate exercises `BlockerDelegation_Unblock` with an
   `Unblock` grant and the same arguments.
8. **Enforcement.** The token's registry and pending contracts check the
   blocklist on every path that moves value, so a blocked account can neither
   send nor receive. The
   [custom token example](../../token/token-cip112-custom/README.md)
   describes these checks.

A change replaces the `Blocklist`. When two delegates change it at the same
time, the second submission fails because its blocklist is archived. That
delegate resubmits with the successor.

## Revocation and expiry

| To stop | Party | Submission |
|---|---|---|
| One grant | Admin | `AuthorizationGrant_Revoke` on the grant |
| One grant, from the delegate's side | Delegate | `AuthorizationGrant_Renounce` on the grant |
| One grant, at a set time | Admin, when it issues the grant | `validUntil` on `BlockerDelegation_Grant` |
| Every grant for the delegation | Admin | `BlockerDelegation_Terminate` |
| Every grant for the delegation | Blocker | `Archive` on the `BlockerDelegation` |
| Every delegation of the blocker | Admin | `Blocklist_SetBlocker` with another party |

Every grant is bound to the contract id of one delegation. After a
termination, a grant does not match a new delegation, so the admin issues new
grants. After `Blocklist_SetBlocker`, the old blocker is not a stakeholder of
the `Blocklist`, so each delegated change fails for missing authority. The new
blocker signs a new delegation, and the admin issues new grants for it.

`validFrom` is inclusive and `validUntil` is exclusive. Both are ledger-time
bounds. Revocation and expiry stop later changes. A block that a delegate made
stays until a party unblocks the account.

## Participants and confirmation

- The delegate submits the change from its own participant. The blocker's
  authority comes from the delegation contract, so a delegated change needs
  no signature from the blocker's keys.
- The participants that host the blocker and the admin confirm each delegated
  change. The blocker signs the delegation and acts in the nested
  `Blocklist_Block`. The admin signs the `Blocklist` and the grant.
- The blocker and the delegates take part in blocklist changes only. Token
  transfers run without them.

## Audit trail

A delegated change is one transaction:

1. The root exercise is `BlockerDelegation_Block` or
   `BlockerDelegation_Unblock`. Its acting party is the delegate, and its
   argument holds the grant's contract id, the accounts, and the reason.
2. The first child is `AuthorizationGrant_Use` on the grant, with the
   delegate as the acting party.
3. The second child is `Blocklist_Block` or `Blocklist_Unblock`, with the
   blocker as the acting party, the accounts, and the reason.

The admin is a choice observer of the root, so its participant receives the
whole transaction. The blocker receives it as the signatory of the
delegation. Read the exercises through the Ledger API with
`TRANSACTION_SHAPE_LEDGER_EFFECTS`.

## Privacy

A delegate sees its grants, the delegation and the `Blocklist` through
disclosure, and the transactions that it submits. It sees no holding,
transfer instruction, allocation, or registry contract of the token. The
`Blocklist` holds digests of the blocked parties. Read
[Privacy and cost](../../../packages/security/blocklist-v1/README.md#privacy-and-cost)
for what a digest reveals.

## Mapping to roles

The grants are role memberships. The delegation is the role's resource, the
operations are its permissions, and the admin is the role administrator. An
application that keeps role grants, as the
[treasury example](../../treasury-rbac-v1/) does, maps a role to a scope in
the `HasAuthorizationPolicy` instance. One role can cover both operations when
the instance returns the same scope for `Block` and `Unblock`. The delegated
choices stay the same.

## Build and test

From the repository root:

```sh
DAML_PACKAGE=examples/compliance/blocklist-delegation-v1 dpm build
DAML_PACKAGE=examples/compliance/blocklist-delegation-v1-test dpm test --all
OZ_SANDBOX_SUITE=blocklist-delegation scripts/check-sandbox.sh
```

The tests in
[`blocklist-delegation-v1-test`](../blocklist-delegation-v1-test/) cover each
guard of the delegated choices, the admin's controls, the audit trail, and the
token flow. These are example-only 0.x contracts with no upgrade guarantee.
