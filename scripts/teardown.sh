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

# Stop and remove all containers
echo "Stopping and removing containers..."
docker-compose down

# Remove Docker network
echo "Removing Docker network..."
docker network rm "${DOCKER_NETWORK}" || true

echo "Teardown complete! All services have been stopped and removed."
echo "Note: Configuration files and data volumes have been preserved."
echo "To completely remove all data, manually delete the directories in ${BASE_PATH}" 