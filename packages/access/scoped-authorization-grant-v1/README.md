# Scoped Authorization Grant V1

An authority issues a grant allowing another party to perform a specific
operation on a resource. Application choices validate the grant against their
own trusted policy. Grants can expire, be revoked by the authority, or be
renounced by the grantee.

| Field | Value |
|---|---|
| Package | `openzeppelin-scoped-authorization-grant-v1` |
| Public module | `OpenZeppelin.ScopedAuthorizationGrantV1` |
| Version | `0.1.0` |
| Status | Library candidate; unreleased and unaudited |

## Guarding a choice

Import the library DAR through `data-dependencies` and use a qualified import:

```daml
import DA.Functor (void)
import qualified OpenZeppelin.ScopedAuthorizationGrantV1 as SAG
```

The [licensing implementation](../../../examples/licensing-app-v1/daml/Example/LicensingV1.daml)
and [end-to-end script](../../../examples/licensing-app-v1-test/daml/Example/LicensingV1Test.daml)
show the integration:

1. The licensor creates a registry and calls `LicenseRegistry_AppointOperator`
   to issue an `AuthorizationGrant` scoped to that registry.
2. The operator obtains the grant's contract ID and the registry disclosure.
3. The operator calls `LicenseRegistry_Issue`, passing
   `SAG.Authorization with actor = operator; grantCid = grant`.

The protected choice makes `authorization.actor` its controller and validates
the grant before performing protected work. An `Update` function cannot discover
the transaction submitter, so the controller clause must require the actor's
authority:

```daml
nonconsuming choice ProtectedOperation : ()
  with authorization : SAG.Authorization
  controller authorization.actor
  do
    let requirement = SAG.AuthorizationRequirement with
          expectedAuthority = administrator
          expectedScope = scopeDerivedFromProtectedState
    void $ SAG.requireAuthorization authorization requirement
    -- protected effects
```

`requireAuthorization` returns the validated grant. Bind the result when its
fields are needed, or use `void` to discard it.

The requirement must be derived from protected contract state and application
constants. Accepting the expected authority, resource, permission, or epoch
only from caller-controlled arguments would let the caller choose the policy
being checked.

`Authorization` is input, not proof by itself. The guard fetches the grant and
matches its grantee to the authorized actor. Keep the guard on the committed
execution path of the protected operation. If a caught exception rolls back a
successful check, call the guard again before continuing with protected work.

### Typed resource policies

Use `HasAuthorizationPolicy resource permission` to define a shared requirement
for grant issuance and protected choices. The application defines its permission
type and maps each permission to an authority and scope. In the licensing example:

```daml
instance SAG.HasAuthorizationPolicy LicenseRegistry Policy.LicensingPermission where
  authorizationRequirement registry cid Policy.IssueLicense = SAG.AuthorizationRequirement with
    expectedAuthority = registry.licensor
    expectedScope = Policy.issueLicenseScope cid registry.registryId registry.policyEpoch
```

The guarded choice still uses `controller authorization.actor`. Its body calls:

```daml
void $ SAG.requirePermission this self Policy.IssueLicense authorization
```

Issuance uses `SAG.authorizationRequirement this self Policy.IssueLicense` to
obtain the same authority and scope. `checkPermission` and `requirePermission`
take the same arguments and delegate to `checkAuthorization` and
`requireAuthorization`, respectively. The check returns the grant or a failure
without recording use; the guard enforces the requirement and records use.
The lower-level functions remain available without a type-class instance.

Pass `this` and `self`, or trusted fetched state with the ID used to fetch it.
The types keep the resource and CID template types aligned; they do not prove
that the payload belongs to that CID or that the resource is still active.
Select the required permission in the protected choice, not from unchecked
caller input. The policy decides whether to include the CID in the scope.

Keep the instance beside the resource template. Permission types and policy
helpers can live in a separate module, as in both examples. The
[treasury policy](../../../examples/treasury-rbac-v1/daml/Example/TreasuryRbacV1/RolePolicy.daml)
also selects a different authority for each role.

## Conditional checks

Use `checkPermission` with a typed policy, or `checkAuthorization` with an
explicit requirement, to choose between candidate grants. Both fetch the grant
and check the actor, authority, exact scope, and validity window. They return
`Right grant` on success or `Left FailureStatus` with the first mismatch,
without recording use. Call the corresponding `require` helper for the selected
grant before performing protected work:

