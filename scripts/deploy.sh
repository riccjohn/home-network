#!/bin/bash

# Exit on error
set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from env.example"
    exit 1
fi

# Load environment variables
source .env

# Create necessary directories
echo "Creating configuration directories..."
mkdir -p "${HOMEPAGE_CONFIG_PATH}"
mkdir -p "${HOMEPAGE_DATA_PATH}"
mkdir -p "${HOMEASSISTANT_CONFIG_PATH}"
mkdir -p "${SYNCTHING_CONFIG_PATH}"
mkdir -p "${JELLYFIN_CONFIG_PATH}"
mkdir -p "${CALIBRE_CONFIG_PATH}"
mkdir -p "${PIHOLE_CONFIG_PATH}"
mkdir -p "./traefik"

# Create acme.json for Traefik with proper permissions
echo "Setting up Traefik..."
touch ./traefik/acme.json
chmod 600 ./traefik/acme.json

# Start the services
echo "Starting services..."
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check service status
echo "Checking service status..."
docker compose ps

echo "Deployment complete! Services should be accessible at:"
echo "- Dashboard: https://dashboard.${DOMAIN}"
echo "- Home Assistant: https://homeassistant.${DOMAIN}"
echo "- Syncthing: https://syncthing.${DOMAIN}"
echo "- Jellyfin: https://jellyfin.${DOMAIN}"
echo "- Calibre: https://calibre.${DOMAIN}"
echo "- Pi-hole: https://pihole.${DOMAIN}"
echo "- Traefik Dashboard: https://traefik.${DOMAIN}"

echo "Please ensure your DNS records are properly configured and ports 80/443 are forwarded to this server." 