<!-- markdownlint-disable MD024 -->

# Changelog

User-visible changes to production packages and their public APIs are documented
in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## Unreleased

### `openzeppelin-timelock-api-v1`

#### Added

- Added the frozen interface package `openzeppelin-timelock-api-v1` with public
  module `OpenZeppelin.TimelockV1`.

### `openzeppelin-pausable-api-v1`

#### Added

- Added the frozen interface package `openzeppelin-pausable-api-v1` with public
  module `OpenZeppelin.PausableV1`.

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

#### Changed (Breaking)

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.

### `openzeppelin-ownable-v1`

#### Changed (Breaking)

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.
