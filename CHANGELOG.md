<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and each production package adheres independently to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Repository

#### Added

- Consumer, package, architecture, release, security, audit, and contribution
  documentation.
- Structural checks and isolated component test entrypoints.
- DAR release, vendor, and lock-file conventions.

#### Changed

- Reorganized the workspace into versioned, independently releasable component
  packages under navigation-only category directories.
- Split the shared test package into isolated, never-released component test
  packages.
- Simplified the test entrypoint to discover component suites and emit native
  JUnit and coverage artifacts.

#### Removed

- Hello World and proof scaffolding.
- Experimental settlement, interoperability, and token-standard mock packages
  from the reusable library release surface.
- Repository-local DPM, Java, and cache environment auto-configuration.

### `openzeppelin-access-control-v1`

#### Changed

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.

### `openzeppelin-ownable-v1`

#### Changed

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.

### `openzeppelin-pausable-v1`

#### Changed

- Renamed the pre-release package and public module into the `v1` lineage
  without changing contract behavior.
