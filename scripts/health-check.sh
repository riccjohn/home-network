#!/usr/bin/env bash
# health-check.sh — verify local dev services are responding
#
# Usage:
#   ./scripts/health-check.sh            Check all services
#   ./scripts/health-check.sh traefik    Check one service by name
#
# Exit code: 0 if all checked services pass, 1 if any fail.

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

TIMEOUT=5
OVERALL=0
FILTER="${1:-}"

check() {
  local name="$1" url="$2"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")

  if [[ "$code" =~ ^2 ]]; then
    printf "${GREEN}  PASS${RESET}  %-15s  %s\n" "$name" "$url"
  else
    printf "${RED}  FAIL${RESET}  %-15s  %s  (HTTP %s)\n" "$name" "$url" "$code"
    OVERALL=1
  fi
}

run_check() {
  local name="$1"
  if [[ -z "$FILTER" || "$FILTER" == "$name" ]]; then
    check "$@"
  fi
}

printf "Local dev health checks\n"
printf '%.0s─' {1..60}; echo

run_check "traefik"     "http://localhost:8080/ping"
run_check "homepage"    "http://localhost:3001"
run_check "portainer"   "http://localhost:9000/api/status"
run_check "filebrowser" "http://localhost:8081"
run_check "wallabag"    "http://localhost:8888/login"

printf '%.0s─' {1..60}; echo

if [[ $OVERALL -eq 0 ]]; then
  printf "${GREEN}All services healthy${RESET}\n"
else
  printf "${RED}One or more services failed${RESET} — check logs:\n"
  printf "  ./scripts/dev.sh logs <service>\n"
fi

exit $OVERALL
