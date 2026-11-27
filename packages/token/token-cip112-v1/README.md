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
  instrument admin and the account parties, with optional locks, unlock
  choices for an expired lock (one for the account parties, one for the
  admin alone), and merge and split choices.
- `TokenTransferInstruction` (`Transfer`): the TSv2 transfer-instruction
  lifecycle over a `TransferInstructionState` payload, including accept,
  reject, withdraw, and expiry paths.
- `TokenAllocation` (`Allocation`): ready-to-settle allocations over an
  `AllocationState` payload, backed by locked holdings, with exact-cover batch
  settlement and CIP-0112 iterated settlement.
- `TokenRules` (`Registry`): the registry rules contract over a
  `RegistryConfig` payload, implementing the TSv2 transfer, allocation, and
  settlement factories plus mint offers and expiry.
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
  instruction. A one-step transfer shows the receiver's account parties the
  sender's consumed inputs and change holding. An accepted two-step transfer
  shows the sender's account parties the receiver's new holding. Account
  parties include a provider distinct from the owner. Where the sender's
  balance must stay private from the receiver, use a two-step transfer, or
  fund a one-step transfer from a single holding of exactly the amount, as
  the [integration guide](integration-guide.md#two-step-and-one-step-transfers)
  describes.
- A two-step transfer locks the transfer amount in a sender holding whose
  only lock holder is the admin. The registry serves that holding to the
  receiver's wallet by explicit disclosure, and the wallet attaches it when
  it accepts or rejects. Accept fails after `executeBefore`. Reject and
  withdraw have no deadline. After `executeBefore`, the admin may also
  return the funds to the sender through `TokenTransferInstruction_Expire`.
  Withdraw and expiry archive the pending instruction, so they need the
  receiver to stay hosted with the packages vetted (see
  [Security caveats](#security-caveats)). Once the lock expires at
  `executeBefore` plus `lockGrace`, the sender's parties can also recover the
  funds through `TokenHolding_OwnerUnlock`, which does not involve the
  receiver.
- The admin issues supply with `TokenRules_OfferMint`: a pending transfer
  instruction from the CIP-0112 mint account (`cip-112/mint`) that locks
  nothing. The receiver's account parties accept it to create the holding or
  reject it. The admin can withdraw it until then and expire it after
  `executeBefore`. A mint is always two-step.
- A holder burns with `TransferFactory_Transfer` to the CIP-0112 burn account
  (`cip-112/burn`), whose only account party is the admin. The holder's
  account parties create a burn request that locks the amount, and the admin
  accepts or rejects it; together with the admin they burn in one step.
  Accepting archives the locked amount and creates no holding for the burn
  account.
- An allocation created with `nextIterationFunding` set enables iterated
  settlement: the executors supply extra transfer legs per settlement
  iteration, bounded by the locked reserve plus incoming credits, and may
  reserve funding for a successor allocation created in the same transaction.
  A settle with no reservation ends the chain and releases all proceeds
  unlocked. Successors carry the original settlement deadline and commitment,
  clear the leg set, and extend the previous storage expiry by the `maxTTL`
  snapshotted at allocation time, capped by the settlement deadline. The
  authorizer withdraws a successor like any other allocation.
- An allocation can be settled only before its `expiresAt`, directly or
  through the settlement factory. With a settlement deadline, `expiresAt` is
  the deadline. Without one, `expiresAt` is `createdAt + maxTTL`, and a
  successor's is the previous `expiresAt` plus `maxTTL`. From `expiresAt`
  on, the executors must ask the authorizer for a new allocation.
- The admin ends a stale transfer instruction or allocation once its
  `expiresAt` has passed: an instruction through
  `TokenTransferInstruction_Expire`, an allocation through `Allocation_Cancel`
  with `actors = [admin]`, or many at once through
  `TokenRules_ExpireTransferInstructions` and `TokenRules_ExpireAllocations`.
  Each expiry reads Splice's `expire-lock` flag from its `extraArgs.context`.
  With the flag missing or set to `AV_Bool True`, the funding returns to its
  account. With the flag cleared, which is `AV_Bool False`, the expiry ends
  the contract without touching the funding, and only once `lockExpiresAt`
  has passed. For an allocation the flag is read only when the actors are
  exactly `[admin]`, including when the admin is its only executor.
- Every time check is a ledger-time bound. See "Time bounds" in the
  `token-cip112-utils` [`README.md`](../token-cip112-utils/README.md).
- The account parties rebalance their holdings with `TokenHolding_Merge`,
  which merges other holdings of the same account and instrument into the
  exercised one, and `TokenHolding_Split`, which splits a holding into the
  amounts given. A wallet that uses only the `HoldingV2.Holding` interface
  rebalances with a one-step self-transfer through
  `TransferFactory_Transfer`, which merges its inputs and splits off the
  transfer amount from the change.
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
  only through the settlement factory.
- A mint-account or burn-account allocation commits the admin to that supply
  change. The executors decide whether and when it settles, until its
  `expiresAt` or until the admin withdraws an uncommitted allocation.
  The netting ignores the amount on the special side, so the exact-cover check
  is what bounds the amount minted or burned to the legs the admin allocated.
- Enabling iterated settlement hands the executors control of the reserve.
  In each iteration they choose the authorizer's extra legs, which may send
  the reserve to any account that allocates to receive it, and whether to keep
  a reserve for the next iteration, which renews the allocation's expiry and
  lock. Without a settlement deadline each renewal adds a full `maxTTL` to
  the previous expiry, so repeated settlements can keep the reserve locked
  well past `maxTTL` from ledger time. The authorizer bounds this with a
  settlement deadline, or by withdrawing an uncommitted allocation. Enable
  iterated settlement only with executors trusted with the amount reserved.
- The vendored settlement-factory default does not validate a
  `FinalizedAllocation.nextIterationFunding`; the check in
  `allocation_settleImpl` is the effective guard. Registry forks that replace
  that choice body must keep an equivalent check.
- `TokenTransferInstruction` and `TokenAllocation` run accept, reject,
  withdraw, settle, cancel, and expiry on the pending contract alone. A
  policy that a consumer's own rules template checks in a factory body,
  such as a pause, an allowlist, a cap, or a fee, therefore binds only when
  the instruction or allocation is created. A consumer that counts totals
  when an offer is made, such as minted supply against a cap, must correct
  them when the offer is rejected, withdrawn, cancelled, or expired. Such a
  consumer owns its pending templates, which check policy at delivery as
  [`integration-guide.md`](integration-guide.md#policy-at-delivery) shows
  and correct the totals in their own choices.
- `maxTTL` and `lockGrace` are only required to be positive. Between
  `expiresAt` and `lockExpiresAt` only the pending contract can move its
  funding, so an expiry that does not clear the `expire-lock` flag releases
  it. A `lockGrace` too short for the admin's expiry automation to act in
  lets the account parties unlock or spend the funding first, and the
  contract then ends only through an expiry with the flag cleared. Size
  `lockGrace` to the automation's reaction time (minutes to hours), and size
  `maxTTL` to the longest workflow the registry accepts, counted from ledger
  time for a transfer and from `requestedAt` for an allocation. Deadlines
  are checked against ledger time, which may differ from the
  synchronizer's record time by up to its ledger-time tolerance. Keep
  `lockGrace` above twice that tolerance, so that the owner cannot unlock
  the funding while a settle can still commit.
  A time computed from an oversized value saturates at the bounds of `Time`.
  The time bounds section of the `token-cip112-utils`
  [`README.md`](../token-cip112-utils/README.md) lists the effects.
- An expiry with the `expire-lock` flag cleared trusts the admin that the
  funding is gone. The ledger cannot check this, because fetching an archived
  holding aborts. The admin clears the flag only after finding the contract's
  locked holdings no longer active, and never on `lockExpiresAt` alone. A
  flag cleared while the funding is still locked ends the contract and leaves
  the holding locked; `TokenHolding_AdminUnlock` repairs this.
- The receiver's account parties and the settlement executors observe the
  pending transfer instruction or allocation. Canton rejects a transaction
  if one of its informees has no hosting participant, or if a participant
  hosting one has not vetted the packages. If either happens to a receiver
  or an executor, every choice on the pending contract fails, including
  withdraw and admin expiry, with or without the `expire-lock` flag. A
  counterparty's operator can cause this at will by unvetting the packages.
  The funds then stay locked until the lock expires: `lockGrace` after
  `executeBefore` for a transfer, and `lockGrace` after the view's
  `expiresAt` for an allocation. For a transfer and for an allocation the
  factory creates, these deadlines fall within `maxTTL` of the pending
  contract's creation, so `maxTTL` plus `lockGrace` caps how long the funds
  stay frozen. A lock expiry that saturates at `maxTime` leaves no finite
  cap. A successor without a settlement deadline can carry an
  `expiresAt` later than its creation plus `maxTTL`, as the iterated-settlement
  caveat above describes. Size both settings with that cap in mind. The
  account parties then recover the funds through `TokenHolding_OwnerUnlock`,
  which involves only their participants and the admin's, because the admin
  is the only lock holder. The pending contract stays on the ledger until the
  counterparty is hosted again with the packages vetted, or until
  [participant repair](https://docs.canton.network/global-synchronizer/production-operations/repair-canton-nodes)
  removes it if the party has lost its last hosting participant.
- `TokenHolding` makes every lock holder an observer. If a workflow that
  reuses it names another lock holder, `TokenHolding_OwnerUnlock` and
  `TokenHolding_AdminUnlock` also fail while that party has no hosting
  participant or a participant hosting it has not vetted the packages.
- On an account whose provider differs from its owner, every choice the
  owner takes for the account needs the provider too:
  `TransferFactory_Transfer` and `AllocationFactory_Allocate`, accepting,
  rejecting, or withdrawing a transfer instruction, withdrawing an
  allocation, `TokenHolding_OwnerUnlock`, `TokenHolding_Merge`, and
  `TokenHolding_Split`. Other parties still end a
  pending workflow without the sender's or authorizer's provider signing:
  the receiver's account parties accept or reject a transfer instruction,
  the executors cancel an allocation at any time or settle it, and after
  the pending contract's `expiresAt` the admin expires a transfer
  instruction or cancels an allocation. Once a lock has expired, the admin
  also returns the holding alone with `TokenHolding_AdminUnlock`. Reject,
  cancel, expiry, and the admin unlock return the locked funds to the same
  account as unlocked holdings, and a settle pays the authorizer's proceeds
  there. Spending them still needs the provider, so no path returns control
  to the owner alone. Open provider accounts only with a provider committed
  to staying available; accounts without a separate provider avoid this.
- `TokenHolding_Merge` and `TokenHolding_Split` bypass the rules contract
  and its transfer policy, so a gate, fee, or pause that a fork adds to its
  factories leaves them running. They keep value within one account, but a
  holder can split one holding into as many parts as a transaction holds,
  each a contract the admin signs and stores. To bound that storage, cap
  the parts or their size in a fork's split choice.
- An allocation's view advertises the withdraw action statically. For a
  committed allocation the choice still fails until the settlement deadline
  passes; wallets should treat the advertised action as "who", not "when".
- The batched expiry choices `TokenRules_ExpireAllocations` and
  `TokenRules_ExpireTransferInstructions` have no observers, so each item is
  witnessed only by its own stakeholders. A party that must follow expiries
  without being a stakeholder, such as an auditor, needs read-as rights on
  the admin, which show it everything the admin sees. To show such a party
  only some accounts' holdings-change events, a registry owns its templates
  and returns the party from `HoldingOps.eventObservers` for those accounts.

## Sandbox validation

`dpm test` runs the test suite on an in-memory ledger.
`scripts/check-sandbox.sh` runs the scripts in
`OpenZeppelin.Token.Cip112.V1.Test.Sandbox` against a static-time Canton
sandbox, and reads each party's transactions from the JSON Ledger API to
check what it witnesses. From the repository root:

```sh
scripts/check-sandbox.sh
```

The script requires:

- `dpm` on the `PATH`
- Java 21 or newer
- `lsof`, `curl`, and `jq`
- A free Ledger API port (`6865` by default; override with `OZ_LEDGER_PORT`)
- A free JSON Ledger API port (`7575` by default; override with
  `OZ_JSON_API_PORT`)

Logs are written under `.cache/sandbox-token/`. To target a running ledger
instead of the script-managed sandbox, set `OZ_USE_EXTERNAL_LEDGER=1`,
`OZ_LEDGER_HOST`, `OZ_LEDGER_PORT`, and the port its JSON Ledger API listens
on as `OZ_JSON_API_PORT`. The external ledger must run in
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
