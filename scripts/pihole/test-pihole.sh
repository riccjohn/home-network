#!/bin/bash

# Pi-hole Testing Script
# Quick tests to verify Pi-hole is working correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Pi-hole Testing Script${NC}"
echo "=========================="
echo ""

# Get server IP - detect automatically (don't source .env to avoid issues with special characters)
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1.1.1.1 | awk '{print $7}' 2>/dev/null || echo "127.0.0.1")

echo -e "${BLUE}Server IP: ${SERVER_IP}${NC}"
echo ""

# Test 1: Check if Pi-hole container is running
echo -e "${BLUE}Test 1: Checking Pi-hole container status...${NC}"
if docker compose ps pihole | grep -q "Up"; then
    echo -e "${GREEN}✅ Pi-hole container is running${NC}"
else
    echo -e "${RED}❌ Pi-hole container is not running${NC}"
    echo "   Start it with: docker compose up -d"
    exit 1
fi
echo ""

# Test 2: Test DNS resolution
echo -e "${BLUE}Test 2: Testing DNS resolution...${NC}"
if dig @127.0.0.1 google.com +short +timeout=2 2>/dev/null | grep -q "172\|192\|[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+"; then
    RESULT=$(dig @127.0.0.1 google.com +short +timeout=2 2>/dev/null | head -n1)
    echo -e "${GREEN}✅ DNS resolution working${NC}"
    echo "   google.com resolves to: $RESULT"
else
    echo -e "${RED}❌ DNS resolution failed${NC}"
    echo "   Check Pi-hole logs: docker compose logs pihole"
fi
echo ""

# Test 3: Test ad-blocking
echo -e "${BLUE}Test 3: Testing ad-blocking...${NC}"
BLOCKED_RESULT=$(dig @127.0.0.1 doubleclick.net +short +timeout=2 2>/dev/null | head -n1)
if [ "$BLOCKED_RESULT" = "0.0.0.0" ] || [ "$BLOCKED_RESULT" = "" ]; then
    echo -e "${GREEN}✅ Ad-blocking is working${NC}"
    echo "   doubleclick.net is blocked (returned: ${BLOCKED_RESULT:-"blocked"})"
else
    echo -e "${YELLOW}⚠️  Ad-blocking may not be working${NC}"
    echo "   doubleclick.net resolved to: $BLOCKED_RESULT"
    echo "   (Expected: 0.0.0.0 or empty)"
fi
echo ""

# Test 4: Check Pi-hole web interface
echo -e "${BLUE}Test 4: Checking Pi-hole web interface...${NC}"
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://${SERVER_IP}/admin" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Pi-hole web interface is accessible${NC}"
    echo "   Access at: http://${SERVER_IP}/admin"
else
    echo -e "${YELLOW}⚠️  Could not verify web interface (may require authentication)${NC}"
    echo "   Try accessing: http://${SERVER_IP}/admin"
fi
echo ""

# Test 5: Check recent logs
echo -e "${BLUE}Test 5: Checking recent Pi-hole activity...${NC}"
RECENT_LOGS=$(docker compose logs --tail=10 pihole 2>/dev/null | grep -ic "query\|dns" || echo "0")
if [ "$RECENT_LOGS" -gt 0 ]; then
    echo -e "${GREEN}✅ Pi-hole is processing queries${NC}"
    echo "   Found DNS activity in recent logs"
else
    echo -e "${YELLOW}⚠️  No recent DNS activity in logs${NC}"
    echo "   This may be normal if no devices are querying yet"
fi
echo ""

# Summary
echo -e "${BLUE}📊 Summary${NC}"
echo "=========="
echo ""
echo "Next steps to verify Pi-hole is working:"
echo ""
echo "1. Check Pi-hole Dashboard:"
echo "   http://${SERVER_IP}/admin"
echo "   - Go to 'Query Log' to see DNS queries from devices"
echo "   - Check 'Dashboard' for statistics"
echo ""
echo "2. Test from a device on your network:"
echo "   - Visit a website with ads (e.g., forbes.com)"
echo "   - Check if ads are blocked"
echo ""
echo "3. Verify devices are using Pi-hole DNS:"
echo "   - Check DNS settings on your devices"
echo "   - Should show: ${SERVER_IP}"
echo ""
echo "4. Check Query Log in Pi-hole admin:"
echo "   - Should show queries from multiple devices"
echo "   - Should show some blocked domains"
echo ""

