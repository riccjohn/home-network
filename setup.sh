#!/bin/bash

# Home Network Setup Script
# This script helps set up the initial configuration

set -e

echo "🏠 Home Network Setup Script"
echo "============================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if user can access Docker daemon
if ! docker info &> /dev/null; then
    echo "⚠️  Warning: Cannot access Docker daemon. You may need to:"
    echo "   1. Add your user to the docker group: sudo usermod -aG docker $USER"
    echo "   2. Log out and log back in (or run: newgrp docker)"
    echo "   3. Or run this script with sudo (not recommended)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Docker Compose is installed
# Check for docker-compose (standalone) or docker compose (plugin)
HAS_DOCKER_COMPOSE=false
if command -v docker-compose &> /dev/null; then
    HAS_DOCKER_COMPOSE=true
elif docker compose version &> /dev/null 2>&1; then
    HAS_DOCKER_COMPOSE=true
fi

if [ "$HAS_DOCKER_COMPOSE" = false ]; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "   Install via: https://docs.docker.com/compose/install/"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from env.example..."
    if [ -f env.example ]; then
        cp env.example .env
        echo "✅ Created .env file. Please edit it with your settings."
    else
        echo "⚠️  env.example not found. Creating basic .env file..."
        cat > .env << EOF
DOMAIN=home.local
TZ=America/New_York
MEDIA_PATH=./media
ACME_EMAIL=admin@example.com
PIHOLE_PASSWORD=changeme
EOF
    fi
else
    echo "✅ .env file already exists"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p traefik/letsencrypt
mkdir -p pihole/{etc,etc-dnsmasq.d}
mkdir -p syncthing/{config,data}
mkdir -p jellyfin/{config,cache}
mkdir -p homepage/config
mkdir -p media

# Set permissions
echo "🔐 Setting permissions..."
chmod 600 traefik/letsencrypt 2>/dev/null || true

# Get server IP (cross-platform)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n1 || echo "YOUR_SERVER_IP")
else
    # Linux
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1.1.1.1 | awk '{print $7}' | head -n1 || echo "YOUR_SERVER_IP")
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env file with your settings:"
echo "   - Set DOMAIN (e.g., home.local or your actual domain)"
echo "   - Set MEDIA_PATH to your media directory"
echo "   - Set TZ to your timezone"
echo "   - Set PIHOLE_PASSWORD (change from default!)"
echo ""
echo "2. Add DNS entries to your router or /etc/hosts file:"
echo "   $SERVER_IP  home.local"
echo "   $SERVER_IP  homepage.home.local"
echo "   $SERVER_IP  pihole.home.local"
echo "   $SERVER_IP  syncthing.home.local"
echo "   $SERVER_IP  jellyfin.home.local"
echo "   $SERVER_IP  traefik.home.local"
echo ""
echo "3. Configure your router to use Pi-hole as DNS server:"
echo "   - Set router DNS to: $SERVER_IP"
echo "   - This enables network-wide ad blocking"
echo ""
echo "4. Start the services:"
echo "   docker compose up -d"
echo ""
echo "5. Access the homepage at:"
echo "   http://homepage.home.local or http://$SERVER_IP:3000"
echo ""

