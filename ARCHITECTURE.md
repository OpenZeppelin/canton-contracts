# Architecture

## Product boundary

`canton-contracts` contains reusable, on-ledger Daml components. It does not
contain grant evidence, reference-implementation business logic, research
prototypes, interoperability experiments, or local lookalikes of upstream
Canton standards.

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

Access Control, Ownable, and Pausable remain separate packages even though they
are often used together. Combining them would force every consumer and operator
to accept the whole dependency, audit, upgrade, and vetting surface.

## Interfaces and implementations

Daml interfaces and exceptions are not SCU-upgradeable. A package that defines
them beside templates prevents those templates from benefiting from SCU.

When a component defines an interface, use two production packages:

```text
<component>-api-v1     Frozen interfaces, exceptions, and API types; no templates
<component>-v1         Templates implementing the API
<component>-test       Daml Script tests; never released
```

API packages may depend only on other API packages. A template-only component
ships one implementation package; empty API packages add ceremony without an
upgrade or interoperability benefit.

The current three components define templates and functions but no Daml
interfaces, so each presently has one production package.

## Dependency policy

- Implementation packages do not depend on other implementation packages.
  Compose through stable interfaces or in a consuming application instead.
- Shared pure helpers belong in a utility package that defines no templates,
  interfaces, exceptions, or serializable public state.
- Adding a production dependency requires explicit architecture review because
  an SCU lineage cannot later drop or downgrade that dependency.
- Third-party DARs are pinned by source, version, package IDs, SHA-256, and
  license in `dars/manifest.yaml`; binaries live in `dars/vendor/` when
  vendoring is needed.
- Upstream interfaces retain their upstream package identity and namespace.

## Naming and public modules

Production package names use an organization prefix and an explicit
contract-model generation:

```text
openzeppelin-ownable-v1
openzeppelin-rbac-api-v1
openzeppelin-rbac-v1
```

Public modules use matching major-version namespaces:

```daml
OpenZeppelin.OwnableV1
OpenZeppelin.RbacV1
OpenZeppelin.RbacV1.Internal
```

Compatible SCU releases keep the same package name and increment the package
version. A breaking change creates a sibling `-v2` package and a `V2` module
suffix so both generations can coexist while consumers migrate. Template names
remain stable component terms such as `Ownership` and `RoleGrant`.

`exposed-modules` is not used as an API boundary: export information is not
preserved when a consumer imports a compiled DAR through `data-dependencies`.
`.Internal` is a clear convention, not ledger-enforced access control.

## Release and vetting surface

Every supported release records the production DAR, source commit, package name
and version, main and dependency package IDs, SDK and LF versions, SHA-256,
signature/provenance, license information, changelog, and audit status.

Release DARs are distributed through GitHub Releases and retained under
`dars/released/` as immutable compatibility baselines. `dars/manifest.yaml` is
the reviewable package-ID and provenance index. CI verifies a candidate against
the previous released DAR before claiming SCU compatibility.

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
