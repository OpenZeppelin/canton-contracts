#!/usr/bin/env bash
# CI-only orchestration for production package tests and DPM coverage reports.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REPORTS="test-reports"
mkdir -p "$REPORTS"

# Trees under policy as "<source tree>:<test tree>" pairs; keep in sync with
# scripts/check.sh.
TREES=("packages:test" "experiments:experiments/test")

fail() {
	printf 'coverage: %s\n' "$*" >&2
	exit 1
}

check_zero() {
	local report="$1"
	local metric="$2"
	local value=""

	value="$(sed -n "s/^  ${metric}: //p" "$report")"
	[ -n "$value" ] || fail "DPM metric not found in $report: $metric"
	[ "$value" -eq 0 ] || fail "$metric: $value ($report)"
}

package_count=0

for tree_pair in "${TREES[@]}"; do
	source_tree="${tree_pair%%:*}"
	test_tree="${tree_pair##*:}"

	[ -d "$source_tree" ] || continue
	production_manifests="$(find "$source_tree" -type d -name .daml -prune -o -path "$test_tree" -prune -o -name daml.yaml -type f -print | sort)" ||
		fail "failed to discover production package manifests under $source_tree"
	[ -n "$production_manifests" ] || continue

	while IFS= read -r manifest; do
		package_dir="$(dirname "$manifest")"
		component="$(basename "$package_dir")"
		test_package="$test_tree/$component"
		test_manifest="$test_package/daml.yaml"
		coverage_report="$REPORTS/$component-coverage.txt"

		[ -f "$test_manifest" ] ||
			fail "missing test package for $package_dir: $test_manifest"
		dar_dir="$(realpath --relative-to="$test_package" "$package_dir")/.daml/dist/"
		grep -Fq "$dar_dir" "$test_manifest" ||
			fail "$test_manifest must data-depend on $package_dir"

		printf 'coverage: testing %s\n' "$component"
		# Report paths are absolute: dpm resolves --save-coverage against the package
		# directory and --junit against the working directory.
		DAML_PACKAGE="$test_package" dpm test \
			--all \
			--show-coverage \
			--junit "$ROOT/$REPORTS/$component-junit.xml" \
			--save-coverage "$ROOT/$REPORTS/$component.coverage" \
			| tee "$coverage_report"

		check_zero "$coverage_report" "external templates never created"
		check_zero "$coverage_report" "external template choices never exercised"
		check_zero "$coverage_report" "external interface choices never exercised"

		package_count=$((package_count + 1))
	done <<< "$production_manifests"
done

[ "$package_count" -gt 0 ] || fail "no production package manifests found"

printf 'coverage: OK (%d production packages)\n' "$package_count"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### Daml production coverage"
		echo
		echo "All $package_count production packages have complete template and choice coverage."
		echo
		echo "Daml reports template/choice coverage, not source-line or branch coverage."
	} >> "$GITHUB_STEP_SUMMARY"
fi