```daml
result <- SAG.checkPermission this self Policy.IssueLicense preferred
let selected = case result of
      Right _ -> preferred
      Left _ -> fallback
void $ SAG.requirePermission this self Policy.IssueLicense selected
```

Use the choice's controller as the actor in both `Authorization` values, and
derive the requirement from trusted policy. A successful check does not
establish the actor's authority by itself. The
[conditional-check tests](../../../test/scoped-authorization-grant-v1-test/daml/OpenZeppelin/ScopedAuthorizationGrantV1CheckTest.daml)
and [typed-policy tests](../../../test/scoped-authorization-grant-v1-test/daml/OpenZeppelin/ScopedAuthorizationGrantV1PolicyTest.daml)
include complete choices using both forms.

Fetch visibility and authorization rules still apply. Archived or unavailable
grant IDs still abort on fetch; they are not returned as `Left` and cannot be
skipped this way. Fetching a rejected candidate also makes it a transaction
dependency. Prefer selecting a grant in the backend
when the choice does not need to evaluate alternatives itself.

## Choice contexts

A generic interface can accept a grant without depending on this package. Its
choice takes an extensible context, such as Splice's `ExtraArgs`, and its
implementations read a grant contract ID from that context under a key the
protocol defines.

An implementation reading Splice's `ChoiceContext` converts the looked-up value
and passes it to a guard:

```daml
grantCid <- case TextMap.lookup grantContextKey extraArgs.context.values of
  Some (AV_ContractId cid) -> pure (coerceContractId cid)
  Some _ -> fail "scoped authorization grant context value must be a contract id"
  None -> fail "scoped authorization grant required"
void $ SAG.requireAuthorization (SAG.Authorization with actor; grantCid) requirement
```

To also accept the expected authority acting without a grant, map a missing key
to `None` and pass the `Optional` to `requireAuthorityOrGrant`.

Daml interfaces fix each choice's controller, so the interface choice takes the
actor as an argument and makes it the controller. Every implementation must then
call a guard; otherwise any party can exercise the choice. Take the actor from
the controller and derive the requirement from trusted state, never from the
context values or metadata. The
[authority-or-grant tests](../../../test/scoped-authorization-grant-v1-test/daml/OpenZeppelin/ScopedAuthorizationGrantV1AuthorityOrGrantTest.daml)
model such a choice with a Splice `ChoiceContext`.

## Resource identity

`resourceId` is a stable application identifier represented as `Text`.
`resourceInstanceCid` optionally binds the scope to a specific contract:

- `None` makes the scope depend on the logical fields only. Applications can
  use this mode when grants should apply across successor contract instances.
- `Some (coerceContractId cid)` binds the scope to that exact contract ID. A
  grant cannot then match a different expected ID, even if the text fields are
  identical.

`ContractId ()` lets the field refer to a contract of any template. The guard
compares IDs; it does not fetch the resource, check whether it is active, or
verify its template type. Including the ID does not grant read access to the
resource. Derive the expected ID from trusted contract state.

Every scope field must match: `None` does not match `Some`, and two different
contract IDs do not match. Grants require a nonnegative `policyEpoch`. To invalidate
grants through `policyEpoch`, increase the expected value in the resource's trusted
policy. Never reuse an earlier epoch for the same identity, including after
migration: it can reactivate old grants.
Future-epoch grants become usable when the expected epoch matches, if all other
checks pass. Other resources accepting the old scope remain unaffected.

An instance-bound grant remains active if its resource is archived, but it does
not match a successor contract ID. Bind to the resource's own CID when a recreated
resource must start with fresh grants. Use logical-only scope or a stable anchor
CID when grants should survive those transitions, without reusing earlier epochs.

### Role-based access control

Applications can map a role to a permission string and reuse the same grant at
every choice that requires the same authority and scope. For a given authority,
membership is per grantee and exact scope, not necessarily per business contract.
When several contracts share a role, use the same logical scope or bind their
grants to the same policy contract ID. The application defines role mappings,
delegated role administration, membership queries, and offboarding; the
[treasury example](../../../examples/treasury-rbac-v1/) shows a fixed three-role model.

