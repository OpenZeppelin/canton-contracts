#!/usr/bin/env bash
#
# Top-level validation gate for the OpenZeppelin Daml contracts library.
#
# Builds every package in dependency order, then runs the Daml Script suites and
# captures a coverage report for each:
#
#   * `test/`   — the spine suite: access-control / ownable / pausable AND the
#                 CIP-0112 settlement engine (Cip112Settlement).
#   * `interop/`— the CIP-0086/0103/0104 interop proof scripts. `interop` is NOT
#                 a data-dependency of `test/` (its consumer facade template lives
#                 next to its scripts), so without this gate its scripts would
#                 never run under `cd test && dpm test` and could rot silently.
#
# CI (.github/workflows/ci.yml) invokes this script. Coverage reports are written
# under `test-reports/` (git-ignored) so the "added testing and coverage reports"
# delivery criterion is met per run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/dpm-env.sh"

oz_setup_dpm_env "$ROOT/.cache"
oz_has_dpm || {
	printf 'run-tests: dpm is not available; install DPM or expose ~/.dpm/bin/dpm\n' >&2
	exit 1
}
oz_has_java_21 || {
	printf 'run-tests: Java 21 runtime is not available; install or expose a JDK\n' >&2
	exit 1
}

REPORTS="$ROOT/test-reports"
mkdir -p "$REPORTS"

printf 'run-tests: building all packages\n'
(cd "$ROOT" && dpm build --all)

# `dpm test --show-coverage` prints per-package template/choice/script coverage;
# tee it to a report file. Falls back to a plain `dpm test` if the flag is not
# supported by the installed DPM so the gate never silently skips the suite.
run_suite () { # $1 package dir  $2 report basename
	local dir="$1" name="$2"
	printf 'run-tests: running %s suite (%s/)\n' "$name" "$dir"
	if ! (cd "$ROOT/$dir" && dpm test --show-coverage) | tee "$REPORTS/$name-coverage.txt"; then
		printf 'run-tests: --show-coverage unsupported, retrying without it\n' >&2
		(cd "$ROOT/$dir" && dpm test) | tee "$REPORTS/$name-coverage.txt"
	fi
}

run_suite test spine
run_suite interop interop

printf 'run-tests: OK (coverage reports in test-reports/)\n'
