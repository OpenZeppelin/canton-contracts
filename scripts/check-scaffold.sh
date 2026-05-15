#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
	printf 'check-scaffold: %s\n' "$*" >&2
	exit 1
}

require_file() {
	if [ ! -f "$ROOT/$1" ]; then
		fail "missing $1"
	fi
}

select_daml_tool() {
	case "${OZ_DAML_TOOLCHAIN:-auto}" in
		auto|dpm)
			command -v dpm >/dev/null 2>&1 || fail "daml.yaml exists but dpm is not on PATH"
			printf 'dpm'
			;;
		daml)
			fail "OZ_DAML_TOOLCHAIN=daml is not accepted for the M0 3.4.11 proof baseline; use dpm"
			;;
		*)
			fail "unsupported OZ_DAML_TOOLCHAIN=${OZ_DAML_TOOLCHAIN}; expected auto or dpm"
			;;
	esac
}

require_file README.md
require_file AGENTS.md
require_file LICENSE
require_file .github/workflows/check.yml
require_file daml/HelloWorld/HelloWorld.daml

if [ -f "$ROOT/daml.yaml" ]; then
	tool="$(select_daml_tool)"
	printf 'check-scaffold: running %s build\n' "$tool"
	(cd "$ROOT" && "$tool" build)
else
	require_file daml.yaml.placeholder
	printf 'check-scaffold: SKIP daml build: daml.yaml is not committed yet for the accepted M0 3.4.11 proof baseline\n'
fi

printf 'check-scaffold: OK\n'
