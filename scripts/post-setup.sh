#!/usr/bin/env bash
# post-setup.sh — fetch API keys from running services and write them to .env
#
# Run after:
#   1. docker compose up -d
#   2. Traefik has obtained its TLS cert (check: docker compose logs traefik)
#   3. Jellyfin initial setup wizard is complete (http://localhost:8096)
#
# Requires: curl, jq

set -euo pipefail

ENV_FILE=".env"

# ---- helpers ----------------------------------------------------------------

need() {
  command -v "$1" &>/dev/null || { echo "Error: '$1' is required but not installed."; exit 1; }
}

# Read the current value of a key from .env (empty string if unset)
get_env_var() {
  grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo ""
}

# Write or update a key=value line in .env
set_env_var() {
  local key=$1
  local value=$2
  if grep -qE "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# Check if a key in .env already has a non-empty value
is_set() {
  local val
  val=$(get_env_var "$1")
  [[ -n "$val" ]]
}

wait_for_http() {
  local url=$1
  local label=$2
  local tries=0
  printf "    Waiting for %s" "$label"
  until curl -sf -o /dev/null "$url" 2>/dev/null; do
    printf "."
    sleep 2
    tries=$((tries + 1))
    if [[ $tries -ge 30 ]]; then
      echo " timed out."
      return 1
    fi
  done
  echo " ready."
}

# ---- preflight --------------------------------------------------------------

need curl
need jq
[[ -f "$ENV_FILE" ]] || { echo "Error: .env not found. Run: cp .env.example .env"; exit 1; }

echo ""
echo "=== post-setup: fetching API keys ==="
echo ""

# ---- Portainer --------------------------------------------------------------

if ! is_set PORTAINER_API_KEY || ! is_set PORTAINER_ENV_ID; then
  echo "==> Portainer"

  wait_for_http "http://localhost:9000/api/system/status" "Portainer"

  # Check if admin account already exists
  ADMIN_STATUS=$(curl -sf http://localhost:9000/api/users/admin/check | jq -r '.message // "exists"' 2>/dev/null || echo "exists")

  if [[ "$ADMIN_STATUS" == "no administrator account found" ]]; then
    echo "    Admin account not yet created."
    read -rsp "    Choose a Portainer admin password: " PORTAINER_PASS
    echo ""
    read -rsp "    Confirm password: " PORTAINER_PASS_CONFIRM
    echo ""
    if [[ "$PORTAINER_PASS" != "$PORTAINER_PASS_CONFIRM" ]]; then
      echo "    Passwords do not match. Skipping Portainer."; echo ""
    else
      curl -sf -X POST http://localhost:9000/api/users/admin/init \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"admin\",\"Password\":\"${PORTAINER_PASS}\"}" > /dev/null
      echo "    Admin account created."
    fi
  else
    read -rsp "    Portainer admin password: " PORTAINER_PASS
    echo ""
  fi

  # Get JWT
  JWT=$(curl -sf -X POST http://localhost:9000/api/auth \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"${PORTAINER_PASS}\"}" | jq -r '.jwt')

  if [[ -z "$JWT" || "$JWT" == "null" ]]; then
    echo "    Error: could not authenticate with Portainer. Skipping."
  else
    # Create an API token for Homepage
    API_KEY=$(curl -sf -X POST http://localhost:9000/api/users/1/tokens \
      -H "Authorization: Bearer ${JWT}" \
      -H "Content-Type: application/json" \
      -d '{"description":"homepage"}' | jq -r '.rawAPIKey')

    # Get the first environment ID
    ENV_ID=$(curl -sf http://localhost:9000/api/endpoints \
      -H "X-API-Key: ${API_KEY}" | jq '.[0].Id')

    set_env_var "PORTAINER_API_KEY" "$API_KEY"
    set_env_var "PORTAINER_ENV_ID" "$ENV_ID"
    echo "    PORTAINER_API_KEY and PORTAINER_ENV_ID written to .env."
  fi
  echo ""
else
  echo "==> Portainer: already configured, skipping."
  echo ""
fi

# ---- Pi-hole ----------------------------------------------------------------

if ! is_set PIHOLE_API_KEY; then
  echo "==> Pi-hole"

  wait_for_http "http://localhost:8080/api/auth" "Pi-hole"

  PIHOLE_PASSWORD=$(get_env_var "PIHOLE_PASSWORD")
  if [[ -z "$PIHOLE_PASSWORD" ]]; then
    echo "    PIHOLE_PASSWORD not set in .env. Skipping."
  else
    # Authenticate to get a session
    SID=$(curl -sf -X POST http://localhost:8080/api/auth \
      -H "Content-Type: application/json" \
      -d "{\"password\":\"${PIHOLE_PASSWORD}\"}" | jq -r '.session.sid // empty')

    if [[ -z "$SID" ]]; then
      echo "    Error: could not authenticate with Pi-hole. Check PIHOLE_PASSWORD in .env. Skipping."
    else
      # The app password (API key for homepage) lives in the FTL config
      PIHOLE_API_KEY=$(docker exec pihole grep -oP '(?<=app_password = ")[^"]+' \
        /etc/pihole/pihole.toml 2>/dev/null || echo "")

      if [[ -z "$PIHOLE_API_KEY" ]]; then
        echo "    Could not read API key from Pi-hole config."
        echo "    Get it manually: Portainer > pihole > Settings > API > Show API Token"
        echo "    Then set PIHOLE_API_KEY in .env."
      else
        set_env_var "PIHOLE_API_KEY" "$PIHOLE_API_KEY"
        echo "    PIHOLE_API_KEY written to .env."
      fi

      # Logout
      curl -sf -X DELETE http://localhost:8080/api/auth \
        -H "Content-Type: application/json" \
        -d "{\"sid\":\"${SID}\"}" > /dev/null || true
    fi
  fi
  echo ""
else
  echo "==> Pi-hole: already configured, skipping."
  echo ""
fi

# ---- Jellyfin ---------------------------------------------------------------

if ! is_set JELLYFIN_API_KEY; then
  echo "==> Jellyfin"
  JELLYFIN_URL="http://localhost:8096"

  # Check if initial setup is done
  STARTUP_STATUS=$(curl -sf "${JELLYFIN_URL}/Startup/Configuration" -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")

  if [[ "$STARTUP_STATUS" == "200" ]]; then
    echo "    Jellyfin initial setup wizard is not yet complete."
    echo "    Open http://localhost:8096 (or https://jellyfin.woggles.work) in a browser,"
    echo "    complete the wizard, then re-run this script."
  else
    read -rp "    Jellyfin admin username: " JELLYFIN_USER
    read -rsp "    Jellyfin admin password: " JELLYFIN_PASS
    echo ""

    AUTH_RESPONSE=$(curl -sf -X POST "${JELLYFIN_URL}/Users/AuthenticateByName" \
      -H "Content-Type: application/json" \
      -H 'X-Emby-Authorization: MediaBrowser Client="post-setup", Device="script", DeviceId="post-setup", Version="1.0.0"' \
      -d "{\"Username\":\"${JELLYFIN_USER}\",\"Pw\":\"${JELLYFIN_PASS}\"}" 2>/dev/null || echo "{}")

    TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.AccessToken // empty')

    if [[ -z "$TOKEN" ]]; then
      echo "    Error: could not authenticate with Jellyfin. Skipping."
    else
      # Create a named API key (POST returns 204 No Content)
      curl -sf -X POST "${JELLYFIN_URL}/Auth/Keys?app=homepage" \
        -H "Authorization: MediaBrowser Token=\"${TOKEN}\"" > /dev/null 2>&1 || true

      # Fetch the key we just created
      API_KEY=$(curl -sf "${JELLYFIN_URL}/Auth/Keys" \
        -H "Authorization: MediaBrowser Token=\"${TOKEN}\"" 2>/dev/null \
        | jq -r '.Items | sort_by(.DateCreated) | last | .AccessToken // empty' || echo "")

      # Fall back to the session token if key creation failed
      if [[ -z "$API_KEY" ]]; then
        API_KEY="$TOKEN"
      fi

      set_env_var "JELLYFIN_API_KEY" "$API_KEY"
      echo "    JELLYFIN_API_KEY written to .env."
    fi
  fi
  echo ""
else
  echo "==> Jellyfin: already configured, skipping."
  echo ""
fi

# ---- Apply ------------------------------------------------------------------

echo "==> Restarting Homepage to apply new keys..."
docker compose up -d homepage
echo ""
echo "Done. All configured keys have been written to .env."
echo "If any services were skipped, re-run this script after addressing the issues above."
echo ""
