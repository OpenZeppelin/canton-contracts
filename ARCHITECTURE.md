# Architecture

## Product boundary

`canton-contracts` contains reusable, on-ledger Daml components and focused
integration examples showing how to use them. Broader application implementations,
research prototypes, interoperability experiments, and local lookalikes of
upstream Canton standards belong in their own repositories.

Code moves into this repository only after its research question and upstream
dependency choices are settled. Promotion gives the component a final package
name, module namespace, compatibility policy, test package, documentation, and
release path.

## Package boundaries

The DAR is the unit consumers build against and operators upload. The Daml
package is the unit of package identity, SCU compatibility, dependency retention,
and vetting. Consequently:

1. One independently released unit is one Daml package and one DAR.
2. Unrelated components are never bundled into an umbrella package.
3. Test packages are separate and never released or uploaded.
4. Categories such as `access/` and `security/` organize the source tree only.

Scoped Authorization Grant and Pausable have separate package boundaries.
Combining them would force every consumer and operator to accept the whole
dependency, audit, upgrade, and vetting surface.

## Interfaces and implementations

Daml interfaces and exceptions are not SCU-upgradeable. A package that defines
them beside templates prevents those templates from benefiting from SCU.

When a component defines an interface, use two production packages:

```text
openzeppelin-api-<component>-v1    Frozen interfaces, exceptions, API types
openzeppelin-<component>-v1        Templates or functions implementing the API
openzeppelin-<component>-v1-test   Daml Script tests; never released
```

API packages may depend only on other API packages. A template-only component
ships one implementation package; empty API packages add ceremony without an
upgrade or interoperability benefit.

### Components without templates

Some components ship no template of their own. Pausable is the model: the
pause flag is a field of the consumer's template, because a guard that reads
the contract being exercised is sound and a guard that fetches a separate
switch contract is not, since a caller can substitute or omit a contract it
supplies. The implementing templates live in consuming packages.

The component is still two packages. `openzeppelin-api-pausable-v1` holds the
interface and its view and nothing else, because that is the one part Daml
cannot upgrade. `openzeppelin-pausable-v1` holds the guards and the failure
statuses. A bug fix in `whenNotPaused` is a new version of the function
package, and the frozen interface package does not move. The Splice token
standard follows the same split, keeping its helper functions in
`splice-token-standard-utils` beside its frozen interface packages.

The API package follows the `openzeppelin-api-<component>-vN` freeze rule: no
templates, no SCU, and a breaking change ships as a sibling `-v2` package. The
function package depends on the API package alone, and a consumer data-depends
on both DARs. The consumer's implementing template upgrades through SCU
independently, because the interface instance is declared on the template and
the API package does not move. SCU can only add an interface instance to that
template, never remove one, and adding one needs the `damlc` option
`-Wno-template-has-new-interface-instance`. So adopting an API `-v2` package
means the template implements both interfaces for life; dropping the `-v1`
instance needs a new template version outside SCU and an offline contract
migration that copies the flag.

### Guards that read a shared contract

Blocklist is the model for state that cannot live on the contract being
exercised. A blocked party has many holdings and pending contracts, and a
block must stop all of them at once, so the blocked set is one `Blocklist`
contract that every guarded choice fetches. A caller supplies that contract,
which is the substitution risk the Pausable section describes. Three rules
contain it:

- `fetchBlocklist` pins the template, the admin, and an `id` that the guarded
  template takes from its own state. A caller who presents a blocklist of
  their own fails the admin check. LF 2.1 has no contract keys, so uniqueness
  per admin and `id` is the admin's responsibility.
- A guarded choice that receives no blocklist fails. A token standard
  interface choice has no blocklist argument, so the blocklist arrives in the
  choice context, as the standard intends for registry-supplied contracts.
  `fetchBlocklistFromContext` reads it there, which makes the package depend
  on the frozen `splice-api-token-metadata-v1` API package for the
  `ChoiceContext` type.
- The admin is the only signatory. The informees of a `fetch` are the
  signatories and the acting parties. If the blocker also signed, its
  participant would confirm every guarded transaction and learn its timing.
  As an observer, the blocker sees the blocklist and its changes only, and an
  unavailable blocker never stops a transfer.

