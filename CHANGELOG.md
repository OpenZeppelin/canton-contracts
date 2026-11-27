<!-- markdownlint-disable MD024 -->

# Changelog

User-visible changes to production packages and their public APIs are documented
in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## Unreleased

### `openzeppelin-api-timelock-v1`

#### Added

- Added the frozen interface package `openzeppelin-api-timelock-v1` with public
  module `OpenZeppelin.Api.TimelockV1`, holding the `Timelock`, `Operation`,
  and `Timelocked` interfaces, their views, `TimelockConfig`, `Pending`, and
  `DropReason`.
- The target lifecycle choices `Timelock_Apply` and `Timelock_Drop` call the
  `applyImpl` and `dropImpl` methods of the implementing template.
  `Timelock_Drop` takes a `DropReason` for cancellation or expiry cleanup.

### `openzeppelin-timelock-utils`

#### Added

- Added the function package `openzeppelin-timelock-utils` with public module
  `OpenZeppelin.Timelock.Utils`, holding `applyOperation`, `dropOperation`,
  `scheduleAt`, `scheduleAfter`, `isValidConfig`, `requireValidConfig`,
  `addPending`, `takePending`, `requireReady`, `requireExpired`, `isReadyAt`,
  `isExpiredAt`, and the ten failure statuses of the component. It depends on
  `openzeppelin-api-timelock-v1`.
- `applyOperation` and `dropOperation` authenticate `actor` and enforce
  permissions, time bounds, pending membership, and shared signatory
  authority. Both archive the operation atomically with the state change.

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

### `openzeppelin-pausable-utils`

#### Added

- Added the function package `openzeppelin-pausable-utils` with public module
  `OpenZeppelin.Pausable.Utils`, holding the guards `whenNotPaused` and
  `whenPaused`, `isPaused`, and the failure statuses `eEnforcedPause` and
  `eExpectedPause`. It depends on `openzeppelin-api-pausable-v1`.

### `openzeppelin-api-async-vault-v1`

#### Added

- Added the frozen interface package `openzeppelin-api-async-vault-v1` with
  public module `OpenZeppelin.Api.AsyncVaultV1`, holding the `DepositGate`
  interface, `DepositGateView`, the `DepositGate_Check` choice, and
  `DepositGate_CheckResult`. An asynchronous vault asks a gate before it
  accepts a deposit request, and the gate refuses by failing.

### `openzeppelin-async-vault-types-v1`

#### Added

- Added the async vault types package `openzeppelin-async-vault-types-v1`
  (public module `OpenZeppelin.AsyncVault.TypesV1`), holding the
  `VaultConfig`, `VaultRegistries`, `SharePrice`, `VaultState`,
  `RequestArgs`, `DepositTerms`, `RedeemTerms`, `DepositRequestState`,
  `RedeemRequestState`, `Fill`, and `SettledBatch` records a template stores
  or a choice takes. Built against the official Splice Token Standard V2 DARs
  vendored under `dars/vendor/`.

### `openzeppelin-async-vault-utils`

#### Added

- Added the async vault utils package `openzeppelin-async-vault-utils`
  (public module namespace `OpenZeppelin.AsyncVault.Utils`): exact share
  maths rounded down, and the request, cancel, reject, expiry,
  batch-settlement, reserve-recording, and deposit-gate choice bodies of an
  asynchronous vault as functions parameterised over the caller's templates
  through a `VaultPolicy` record and constructor operations. It defines no
  serializable types and depends on `openzeppelin-async-vault-types-v1` and
  `openzeppelin-api-async-vault-v1`.

### `openzeppelin-async-vault-v1`

#### Added

- Added the async vault package `openzeppelin-async-vault-v1` (public module
  `OpenZeppelin.AsyncVaultV1`): ready-to-use templates over the types and
  utils packages. `Vault` holds the rules and takes deposit and redemption
  requests, with an optional deposit gate. `DepositRequest` and
  `RedeemRequest` hold a pending request whose funds are escrowed in a Token
  Standard allocation, which the requester cancels at any time. `VaultLedger`
  settles requests in batches at one price within a band the admin sets, and
  records the reserves, the shares outstanding, the last price, and the batch
  number.

### `openzeppelin-async-vault-permits-v1`

#### Added

- Added the deposit-gate package `openzeppelin-async-vault-permits-v1`
  (public module `OpenZeppelin.AsyncVaultPermitsV1`), holding
  `DepositPermitRules` and `DepositPermit`. A vault's admin appoints
  validators, and each validator enables one party at a time to deposit,
  optionally only parties of its own namespace. It depends on
  `openzeppelin-api-async-vault-v1` and
  `openzeppelin-scoped-authorization-grant-v1`.

### `openzeppelin-token-cip112-types-v1`

#### Added

- Added the CIP-0112 types package `openzeppelin-token-cip112-types-v1`
  (public module `OpenZeppelin.Token.Cip112.TypesV1`), holding the
  `RegistryConfig`, `TransferInstructionState`, and `AllocationState` records
  a template stores. Built against the official Splice Token Standard V2 DARs
  (release `0.8.3`) vendored under `dars/vendor/`.

### `openzeppelin-token-cip112-utils`

#### Added

- Added the CIP-0112 utils package `openzeppelin-token-cip112-utils` (public
  module namespace `OpenZeppelin.Token.Cip112.Utils`): the transfer,
  allocation, settlement, mint-offer, and expiry choice bodies as functions
  parameterised over the caller's templates through a `HoldingOps` record and
  constructor and pinning operations. It defines no serializable types and
  depends on `openzeppelin-token-cip112-types-v1`.

### `openzeppelin-token-cip112-v1`

#### Added

- Added the CIP-0112 token package `openzeppelin-token-cip112-v1` (public
  module namespace `OpenZeppelin.Token.Cip112.V1`): ready-to-use templates over
  the types and utils packages with holdings with expiring locks and owner
  recovery, one-step and two-step transfers, allocations with exact-cover
  batch settlement and iterated settlement, delivery-vs-mint and
  delivery-vs-burn settlement through the CIP-0112 mint and burn accounts,
  registry rules with mint offers from the mint account, and burns as
  transfers to the burn account.
