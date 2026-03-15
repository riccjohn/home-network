#!/bin/bash

# Home Network Update Script
# Usage: ./scripts/update.sh [--all]
#   --all  Force-recreate all containers, not just changed ones

set -e

echo "🔄 Home Network Update"
echo "======================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Spinner ────────────────────────────────────────────────────────────────────
# Usage: start_spinner "message" ; ... ; stop_spinner
_SPINNER_PID=""

start_spinner() {
    local msg="$1"
    (
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local i=0
        while true; do
            printf "\r   %s  %s" "${frames[$i]}" "$msg"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.1
        done
    ) &
    _SPINNER_PID=$!
    disown "$_SPINNER_PID"
}

stop_spinner() {
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null || true
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=""
        printf "\r\033[K"  # clear the spinner line
    fi
}

# Ensure spinner is stopped on exit
trap stop_spinner EXIT

# ── Flags ──────────────────────────────────────────────────────────────────────
RESTART_ALL=false
for arg in "$@"; do
    case $arg in
        --all)
            RESTART_ALL=true
            ;;
        *)
            echo -e "${RED}❌ Unknown argument: $arg${NC}"
            echo "   Usage: ./scripts/update.sh [--all]"
            echo "   --all  Force-recreate all containers, not just changed ones"
            exit 1
            ;;
    esac
done

# ── Preflight ──────────────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Cannot access Docker daemon.${NC}"
    echo "   Try: sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# ── Step 1: Git pull ───────────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "📥  Step 1/5 — Pull latest changes"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
git pull
echo ""

# ── Step 2: Provision dirs/files ───────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "📁  Step 2/5 — Provision directories and files"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/setup.sh"
echo ""

# ── Step 3: Pull images ────────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "🐳  Step 3/5 — Pull latest Docker images"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
docker compose pull
echo ""

# ── Step 4: Apply changes ──────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$RESTART_ALL" = true ]; then
    echo "🚀  Step 4/5 — Recreating all containers (--all)"
else
    echo "🚀  Step 4/5 — Updating changed containers"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
if [ "$RESTART_ALL" = true ]; then
    docker compose up -d --force-recreate
else
    docker compose up -d
fi
echo ""

# ── Step 5: Prune old images ───────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "🧹  Step 5/5 — Prune unused Docker images"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
start_spinner "Removing dangling images..."
PRUNE_OUTPUT=$(docker image prune -f 2>&1)
stop_spinner
echo "$PRUNE_OUTPUT"
echo ""

# ── Done ───────────────────────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Update complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📋 Running services:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""
