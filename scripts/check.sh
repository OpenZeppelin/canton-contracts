#!/usr/bin/env bash
# Static repository-policy checks. Build and Daml Script execution use DPM
# directly so this check stays fast and produces focused failures.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Trees under policy, as "<source tree>:<test tree>" pairs. Candidates live in
# experiments/ and move to packages/ one component at a time, so both trees are
# checked identically and a tree holding no packages is skipped.
TREES=("packages:test" "experiments:experiments/test")

fail() {
	printf 'check: %s\n' "$*" >&2
	exit 1
}

require_file() {
	[ -f "$ROOT/$1" ] || fail "missing $1"
}

# Print every package manifest in a tree, ignoring build output and an optional
# nested tree. An absent tree prints nothing.
find_manifests() {
	local tree="$1"
	local excluded="${2:-}"
	local exclusion=()

	[ -d "$ROOT/$tree" ] || return 0
	if [ -n "$excluded" ]; then
		exclusion=(-path "$ROOT/$excluded" -prune -o)
	fi

	# The guarded expansion keeps bash 3.2 (macOS default) from treating the
	# empty array as an unbound variable under `set -u`.
	find "$ROOT/$tree" \
		-type d -name .daml -prune -o \
		${exclusion[@]+"${exclusion[@]}"} \
		-name daml.yaml -type f -print
}

for file in \
	README.md ARCHITECTURE.md RELEASING.md CHANGELOG.md CONTRIBUTING.md \
	SECURITY.md AGENTS.md LICENSE multi-package.yaml dars/README.md \
	dars/manifest.yaml audits/README.md examples/README.md \
	experiments/README.md \
	scripts/check-coverage.sh scripts/check-lint.sh scripts/check-sandbox.sh; do
	require_file "$file"
done

if [ -f "$ROOT/daml.yaml" ]; then
	fail "the repository root is a workspace, not a Daml package"
fi

if ! grep -Eq '^sdk-version:[[:space:]]*[^[:space:]]+' "$ROOT/multi-package.yaml"; then
	fail "multi-package.yaml must pin the workspace SDK version"
fi

workspace_sdk="$(sed -n 's/^sdk-version:[[:space:]]*//p' "$ROOT/multi-package.yaml")"

production_manifests=""
test_manifests=""

for tree_pair in "${TREES[@]}"; do
	source_tree="${tree_pair%%:*}"
	test_tree="${tree_pair##*:}"

	production_manifests+="$(find_manifests "$source_tree" "$test_tree")"$'\n'
	test_manifests+="$(find_manifests "$test_tree")"$'\n'
done

production_manifests="$(printf '%s' "$production_manifests" | sed '/^$/d' | sort)"
[ -n "$production_manifests" ] || fail "no production package manifests found"

test_manifests="$(printf '%s' "$test_manifests" | sed '/^$/d' | sort)"
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

while IFS= read -r manifest; do
	if grep -n -E '^[[:space:]]*exposed-modules:' "$manifest"; then
		fail "exposed-modules is not a supported public-API boundary"
	fi
done <<< "$production_manifests"

while IFS= read -r manifest; do
	package_dir="$(dirname "$manifest")"
	package_name="$(sed -n 's/^name:[[:space:]]*//p' "$manifest")"

	case "$package_name" in
	*-test)
		fail "test package ${manifest#"$ROOT/"} must live under a test tree"
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
		# `interface instance` blocks implement an upstream interface and are
		# allowed; only new interface or exception definitions are not.
		if grep -R -n -E --include='*.daml' '^[[:space:]]*(interface|exception)[[:space:]]+' "$package_dir/daml" |
			grep -v -E 'interface[[:space:]]+instance[[:space:]]'; then
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
		fail "package ${manifest#"$ROOT/"} under a test tree must use a -test name"
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
