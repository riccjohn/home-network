#!/usr/bin/env bash
# on-stop.sh — runs after the agent finishes a turn.
# Exit 2 re-engages the agent to fix the reported issues.
# Exit 0 is silent (success swallowed).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

errors=""

# --- lint-config.sh ---
if ! output=$(bash "$REPO_ROOT/scripts/lint-config.sh" 2>&1); then
  errors+="### lint-config.sh failed\n\n$output\n\n"
  errors+="To fix: ensure every {{HOMEPAGE_VAR_*}} in homepage/config/*.yaml is wired into\n"
  errors+="docker-compose.yml AND every \${VAR} with no/empty default is in .env.example.\n\n"
fi

if [[ -n "$errors" ]]; then
  printf "Harness validation failed — fix before finishing:\n\n%b" "$errors"
  exit 2
fi

exit 0
