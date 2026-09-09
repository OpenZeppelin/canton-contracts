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
import qualified OpenZeppelin.ScopedAuthorizationGrantV1 as SAG
```

The [licensing implementation](../../../examples/licensing-app-v1/daml/Example/LicensingV1.daml)
and [end-to-end script](../../../examples/test/licensing-app-v1-test/daml/Example/LicensingV1Test.daml)
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
    SAG.requireAuthorization authorization requirement
    -- protected effects
```

The requirement must be derived from protected contract state and application
constants. Accepting the expected authority, resource, permission, or epoch
only from caller-controlled arguments would let the caller choose the policy
being checked.

`Authorization` is input, not proof by itself. The guard fetches the grant and
matches its grantee to the authorized actor. Keep the guard on the committed
execution path of the protected operation. If a caught exception rolls back a
successful check, call the guard again before continuing with protected work.

## Resource identity

`resourceId` is a stable application identifier represented as `Text`.
`resourceInstanceCid` optionally refines that logical identity:

- `None` makes the scope depend on the logical fields only. Applications can
  use this mode when grants should apply across successor contract instances.
- `Some (coerceContractId cid)` binds the scope to that exact contract ID. A
  grant cannot then match a different expected ID, even if the text fields are
  identical.

The field uses `ContractId ()` as a type-erased identifier so scopes can refer
to any template. It is compared for equality and is not fetched by the guard,
so it proves neither resource liveness nor template type and grants no resource
visibility. The protected choice must derive the expected ID from trusted state.

Scope matching uses full record equality: `None` does not match `Some`, and two
different contract IDs do not match. Advancing the epoch in a protected
resource's trusted requirement rejects older grants at that resource. Other
resources that still accept the old scope remain unaffected.

An instance-bound grant remains active if its resource is archived, but it does
not match a successor contract ID. Applications that frequently recreate a
resource should use logical-only scope or a stable anchor CID when grants must
continue across those transitions.

### Role-based access control

Applications can map a role to a permission string and reuse the same grant at
every choice that requires the same authority and scope. For a given authority,
membership is per grantee and exact scope, not necessarily per business contract.
Use common logical fields or a shared policy-anchor CID when several contracts
deliberately share a role. Role mappings, delegated role administration,
enumeration, and offboarding remain application policy; the
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

Using a grant can add a confirming participant and an availability dependency.
Prefer an authority already involved as a signatory in the protected workflow.
The licensing example uses the same `licensor` for the registry and its grants,
so the grant does not introduce an unrelated confirming participant.

Validity uses a half-open interval: `validFrom` is inclusive and `validUntil` is
exclusive. When both bounds are present, creation requires
`validFrom < validUntil`. Validation uses ledger-time predicates rather than
reading `getTime`, so the check remains compatible with externally prepared and
signed transactions.

Expiration does not archive a grant. An active grant may be outside its validity
window or fail the current policy, so discovery alone does not establish permission.

Duplicate grants have independent contract IDs and can each authorize use;
instance binding does not enforce uniqueness. To offboard a grantee, revoke
every applicable grant or update the trusted policy shared by the affected
operations. Revocation follows ledger ordering and conflict validation; it does
not undo committed work.

## Usage records

Every successful `requireAuthorization` call exercises
`AuthorizationGrant_Use` after validation. The use event is visible only if the
transaction commits and that exercise is not rolled back by a
[caught exception](https://docs.canton.network/appdev/reference/daml-language-reference#catch-exceptions).
The authority, grantee, and other witnesses can read the exercise through the
Ledger API with the appropriate party and event filters. On Canton 3.5, use
`TRANSACTION_SHAPE_LEDGER_EFFECTS`; PQS requires the
[`TransactionTreeStream` data source](https://docs.canton.network/sdks-tools/development-tools/pqs/configure#transactions-data-source)
to index exercises.

The choice returns `()` and adds no observers. A standalone `Use` only records
the grantee's exercise, even if the active grant has expired. Correlate the event
with the application's guarded choice before treating it as evidence of a
protected operation. Plain fetches are not usage records, and the authority
does not necessarily see the enclosing operation's private details.

## Guard failures

The guard uses [`DA.Fail.failWithStatus`](https://docs.canton.network/appdev/reference/daml-standard-library/da-fail)
with these stable IDs and metadata:

| Error ID | Metadata |
|---|---|
| `OZ_SAG_AUTHORITY_MISMATCH` | `expected`, `actual`: issuing parties |
| `OZ_SAG_GRANTEE_MISMATCH` | `expected`, `actual`: actor and grant grantee |
| `OZ_SAG_SCOPE_MISMATCH` | `fields`: comma-separated mismatched scope field names |
| `OZ_SAG_NOT_YET_VALID` | `validFrom`: inclusive lower bound |
| `OZ_SAG_EXPIRED` | `validUntil`: exclusive upper bound |

All use `failedPrecondition` (`FAILED_PRECONDITION`). Match the Ledger API's
`ErrorInfo.reason = DAML_FAILURE` and `metadata.error_id`, rather than parsing
the human-readable message. These failures abort the transaction and cannot be
caught with Daml `try/catch`. Retry only after obtaining a suitable grant or,
for a future-dated grant, reaching its validity window. Scope metadata names
fields instead of copying arbitrary-length scope values.

Unavailable or archived contracts, missing controller authority, and malformed
windows rejected by `ensure` retain Canton-native errors. Those failures can
occur before the guard's checks run.

## Authority rotation

Applications own the trusted authority in their resource policy. To rotate it,
replace that policy through an authorized application choice, select the new
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
the issuer: the issuer's authority inside `AuthorizationGrant_Use` does not
extend to the caller's subsequent sibling actions.

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
- `requireAuthorization` fetches and validates the presented grant, then
  exercises `AuthorizationGrant_Use` to record usage.

`OpenZeppelin.ScopedAuthorizationGrantV1.Internal` contains unsupported
implementation details and is not part of the consumer API.

## Build and compatibility

Build from the repository root with
`DAML_PACKAGE=packages/access/scoped-authorization-grant-v1 dpm build`.
See [Consume a local build](../../../README.md#consume-a-local-build) for the
`data-dependencies` configuration.

The package depends only on `daml-prim` and `daml-stdlib`, builds with SDK 3.5.8,
and targets LF 2.1. The tested runtime is Canton 3.5; there is no released SCU
baseline yet. Pin the built DAR and review package vetting for your deployment.
