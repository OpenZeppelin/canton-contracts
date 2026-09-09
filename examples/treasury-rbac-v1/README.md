# Treasury RBAC V1

An application-specific role-based access-control example built from the Scoped
Authorization Grant DAR. It records a payment workflow but does not transfer a
token or holding.

The example separates role policy from workflow code.
`Example.TreasuryRbacV1.RolePolicy` defines the closed role set, maps each role
to its authority and scope, and applies the authorization guard.
`Example.TreasuryRbacV1` defines the treasury and payment lifecycle that uses
that policy. The workflow derives the policy input only from trusted treasury
state.

## Role policy

| Role | Role authority | Protected operation |
|---|---|---|
| `PaymentProposer` | Operations authority | Propose a payment |
| `PaymentApprover` | Approval authority | Approve a proposal |
| `PaymentExecutor` | Execution authority | Execute an approved payment |

Each role becomes one exact authorization scope for a stable treasury ID, the
current Treasury contract ID, and the policy epoch. `Treasury_GrantRole` derives
the role's authority from treasury state, and its controller is that authority.
A caller cannot select a weaker authority for a stronger role.

Every protected choice derives the expected authority, treasury scope, and role
from the `Treasury` contract before calling `requireAuthorization`. The caller
supplies only its actor and live grant contract ID. The workflow also enforces
separation of duties: a proposer cannot approve the same payment, and an
executor must differ from both proposer and approver.

Each stage accumulates the parties that authorized it. `PaymentProposal` is
signed by the owner and proposer, `ApprovedPayment` adds the approver, and
`PaymentReceipt` adds the executor. Approval and execution are consuming choices
on those workflow contracts, so the previous signatories and the new controller
jointly authorize each successor.

## Lifecycle

Role authorities revoke individual grants through
`AuthorizationGrant_Revoke`; members may renounce them. The treasury owner may
rotate `policyEpoch`, which creates a successor Treasury contract. Earlier role
grants fail because their scope contains the previous contract ID and epoch.
Pending proposals and approvals also record their originating epoch and exact
Treasury contract ID, so they cannot cross a policy or Treasury instance
boundary. After rotation, a stranded workflow contract can be archived only
with its accumulated signatories' authority; an authorized proposer can submit
a replacement under the successor treasury.

`treasuryId` is a stable application-defined `Text` identifier used in grant
scopes. `treasuryCid` is the unique `ContractId Treasury` that binds both role
grants and payment stages to one exact policy contract.

Role authorities and members do not begin as treasury stakeholders. An
application backend discloses the treasury to an authority issuing a role and to
a member performing protected work, and discloses each pending workflow contract
to the next actor. An actor becomes a workflow stakeholder after authorizing a
stage.

## Scope

Scoped grants fit this application because its roles are a closed set and their
authorities are part of trusted treasury policy. This is not a generic dynamic
RBAC engine: it provides no runtime role hierarchy, permission registry,
membership enumeration, or recursive role administration. A generic system
would need a versioned, resource-local policy contract that derives those
relationships on-ledger rather than accepting them from callers.

A role authority can also create an equivalent `AuthorizationGrant` directly,
because it is the grant's signatory. `Treasury_GrantRole` supplies the canonical
scope mapping but is not an exclusive issuance path. Applications that must
enforce additional grant-governance rules need a policy-specific credential
whose creation is anchored to that policy contract.

The treasury owner remains the root of policy and supplies authority to each
workflow stage, but cannot create a stage naming other signatories without their
authority. A production treasury should put the owner Party behind suitable
operator governance, and the actual asset contract must enforce its own transfer
authorization.

Every stage's full signatory set can also create that template directly. A
receipt or approval payload alone therefore does not prove that earlier guarded
choices ran. An auditor needs the committed exercise and creation events, with
sufficient witness visibility, to establish that path. The receipt records a
workflow instruction, not an asset transfer or proof of settlement.

The examples are 0.x application contracts with no upgrade compatibility
promise. Payment IDs are application-defined and are not globally unique.

## Build

From the repository root:

```sh
DAML_PACKAGE=examples/treasury-rbac-v1 dpm build
```

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for the isolated tests.
