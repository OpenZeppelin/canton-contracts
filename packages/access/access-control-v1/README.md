# Access Control V1

Role credentials, delegated administration, self-renunciation, and a timelocked
two-step role handoff for Daml applications.

| Field | Value |
|---|---|
| Package | `openzeppelin-access-control-v1` |
| Public module | `OpenZeppelin.AccessControlV1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Solidity analogue | `AccessControl` and `AccessControlDefaultAdminRules` |

> [!WARNING]
> The delegated grant/revoke choices accept the target role's admin role from
> the caller, and grants are not bound to an application resource or registry
> scope. Applications must validate the intended administration relationship
> and bind grants to the resource or registry they protect.

## What it provides

- `RoleGrant`: an admin-signed, account-observed bearer credential for a textual
  role identifier.
- `RoleAdmin`: direct and delegated grant/revoke entrypoints.
- `DefaultAdminTransferOffer`: a cancellable, timelocked two-party role handoff.
- `hasRole` and `requireRole`: pure/update helpers for validating a fetched
  credential.

Roles use `Text` identifiers because Daml templates are monomorphic. An
application that wants a closed role set should define its own sum type and map
it to stable textual identifiers at the package boundary.

## Authority and lifecycle

- `RoleAdmin` is signed by the root admin.
- `RoleGrant` is signed by the issuing admin and observed by the grantee.
- A grantee may renounce its grant; the issuer or a presented delegate may revoke
  it through `RoleAdmin`.
- A transfer offer is signed by the current admin, observed by the nominee, and
  can be accepted only after its effective time.
- The package uses contract IDs rather than contract keys; the consuming
  application must identify and disclose the authoritative contracts.

The Daml source documents controllers, disclosure, privacy, archival behavior,
failure modes, and upgrade assumptions for every template.

## Build

From the repository root:

```sh
dpm build --package-root packages/access/access-control-v1
```

## Consume a local build

Build the package, then add its generated DAR to another project's
`data-dependencies`:

```yaml
data-dependencies:
  - ../canton-contracts/packages/access/access-control-v1/.daml/dist/openzeppelin-access-control-v1-0.1.0.dar
```

```daml
import OpenZeppelin.AccessControlV1
```
