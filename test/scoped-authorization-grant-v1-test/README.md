# Authorization tests

Tests import the compiled library DAR. The licensing and treasury suites also
import their consumer DARs, so application code is checked across the same
package boundary used by an integrator.

## Coverage

| Area | Checks |
|---|---|
| Issuance and authority | Issuer-only creation and revocation; grantee-only use and renunciation; implicit Archive; authority/grantee equality |
| Actor binding | Forged actors, stolen grants, disclosed contracts, and read access without controller authority |
| Scope | Every field independently; combined mismatch metadata; exact CID, logical-only, and shared logical scopes |
| Time | Unbounded and bounded windows; inclusive start, exclusive end; malformed and empty intervals |
| Lifecycle | Reuse, independent duplicate grants, revocation, renunciation, stale disclosures, atomic command ordering |
| Use event | Nested exercise, direct-use limits, rollback after business failure, no issuer authority leaking into sibling effects |
| Licensing | Issuance, visibility, administration, duplicate registry IDs, policy rotation, grant lifecycle, time bounds, license revocation |
| Treasury | Role-to-authority mapping, multi-payment role reuse, every stage's actor check, duty separation, stage revocation/expiry, policy binding and cleanup |
| Trust limits | Direct creation by full signatory sets; receipt payloads are not proof of prior choices; scope CIDs do not prove liveness |

The CI coverage gate requires every library and example template and choice,
including implicit Archive, to be exercised. Daml does not report source-line
or branch coverage. Negative-only test probes intentionally have no successful
exercise; they are test fixtures rather than production code.

The in-memory tests establish sequential and same-transaction ordering, not
distributed race-freedom. There are no multi-participant, external-signing,
load, or traffic-cost benchmarks in these suites. Release qualification still
requires independent security review and deployment-specific validation.

## Commands

From the repository root:

```sh
dpm build --all
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/test/licensing-app-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/test/treasury-rbac-v1-test dpm test --all --show-coverage
```

The sandbox suites run selected scenarios against a real local Canton Ledger
API, including structured failures, nested use events, disclosure, rollback,
and both application workflows:

```sh
OZ_SANDBOX_SUITE=authorization scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=licensing scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=treasury scripts/check-sandbox.sh
```

Each invocation starts a fresh static-time ledger and stops it on exit. Use
`OZ_LEDGER_PORT` to select another port. These are single-participant integration
tests, not Global Synchronizer deployment tests.
