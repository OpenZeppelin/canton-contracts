#!/usr/bin/env bash
#
# Sandbox validation gate: runs selected scripts
# against a real local Canton ledger over the Ledger API gRPC endpoint,
# instead of the in-memory ledger that `dpm test` uses.
#
# Static time supports the suites' explicit validity-boundary checks. Each
# suite allocates fresh parties and advances the shared clock monotonically.
#
# To target an already-running ledger instead of the script-managed sandbox,
# set OZ_USE_EXTERNAL_LEDGER=1 together with OZ_LEDGER_HOST / OZ_LEDGER_PORT.
# Use a fresh external static-time ledger for each suite. Scripts that advance
# time run last. OZ_SANDBOX_SUITE selects token (default), authorization,
# licensing, or treasury.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v dpm >/dev/null 2>&1 || {
	printf 'check-sandbox: dpm is not available\n' >&2
	exit 1
}
command -v java >/dev/null 2>&1 || {
	printf 'check-sandbox: Java is not available\n' >&2
	exit 1
}
command -v lsof >/dev/null 2>&1 || {
	printf 'check-sandbox: lsof is not available\n' >&2
	exit 1
}

java_version="$(java -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')"
[ -n "$java_version" ] && [ "$java_version" -ge 21 ] || {
	printf 'check-sandbox: Java 21 or newer is required\n' >&2
	exit 1
}

SUITE="${OZ_SANDBOX_SUITE:-token}"
case "$SUITE" in
token)
	TEST_PKG="experiments/test/tokenCIP112-v1-test"
	SCRIPTS=(
		OpenZeppelin.TokenCIP112V1SandboxTest:sandboxMintAndQuery
		OpenZeppelin.TokenCIP112V1SandboxTest:sandboxTransferLifecycle
		OpenZeppelin.TokenCIP112V1SandboxTest:sandboxAllowanceLifecycle
		OpenZeppelin.TokenCIP112V1SandboxTest:sandboxMintAndBurn
	)
	;;
authorization)
	TEST_PKG="test/scoped-authorization-grant-v1-test"
	SCRIPTS=(OpenZeppelin.ScopedAuthorizationGrantV1SandboxTest:sandboxAuthorization)
	;;
licensing)
	TEST_PKG="examples/test/licensing-app-v1-test"
	SCRIPTS=(Example.LicensingV1SandboxTest:sandboxLicensing)
	;;
treasury)
	TEST_PKG="examples/test/treasury-rbac-v1-test"
	SCRIPTS=(Example.TreasuryRbacV1SandboxTest:sandboxTreasury)
	;;
*)
	printf 'check-sandbox: unknown suite: %s\n' "$SUITE" >&2
	exit 1
	;;
esac
PACKAGE_NAME="$(sed -n 's/^name:[[:space:]]*//p' "$ROOT/$TEST_PKG/daml.yaml")"
DAR="$ROOT/$TEST_PKG/.daml/dist/$PACKAGE_NAME-0.0.0.dar"
LEDGER_HOST="${OZ_LEDGER_HOST:-localhost}"
LEDGER_PORT="${OZ_LEDGER_PORT:-6865}"
USE_EXTERNAL_LEDGER="${OZ_USE_EXTERNAL_LEDGER:-0}"
LOG_DIR="${OZ_SANDBOX_LOG_DIR:-$ROOT/.cache/sandbox-$SUITE}"
mkdir -p "$LOG_DIR"

printf 'check-sandbox: building the %s test package\n' "$SUITE"
(cd "$ROOT" && DAML_PACKAGE="$TEST_PKG" dpm build)
[ -f "$DAR" ] || {
	printf 'check-sandbox: expected DAR not found: %s\n' "$DAR" >&2
	exit 1
}

SANDBOX_PID=""
SANDBOX_PGID=""

process_group_alive() {
	[ -n "$1" ] && kill -0 "-$1" >/dev/null 2>&1
}

wait_for_port_release() {
	local port="$1"
	local i=0
	while [ "$i" -lt 20 ]; do
		if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done
	printf 'check-sandbox: Ledger API port %s remains in use after cleanup\n' "$port" >&2
	return 1
}

cleanup() {
	local status=$?
	local cleanup_failed=0
	trap - EXIT
	set +m >/dev/null 2>&1 || true
	if process_group_alive "$SANDBOX_PGID"; then
		printf 'check-sandbox: stopping sandbox (pid %s)\n' "$SANDBOX_PID"
		kill -TERM -- "-$SANDBOX_PGID" 2>/dev/null || true
		local i=0
		while [ "$i" -lt 15 ] && process_group_alive "$SANDBOX_PGID"; do
			i=$((i + 1))
			sleep 1
		done
		if process_group_alive "$SANDBOX_PGID"; then
			kill -KILL -- "-$SANDBOX_PGID" 2>/dev/null || true
		fi
		wait "$SANDBOX_PID" 2>/dev/null || true
		wait_for_port_release "$LEDGER_PORT" || cleanup_failed=1
	fi
	[ "$cleanup_failed" -eq 0 ] || status=1
	exit "$status"
}
trap cleanup EXIT

if [ "$USE_EXTERNAL_LEDGER" = 1 ]; then
	printf 'check-sandbox: using external ledger at %s:%s (no sandbox started; must be static-time)\n' "$LEDGER_HOST" "$LEDGER_PORT"
else
	if lsof -nP -iTCP:"$LEDGER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
		printf 'check-sandbox: Ledger API port %s is already in use\n' "$LEDGER_PORT" >&2
		exit 1
	fi
	set -m
	printf 'check-sandbox: starting static-time Canton sandbox on %s:%s\n' "$LEDGER_HOST" "$LEDGER_PORT"
	(cd "$LOG_DIR" && dpm sandbox --static-time --ledger-api-port "$LEDGER_PORT" --dar "$DAR" \
		> "$LOG_DIR/sandbox.log" 2>&1) &
	SANDBOX_PID=$!
	SANDBOX_PGID=$SANDBOX_PID

	ready=0
	for _ in $(seq 1 120); do
		if grep -q 'Canton sandbox is ready' "$LOG_DIR/sandbox.log" 2>/dev/null; then
			ready=1
			break
		fi
		kill -0 "$SANDBOX_PID" 2>/dev/null || break
		sleep 1
	done
	[ "$ready" = 1 ] || {
		printf 'check-sandbox: sandbox did not become ready; see %s\n' "$LOG_DIR/sandbox.log" >&2
		exit 1
	}
fi

fail=0
for name in "${SCRIPTS[@]}"; do
	s="${name##*:}"
	log="$LOG_DIR/$s.log"
	if (cd "$ROOT" && DAML_PACKAGE="$TEST_PKG" dpm script --dar "$DAR" --script-name "$name" \
		--ledger-host "$LEDGER_HOST" --ledger-port "$LEDGER_PORT" \
		--static-time > "$log" 2>&1); then
		printf 'check-sandbox: PASS %s\n' "$s"
	else
		printf 'check-sandbox: FAIL %s (see %s)\n' "$s" "$log" >&2
		fail=1
	fi
done

[ "$fail" = 0 ] || {
	printf 'check-sandbox: FAILED\n' >&2
	exit 1
}
printf 'check-sandbox: OK - all %d %s scripts passed on the sandbox\n' "${#SCRIPTS[@]}" "$SUITE"