The set stores unsalted SHA-256 digests of parties. Every submitter of a
guarded transaction receives the whole contract by disclosure. A digest keeps
party ids out of the payload, which is obfuscation, not confidentiality:
anyone who can list party ids computes their digests, successive disclosures
show the changes, and a party has the same digest in every blocklist. A salt
would not change this, because the guard needs the salt to compute the
digest, so every reader of the contract would also hold it.

Two other structures trade simplicity for confidentiality or cost. A
contract that holds a Merkle root of the sorted set lets a guarded
transaction carry a proof of non-membership for its parties instead of the
set: a reader learns nothing beyond that proof, and the cost per transfer
grows with the logarithm of the set size. Shards by digest prefix, one
contract per prefix, let a transaction carry only the shards of its parties:
the cost per transfer falls, and a reader still learns every digest in those
shards. The single contract is the simplest structure whose guard is sound
without contract keys, and its cost is linear in the size of the set.

The key is a party, not an account record. A CIP-0112 account `id` is free
text that its owner chooses, so a block on an `id` does not hold. The token
checks the owner and the provider of each account. A provider authorizes
every movement of the accounts it provides, so a blocked provider blocks all
of them; to block one client of a provider, block the client.

One contract keeps the guard sound, and it bounds the size of the set. A
change carries the set twice and a guarded transaction carries it once, so
the synchronizer's maximum request size limits both. Past that limit no
change fits, not even an unblock, so the `ensure` clause bounds the set by an
admin-chosen `maxEntries`. Each change also invalidates every transaction
prepared against the predecessor, so one choice changes a list of parties:
an update of a screening list is one change, and its audit record is one
exercise. A party already in the target state is skipped, as the
OpenZeppelin EVM and Stellar blocklists do, so a synchronization job sends
the whole list without first computing the difference. A call that changes
nothing keeps the contract, so it invalidates no prepared transaction.

The blocklist stops value from moving between accounts. Withdraw, reject,
cancel, expiry, and owner unlock return locked funds to the account that
locked them, so they stay open for a blocked account, and every later
transfer from that account is refused. This keeps the CIP-0112 section 4.3.3
withdraw after the settlement deadline, and it keeps every pending workflow
recoverable by its own parties.

Settlement checks run in each allocation's settle as well as in the
settlement factory, so a direct `Allocation_Settle` by the admin and the
executors is checked too. The factory forwards only the blocklist entry of
its context to each settle, through the context argument of
`settleBatchImpl`, so no other part of the batch's arguments reaches an
authorizer.

The admin changes the blocker in one step. A two-step handover protects a
role that signs the contract; the blocker only observes it, and the admin
can correct a wrong party at any time. A key rotation of an external blocker
is a topology change that keeps the party, so it needs no ledger change.

More than one party can change one blocklist in two ways. A threshold
blocker is one external party whose changes need k of its n signing keys,
and the topology enforces the threshold. Delegation lets several parties act
alone: the blocker signs a delegation contract once, the admin issues a
scoped authorization grant to each delegate, and the delegation's choices
check the grant and exercise the blocklist choices with the blocker's
authority. Delegation composes the two components in the consuming
application, as `examples/compliance/blocklist-delegation-v1` does, so
`openzeppelin-blocklist-v1` stays independent of
`openzeppelin-scoped-authorization-grant-v1` and deployments with one blocker
vet one package. The admin issues the grants because it already controls the
blocker role and signs the blocklist: it revokes a grant alone, and a grant
adds no confirming participant.

`Blocklist` is a template with no interface, so the component is one package.
A guard reads the blocklist through the template, which it can pin; a frozen
interface would admit implementations that it cannot pin.

A token that needs a blocklist owns its templates and adds the checks, as
`examples/token/token-cip112-custom` does. `openzeppelin-token-cip112-v1`
stays independent of `openzeppelin-blocklist-v1`, because a dependency
between implementation packages needs an architecture decision and an SCU
lineage cannot drop it later.

### Utilities, types, and templates

A component whose choice bodies consumers want to reuse with templates of
their own ships three production packages:

```text
<component>-types-v1   The serializable records its templates store; no
                       templates, no interfaces
<component>-utils      Choice bodies as functions, parameterised over the
                       templates through constructor and policy operations;
                       nothing serializable
<component>-v1         Ready-to-use templates delegating to the utils
```

