#!/usr/bin/env bash
# lint-config.sh — validates that env vars are consistently declared across
# docker-compose.yml, homepage config, and .env.example.
#
# Checks:
#   1. Every {{HOMEPAGE_VAR_*}} in homepage/config/*.yaml is in the homepage
#      service's environment block in docker-compose.yml
#   2. Every ${VAR} or ${VAR:-} (no/empty default) in docker-compose.yml is
#      declared in .env.example
#
# Exit codes: 0 = all good, 1 = mismatches found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="$REPO_ROOT/docker-compose.yml"
ENV_EXAMPLE="$REPO_ROOT/.env.example"
HOMEPAGE_CONFIG="$REPO_ROOT/homepage/config"

errors=0

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Check 1: {{HOMEPAGE_VAR_*}} in homepage yaml → docker-compose.yml homepage env
# ---------------------------------------------------------------------------
bold "Check 1: homepage config vars → docker-compose.yml homepage environment"

homepage_vars=$(grep -roh '{{HOMEPAGE_VAR_[A-Z0-9_]*}}' "$HOMEPAGE_CONFIG" 2>/dev/null \
  | sed 's/[{}]//g' | sort -u)

if [[ -z "$homepage_vars" ]]; then
  green "  No HOMEPAGE_VAR_* references found in homepage config."
else
  while IFS= read -r var; do
    if grep -q "$var" "$COMPOSE"; then
      green "  OK  $var"
    else
      red "  MISSING  $var is used in homepage config but not declared in docker-compose.yml"
      errors=$((errors + 1))
    fi
  done <<< "$homepage_vars"
fi

echo

# ---------------------------------------------------------------------------
# Check 2: ${VAR} or ${VAR:-} (empty/no default) in docker-compose.yml → .env.example
# ---------------------------------------------------------------------------
bold "Check 2: docker-compose.yml vars with no/empty default → .env.example"

# Match ${VAR} (no default) and ${VAR:-} (explicitly empty default).
# Exclude vars that have a non-empty default like ${VAR:-somevalue}.
required_vars=$(grep -oh '\${[A-Z0-9_]*\(:-\)\?}' "$COMPOSE" 2>/dev/null \
  | sed 's/[${}]//g; s/:-$//' | sort -u)

if [[ -z "$required_vars" ]]; then
  green "  No vars without defaults found in docker-compose.yml."
else
  while IFS= read -r var; do
    if grep -q "^${var}=" "$ENV_EXAMPLE" 2>/dev/null; then
      green "  OK  $var"
    else
      red "  MISSING  \${$var} is in docker-compose.yml but not declared in .env.example"
      errors=$((errors + 1))
    fi
  done <<< "$required_vars"
fi

echo

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [[ $errors -eq 0 ]]; then
  green "All config checks passed."
  exit 0
else
  red "$errors issue(s) found. Fix the mismatches above before committing."
  exit 1
fi
