# Async Vault Permits V1

A deposit gate for an asynchronous vault that admits a party only when a
validator the vault's admin appointed has enabled it. The admin appoints
validators, each validator enables one party at a time, and a deposit request
shows the party's permit.

| Field | Value |
|---|---|
| Package | `openzeppelin-async-vault-permits-v1` |
| Public module | `OpenZeppelin.AsyncVaultPermitsV1` |
| Depends on | `openzeppelin-api-async-vault-v1`, `openzeppelin-scoped-authorization-grant-v1` |
| Version | `0.1.0` |
| Status | Pre-release; unaudited |

## What it provides

- `DepositPermitRules`: the permit rules of one vault. It implements the
  `DepositGate` interface of
  [`openzeppelin-api-async-vault-v1`](../api-async-vault-v1/), so a vault
  names it as its gate.
- `DepositPermit`: a validator's statement that one party may deposit into
  one vault.
- `permitArgs`: the extra arguments a requester passes to show its permit.
- `partyNamespace` and `sameNamespace`: the namespace of a party id and the
  comparison the same-namespace rule uses.
- `enableScope` and `enableRequirement`: the scope of the grant a validator
  holds.
- `eWrongVault`, `eNoPermit`, `ePermitMismatch`, and `eOtherNamespace`: the
  failure statuses.

The grant a validator holds is an `AuthorizationGrant` of
[`openzeppelin-scoped-authorization-grant-v1`](../../../packages/access/scoped-authorization-grant-v1/).

## Authority and lifecycle

| Party | What it does |
|---|---|
| Admin | Creates the rules, appoints validators, and can revoke any appointment or permit. |
| Validator | Enables one party at a time and removes the permits it made. |
| Party | Shows its permit when it asks to deposit. |

1. **Create the rules.** The admin creates a `DepositPermitRules` for a vault
   and names it in the vault's `depositGate`.
2. **Appoint a validator.** The admin exercises `DepositPermitRules_Appoint`.
   The validator receives an `AuthorizationGrant` scoped to the vault, with
   an optional validity window.
3. **Enable a party.** The validator exercises `DepositPermitRules_Enable`
   with its grant and the party. The party receives a `DepositPermit` signed
   by the admin and the validator.
4. **Deposit.** The party opens a deposit request on the vault and passes
   `permitArgs permitCid` as the request's `vault` extra arguments. The gate
   admits the request when the permit is the requesting account owner's
   permit for this vault and the validator's grant is still valid.
5. **Withdraw access.** The validator removes one permit with
   `DepositPermit_Remove`, and the admin with `DepositPermit_Revoke`. The
   admin withdraws a validator with the grant's `AuthorizationGrant_Revoke`,
   and every permit that validator made stops admitting its party. A request
   that shows a removed permit, or a permit made under a revoked grant, names
   a contract that is no longer active. The ledger rejects it for that
   reason, so the rejection carries none of this package's failure ids.

Every choice on the rules is nonconsuming, so appointing, enabling, and
checking never contend.

What each party must be shown, by explicit disclosure:

- A validator: the rules.
- A requester: the vault, the rules, and the validator's grant. It observes
  its own permit.

The admin signs every permit, so the admin sees every party a validator
enables.

## The same-namespace rule

With `sameNamespaceOnly` set on the rules, a validator enables only parties
of its own namespace. A Canton party id is `name::namespace`, and the
namespace identifies the key the party was created under.

- A participant puts the parties it allocates through its Ledger API into
  its own namespace. Under the rule, a validator that runs its own
  participant enables the parties allocated there and none allocated on
  another participant.
- The rule is checked when a party is enabled and again at every deposit
  request. A permit made before the rule was switched on admits nobody of
  another namespace afterwards.
- A party with external signing has a namespace of its own. Under the rule
  it cannot be enabled.
- A shared namespace shows that the same key created both parties. It does
  not show where a party is hosted, and nothing on the ledger can.
- The rule reads the text of a party id. A party whose id has no `::` part
  has no namespace, and under the rule it is neither enabled nor able to
  enable.

## Security caveats

- Without the same-namespace rule a validator can enable any party, hosted
  on it or not. The admin's appointment makes the validator answerable for
  the parties it enables.
- A permit is tied to the grant it was made under. A validator that is
  appointed again after its grant was revoked must enable its parties again,
  because the earlier permits stay without effect.
- A validator can enable the same party more than once. Each permit admits
  the party until it is removed, so withdrawing a party means removing every
  permit it holds.
- The gate admits the owner of the requesting account. An account's provider
  is not checked.
- The rules cannot be changed in place. The admin archives them, creates
  others, and names the new contract as the vault's gate. Grants and permits
  stay valid under rules with the same admin, vault id, and policy epoch.
  Rules with a higher `policyEpoch` accept none of the grants and permits
  made before.
- The gate is asked about deposit requests only. A party whose permit is
  withdrawn keeps the requests it already opened and can still ask to redeem
  its shares.
- This package depends on `openzeppelin-scoped-authorization-grant-v1`, an
  implementation package. A consumer vets both.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/vault/async-vault-permits-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/vault/api-async-vault-v1/.daml/dist/openzeppelin-api-async-vault-v1-0.1.0.dar
  - ../canton-contracts/packages/vault/async-vault-permits-v1/.daml/dist/openzeppelin-async-vault-permits-v1-0.1.0.dar
  - ../canton-contracts/packages/access/scoped-authorization-grant-v1/.daml/dist/openzeppelin-scoped-authorization-grant-v1-0.1.0.dar
```

```daml
import OpenZeppelin.AsyncVaultPermitsV1
```

[`examples/vault/async-vault-fund-test`](../../../examples/vault/async-vault-fund-test/)
runs these rules as the deposit gate of a `Vault` of
`openzeppelin-async-vault-v1`.
