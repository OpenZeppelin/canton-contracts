# Examples

Integration examples show how to use the library in Daml applications.
Each example builds separately and imports the library DAR through
`data-dependencies`. Policy modules define trusted requirements; application
choices bind the actor and apply the guard.

- [Licensing](licensing-app-v1/): delegate issuance on a registry to an operator.
- [Treasury RBAC](treasury-rbac-v1/): reusable role grants, separate authorities,
  and a proposal–approval–execution workflow.

Examples are reference implementations of library integration, rather than
released library components. Their test packages live under [test/](test/); see
[CONTRIBUTING.md](../CONTRIBUTING.md) for build and test commands.
