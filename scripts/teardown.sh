#!/bin/bash

# Exit on error
set -e

# Stop and remove all containers
echo "Stopping and removing containers..."
docker compose down

# Remove volumes (optional, uncomment if you want to remove all data)
# echo "Removing volumes..."
# docker compose down -v

# Remove network
echo "Removing network..."
docker network rm ${DOCKER_NETWORK:-home-server-network} || true

echo "Teardown complete! All services have been stopped and removed."
echo "Note: Configuration files in service-configs/ have been preserved." 