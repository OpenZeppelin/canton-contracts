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

An interface choice body calls a method of the implementing template, and the
template implements that method with a call to a function in the
implementation package. In Timelock, `Timelock_Apply` calls `applyImpl`, and
the consumer implements `applyImpl` with one call to `applyOperation`. The
Splice token standard interfaces use the same pattern (e.g., see
[`TransferFactory_Transfer`](https://github.com/hyperledger-labs/splice/blob/69b43eb761e38695052c983715aa855c8cb207fc/token-standard/splice-api-token-transfer-instruction-v1/daml/Splice/Api/Token/TransferInstructionV1.daml#L175-L198)). A fix to
a check in the function is a new version of the implementation package, and the
consumer picks it up through an SCU of its own package. A check in a frozen choice body cannot
be fixed: SCU cannot remove an interface instance, so the faulty choice stays
callable on every implementing contract. The cost is that the interface does not
enforce the checks. They run because the consumer's method calls the function.

### Components without templates

Some components ship no template of their own. `Pausable` is the model: the
`pause` flag is a field of the consumer's template, because a guard that reads
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

Timelock ships no template for a different reason. A scheduled operation is a
contract of the consumer's own template, typed by its fields, because a Daml
choice applies typed contract data rather than forwarding an encoded call.

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
migration that copies the contract state.

## Dependency policy

- Implementation packages do not depend on other implementation packages.
  Compose through stable interfaces or in a consuming application instead.
- Shared pure helpers belong in a utility package that defines no templates,
  interfaces, exceptions, or serializable public state.
- Adding a production dependency requires explicit architecture review because
  an SCU lineage cannot later drop or downgrade a dependency other than a
  utility package.
- Third-party DARs are pinned by source, version, package IDs, SHA-256, and
  license in `dars/manifest.yaml`; binaries live in `dars/vendor/` when
  vendoring is needed.
- Upstream interfaces retain their upstream package identity and namespace.

## Naming and public modules

Production package names use an organization prefix and an explicit
contract-model generation:

```text
openzeppelin-scoped-authorization-grant-v1
openzeppelin-api-rbac-v1
openzeppelin-rbac-v1
```

Public modules use matching major-version namespaces:

```daml
OpenZeppelin.ScopedAuthorizationGrantV1
OpenZeppelin.RbacV1
OpenZeppelin.RbacV1.Internal
OpenZeppelin.Api.RbacV1
```

An API package places its modules under `OpenZeppelin.Api`, the same way the
Splice token standard places its interface modules under `Splice.Api`. The
namespace tells a consumer that the module holds only frozen interface and
exception definitions.

Compatible SCU releases keep the same package name and increment the package
version. A breaking change creates a sibling `-v2` package and a `V2` module
suffix so both generations can coexist while consumers migrate. Template names
remain stable component terms such as `AuthorizationGrant` and `RoleGrant`.

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
