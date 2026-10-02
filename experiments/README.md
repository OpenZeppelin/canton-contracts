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

No component is under evaluation here at the moment. When one is, its package
`README.md` states what it provides and, more importantly, the authority and
canonical-instance problems it does not solve.

## Build and test

These packages are part of the workspace build, so they keep compiling and their
tests keep running as the repository changes. From the repository root:

```sh
dpm build --all
```

Each component's isolated test package lives under [`test/`](test/) and
data-depends on the built DAR.

## What to use them for

Reading the code, comparing modeling approaches, and giving feedback on the
design before it is rebuilt. Open an issue or discussion if a shape here is
wrong or a Canton constraint is being modeled the hard way. That feedback is
worth more now than after the redesign.

Library candidates live under [packages/](../packages/). The
[repository README.md](../README.md) describes their status, package boundaries,
and compatibility model.
