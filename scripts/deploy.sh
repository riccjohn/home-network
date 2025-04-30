#!/bin/bash

# Exit on error
set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please create it from env.example"
    exit 1
fi

# Load environment variables
# shellcheck disable=SC1091
source .env

# Create necessary directories
echo "Creating directories..."
mkdir -p "${TRAEFIK_CONFIG_PATH}"
mkdir -p "${HOMEPAGE_CONFIG_PATH}"
mkdir -p "${HOMEPAGE_DATA_PATH}"
mkdir -p "${HOMEASSISTANT_CONFIG_PATH}"
mkdir -p "${SYNCTHING_CONFIG_PATH}"
mkdir -p "${JELLYFIN_CONFIG_PATH}"
mkdir -p "${JELLYFIN_DATA_PATH}"
mkdir -p "${CALIBRE_CONFIG_PATH}"
mkdir -p "${CALIBRE_DATA_PATH}"
mkdir -p "${PIHOLE_CONFIG_PATH}"
mkdir -p "${PIHOLE_DNSMASQ_PATH}"

# Set proper permissions for Traefik's acme.json
if [ ! -f "${TRAEFIK_CONFIG_PATH}/acme.json" ]; then
    touch "${TRAEFIK_CONFIG_PATH}/acme.json"
    chmod 600 "${TRAEFIK_CONFIG_PATH}/acme.json"
fi

# Copy Traefik configuration if it doesn't exist
if [ ! -f "${TRAEFIK_CONFIG_PATH}/traefik.yml" ]; then
    cp traefik/traefik.yml "${TRAEFIK_CONFIG_PATH}/"
fi

# Copy Homepage configurations if they don't exist
if [ ! -f "${HOMEPAGE_CONFIG_PATH}/settings.yaml" ]; then
    cp homepage/config/settings.yaml "${HOMEPAGE_CONFIG_PATH}/"
fi
if [ ! -f "${HOMEPAGE_CONFIG_PATH}/services.yaml" ]; then
    cp homepage/config/services.yaml "${HOMEPAGE_CONFIG_PATH}/"
fi

# Start the services
echo "Starting services..."
docker-compose up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Check service status
echo "Checking service status..."
docker-compose ps

echo "Deployment complete! Services should be accessible at:"
echo "- Homepage: https://homepage.${DOMAIN}"
echo "- Home Assistant: https://homeassistant.${DOMAIN}"
echo "- Syncthing: https://syncthing.${DOMAIN}"
echo "- Jellyfin: https://jellyfin.${DOMAIN}"
echo "- Calibre: https://calibre.${DOMAIN}"
echo "- Pi-hole: https://pihole.${DOMAIN}"
echo "- Traefik Dashboard: https://traefik.${DOMAIN}"

echo "Note: It may take a few minutes for Let's Encrypt certificates to be issued." 