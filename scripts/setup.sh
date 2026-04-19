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
mkdir -p wallabag/data

# Set proper permissions
echo "🔐 Setting permissions..."
chmod 777 filebrowser/database
chmod 777 filebrowser/config
chmod 777 wallabag/data

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

# Install Tailscale (Linux only)
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "🔒 Checking Tailscale installation..."
    if command -v tailscale &> /dev/null; then
        echo -e "${GREEN}✅ Tailscale already installed ($(tailscale version | head -n1))${NC}"
    else
        echo "   Tailscale is not installed."
        read -p "   Install Tailscale now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            curl -fsSL https://tailscale.com/install.sh | sh
            echo -e "${GREEN}✅ Tailscale installed${NC}"
        else
            echo -e "${YELLOW}⚠️  Skipping Tailscale install. Run manually when ready:${NC}"
            echo "   curl -fsSL https://tailscale.com/install.sh | sh"
        fi
    fi
    echo ""
fi

# Set up Traefik dashboard BasicAuth (Linux only)
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "🔐 Setting up Traefik dashboard BasicAuth..."

    # Check if already set in .env
    if grep -q "^TRAEFIK_DASHBOARD_USERS=.\+" .env 2>/dev/null; then
        echo -e "${GREEN}✅ TRAEFIK_DASHBOARD_USERS already set in .env${NC}"
    else
        # Install apache2-utils if htpasswd is not available
        if ! command -v htpasswd &> /dev/null; then
            echo "   htpasswd not found. Installing apache2-utils..."
            sudo apt-get install -y apache2-utils
        fi

        read -s -p "   Enter a password for the Traefik dashboard (username: admin): " TRAEFIK_PASS
        echo
        HTPASSWD_ENTRY=$(htpasswd -nbB admin "$TRAEFIK_PASS")
        # Escape $ → $$ for Docker Compose label interpolation
        ESCAPED=$(echo "$HTPASSWD_ENTRY" | sed 's/\$/\$\$/g')

        # Write TRAEFIK_DASHBOARD_USERS (hashed) into .env
        if grep -q "^TRAEFIK_DASHBOARD_USERS=" .env; then
            sed -i "s|^TRAEFIK_DASHBOARD_USERS=.*|TRAEFIK_DASHBOARD_USERS=$ESCAPED|" .env
        else
            echo "TRAEFIK_DASHBOARD_USERS=$ESCAPED" >> .env
        fi

        # Write plain-text credentials for Homepage widget
        if grep -q "^TRAEFIK_USERNAME=" .env; then
            sed -i "s|^TRAEFIK_USERNAME=.*|TRAEFIK_USERNAME=admin|" .env
        else
            echo "TRAEFIK_USERNAME=admin" >> .env
        fi
        if grep -q "^TRAEFIK_PASSWORD=" .env; then
            sed -i "s|^TRAEFIK_PASSWORD=.*|TRAEFIK_PASSWORD=$TRAEFIK_PASS|" .env
        else
            echo "TRAEFIK_PASSWORD=$TRAEFIK_PASS" >> .env
        fi

        echo -e "${GREEN}✅ Traefik dashboard credentials set in .env${NC}"
    fi
    echo ""
fi

# Generate Wallabag secret if not already set
echo "🔐 Setting up Wallabag secret..."
if grep -q "^WALLABAG_SECRET=.\+" .env 2>/dev/null; then
    echo -e "${GREEN}✅ WALLABAG_SECRET already set in .env${NC}"
else
    WALLABAG_SECRET=$(openssl rand -hex 32)
    if grep -q "^WALLABAG_SECRET=" .env; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^WALLABAG_SECRET=.*|WALLABAG_SECRET=$WALLABAG_SECRET|" .env
        else
            sed -i "s|^WALLABAG_SECRET=.*|WALLABAG_SECRET=$WALLABAG_SECRET|" .env
        fi
    else
        echo "WALLABAG_SECRET=$WALLABAG_SECRET" >> .env
    fi
    echo -e "${GREEN}✅ WALLABAG_SECRET generated and written to .env${NC}"
fi

# Generate KOReader Sync password salt if not already set
echo "🔐 Setting up KOReader Sync password salt..."
if grep -q "^KOSYNC_PASSWORD_SALT=.\+" .env 2>/dev/null; then
    echo -e "${GREEN}✅ KOSYNC_PASSWORD_SALT already set in .env${NC}"
else
    KOSYNC_PASSWORD_SALT=$(openssl rand -hex 32)
    if grep -q "^KOSYNC_PASSWORD_SALT=" .env; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^KOSYNC_PASSWORD_SALT=.*|KOSYNC_PASSWORD_SALT=$KOSYNC_PASSWORD_SALT|" .env
        else
            sed -i "s|^KOSYNC_PASSWORD_SALT=.*|KOSYNC_PASSWORD_SALT=$KOSYNC_PASSWORD_SALT|" .env
        fi
    else
        echo "KOSYNC_PASSWORD_SALT=$KOSYNC_PASSWORD_SALT" >> .env
    fi
    echo -e "${GREEN}✅ KOSYNC_PASSWORD_SALT generated and written to .env${NC}"
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
echo "   - TRAEFIK_DASHBOARD_USERS: set by this script (re-run to change)"
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
echo "   https://files.woggles.work     — FileBrowser (random password — run: docker logs filebrowser)"
echo "   https://wallabag.woggles.work  — Read-it-later (default login: wallabag/wallabag — change immediately)"
echo ""
echo "6. Enable Tailscale remote access:"
echo "   sudo tailscale up --ssh"
echo "   (Visit the printed URL to authenticate with your Tailscale account)"
echo "   See docs/tailscale.md for full details."
echo ""
