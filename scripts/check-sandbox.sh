#!/usr/bin/env bash
#
# Sandbox validation gate: runs selected scripts
# against a real local Canton ledger over the Ledger API gRPC endpoint,
# instead of the in-memory ledger that `dpm test` uses.
#
# Static time supports the suites' explicit validity-boundary checks. Each
# suite allocates fresh parties and advances the shared clock monotonically.
#
# check_witnesses checks the records a script in WITNESS_SCRIPTS returns
# against the JSON Ledger API. CONTRIBUTING.md explains the convention.
#
# To target an already-running ledger instead of the script-managed sandbox,
# set OZ_USE_EXTERNAL_LEDGER=1 together with OZ_LEDGER_HOST / OZ_LEDGER_PORT,
# and OZ_JSON_API_PORT for a suite with witness scripts. Use a fresh external
# static-time ledger for each suite. Scripts that advance time run last.
# OZ_SANDBOX_SUITE selects token (default), authorization, licensing, or
# treasury.
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
		# Moves the clock past every other script's deadlines: keep it last.
		OpenZeppelin.Token.Cip112.V1.Test.Sandbox:sandboxBatchExpiryWitnesses
	)
	WITNESS_SCRIPTS="sandboxBatchExpiryWitnesses"
	;;
authorization)
	TEST_PKG="test/scoped-authorization-grant-v1-test"
	SCRIPTS=(OpenZeppelin.ScopedAuthorizationGrantV1SandboxTest:sandboxAuthorization)
	WITNESS_SCRIPTS=""
	;;
licensing)
	TEST_PKG="examples/licensing-app-v1-test"
	SCRIPTS=(Example.LicensingV1SandboxTest:sandboxLicensing)
	WITNESS_SCRIPTS=""
	;;
treasury)
	TEST_PKG="examples/treasury-rbac-v1-test"
	SCRIPTS=(Example.TreasuryRbacV1SandboxTest:sandboxTreasury)
	WITNESS_SCRIPTS=""
	;;
*)
	printf 'check-sandbox: unknown suite: %s\n' "$SUITE" >&2
	exit 1
	;;
esac
for w in $WITNESS_SCRIPTS; do
	case " ${SCRIPTS[*]##*:} " in
	*" $w "*) ;;
	*)
		printf 'check-sandbox: witness script %s is not in SCRIPTS\n' "$w" >&2
		exit 1
		;;
	esac
done
PACKAGE_NAME="$(sed -n 's/^name:[[:space:]]*//p' "$ROOT/$TEST_PKG/daml.yaml")"
DAR="$ROOT/$TEST_PKG/.daml/dist/$PACKAGE_NAME-0.0.0.dar"
LEDGER_HOST="${OZ_LEDGER_HOST:-localhost}"
LEDGER_PORT="${OZ_LEDGER_PORT:-6865}"
JSON_API_PORT="${OZ_JSON_API_PORT:-7575}"
JSON_API="http://$LEDGER_HOST:$JSON_API_PORT"
USE_EXTERNAL_LEDGER="${OZ_USE_EXTERNAL_LEDGER:-0}"
# Only a suite with witness scripts reads the JSON Ledger API, so only its
# sandbox gets `--json-api-port` and has that port checked and released.
# Without the flag, `dpm sandbox` serves the JSON Ledger API on 6864.
SANDBOX_PORTS="$LEDGER_PORT"
if [ -n "$WITNESS_SCRIPTS" ]; then
	for tool in curl jq; do
		command -v "$tool" >/dev/null 2>&1 || {
			printf 'check-sandbox: %s is required for the %s witness checks\n' "$tool" "$SUITE" >&2
			exit 1
		}
	done
	SANDBOX_PORTS="$LEDGER_PORT $JSON_API_PORT"
fi
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
	printf 'check-sandbox: port %s remains in use after cleanup\n' "$port" >&2
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
		for port in $SANDBOX_PORTS; do
			wait_for_port_release "$port" || cleanup_failed=1
		done
	fi
	[ "$cleanup_failed" -eq 0 ] || status=1
	exit "$status"
}
trap cleanup EXIT

if [ "$USE_EXTERNAL_LEDGER" = 1 ]; then
	printf 'check-sandbox: using external ledger at %s:%s (no sandbox started; must be static-time)\n' "$LEDGER_HOST" "$LEDGER_PORT"
