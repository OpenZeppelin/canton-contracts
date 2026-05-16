#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'manual-workflow-test: repo %s\n' "$ROOT"
"$ROOT/scripts/check-scaffold.sh"
printf 'manual-workflow-test: OK\n'
