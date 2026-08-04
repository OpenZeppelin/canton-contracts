# Security policy

## Security response

OpenZeppelin publishes source code and versioned DAR artifacts, but does not
operate or control adopter participant nodes. When a vulnerability is identified,
OpenZeppelin will investigate affected package IDs, publish a corrected release
where technically possible, provide Smart Contract Upgrade (SCU) compatibility
or migration evidence, and communicate required operator actions. Applying the
remediation remains the responsibility of application developers, participant
operators, and counterparties. Some classes of Daml contract or interface defects
may require explicit contract migration and may not be recoverable after
exploitation.

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/OpenZeppelin/canton-contracts/security/advisories/new).
Do not disclose a suspected vulnerability through a public issue, discussion,
or pull request before coordinated disclosure.

Include the affected package and version or source commit, reproduction steps,
expected and observed authorization behavior, ledger/topology assumptions, and
any known impact. OpenZeppelin will acknowledge and triage the report through
the private advisory.

## Scope

Security review must include the consuming application's canonical-contract
selection, resource binding, party authorization, disclosure, privacy, package
dependencies, participant configuration, and vetting policy. A library package
cannot establish these application-level assumptions by itself.
