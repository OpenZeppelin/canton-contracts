#!/usr/bin/env bash
# CI-only orchestration for linting every Daml package declared by the workspace.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
	printf 'lint: %s\n' "$*" >&2
	exit 1
}

package_paths="$(sed -n 's/^[[:space:]]*-[[:space:]]*//p' multi-package.yaml)" ||
	fail "failed to read package paths from multi-package.yaml"
[ -n "$package_paths" ] || fail "multi-package.yaml declares no packages"

package_count=0
while IFS= read -r package_path; do
	[ -f "$package_path/daml.yaml" ] || fail "missing $package_path/daml.yaml"

	printf 'lint: checking %s\n' "$package_path"
	DAML_PACKAGE="$package_path" dpm damlc lint
	package_count=$((package_count + 1))
done <<< "$package_paths"

printf 'lint: OK (%d packages)\n' "$package_count"
