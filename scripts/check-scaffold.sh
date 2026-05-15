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
		auto)
			if command -v dpm >/dev/null 2>&1; then
				printf 'dpm'
			elif command -v daml >/dev/null 2>&1; then
				printf 'daml'
			else
				fail "daml.yaml exists but neither dpm nor daml is on PATH"
			fi
			;;
		dpm)
			command -v dpm >/dev/null 2>&1 || fail "OZ_DAML_TOOLCHAIN=dpm but dpm is not on PATH"
			printf 'dpm'
			;;
		daml)
			command -v daml >/dev/null 2>&1 || fail "OZ_DAML_TOOLCHAIN=daml but daml is not on PATH"
			printf 'daml'
			;;
		*)
			fail "unsupported OZ_DAML_TOOLCHAIN=${OZ_DAML_TOOLCHAIN}; expected auto, dpm, or daml"
			;;
	esac
}

require_file README.md
require_file AGENTS.md
require_file LICENSE
require_file .github/workflows/check.yml
require_file daml/HelloWorld/HelloWorld.daml
require_file daml.yaml.placeholder

if [ -f "$ROOT/daml.yaml" ]; then
	tool="$(select_daml_tool)"
	printf 'check-scaffold: running %s build\n' "$tool"
	(cd "$ROOT" && "$tool" build)
else
	printf 'check-scaffold: SKIP daml build: daml.yaml is absent until SDK pinning ADR is accepted\n'
fi

printf 'check-scaffold: OK\n'
