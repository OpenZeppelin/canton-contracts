#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/dpm-env.sh"
DAML_TOOL=""
PROOF_ROOT="$ROOT/proof"

fail() {
	printf 'check-scaffold: %s\n' "$*" >&2
	exit 1
}

require_file() {
	if [ ! -f "$ROOT/$1" ]; then
		fail "missing $1"
	fi
}

reject_production_daml_script() {
	if grep -Eq '(^|[[:space:]-])daml-script($|[[:space:]])' "$ROOT/daml.yaml"; then
		fail "production daml.yaml must not depend on daml-script; keep script code in proof/daml.yaml"
	fi
}

select_daml_tool() {
	case "${OZ_DAML_TOOLCHAIN:-auto}" in
	auto | dpm)
		oz_setup_dpm_env "$ROOT/.cache"
		oz_has_dpm || fail "daml.yaml exists but dpm is not available; install DPM or expose ~/.dpm/bin/dpm"
		oz_has_java_21 || fail "Java 21 runtime is not available; install or expose a JDK before running dpm build"
		DAML_TOOL="dpm"
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
require_file scripts/manual-workflow-test.sh
require_file scripts/check-no-github-workflows.sh
require_file daml/HelloWorld/HelloWorld.daml
require_file proof/daml.yaml
require_file proof/daml/HelloWorld/Proof.daml

"$ROOT/scripts/check-no-github-workflows.sh"

if [ -f "$ROOT/daml.yaml" ]; then
	reject_production_daml_script
	select_daml_tool
	printf 'check-scaffold: running %s build for production package\n' "$DAML_TOOL"
	(cd "$ROOT" && "$DAML_TOOL" build)
	printf 'check-scaffold: running %s build for proof package\n' "$DAML_TOOL"
	(cd "$PROOF_ROOT" && "$DAML_TOOL" build)
else
	require_file daml.yaml.placeholder
	printf 'check-scaffold: SKIP daml build: daml.yaml is not committed yet for the accepted M0 3.4.11 proof baseline\n'
fi

printf 'check-scaffold: OK\n'
