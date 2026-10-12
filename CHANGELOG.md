<!-- markdownlint-disable MD024 -->

# Changelog

User-visible changes to production packages and their public APIs are documented
in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## Unreleased

### `openzeppelin-scoped-authorization-grant-v1`

#### Added

- Added Scoped Authorization Grant for authority-signed, resource-scoped
  permissions with typed policies, expiry, revocation, conditional checks,
  usage records, and structured failures.

### `openzeppelin-api-pausable-v1`

#### Added

- Added the frozen interface package `openzeppelin-api-pausable-v1` with public
  module `OpenZeppelin.Api.PausableV1`, holding the `Pausable` interface and
  `PausableView`.

### `openzeppelin-pausable-v1`

#### Added

- Added the function package `openzeppelin-pausable-v1` with public module
  `OpenZeppelin.PausableV1`, holding the guards `whenNotPaused` and
  `whenPaused`, `isPaused`, and the failure statuses `eEnforcedPause` and
  `eExpectedPause`. It depends on `openzeppelin-api-pausable-v1`.

### `openzeppelin-cip112-token-types-v1`

#### Added

- Added the CIP-0112 types package `openzeppelin-cip112-token-types-v1`
  (public module `OpenZeppelin.CIP112Token.TypesV1`), holding the
  `RegistryConfig`, `TransferInstructionState`, and `AllocationState` records
  a template stores. Built against the official Splice Token Standard V2 DARs
  (release `0.8.3`) vendored under `dars/vendor/`.

### `openzeppelin-cip112-token-utils`

#### Added

- Added the CIP-0112 utils package `openzeppelin-cip112-token-utils` (public
  module namespace `OpenZeppelin.CIP112Token.Utils`): the transfer,
  allocation, settlement, mint, burn, and expiry choice bodies as functions
  parameterised over the caller's templates through a `HoldingOps` record and
  constructor and pinning operations. It defines no serializable types and
  depends on `openzeppelin-cip112-token-types-v1`.

### `openzeppelin-cip112-token-v1`

#### Added

- Added the CIP-0112 token package `openzeppelin-cip112-token-v1` (public
  module namespace `OpenZeppelin.CIP112TokenV1`): ready-to-use templates over
  the types and utils packages with holdings with expiring locks and owner
  recovery, one-step and two-step transfers, allocations with exact-cover
  batch settlement and iterated settlement, and registry rules with evented
  mint and burn.
