# Token CIP-0112 V1

A CIP-0112-compliant token implementation built against the Token Standard V2
(TSv2) interfaces. It provides holdings, transfer instructions, allocations,
registry rules, and event logging as ready-to-use templates. The templates
store the records of `openzeppelin-token-cip112-types-v1` and delegate their
choice bodies to `openzeppelin-token-cip112-utils`, which a consumer who owns
their own templates reuses directly.

| Field | Value |
|---|---|
| Package | `openzeppelin-token-cip112-v1` |
| Public modules | `OpenZeppelin.Token.Cip112.V1.Holding`, `.Transfer`, `.Allocation`, `.Registry`, `.Base` |
| Depends on | `openzeppelin-token-cip112-types-v1`, `openzeppelin-token-cip112-utils` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |
| Standard | [CIP-0112](https://github.com/global-synchronizer-foundation/cips) / Token Standard V2 |

> [!NOTE]
> The Token Standard V2 interface DARs under
> [`dars/vendor/`](../../../dars/vendor/) are byte-identical copies of the
> artifacts Splice releases under `daml/dars/` (release tag `0.8.3`). Their
> package IDs are the ones Splice deployments already vet, so this package
> interoperates with wallets and registries built on the official interfaces.
> [`dars/manifest.yaml`](../../../dars/manifest.yaml) records every package ID
> and digest.

## What it provides

- `TokenHolding` (`Holding`): an asset holding maintained jointly by the
  instrument admin and the account parties, with optional locks and an
  owner-unlock choice.
- `TokenTransferInstruction` (`Transfer`): the TSv2 transfer-instruction
  lifecycle over a `TransferInstructionState` payload, including accept,
  reject, withdraw, and expiry paths.
- `TokenAllocation` (`Allocation`): ready-to-settle allocations over an
  `AllocationState` payload, backed by locked holdings, with exact-cover batch
  settlement and CIP-0112 iterated settlement.
- `TokenRules` (`Registry`): the registry rules contract over a
  `RegistryConfig` payload, implementing the TSv2 transfer, allocation, and
  settlement factories plus mints and instruction expiry.
- `TokenEventLog` (`Base`): the holdings-change event-log host.
- `defaultHoldingOps` (`Holding`): the operations record these templates run
  the utils functions with. A consumer that keeps `TokenHolding` but owns
  another template starts from it.

Each public module implements the matching upstream `Splice.Api.Token.*V2`
interfaces. Every choice body is a function of
`openzeppelin-token-cip112-utils` applied to these templates; the templates
add signatories, observers, `ensure` clauses, and the constructors and
policies those functions are parameterised over. The package defines no Daml
interfaces or exceptions of its own.

## Authority and lifecycle

- The instrument admin and the account parties jointly maintain holdings.
- Wallets act through the TSv2 interface choices; the choice bodies validate
  identity, funding, and expiry before they move value.
- A transfer completes in one step when the receiver's account parties
  authorize the same transaction. Otherwise the receiver accepts a pending
  instruction.
- A two-step transfer locks the transfer amount in a sender holding whose
  lock holders are the admin and the receiver's account parties, so the
  receiver's parties see that holding while the offer is pending. Accept
  fails after `executeBefore`. Reject and withdraw have no deadline. Until
  the lock expires at `executeBefore` plus `lockGrace`, withdraw is the only
  recovery the sender's parties can perform alone. After `executeBefore`, the
  admin alone may also return the funds to the sender through
  `TokenTransferInstruction_Expire`.
- The admin issues supply with `TransferFactory_Transfer` from the CIP-0112
  mint account (`cip-112/mint`), whose only account party is the admin. A
  mint takes no input holdings and locks nothing. The admin and the
  receiver's account parties acting together mint in one step. When the
  receiver's account has parties other than the admin, the admin alone
  creates a pending mint offer, which those parties accept to create the
  holding or reject. The admin can withdraw the offer until then and expire
  it after `executeBefore`. A mint to an account whose only party is the
  admin always completes in one step. Clients handle both the `Completed`
  and the `Pending` result.
- A holder burns with `TransferFactory_Transfer` to the CIP-0112 burn account
  (`cip-112/burn`), whose only account party is the admin. The holder alone
  creates a burn request that locks the amount, and the admin accepts or
  rejects it; the holder and the admin acting together burn in one step.
  Accepting archives the locked amount and creates no holding for the burn
  account.
- An allocation created with `nextIterationFunding` set enables iterated
  settlement: the executors supply extra transfer legs per settlement
  iteration, bounded by the locked reserve plus incoming credits, and may
  reserve funding for a successor allocation created in the same transaction.
  A settle with no reservation ends the chain and releases all proceeds
  unlocked. Successors carry the original settlement deadline and commitment,
  clear the leg set, and bump the storage expiry using the registry
  configuration snapshotted at allocation time. The authorizer withdraws a
  successor like any other allocation.
- The consuming application selects and discloses the canonical `TokenRules`
  contract for its instrument.
- Only regular (owned) accounts hold balances. The admin also authors
  allocations for the CIP-0112 mint and burn accounts, so a settlement batch
  can issue or redeem supply as one side of a trade. The special accounts
  appear in events only as the other side of a supply change.

For multi-participant deployment, disclosure, and wallet integration, see
[`integration-guide.md`](integration-guide.md).

## Standards conformance

The package implements Token Standard V2 (CIP-0112).

The V2 interface hierarchy is parallel to V1: the two share only
`splice-api-token-metadata-v1`, so V1 tooling cannot see this token. When a
deployment target requires V1 visibility, add the V1 interface instances to
the same templates: the V1 interface packages ship inside the vendored
`splice-token-standard-utils` DAR, whose `...V1...DefaultImplUsingV2`
helpers exist for exactly this pattern.

## Compatibility

The package builds with the workspace SDK declared in
[`multi-package.yaml`](../../../multi-package.yaml) and targets Daml-LF 2.1.
It is the first release of the `openzeppelin-token-cip112-v1` SCU lineage and
depends on the official Splice Token Standard V2 packages (see the note
above), on `openzeppelin-token-cip112-types-v1`, whose records its templates
store, and on `openzeppelin-token-cip112-utils`. Later versions of the lineage
that keep the Splice and types dependencies can upgrade its templates in
place. The utils package defines nothing serializable, so a later version of
this package may move to any utils version or drop it.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/token/token-cip112-v1 dpm build
```

## Security caveats

- The exact-cover check runs only inside `SettlementFactory_SettleBatch`. A
  direct `Allocation_Settle` by the admin plus the executors bypasses it and
  can create or destroy value, so the admin's authority must never co-sign a
  settle outside the factory. Operate the admin party so that it signs settles
  only through the settlement factory. See `ideas.md` on reintroducing the
  on-ledger guard that removes this trust assumption.
- A mint-account or burn-account allocation commits the admin to that supply
  change. The executors decide whether and when it settles, until the
  settlement deadline or until the admin withdraws an uncommitted allocation.
  The netting ignores the amount on the special side, so the exact-cover check
  is what bounds the amount minted or burned to the legs the admin allocated.
- Enabling iterated settlement hands the executors control of the reserve.
  In each iteration they choose the authorizer's extra legs, which may send
  the reserve to any account that allocates to receive it, and whether to keep
  a reserve for the next iteration, which renews the allocation's expiry and
  lock. The authorizer bounds this with a settlement deadline, or by
  withdrawing an uncommitted allocation. Enable iterated settlement only with
  executors trusted with the amount reserved.
- The vendored settlement-factory default does not validate a
  `FinalizedAllocation.nextIterationFunding`; the check in
  `allocation_settleImpl` is the effective guard. Registry forks that replace
  that choice body must keep an equivalent check.
- `maxTTL` and `lockGrace` are only required to be positive. A `lockGrace` too
  short for the admin's cleanup automation to act in leaves expiry to the
  owner-recovery path; size it to the automation's reaction time (minutes to
  hours), and size `maxTTL` to the longest workflow the registry accepts.
- Recovering an expired-lock holding through `TokenHolding_OwnerUnlock` needs
  every account party. On accounts with a distinct provider, an unresponsive
  provider blocks recovery until it cooperates; single-party accounts avoid
  this.
- An allocation's view advertises the withdraw action statically. For a
  committed allocation the choice still fails until the settlement deadline
  passes; wallets should treat the advertised action as "who", not "when".

## Sandbox validation

`dpm test` runs the test suite on an in-memory ledger. The sandbox gate runs
mint offers, transfers, querying, and burn requests against a real
static-time Canton sandbox over the Ledger API. From the repository root:

```sh
scripts/check-sandbox.sh
```

The script requires:

- `dpm` on the `PATH`
- Java 21 or newer
- `lsof`
- A free Ledger API port (`6865` by default; override with `OZ_LEDGER_PORT`)

Logs are written under `.cache/sandbox-token/`. To target a running ledger
instead of the script-managed sandbox, set `OZ_USE_EXTERNAL_LEDGER=1`,
`OZ_LEDGER_HOST`, and `OZ_LEDGER_PORT`. The external ledger must run in
static-time mode with its clock at or before 2026-01-01T00:10Z: the scripts
pin the clock with `setTime`, and a static-time ledger only moves its clock
forward.

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/token/token-cip112-types-v1/.daml/dist/openzeppelin-token-cip112-types-v1-0.1.0.dar
  - ../canton-contracts/packages/token/token-cip112-utils/.daml/dist/openzeppelin-token-cip112-utils-0.1.0.dar
  - ../canton-contracts/packages/token/token-cip112-v1/.daml/dist/openzeppelin-token-cip112-v1-0.1.0.dar
```

```daml
import OpenZeppelin.Token.Cip112.V1.Registry
```

`examples/token/token-cip112-trading-test` launches a registry from this package and
drives it through the standard interfaces. To own the templates instead and
reuse only the choice bodies, see the utils package `README.md` and
`examples/token/token-cip112-custom`.

## License

Two modules contain code derived from the Splice
[TestTokenV2](https://github.com/canton-network/splice/tree/8460154135f39019b8bb370c9c1321ff13c9bb10/token-standard/examples/splice-test-token-v2)
example and modified by OpenZeppelin:

- `OpenZeppelin.Token.Cip112.V1.Holding`, from
  `Splice.Testing.Tokens.TestTokenV2.Holding`.
- `OpenZeppelin.Token.Cip112.V1.Registry`, from
  `Splice.Testing.Tokens.TestTokenV2`.

The TestTokenV2 example is Copyright (c) 2024 Digital Asset (Switzerland) GmbH
and/or its affiliates, licensed under the Apache License 2.0
([`LICENSES/Apache-2.0.txt`](../../../LICENSES/Apache-2.0.txt)). The two
modules are licensed `MIT AND Apache-2.0`, and each carries its copyright and
license notice. The rest of the package is licensed under the repository's
MIT [`LICENSE`](../../../LICENSE).