Nothing executable is stored on the ledger: a pending contract holds records
only and rebuilds its operations when its choice runs. A consumer who owns
their templates depends on the types and utils packages and keeps their own
upgrade lineage. SCU ignores the utils package because it defines nothing
serializable, so the consumer may move to any later utils version, switch to
a fork, or drop it; no contract references its functions. Storing the types
package's records binds a template to that package's lineage, so those
records only ever gain `Optional` fields; a consumer who stores the fields
separately and builds the record per call avoids even that.

A utils package carries no `vN` suffix and versions by semver alone. When an
API or types `-v2` package ships, one utils lineage carries helpers for both
generations, and the generation shows in qualified imports rather than in
the package name. `splice-token-standard-utils` 2.0.0 follows the same
model: it depends on the `-v1` and `-v2` token standard API packages and
bridges them in functions. The cost is that a consumer who takes a utils
release adding `-v2` support also depends on and vets the `-v2` package; a
fix needed by a `-v1`-only consumer is backported on a `1.x` branch.

## Dependency policy

- Implementation packages do not depend on other implementation packages,
  except a component's templates package on its own types package.
  Compose through stable interfaces or in a consuming application instead.
- Shared pure helpers belong in an `openzeppelin-<component>-utils` package
  that defines no templates, interfaces, exceptions, or serializable types.
  A component's templates package may depend on its own utils package.
- Adding a production dependency requires explicit architecture review because
  an SCU lineage cannot later drop or downgrade a dependency other than a
  utility package.
- Third-party DARs are pinned by source, version, package IDs, SHA-256, and
  license in `dars/manifest.yaml`; binaries live in `dars/vendor/` when
  vendoring is needed.
- Upstream interfaces retain their upstream package identity and namespace.

## Naming and public modules

Production package names use an organization prefix and, except for utils
packages, an explicit contract-model generation:

```text
openzeppelin-scoped-authorization-grant-v1
openzeppelin-api-rbac-v1
openzeppelin-rbac-v1
openzeppelin-token-cip112-utils
```

Public modules use matching major-version namespaces, and a utils package
places its modules under `.Utils`:

```daml
OpenZeppelin.ScopedAuthorizationGrantV1
OpenZeppelin.RbacV1
OpenZeppelin.RbacV1.Internal
OpenZeppelin.Api.RbacV1
OpenZeppelin.Token.Cip112.Utils
```

A component that implements a named standard carries the standard as a second
segment of its component name and module namespace: the CIP-0112 token is
`openzeppelin-token-cip112-v1` under `OpenZeppelin.Token.Cip112.V1`. The
`-vN` suffix counts this package's own breaking changes, not the standard's
generation; naming the standard keeps the two numbers apart.
A sibling implementation of another token standard shares the
`token` category and the `OpenZeppelin.Token` namespace without renaming
either.

An API package places its modules under `OpenZeppelin.Api`, the same way the
Splice token standard places its interface modules under `Splice.Api`. The
namespace tells a consumer that the module holds only frozen interface and
exception definitions.

Compatible SCU releases keep the same package name and increment the package
version. A breaking change creates a sibling `-v2` package and a `V2` module
suffix so both generations can coexist while consumers migrate. A utils
package keeps its name across breaking changes and signals them with a new
semver major version. Template names remain stable component terms such as
`AuthorizationGrant` and `RoleGrant`.

`exposed-modules` is not used as an API boundary: export information is not
preserved when a consumer imports a compiled DAR through `data-dependencies`.
`.Internal` is a clear convention, not ledger-enforced access control.

## Release and vetting surface

Every supported release records the production DAR, source commit, package name
and version, main and dependency package IDs, SDK and LF versions, SHA-256,
signature/provenance, license information, changelog, and audit status.

Supported releases must distribute DARs through GitHub Releases and retain them
under `dars/released/` as immutable compatibility baselines. `dars/manifest.yaml`
records package IDs and provenance. Any SCU compatibility claim requires CI
verification against the previous released DAR. The current CI has no released
baseline or upgrade-compatibility check; the release process is tracked in
[RELEASING.md](RELEASING.md).

Participant vetting behavior varies by Canton version and topology. Publishing
the exact package closure lets each operator review and vet the package IDs its
deployment requires. Fine-grained component packages minimize that closure.

## Maturity

```text
research prototype (outside this repository)
  -> library candidate
  -> unaudited release candidate
  -> audited supported release
  -> deprecated with migration and support window
```

Merging a package does not make it stable. Only a tagged release manifest defines
a supported artifact.
