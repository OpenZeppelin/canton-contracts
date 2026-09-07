# Token CIP-0112 Trading Example

Minimal integration of `openzeppelin-tokenCIP112-v1` and
`openzeppelin-allocation-request-v1`: an exchange settling trades between two
traders, driven entirely through the Token Standard V2 interfaces the way a
wallet or settlement app drives any compliant registry.

| Field | Value |
|---|---|
| Package | `tokenCIP112-trading-example` |
| Modules | `MyApp.TradingDemo` |
| Consumes | `openzeppelin-tokenCIP112-v1` `0.1.0`, `openzeppelin-allocation-request-v1` `0.1.0` |

## What it shows

- The intended consumption model: the issuer consumes the DAR, creates one
  `TokenRules` contract, and the token is live — a new instrument is just a
  fresh instrument id minted under the same registry, with no further
  deployment.
- Minting through the registry's evented path, so supply changes are visible
  to token-standard history parsers.
- The exchange requesting one `TokenAllocationRequest` per trader, and each
  trader accepting the request and funding the allocation in a single
  transaction; only the trader's net debit is locked.
- Atomic DvP through `SettlementFactory_SettleBatch`, and why it is the only
  settlement path: a direct `Allocation_Settle` by the choice's own default
  controllers is refused without the factory's admin-signed proof, and a batch
  whose legs are not exactly covered by the presented allocations is refused.
- The iterated-settlement deposit flow: traders deposit by reserving funding
  with no transfer legs, the exchange specifies fills per iteration up to the
  reserve, proceeds roll into successor deposits, and a settle with no
  reservation releases everything unlocked. Reserving more than the
  settlement proceeds is refused.

`MyApp.TradingDemo` carries three scripts: `demoCreateToken` launches a token,
`demoDvpSettlement` runs the OTC trade lifecycle, and `demoIteratedSettlement`
runs the deposit flow across two fills.

## Authority model

The registry `admin` co-signs every holding and allocation; traders act
through their account parties; the `exchange` is the settlement executor named
in the `SettlementInfo`. Settlement runs on executor authority against
factory-minted, admin-signed batch authorizations, so no trader sees the other
allocations in a batch.

## Build and run

From the repository root:

```sh
DAML_PACKAGE=examples/tokenCIP112/trading dpm build
DAML_PACKAGE=examples/tokenCIP112/trading dpm test
```
