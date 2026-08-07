# Packages

Released Daml components. A package moves here only after it has gone through
the review, interface, and upgrade decisions described in the
[repository README.md](../README.md) and [ARCHITECTURE.md](../ARCHITECTURE.md):
one package per release unit, a frozen `-api-vN` package where interfaces are
involved, and a `V2` sibling for breaking changes. Once released, a package's
module names, template and choice signatures, and package identity are stable
within its major version.

## Contents

No component has been released yet. Early-stage candidates live under
[`experiments/`](../experiments/); see [experiments/README.md](../experiments/README.md)
for their status and warnings.

## Release process

[RELEASING.md](../RELEASING.md) describes how a component graduates into this
directory. Released DAR baselines are recorded under
[`dars/released/`](../dars/released/), and audit reports keyed to exact
releases live under [`audits/`](../audits/).
