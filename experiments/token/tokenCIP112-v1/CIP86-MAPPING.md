# CIP-86 and grant M1 mapping

This document maps `openzeppelin-tokenCIP112-v1` to
[CIP-0086](https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0086/cip-0086.md)
and to milestone M1 of the
[Canton ecosystem stack proposal](https://github.com/canton-foundation/canton-dev-fund/blob/main/proposals/2026-04-OpenZeppelin-canton-ecosystem-stack.md).
It records what the package covers, what it does not cover, and the
adaptations M1 requires.

## What M1 requires

M1 lists four library deliverables that touch this package:

1. A CIP-56 (Canton Network Token Standard) implementation.
2. A CIP-86 (ERC-20 Compatible Interface) implementation.
3. Token creation, transfer, and querying demonstrated on LocalNet.
4. More than 90% test coverage.

## What CIP-86 specifies

CIP-86 defines a three-phase initiative:

- **Phase 1**: a CIP-56-compliant fungible token in Daml with four
  template roles: `ERC20Token` (the token definition), `TokenHolding`
  (balances), `Allowance` (approve and transferFrom semantics), and
  `TokenManager` (mint and burn governance). Off-ledger middleware
  exposes the six ERC-20 endpoints: `transfer`, `transferFrom`,
  `approve`, `balanceOf`, `allowance`, `totalSupply`.
- **Phase 2**: a Daml interface that abstracts the canonical ERC-20
  operations, so one middleware serves many compliant tokens.
- **Phase 3**: promotion of that interface to a network-wide standard
  through CIP governance.

The middleware and the distributed indexer are off-ledger components.
They are out of scope for this library. The Daml primitives they
exercise are in scope.

## What the package provides

`openzeppelin-tokenCIP112-v1` implements the Token Standard V2
(CIP-0112) interfaces: holdings, transfer instructions, allocations,
allocation requests, registry factories, event logging, and the D1/D2
compliance hooks. Admin mint and burn exist as `TokenRules_Mint` and
`TokenRules_Burn`.

## Mapping

| CIP-86 element | Package element | Status |
|---|---|---|
| `ERC20Token` (token definition, CIP-56 compliant) | `TokenRules` (registry rules and instrument configuration) | Partial: the template exists, but it implements the V2 interfaces, not the ratified CIP-56 V1 interfaces |
| `TokenHolding` (balances) | `TokenHolding` | Covered at the V2 interface level |
| `TokenManager` (mint and burn) | `TokenRules_Mint`, `TokenRules_Burn` | Covered; governance sits on the registry contract instead of a separate template |
| `Allowance` (approve, transferFrom) | None | **Missing** |
| `transfer` endpoint primitive | `TokenTransferInstruction` and the transfer factory | Covered at the V2 interface level |
| `transferFrom`, `approve`, `allowance` endpoint primitives | None | **Missing**: they need the `Allowance` component |
| `balanceOf`, `totalSupply` endpoint primitives | Holdings and metadata views | Partial: the on-ledger views exist; aggregation is indexer work, out of library scope |
| Phase 2 abstraction interface | None | **Missing**; it also cannot live in this package, because repository policy freezes interfaces in a separate `-api` package |

## CIP-56 status

CIP-56 is Final, and its six APIs are the `splice-api-token-*` V1
interfaces. This package implements the V2 (CIP-0112) variants, which
are devnet-stage upstream with no released artifacts. M1 names CIP-56,
so V2 conformance alone does not satisfy the deliverable as written.
The V1 interface DARs are already vendored under `dars/vendor/`.

## Assessment

The package is a sound CIP-0112 token and settlement core, and it is
worth keeping as the V2 lineage. It does not deliver CIP-86, and it
does not deliver CIP-56 as named in M1. Three adaptations close the
gap:

1. **Add CIP-56 V1 interface instances.** Implement the V1 `Holding`,
   `TransferInstruction`, `TransferFactory`, and allocation interfaces
   on the existing templates, or ship a sibling V1 package. This
   satisfies the CIP-56 deliverable with the vendored, released V1
   interfaces.
2. **Add an allowance component.** A new `Allowance` template with
   approve, increase, decrease, and revoke choices, plus a
   delegated-transfer path that debits the owner's holdings within the
   approved budget. This provides the Daml primitives for
   `approve`, `transferFrom`, and `allowance`.
3. **Define the ERC-20 abstraction as a frozen API package** (CIP-86
   Phase 2), for example `openzeppelin-erc20-api-v1`, once the choice
   surface of item 2 is stable.

The middleware and indexer (CIP-86 Phase 1 off-ledger parts) and the
LocalNet demonstration are separate deliverables outside this
repository.
