# Authorization tests

Tests import the compiled library DAR. The licensing and treasury suites also
import their consumer DARs, so application code is checked across the same
package boundary used by an integrator.

## Coverage

| Area | Checks |
|---|---|
| Issuance and authority | Issuer-only creation and revocation; grantee-only use and renunciation; implicit Archive; authority/grantee equality |
| Actor binding | Forged actors, stolen grants, native fetch rejection, read access without authority, and grantee authority delegated by a consumer signatory |
| Scope | Every field independently; combined mismatch metadata; exact CID, logical-only, and shared logical scopes; negative epoch rejection, zero epoch use, epoch reuse and future epochs |
| Time | Unbounded, one-sided, and bounded windows; inclusive start and exclusive end; microsecond edges and windows; expired-at-creation grants; malformed and empty intervals |
| Validation results | Both helpers return the fetched grant on success; returned failure IDs and metadata; first-mismatch order; no Use on checks; fallback records only the selected grant; unavailable CIDs still abort; checks do not authenticate the actor |
| Typed policies | Permission-to-authority mapping; shared issuance and guard requirements; matching failures; logical and instance binding; consuming choices; returned grant and single Use event; conditional fallback |
| Lifecycle | Reuse, independent duplicate grants, revocation, renunciation, stale disclosures, atomic command ordering |
| Failures | All five guard failures remain uncatchable; first-mismatch order and metadata |
| Use event | Nested exercise, direct-use limits, full-transaction and caught-exception rollback, rechecking after catch, no issuer authority leaking into sibling effects |
| Licensing | Issuance, visibility, administration, duplicate registry IDs, policy rotation, grant lifecycle, time bounds, license revocation; removing an operator grant preserves issued licenses |
| Treasury | Role-to-authority mapping, role reuse, actor checks, duty separation, stage revocation/expiry, wrong permission, policy binding and cleanup; earlier role revocation preserves pending work |
| Trust limits | Direct creation by full signatory sets; receipt payloads are not proof of prior choices; scope CIDs do not prove liveness |

The CI coverage gate requires every library and example template and choice,
including implicit Archive, to be exercised. Daml does not report source-line
or branch coverage. Negative-only test probes intentionally have no successful
exercise; they are test fixtures rather than production code.

These suites do not cover independent ledger/record-time skew, external signing,
multi-participant races, raw gRPC error metadata, or per-party update filters.
They establish sequential and same-transaction ordering, not distributed
race-freedom. There are no load or traffic-cost benchmarks. Release qualification
still requires independent security review and deployment-specific validation.

## Commands

From the repository root:

```sh
dpm build --all
DAML_PACKAGE=test/scoped-authorization-grant-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/licensing-app-v1-test dpm test --all --show-coverage
DAML_PACKAGE=examples/treasury-rbac-v1-test dpm test --all --show-coverage
```

The sandbox suites run selected scenarios against a real local Canton Ledger
API, including structured failures, nested use events, disclosure, caught-exception
rollback, ledger-time boundaries, and both application workflows:

```sh
OZ_SANDBOX_SUITE=authorization scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=licensing scripts/check-sandbox.sh
OZ_SANDBOX_SUITE=treasury scripts/check-sandbox.sh
```

Each invocation starts a fresh static-time ledger and stops it on exit. Run local
sandbox suites sequentially: `OZ_LEDGER_PORT` changes only the Ledger API port;
the other API ports keep their defaults. These are single-participant integration
tests, not Global Synchronizer deployment tests.
