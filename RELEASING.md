# Releasing packages

The release process will be defined and validated as part of preparing the first
package release. It will cover package versioning, validation, DAR publication
and provenance, compatibility or migration evidence, and operator guidance.

## License files

A DAR has no place for license files, so each GitHub Release attaches them as
release assets next to the DAR. Every release attaches `LICENSE`.

The token packages also contain Apache-2.0 code. Each of their DARs bundles the
Splice token standard packages from `dars/vendor/` as compiled DALFs, and two of
them contain source derived from the Splice TestTokenV2 example and the Splice
`splice-token-standard-utils` package:

| Package | Apache-2.0 content in the DAR |
|---|---|
| `openzeppelin-token-cip112-types-v1` | Splice DALFs |
| `openzeppelin-token-cip112-utils` | Splice DALFs; `OpenZeppelin.Token.Cip112.Utils.Holding`, `.Transfer`, and `.Allocation` |
| `openzeppelin-token-cip112-v1` | Splice DALFs; `OpenZeppelin.Token.Cip112.V1.Holding` and `.Registry` |

A release of one of these packages:

1. Attaches `LICENSES/Apache-2.0.txt` in addition to `LICENSE`.
2. Records `license: MIT AND Apache-2.0` in its `dars/manifest.yaml` entry.
3. Includes this notice in the release notes:

   ```markdown
   ## License

   This DAR is licensed under MIT, except for the parts listed below, which
   are licensed under the Apache License 2.0 (`Apache-2.0.txt`):

   - The bundled `splice-*` packages, Copyright (c) 2024 Digital Asset
     (Switzerland) GmbH and/or its affiliates, distributed unmodified.
   - Modules marked `SPDX-License-Identifier: MIT AND Apache-2.0`, which
     contain code derived from the Splice TestTokenV2 example or the Splice
     `splice-token-standard-utils` package and modified by OpenZeppelin.
   ```

If the Splice release tag recorded in `dars/manifest.yaml` contains a `NOTICE`
file, the release also attaches that file. Splice `0.8.3` has none.

A package that adds a Splice dependency or Splice-derived source joins the
table above.
