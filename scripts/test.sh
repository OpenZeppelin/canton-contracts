#!/usr/bin/env bash
# Build every package and run each isolated test suite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v dpm >/dev/null 2>&1 || {
	printf 'test: dpm is required; install it and add it to PATH\n' >&2
	exit 1
}

REPORTS="$ROOT/test-reports"
mkdir -p "$REPORTS"

printf 'test: building all packages\n'
(cd "$ROOT" && dpm build --all)

run_suite() {
	local package_dir="$1"
	local report_name=""

	report_name="$(basename "$package_dir")"

	printf 'test: running %s suite\n' "$report_name"
	(
		cd "$package_dir"
		dpm test \
			--show-coverage \
			--junit "$REPORTS/$report_name-junit.xml" \
			--save-coverage "$REPORTS/$report_name.coverage"
	)
}

suite_count=0
while IFS= read -r manifest; do
	run_suite "$(dirname "$manifest")"
	suite_count=$((suite_count + 1))
done < <(find "$ROOT/test" -type d -name .daml -prune -o -name daml.yaml -type f -print | sort)

[ "$suite_count" -gt 0 ] || {
	printf 'test: no test packages found under test/\n' >&2
	exit 1
}

printf 'test: OK (%d suites; reports in test-reports/)\n' "$suite_count"
