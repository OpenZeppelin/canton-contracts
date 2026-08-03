# DAR artifacts

This directory records binary inputs and outputs that affect reproducibility,
SCU compatibility, and operator vetting.

- `released/` contains immutable OpenZeppelin production DARs copied from tagged
  GitHub Releases.
- `vendor/` contains verified third-party DAR dependencies used for reproducible
  local builds.
- `dars.lock` indexes package names, versions, package IDs, SHA-256 hashes,
  provenance URLs, and licenses.

DPM writes local build output under each package's `.daml/dist` directory.
[RELEASING.md](../RELEASING.md) defines how production artifacts are added here.
