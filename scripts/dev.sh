#!/usr/bin/env bash
# dev.sh — manage the local development stack
#
# Usage:
#   ./scripts/dev.sh up [svc...]   Start local stack (creates dirs + .env.dev on first run)
#   ./scripts/dev.sh down          Stop and remove containers
#   ./scripts/dev.sh restart [svc] Restart one or all services
#   ./scripts/dev.sh status        Show container status
#   ./scripts/dev.sh logs [svc]    Tail logs (all services or one)
#
# Services skipped automatically in local dev:
#   pihole   — requires Linux host networking
#   jellyfin — requires /dev/dri render device

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.dev"
ENV_EXAMPLE="$REPO_ROOT/.env.dev.example"
DEV_DATA="$REPO_ROOT/.dev/data"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

log()  { printf "${GREEN}[dev]${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}[dev]${RESET} %s\n" "$*"; }
err()  { printf "${RED}[dev]${RESET} %s\n" "$*" >&2; }

# compose_env: requires .env.dev (up, restart, logs)
compose_env() {
  docker compose \
    -f "$REPO_ROOT/docker-compose.yml" \
    -f "$REPO_ROOT/docker-compose.dev.yml" \
    --env-file "$ENV_FILE" \
    "$@"
}

# compose_no_env: works without .env.dev (down, status)
compose_no_env() {
  docker compose \
    -f "$REPO_ROOT/docker-compose.yml" \
    -f "$REPO_ROOT/docker-compose.dev.yml" \
    "$@"
}

ensure_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
      err ".env.dev.example not found — cannot create .env.dev"
      exit 1
    fi
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    warn "Created .env.dev from .env.dev.example — edit before running if needed"
  fi
}

ensure_dirs() {
  local dirs=(
    "$DEV_DATA/portainer"
    "$DEV_DATA/filebrowser/database"
    "$DEV_DATA/filebrowser/config"
    "$DEV_DATA/filebrowser/files"
    "$DEV_DATA/wallabag"
    "$DEV_DATA/wallabag-images"
    "$DEV_DATA/media"
  )
  for d in "${dirs[@]}"; do
    mkdir -p "$d"
  done

  # acme.dev.json must exist with 600 permissions for Traefik
  local acme="$REPO_ROOT/traefik/letsencrypt/acme.dev.json"
  mkdir -p "$(dirname "$acme")"
  if [[ ! -f "$acme" ]]; then
    touch "$acme"
    chmod 600 "$acme"
    log "Created traefik/letsencrypt/acme.dev.json"
  fi
}

cmd_up() {
  ensure_env
  ensure_dirs
  log "Starting local dev stack..."
  compose_env up -d "$@"
  log "Stack started. Run './scripts/health-check.sh' to verify services."
  log "Note: Wallabag takes ~30s on first run (DB migration). Re-run health-check if it fails initially."
}

cmd_down() {
  log "Stopping local dev stack..."
  compose_no_env down "$@"
}

cmd_restart() {
  ensure_env
  ensure_dirs
  compose_env restart "$@"
}

cmd_status() {
  compose_no_env ps
}

cmd_logs() {
  ensure_env
  compose_env logs --tail=50 -f "$@"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  up [svc...]     Start local stack (creates .env.dev and data dirs on first run)
  down            Stop and remove containers
  restart [svc]   Restart one or all services
  status          Show container status
  logs [svc]      Tail logs (Ctrl-C to exit)

Services skipped in local dev (require Linux-only features):
  pihole    — host networking (Linux only)
  jellyfin  — /dev/dri render device (Linux only)
EOF
}

case "${1:-}" in
  up)      shift; cmd_up "$@" ;;
  down)    shift; cmd_down "$@" ;;
  restart) shift; cmd_restart "$@" ;;
  status)  cmd_status ;;
  logs)    shift; cmd_logs "$@" ;;
  *)       usage; exit 1 ;;
esac
