#!/usr/bin/env bash
# CI-only orchestration for the consumer examples. Each example integrates a
# production DAR through data-dependencies and carries a Daml Script that runs
# its lifecycle, so running them proves the published API works from outside
# the workspace.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
	printf 'examples: %s\n' "$*" >&2
	exit 1
}

manifests="$(find examples -type d -name .daml -prune -o -name daml.yaml -type f -print | sort)" ||
	fail "failed to discover example package manifests"
[ -n "$manifests" ] || fail "no example package manifests found"

example_count=0
while IFS= read -r manifest; do
	package_dir="$(dirname "$manifest")"

	grep -Eq '^[[:space:]]*-[[:space:]]*\.\./.+\.dar$' "$manifest" ||
		fail "example $package_dir must data-depend on a production DAR"

	printf 'examples: running %s\n' "$package_dir"
	DAML_PACKAGE="$package_dir" dpm test
	example_count=$((example_count + 1))
done <<< "$manifests"

printf 'examples: OK (%d examples)\n' "$example_count"
