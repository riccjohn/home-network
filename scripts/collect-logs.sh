#!/usr/bin/env bash
# collect-logs.sh — capture diagnostic info from the running stack
#
# Paste the output into Claude to diagnose deployment issues.
#
# Usage:
#   ./scripts/collect-logs.sh           # all services
#   ./scripts/collect-logs.sh jellyfin  # one service

set -uo pipefail

LINES=75
FILTER="${1:-}"

section() { printf "\n\n### %s\n\n" "$1"; }

section "Stack status"
docker compose ps

section "Recent errors (all services)"
docker compose logs --tail=300 --no-color 2>&1 \
  | grep -iE '\b(err(or)?|warn(ing)?|fatal|panic|exception|failed)\b' \
  | tail -60 \
  || echo "(none found)"

section "Service logs"
services=(traefik homepage jellyfin portainer filebrowser syncthing wallabag pihole)
for svc in "${services[@]}"; do
  [[ -n "$FILTER" && "$FILTER" != "$svc" ]] && continue
  printf "\n#### %s (last %d lines)\n\n" "$svc" "$LINES"
  docker compose logs --tail="$LINES" --no-color "$svc" 2>&1 || true
done
