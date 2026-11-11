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
# licensing, treasury, blocklist, custom-token, blocklist-delegation, or
# external-blocker.
#
# The external-blocker suite onboards an external party that needs two of its
# three signing keys, and blocks a party as that party through interactive
# submission. It drives the sandbox with `dpm canton-console`, which connects
# to the default sandbox ports, so it runs on the script-managed sandbox only.
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
	TEST_PKG="test/token-cip112-v1-test"
	SCRIPTS=(
		OpenZeppelin.Token.Cip112.V1.Test.Sandbox:sandboxMintAndQuery
		OpenZeppelin.Token.Cip112.V1.Test.Sandbox:sandboxTransferLifecycle
		OpenZeppelin.Token.Cip112.V1.Test.Sandbox:sandboxMintAndBurn
	)
	;;
authorization)
	TEST_PKG="test/scoped-authorization-grant-v1-test"
	SCRIPTS=(OpenZeppelin.ScopedAuthorizationGrantV1SandboxTest:sandboxAuthorization)
	;;
licensing)
	TEST_PKG="examples/licensing-app-v1-test"
	SCRIPTS=(Example.LicensingV1SandboxTest:sandboxLicensing)
	;;
treasury)
	TEST_PKG="examples/treasury-rbac-v1-test"
	SCRIPTS=(Example.TreasuryRbacV1SandboxTest:sandboxTreasury)
	;;
blocklist)
	TEST_PKG="test/blocklist-v1-test"
	SCRIPTS=(OpenZeppelin.BlocklistV1SandboxTest:sandboxBlocklist)
	;;
custom-token)
	TEST_PKG="examples/token/token-cip112-custom-test"
	SCRIPTS=(OpenZeppelin.Examples.Token.Cip112.Custom.Test.Sandbox:sandboxCustomTokenBlocklist)
	;;
blocklist-delegation)
	TEST_PKG="examples/compliance/blocklist-delegation-v1-test"
	SCRIPTS=(Example.BlocklistDelegationV1SandboxTest:sandboxBlocklistDelegation)
	;;
external-blocker)
	TEST_PKG="test/blocklist-v1-test"
	SCRIPTS=()
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

if [ "$SUITE" = external-blocker ] && { [ "$USE_EXTERNAL_LEDGER" = 1 ] || [ "$LEDGER_PORT" != 6865 ]; }; then
	printf 'check-sandbox: the external-blocker suite needs the script-managed sandbox on port 6865\n' >&2
	exit 1
fi

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

# Run one Canton console script against the sandbox and require its marker.
run_console() {
	local script="$1"
	local marker="$2"
	local log
	log="$LOG_DIR/$(basename "$script" .canton).log"
	(cd "$LOG_DIR" && OZ_EXTERNAL_DIR="$LOG_DIR" dpm canton-console --no-tty \
		--bootstrap "$ROOT/$TEST_PKG/canton/$script" < /dev/null > "$log" 2>&1) || true
	grep -q "^$marker" "$log"
}

# Run one Daml Script with a JSON input and an optional JSON output.
run_script_io() {
	local name="$1"
	local input="$2"
	local output="${3:-}"
	local log="$LOG_DIR/${name##*:}.log"
	(cd "$ROOT" && DAML_PACKAGE="$TEST_PKG" dpm script --dar "$DAR" --script-name "$name" \
		--ledger-host "$LEDGER_HOST" --ledger-port "$LEDGER_PORT" --static-time \
		--input-file "$input" ${output:+--output-file "$output"} > "$log" 2>&1)
}

fail=0
passed=0
unit=scripts

pass_step() {
	printf 'check-sandbox: PASS %s\n' "$1"
	passed=$((passed + 1))
}

# Require the reason that the console logged between the start and the result
# of one step of block-as-external-blocker.canton.
check_refusal() {
	local name="$1"
	local reason="$2"
	local log="$LOG_DIR/block-as-external-blocker.log"
	if awk -v start="EXTERNAL-BLOCKER-STEP $name" -v done_pass="EXTERNAL-BLOCKER-PASS $name" \
		'$0 == start { on = 1; next } $0 == done_pass { on = 0 } on' "$log" | grep -Fq "$reason"; then
		pass_step "$name is refused: $reason"
	else
		printf 'check-sandbox: FAIL %s: expected the reason "%s" in %s\n' "$name" "$reason" "$log" >&2
		return 1
	fi
}

run_external_blocker() {
	local module=OpenZeppelin.BlocklistV1ExternalBlockerTest
	run_console onboard-external-blocker.canton EXTERNAL-BLOCKER-ONBOARDED || return 1
	pass_step "onboard an external blocker that needs two of its three keys"
	run_script_io "$module:setupExternalBlocker" "$LOG_DIR/party.json" "$LOG_DIR/fixture.json" || return 1
	pass_step "create a blocklist whose blocker is the external party"
	run_console block-as-external-blocker.canton EXTERNAL-BLOCKER-OK || return 1
	check_refusal no-signature NO_SYNCHRONIZER_ON_WHICH_ALL_SUBMITTERS_CAN_SUBMIT || return 1
	check_refusal one-signature "Received 1 valid signatures from distinct keys" || return 1
	check_refusal same-key-twice "Received 1 valid signatures from distinct keys" || return 1
	pass_step "two-distinct-keys blocks the party"
	run_script_io "$module:checkExternalBlocker" "$LOG_DIR/fixture.json" || return 1
	pass_step "the guard refuses the blocked party"
}

if [ "$SUITE" = external-blocker ]; then
	unit=steps
	if ! run_external_blocker; then
		printf 'check-sandbox: FAIL external blocker (see %s)\n' "$LOG_DIR" >&2
		fail=1
	fi
fi
for name in ${SCRIPTS[@]+"${SCRIPTS[@]}"}; do
	s="${name##*:}"
	log="$LOG_DIR/$s.log"
	if (cd "$ROOT" && DAML_PACKAGE="$TEST_PKG" dpm script --dar "$DAR" --script-name "$name" \
		--ledger-host "$LEDGER_HOST" --ledger-port "$LEDGER_PORT" \
		--static-time > "$log" 2>&1); then
		printf 'check-sandbox: PASS %s\n' "$s"
		passed=$((passed + 1))
	else
		printf 'check-sandbox: FAIL %s (see %s)\n' "$s" "$log" >&2
		fail=1
	fi
done

[ "$fail" = 0 ] || {
	printf 'check-sandbox: FAILED\n' >&2
	exit 1
}
printf 'check-sandbox: OK - all %d %s %s passed on the sandbox\n' "$passed" "$SUITE" "$unit"
