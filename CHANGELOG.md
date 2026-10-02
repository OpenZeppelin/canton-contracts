<!-- markdownlint-disable MD024 -->

# Changelog

User-visible changes to production packages and their public APIs are documented
in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## Unreleased

### `openzeppelin-tokenCIP112-workflows-v1`

#### Added

- Added the CIP-0112 workflows package `openzeppelin-tokenCIP112-workflows-v1`
  (public module namespace `OpenZeppelin.TokenCIP112WorkflowsV1`): the
  transfer, allocation, settlement, mint, burn, and expiry choice bodies as
  functions parameterised over the caller's templates through a `HoldingOps`
  record and constructor and pinning operations, plus the `RegistryConfig`,
  `TransferInstructionState`, and `AllocationState` records a template
  stores. Built against the official Splice Token Standard V2 DARs (release
  `0.8.3`) vendored under `dars/vendor/`.

### `openzeppelin-tokenCIP112-v1`

#### Added

- Added the CIP-0112 token package `openzeppelin-tokenCIP112-v1` (public
  module namespace `OpenZeppelin.TokenCIP112V1`): ready-to-use templates over
  the workflows package with holdings with expiring locks and owner recovery,
  one-step and two-step transfers, allocations with exact-cover batch
  settlement and iterated settlement, and registry rules with evented mint
  and burn.

### `openzeppelin-access-control-v1`

#### Changed (Breaking)

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.

### `openzeppelin-ownable-v1`

#### Changed (Breaking)

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.

### `openzeppelin-pausable-v1`

#### Changed (Breaking)

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.
