# Licensing app V1

A small integration example demonstrating delegated license issuance through
the Scoped Authorization Grant DAR.

The package imports the library through `data-dependencies`.
[`Policy.daml`](daml/Example/LicensingV1/Policy.daml) defines the issuance scope
and guard; [`LicensingV1.daml`](daml/Example/LicensingV1.daml) defines the registry,
license, and choices that apply that policy.

## Workflow

1. A licensor creates a `LicenseRegistry` with a stable registry ID and policy
   epoch.
2. The licensor exercises `LicenseRegistry_AppointOperator`, which creates an
   `AuthorizationGrant` using a scope derived from the registry's fields and
   exact contract ID.
3. The operator receives the registry contract through explicit disclosure and
   exercises `LicenseRegistry_Issue` as itself.
4. The choice derives its requirement from registry state, validates the live
   grant, and creates a licensor-signed `SoftwareLicense` for the licensee.
5. The licensor can revoke one license or rotate the registry's policy epoch.
   Rotation makes grants from earlier epochs fail exact-scope validation.

`registryId` is a stable application-defined `Text` identifier. The scope also
contains `Some (coerceContractId self)`, which binds each grant to the exact
`LicenseRegistry` instance that issued it. Two registries with the same text ID
and epoch cannot use each other's grants. Epoch rotation creates a successor
contract ID, so its operators need grants issued by that successor.

## Trust and lifecycle

The licensor signs the registry and licenses, and is trusted to issue directly
as well as through the operator workflow. License payloads alone do not prove
that the guarded choice ran. Operators cannot create licensor-signed contracts
without authorization. License IDs are application identifiers; uniqueness is
an application responsibility.

The registry has no observers. Licensees observe their licenses; operators use
transaction-scoped registry disclosure. The licensor can archive either
template through the implicit Archive choice. Revoking an operator grant blocks
future issuance but preserves existing licenses, which have their own revocation
choice. These are example-only 0.x contracts with no upgrade guarantee.

## Build

From the repository root:

```sh
DAML_PACKAGE=examples/licensing-app-v1 dpm build
```

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for the isolated tests.
