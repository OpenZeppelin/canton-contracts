#!/usr/bin/env bash
# Static repository-policy checks. Build and Daml Script execution use DPM
# directly so this check stays fast and produces focused failures.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Trees under policy. Every component currently lives in experiments/ as a
# pre-release candidate; a component graduating to packages/ moves both values.
SOURCE_TREE="experiments"
TEST_TREE="experiments/test"

fail() {
	printf 'check: %s\n' "$*" >&2
	exit 1
}

require_file() {
	[ -f "$ROOT/$1" ] || fail "missing $1"
}

for file in \
	README.md ARCHITECTURE.md RELEASING.md CHANGELOG.md CONTRIBUTING.md \
	SECURITY.md AGENTS.md LICENSE multi-package.yaml dars/README.md \
	dars/manifest.yaml audits/README.md examples/README.md \
	experiments/README.md \
	scripts/check-coverage.sh scripts/check-lint.sh; do
	require_file "$file"
done

if [ -f "$ROOT/daml.yaml" ]; then
	fail "the repository root is a workspace, not a Daml package"
fi

[ -d "$ROOT/$TEST_TREE" ] || fail "missing $TEST_TREE directory"

if ! grep -Eq '^sdk-version:[[:space:]]*[^[:space:]]+' "$ROOT/multi-package.yaml"; then
	fail "multi-package.yaml must pin the workspace SDK version"
fi

workspace_sdk="$(sed -n 's/^sdk-version:[[:space:]]*//p' "$ROOT/multi-package.yaml")"

production_manifests="$(find "$ROOT/$SOURCE_TREE" -path "$ROOT/$TEST_TREE" -prune -o -name daml.yaml -type f -print | sort)" ||
	fail "failed to discover production package manifests"
[ -n "$production_manifests" ] || fail "no production package manifests found"

test_manifests="$(find "$ROOT/$TEST_TREE" -name daml.yaml -type f | sort)" ||
	fail "failed to discover test package manifests"
[ -n "$test_manifests" ] || fail "no test package manifests found"

for manifest_list in "$production_manifests" "$test_manifests"; do
	while IFS= read -r manifest; do
		package_sdk="$(sed -n 's/^sdk-version:[[:space:]]*//p' "$manifest")"
		[ "$package_sdk" = "$workspace_sdk" ] ||
			fail "${manifest#"$ROOT/"} sdk-version must match multi-package.yaml"
	done <<< "$manifest_list"
done

package_paths="$(sed -n 's/^[[:space:]]*-[[:space:]]*//p' "$ROOT/multi-package.yaml")" ||
	fail "failed to read package paths from multi-package.yaml"
[ -n "$package_paths" ] || fail "multi-package.yaml declares no packages"

while IFS= read -r package_path; do
	require_file "$package_path/daml.yaml"
done <<< "$package_paths"

if grep -R -n -E --include='daml.yaml' '^[[:space:]]*exposed-modules:' "$ROOT/$SOURCE_TREE"; then
	fail "exposed-modules is not a supported public-API boundary"
fi

while IFS= read -r manifest; do
	package_dir="$(dirname "$manifest")"
	package_name="$(sed -n 's/^name:[[:space:]]*//p' "$manifest")"

	case "$package_name" in
	*-test)
		fail "test package ${manifest#"$ROOT/"} must live under $TEST_TREE/"
		;;
	esac

	if grep -Eq '(^|[[:space:]-])daml-script($|[[:space:]])' "$manifest"; then
		fail "production package ${manifest#"$ROOT/"} depends on daml-script"
	fi

	if [[ "$package_name" == *-api-v* ]]; then
		if grep -R -n -E --include='*.daml' '^[[:space:]]*template[[:space:]]+' "$package_dir/daml"; then
			fail "API package ${manifest#"$ROOT/"} defines templates"
		fi
	else
		if grep -R -n -E --include='*.daml' '^[[:space:]]*(interface|exception)[[:space:]]+' "$package_dir/daml"; then
			fail "implementation package ${manifest#"$ROOT/"} defines interfaces or exceptions; create a frozen -api-vN package"
		fi
	fi

	require_file "${package_dir#"$ROOT/"}/README.md"
done <<< "$production_manifests"

while IFS= read -r manifest; do
	package_name="$(sed -n 's/^name:[[:space:]]*//p' "$manifest")"
	package_version="$(sed -n 's/^version:[[:space:]]*//p' "$manifest")"

	case "$package_name" in
	*-test)
		;;
	*)
		fail "package ${manifest#"$ROOT/"} under $TEST_TREE/ must use a -test name"
		;;
	esac

	[ "$package_version" = "0.0.0" ] ||
		fail "test package ${manifest#"$ROOT/"} must use version 0.0.0"

	grep -Eq '(^|[[:space:]-])daml-script($|[[:space:]])' "$manifest" ||
		fail "test package ${manifest#"$ROOT/"} must depend on daml-script"

	grep -Eq '^[[:space:]]*-[[:space:]]*\.\./\.\./.+\.dar$' "$manifest" ||
		fail "test package ${manifest#"$ROOT/"} must data-depend on a production DAR"
done <<< "$test_manifests"

printf 'check: OK\n'
