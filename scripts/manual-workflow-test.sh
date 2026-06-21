#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'manual-workflow-test: repo %s\n' "$ROOT"
"$ROOT/scripts/check-scaffold.sh"
"$ROOT/scripts/identity-hook-upgrade-smoke.sh"
printf 'manual-workflow-test: OK\n'
