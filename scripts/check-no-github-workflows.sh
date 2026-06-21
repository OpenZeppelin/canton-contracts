#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

matches="$(find "$ROOT" -path '*/.github/workflows/*' -type f 2>/dev/null || true)"

if [ -n "$matches" ]; then
	printf 'check-no-github-workflows: hosted workflow files are not allowed:\n%s\n' "$matches" >&2
	exit 1
fi

printf 'check-no-github-workflows: OK\n'
