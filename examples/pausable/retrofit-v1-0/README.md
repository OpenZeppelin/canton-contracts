# Pausable Retrofit Baseline

Version `1.0.0` of the account template used by the
[Pausable retrofit example](../retrofit-v1-1/). It supports withdrawals without
a pause switch. Version `1.1.0` adds the Pausable interface and guards through
Smart Contract Upgrade.

The shared [`retrofit-test`](../retrofit-test/) package imports both versions
and tests the upgrade with active contracts.

From the repository root:

```sh
dpm build --all
DAML_PACKAGE=examples/pausable/retrofit-test dpm test --all
```
