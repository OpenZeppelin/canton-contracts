# DAR artifacts

This directory records binary inputs and outputs that affect reproducibility,
SCU compatibility, and operator vetting.

- `released/` contains immutable OpenZeppelin production DARs copied from tagged
  GitHub Releases. It never contains test or example DARs.
- `vendor/` contains verified third-party DAR dependencies when a remote source
  cannot be used reliably during a build.
- `dars.lock` indexes package names, versions, package IDs, SHA-256 hashes,
  provenance URLs, and licenses.

Generated `.daml/dist` output does not belong here. Follow `RELEASING.md` before
adding an artifact.