## Lifecycle and visibility

The authority is the grant signatory and may revoke it. The grantee is an
observer and may record use or renounce it. Revocation and renunciation archive
the credential; a later use of that contract ID fails atomically. Recording use
preserves the grant and its contract ID.

The grantee's backend queries visible `AuthorizationGrant` contracts through
its participant's Ledger API or an index such as PQS, then presents the selected
ID to the protected choice. A non-stakeholder actor also needs the protected
resource disclosed by a stakeholder. Discovery and disclosure provide input
data; the on-ledger guard and controller clause still enforce authorization.

Using a grant may require another participant to be available to confirm the
transaction. Prefer an authority already involved as a signatory in the workflow.
The licensing example uses the same `licensor` for the registry and its grants,
so the grant does not introduce an unrelated confirming participant.

`validFrom` is inclusive and `validUntil` is exclusive. When both bounds are
present, creation requires `validFrom < validUntil`. Validation uses ledger-time
predicates rather than reading `getTime`, so the check remains compatible with
externally prepared and signed transactions.

These are ledger-time bounds, not exact wall-clock deadlines. Ledger time may
differ from record time within the synchronizer's
[configured tolerance](https://docs.canton.network/overview/reference/ledger-causality#guarantees).
Allow a margin for real-world deadlines. A prepared transaction submitted too
late can fail with `LEDGER_TIME_OUTSIDE_BOUNDS` instead of the grant's expiration error.

Expiration does not archive a grant. An active grant may be outside its validity
window or fail the current policy, so discovery alone does not establish permission.

Duplicate grants have independent contract IDs and can each authorize use;
instance binding does not enforce uniqueness. To offboard a grantee, revoke
every applicable grant or update the trusted policy shared by the affected
operations. Revocation follows ledger ordering and conflict validation; it does
not undo committed work.

## Usage records

Every successful `requireAuthorization` call exercises
`AuthorizationGrant_Use` after matching the actor, authority, and scope. The choice
enforces the grant's validity window. `requirePermission` uses the same path,
as does `requireAuthorityOrGrant` when a grant is presented. Its direct authority
path records no use.
The use event is visible only if the transaction commits and that exercise is
not rolled back by a
[caught exception](https://docs.canton.network/appdev/reference/daml-language-reference#catch-exceptions).
The authority, grantee, and other witnesses can read the exercise through the
Ledger API with the appropriate party and event filters. On Canton 3.5, use
`TRANSACTION_SHAPE_LEDGER_EFFECTS`; PQS requires the
[`TransactionTreeStream` data source](https://docs.canton.network/sdks-tools/development-tools/pqs/configure#transactions-data-source)
to index exercises.

The choice returns `()` and adds no observers. Calling `Use` directly records
that the grantee exercised it within the grant's validity window; it does not
validate the application's expected authority or scope.
Check that the event came from the application's guarded choice before treating
it as proof of a protected operation. Plain fetches are not usage records, and
the authority does not necessarily see the enclosing operation's private details.
Neither check helper produces a `Use` event, whether its result is success or failure.

## Validation results

`checkAuthorization` and `checkPermission` return failures as `Left FailureStatus`.
`requireAuthorization`, `requirePermission`, and `requireAuthorityOrGrant` raise
them with
[`DA.Fail.failWithStatus`](https://docs.canton.network/appdev/reference/daml-standard-library/da-fail).
The helpers use these stable IDs and metadata. Grant checks run in the order
shown and stop at the first mismatch:

| Error ID | Metadata | Raised by |
|---|---|---|
| `openzeppelin.com/scoped-authorization-grant-authority-mismatch` | `expected`, `actual`: issuing parties | All helpers |
| `openzeppelin.com/scoped-authorization-grant-grantee-mismatch` | `expected`, `actual`: actor and grant grantee | All helpers |
| `openzeppelin.com/scoped-authorization-grant-scope-mismatch` | `fields`: comma-separated mismatched scope field names | All helpers |
| `openzeppelin.com/scoped-authorization-grant-not-yet-valid` | `validFrom`: inclusive lower bound | All helpers |
| `openzeppelin.com/scoped-authorization-grant-expired` | `validUntil`: exclusive upper bound | All helpers |
| `openzeppelin.com/scoped-authorization-grant-required` | `expected`, `actual`: expected authority and actor | `requireAuthorityOrGrant` without a grant, when the actor is not the expected authority |

Direct `AuthorizationGrant_Use` calls raise the same validity-window failures.

All statuses use `failedPrecondition` (`FAILED_PRECONDITION`). For a returned
status, inspect `errorId` and `meta`; returning `Left` does not fail the transaction.
For an aborted transaction, match the Ledger API's
`ErrorInfo.reason = DAML_FAILURE` and `metadata.error_id`, rather than parsing
the human-readable message. Raised failures abort the transaction and cannot be
caught with Daml `try/catch`. Retry only after obtaining a suitable grant or,
for a future-dated grant, reaching its validity window. Scope metadata names
fields instead of copying arbitrary-length scope values.

`FailureStatus` is not serializable as a choice result. To return a check result
to a backend, map it to an application-defined serializable type, such as a
record containing the error ID and metadata.

Matching starts only after a successful fetch. If neither the grant's authority
nor its grantee authorizes that fetch, even a disclosed grant fails with a native
authorization error before the grantee check runs. Unavailable or archived
contracts and missing controller authority also retain Canton-native errors;
neither check helper returns these as `Left`.

Creation rejects negative epochs and malformed validity windows through
`ensure`, also with a Canton-native error.

## Authority rotation

The application's resource policy determines which authority it trusts. To rotate
that authority, update the policy through an authorized choice, select the new
issuer, advance the policy epoch, and issue replacement grants. If the successor
contract adds a signatory, its creation also needs that party's consent.

Existing grants keep their original signatory; they fail against the updated
requirement rather than changing issuer. The
[`Treasury` example](../../../examples/treasury-rbac-v1/README.md) rotates only its
epoch, leaving the authority parties unchanged. Pending workflows tied to an
archived resource require application-specific migration or cancellation.

## Trust and limits

The authority can create grants directly and is trusted to issue the scopes it
controls. Grant creation does not prove that an application-specific issuance
choice ran. Validating a grant does not let the caller sign other contracts as
the issuer. The issuer's authority is available inside `AuthorizationGrant_Use`,
but does not extend to later actions in the enclosing choice.

There is no canonical lookup in the LF 2.1 keyless model. The caller presents a
specific contract ID. V1 does not define wildcard matching, hierarchy, delegated
grant administration, transferability, counters, or an interface.

## API

- `AuthorizationScope` identifies one namespace, resource type, stable resource
  ID, permission, policy epoch, and optional exact contract instance.
- `AuthorizationGrant` records an authority's grant to one Party, with optional
  validity bounds.
- `Authorization` carries the exercising actor and grant contract ID presented
  to a protected choice.
- `AuthorizationRequirement` carries the authority and exact scope expected by
  that choice.
- `HasAuthorizationPolicy` defines `authorizationRequirement`, which derives
  a requirement from a resource, its typed contract ID, and an application-defined
  permission.
- `checkAuthorization` returns `Right grant` after matching the actor, authority,
  scope, and validity window, or `Left FailureStatus`, without recording usage.
- `requireAuthorization` fetches the grant and checks the actor, authority, and
  scope, then exercises `AuthorizationGrant_Use` to check the validity window
  and record usage, then returns the validated grant.
- `checkPermission` derives the requirement through `HasAuthorizationPolicy`
  and calls `checkAuthorization`.
- `requirePermission` derives the requirement through `HasAuthorizationPolicy`
  and calls `requireAuthorization`.
- `requireAuthorityOrGrant` accepts the expected authority acting without a
  grant, or calls `requireAuthorization` for a presented grant. It returns the
  validated grant, or `None` on the direct path.

Only the entries above and the documented grant choices form the consumer API.
Matching helpers and `OpenZeppelin.ScopedAuthorizationGrantV1.Internal` contain
unsupported implementation details.

## Build and compatibility

Build from the repository root with
`DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm build`.
See [Consume a local build](../../../README.md#consume-a-local-build) for the
`data-dependencies` configuration.

The package depends only on `daml-prim` and `daml-stdlib`, builds with SDK 3.5.8,
and targets LF 2.1. The tested runtime is Canton 3.5; there is no released SCU
baseline yet. Pin the built DAR and review package vetting for your deployment.
