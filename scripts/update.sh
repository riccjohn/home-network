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

# Pull latest images
echo "Pulling latest images..."
docker compose pull

# Stop and remove existing containers
echo "Stopping existing containers..."
docker compose down

# Start containers with new images
echo "Starting containers with new images..."
docker compose up -d

# Clean up unused images
echo "Cleaning up unused images..."
docker image prune -f

echo "Update complete! All services have been updated to their latest versions."
echo "Please check the service status:"
docker compose ps 