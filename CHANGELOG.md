<!-- markdownlint-disable MD024 -->

# Changelog

User-visible changes to production packages and their public APIs are documented
in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## Unreleased

### `openzeppelin-scoped-authorization-grant-v1`

#### Added

- Added an unaudited library candidate for authority-signed, resource-scoped
  permissions with optional contract-instance binding and ledger-time bounds.
- Added atomic grant-use records, revocation and renunciation choices, and
  stable machine-readable guard failures.

### `openzeppelin-tokenCIP112-v1`

#### Added

- Added the experimental CIP-0112-compliant token package
  `openzeppelin-tokenCIP112-v1` with public module namespace
  `OpenZeppelin.TokenCIP112V1`. It implements the Token Standard V2 interfaces
  and builds against the 13 vendored Token Standard V2 DARs under
  `dars/vendor/`, with provenance recorded in `dars/manifest.yaml`.
- Added the CIP-86 allowance component: the `TokenAllowance` template with
  ERC-20 `approve` and `transferFrom` semantics, spent through the new
  `TokenRules_ApproveAllowance` and `TokenRules_TransferFrom` registry
  choices.

### `openzeppelin-access-control-v1`

#### Removed (Breaking)

- Removed the experimental Access Control package. Scoped Authorization Grant
  provides the permission-checking foundation; it is not an API-compatible
  replacement for the experimental role-management choices.

### `openzeppelin-ownable-v1`

#### Removed (Breaking)

- Removed the experimental Ownable package.

### `openzeppelin-pausable-v1`

#### Changed (Breaking)

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.
