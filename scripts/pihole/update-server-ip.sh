#!/bin/bash

# Update SERVER_IP in .env file
# Useful if the server's IP address changes

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🌐 Detecting server IP address..."

# Detect server IP
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n1 || echo "")
else
    # Linux
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1.1.1.1 | awk '{print $7}' | head -n1 || echo "")
fi

if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" = "" ]; then
    echo -e "${RED}❌ Could not detect server IP address${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Detected server IP: $SERVER_IP${NC}"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "   Run ./setup.sh first to create .env file"
    exit 1
fi

# Update or add SERVER_IP in .env
if grep -q "^SERVER_IP=" .env; then
    # Update existing SERVER_IP
    OLD_IP=$(grep "^SERVER_IP=" .env | cut -d'=' -f2)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" .env
    else
        sed -i "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" .env
    fi
    echo -e "${GREEN}✅ Updated SERVER_IP from $OLD_IP to $SERVER_IP${NC}"
else
    # Add SERVER_IP to .env
    {
        echo ""
        echo "# Server IP (auto-detected)"
        echo "SERVER_IP=$SERVER_IP"
    } >> .env
    echo -e "${GREEN}✅ Added SERVER_IP to .env file${NC}"
fi

echo ""
echo "💡 If Pi-hole is running, restart it to apply the change:"
echo "   docker compose restart pihole"

