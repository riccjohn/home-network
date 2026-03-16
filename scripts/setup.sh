#!/bin/bash

# Home Network Server Setup Script

set -e

echo "🏠 Home Network Server Setup"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if user can access Docker daemon
if ! docker info &> /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: Cannot access Docker daemon.${NC}"
    echo "   You may need to:"
    echo "   1. Add your user to the docker group: sudo usermod -aG docker \$USER"
    echo "   2. Log out and log back in (or run: newgrp docker)"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Docker Compose is installed
HAS_DOCKER_COMPOSE=false
if command -v docker-compose &> /dev/null; then
    HAS_DOCKER_COMPOSE=true
elif docker compose version &> /dev/null 2>&1; then
    HAS_DOCKER_COMPOSE=true
fi

if [ "$HAS_DOCKER_COMPOSE" = false ]; then
    echo -e "${RED}❌ Docker Compose is not installed.${NC}"
    echo "   Install via: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✅ Docker and Docker Compose are installed${NC}"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ Created .env file${NC}"
        echo -e "${YELLOW}⚠️  Please edit .env file with your settings before starting services!${NC}"
    else
        echo -e "${YELLOW}⚠️  .env.example not found. Creating basic .env file...${NC}"
        cat > .env << EOF
DOMAIN=home.local
TZ=America/Chicago
PIHOLE_PASSWORD=changeme
PIHOLE_DNS=8.8.8.8;1.1.1.1
ADMIN_EMAIL=
# SERVER_IP will be auto-detected below
SERVER_IP=
EOF
        echo -e "${YELLOW}⚠️  Please edit .env file with your settings before starting services!${NC}"
    fi
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

echo ""

# Create necessary directories for Pi-hole
echo "📁 Creating necessary directories..."
mkdir -p pihole/etc
mkdir -p pihole/etc-dnsmasq.d
mkdir -p jellyfin/config
mkdir -p jellyfin/cache
mkdir -p syncthing/config
mkdir -p traefik/dynamic
mkdir -p filebrowser/database
mkdir -p filebrowser/config

# Set proper permissions
echo "🔐 Setting permissions..."
chmod 755 pihole/etc
chmod 755 pihole/etc-dnsmasq.d

echo -e "${GREEN}✅ Directories created${NC}"
echo ""

# Set up Traefik certificate storage
echo "🔐 Setting up Traefik certificate storage..."
touch traefik/letsencrypt/acme.json
chmod 600 traefik/letsencrypt/acme.json
echo -e "${GREEN}✅ acme.json permissions set (600 required by Traefik)${NC}"
echo ""

# Get server IP
echo "🌐 Detecting server IP address..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n1 || echo "")
else
    # Linux
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1.1.1.1 | awk '{print $7}' | head -n1 || echo "")
fi

if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "" ]; then
    echo -e "${GREEN}✅ Server IP detected: $SERVER_IP${NC}"

    # Update .env file with detected IP
    if [ -f .env ]; then
        # Check if SERVER_IP already exists in .env
        if grep -q "^SERVER_IP=" .env; then
            # Update existing SERVER_IP
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS uses BSD sed
                sed -i '' "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" .env
            else
                # Linux uses GNU sed
                sed -i "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" .env
            fi
            echo -e "${GREEN}✅ Updated SERVER_IP in .env file${NC}"
        else
            # Add SERVER_IP to .env
            {
                echo ""
                echo "# Server IP (auto-detected)"
                echo "SERVER_IP=$SERVER_IP"
            } >> .env
            echo -e "${GREEN}✅ Added SERVER_IP to .env file${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Could not detect server IP automatically${NC}"
    echo -e "${YELLOW}   You'll need to set SERVER_IP manually in .env file${NC}"
fi

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "📋 Next Steps:"
echo "=============="
echo ""
echo "1. Edit .env file with your settings:"
echo "   - Set PIHOLE_PASSWORD"
echo "   - Set ADMIN_EMAIL (for Let's Encrypt notifications)"
echo "   - Set CF_DNS_API_TOKEN (Cloudflare API token for DNS-01 ACME)"
echo "   - Set RENDER_GID (run: getent group render | cut -d: -f3)"
if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "" ]; then
    echo "   - SERVER_IP auto-detected: $SERVER_IP"
fi
echo ""
echo "2. In Cloudflare dashboard (dash.cloudflare.com):"
echo "   - Add A record: woggles.work → $SERVER_IP (DNS only, grey cloud)"
echo "   - Add A record: *.woggles.work → $SERVER_IP (DNS only, grey cloud)"
echo ""
echo "3. Start services (staging certs first):"
echo "   docker compose up -d"
echo ""
echo "4. Verify Traefik gets a staging cert, then switch to production:"
echo "   Edit traefik/traefik.yml — comment out caServer staging line, uncomment production"
echo "   docker compose restart traefik"
echo ""
echo "5. Access your services:"
echo "   https://homepage.woggles.work  — Dashboard"
echo "   https://pihole.woggles.work    — Pi-hole admin"
echo "   https://traefik.woggles.work   — Traefik dashboard"
echo "   https://jellyfin.woggles.work  — Media server"
echo "   https://syncthing.woggles.work — File sync"
echo "   https://files.woggles.work     — FileBrowser (default login: admin/admin — change immediately!)"
echo ""
