#!/bin/bash

# Update Pi-hole DNS configuration from .env file
# Generates pihole/etc-dnsmasq.d/05-custom.conf based on DOMAIN and SERVER_IP from .env

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "   Run ./setup.sh first to create .env file"
    exit 1
fi

# Read specific variables from .env file
# Use grep to extract values, handling comments and empty lines
DOMAIN=$(grep -E "^DOMAIN=" .env | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")
SERVER_IP=$(grep -E "^SERVER_IP=" .env | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")

# Check if required variables are set
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "" ]; then
    echo -e "${RED}❌ DOMAIN is not set in .env file${NC}"
    exit 1
fi

if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" = "" ]; then
    echo -e "${RED}❌ SERVER_IP is not set in .env file${NC}"
    echo "   Run ./scripts/pihole/update-server-ip.sh to set it"
    exit 1
fi

# Ensure directory exists
mkdir -p pihole/etc-dnsmasq.d

# Generate DNS configuration file
DNS_CONFIG_FILE="pihole/etc-dnsmasq.d/05-custom.conf"

cat > "$DNS_CONFIG_FILE" << EOF
# Custom DNS records for Pi-hole
# This file is auto-generated from .env values
# Do not edit manually - run ./scripts/pihole/update-dns-config.sh to regenerate
# 
# Format: address=/domain.com/ip.address
#
# After editing, restart Pi-hole: docker compose restart pihole

# Domain resolution for ${DOMAIN}
address=/${DOMAIN}/${SERVER_IP}
EOF

echo -e "${GREEN}✅ Generated DNS configuration:${NC}"
echo "   Domain: ${DOMAIN} → ${SERVER_IP}"
echo "   File: ${DNS_CONFIG_FILE}"
echo ""
echo "💡 If Pi-hole is running, restart it to apply the change:"
echo "   docker compose restart pihole"

