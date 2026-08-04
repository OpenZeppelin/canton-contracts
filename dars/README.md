# DAR artifacts

This directory records binary inputs and outputs that affect reproducibility,
SCU compatibility, and operator vetting.

- `released/` contains immutable OpenZeppelin production DARs copied from tagged
  GitHub Releases.
- `vendor/` contains verified third-party DAR dependencies used for reproducible
  local builds.
- `manifest.yaml` indexes every recorded DAR and its provenance.

Each manifest entry contains:

| Field | Meaning |
|---|---|
| `kind` | `release` for an OpenZeppelin DAR or `vendor` for a third-party DAR |
| `package` | Daml package name |
| `version` | Daml package version |
| `file` | Repository-relative path to the DAR |
| `main-package-id` | Package ID of the DAR's main package |
| `package-ids` | Main package ID and complete transitive package-ID closure |
| `sha256` | Lowercase SHA-256 digest of the DAR file |
| `source` | Canonical release or upstream artifact URL |
| `license` | SPDX license identifier |

These values let consumers verify downloaded artifacts and give participant
operators the exact package IDs to review for vetting.
