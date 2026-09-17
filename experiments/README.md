# Experiments

Early-stage Daml packages that are not ready for application use. They compile
and express a working design, but they have not gone through the review,
interface, and upgrade decisions that a released component under `packages/`
must satisfy.

> [!WARNING]
> Do not depend on anything in this directory. These packages will be redesigned
> and rewritten before they appear under `packages/`, and the rewrite can be expected
> to change module names, template and choice signatures, and package identity.
> They carry no upgrade path, no compatibility guarantee, and no audit.

## Contents

| Component | Package | Public module | Solidity analogue |
|---|---|---|---|
| [Access Control](access/access-control-v1/) | `openzeppelin-access-control-v1` | `OpenZeppelin.AccessControlV1` | `AccessControl`, `AccessControlDefaultAdminRules` |
| [Ownable](access/ownable-v1/) | `openzeppelin-ownable-v1` | `OpenZeppelin.OwnableV1` | `Ownable2Step` |
| [Token CIP-0112](token/tokenCIP112-v1/) | `openzeppelin-tokenCIP112-v1` | `OpenZeppelin.TokenCIP112V1` | `ERC20` (partial) |

Each package README.md states what the package provides and, more importantly, the
authority and canonical-instance problems it does not solve. Read those warnings
before drawing conclusions from the code.

## Build and test

These packages are part of the workspace build, so they keep compiling and their
tests keep running as the repository changes. From the repository root:

```sh
dpm build --all
DAML_PACKAGE=experiments/test/ownable-v1 dpm test --all --show-coverage
```

Each component's isolated test package lives under [`test/`](test/) and
data-depends on the built DAR. Build one component on its own with:

```sh
DAML_PACKAGE=experiments/access/ownable-v1 dpm build
```

## What to use them for

Reading the code, comparing modeling approaches, and giving feedback on the
design before it is rebuilt. Open an issue or discussion if a shape here is
wrong or a Canton constraint is being modeled the hard way. That feedback is
worth more now than after the redesign.

No component has graduated to `packages/` yet, so there is nothing here you can
safely build an application on. The [repository README.md](../README.md) covers
the package and compatibility model a component must satisfy before it does.