else
	for port in $SANDBOX_PORTS; do
		if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
			printf 'check-sandbox: port %s is already in use\n' "$port" >&2
			exit 1
		fi
	done
	set -m
	printf 'check-sandbox: starting static-time Canton sandbox on %s:%s%s\n' "$LEDGER_HOST" "$LEDGER_PORT" \
		"${WITNESS_SCRIPTS:+ (JSON API on port $JSON_API_PORT)}"
	# The JSON API flag expands to nothing for a suite without witness scripts.
	# shellcheck disable=SC2086
	(cd "$LOG_DIR" && dpm sandbox --static-time --ledger-api-port "$LEDGER_PORT" \
		${WITNESS_SCRIPTS:+--json-api-port $JSON_API_PORT} --dar "$DAR" \
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

# Check a witness script's result against each listed party's own
# transactions, read from the JSON Ledger API in ledger-effects shape. The
# contracts in `witnessed` must all appear in the events of one transaction,
# so a contract's earlier creation does not count. No contract in `hidden`
# may appear anywhere in the party's transactions, choice arguments and
# results included.
check_witnesses() {
	local script="$1" result="$2" count end i party updates report status=0
	count="$(jq -er 'length' "$result")" && [ "$count" -gt 0 ] || {
		printf 'check-sandbox: FAIL %s returned no Witnessing records\n' "$script" >&2
		return 1
	}
	end="$(curl -fsS "$JSON_API/v2/state/ledger-end" | jq -er .offset)" || {
		printf 'check-sandbox: FAIL cannot read the ledger end from %s\n' "$JSON_API" >&2
		return 1
	}
	for i in $(seq 0 $((count - 1))); do
		party="$(jq -er --argjson i "$i" '.[$i].party' "$result")" || {
			printf 'check-sandbox: FAIL %s record %s names no party\n' "$script" "$i" >&2
			status=1
			continue
		}
		updates="$LOG_DIR/$script.$i.updates.json"
		if ! jq -n --arg party "$party" --argjson upto "$end" '{
			beginExclusive: 0,
			endInclusive: $upto,
			verbose: false,
			updateFormat: {includeTransactions: {
				eventFormat: {
					filtersByParty: {($party): {cumulative: [
						{identifierFilter: {WildcardFilter: {value: {includeCreatedEventBlob: false}}}}
					]}},
					verbose: false
				},
				transactionShape: "TRANSACTION_SHAPE_LEDGER_EFFECTS"
			}}
		}' | curl -fsS -X POST "$JSON_API/v2/updates" -H 'Content-Type: application/json' -d @- \
			> "$updates"; then
			printf 'check-sandbox: FAIL cannot read the transactions of %s\n' "$party" >&2
			status=1
			continue
		fi
		if ! report="$(jq -nr --argjson i "$i" --slurpfile result "$result" --slurpfile updates "$updates" '
			$result[0][$i] as $w
			| [$updates[0][] | .update.Transaction?.value | select(. != null)
				| [.events[] | .[].contractId]] as $txs
			| any($txs[]; ($w.witnessed - .) == []) as $together
			| ($updates[0] | tostring) as $view
			| [$w.hidden[] | select(. as $cid | $view | contains($cid))] as $leaked
			| [ (if $together then empty
				 else "witnessed \($w.witnessed) appear together in no transaction" end),
				(if $leaked == [] then empty else "hidden \($leaked) appear" end) ] as $problems
			| if $problems == [] then "" else "\($w.party): \($problems | join("; "))" end')"; then
			printf 'check-sandbox: FAIL cannot parse %s\n' "$updates" >&2
			status=1
		elif [ -n "$report" ]; then
			printf 'check-sandbox: FAIL %s witnesses (see %s)\n%s\n' "$script" "$updates" "$report" >&2
			status=1
		fi
	done
	[ "$status" = 0 ] || return 1
	printf 'check-sandbox: PASS %s witnesses for %d parties\n' "$script" "$count"
}

fail=0
for name in "${SCRIPTS[@]}"; do
	s="${name##*:}"
	log="$LOG_DIR/$s.log"
	if (cd "$ROOT" && DAML_PACKAGE="$TEST_PKG" dpm script --dar "$DAR" --script-name "$name" \
		--ledger-host "$LEDGER_HOST" --ledger-port "$LEDGER_PORT" \
		--static-time --output-file "$LOG_DIR/$s.json" > "$log" 2>&1); then
		printf 'check-sandbox: PASS %s\n' "$s"
		case " $WITNESS_SCRIPTS " in
		*" $s "*) check_witnesses "$s" "$LOG_DIR/$s.json" || fail=1 ;;
		esac
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
