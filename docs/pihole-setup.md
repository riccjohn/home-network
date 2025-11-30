# Pi-hole Setup Guide

## Prerequisites

- Docker and Docker Compose installed
- Ubuntu Server (or compatible Linux distribution)
- Router with configurable DNS settings

## Installation Steps

1. **Run the setup script:**
   ```bash
   ./setup.sh
   ```
   This will:
   - Check Docker installation
   - Create `.env` file from template
   - Auto-detect and set `SERVER_IP`
   - Create necessary directories

2. **Configure environment variables:**
   Edit the `.env` file created by the setup script:
   ```bash
   nano .env
   ```
   - Set `PIHOLE_PASSWORD` to a strong password
   - `SERVER_IP` is automatically detected and set by the setup script
   - Adjust `TZ` to your timezone
   - Modify `DOMAIN` if needed (default: home.local)
   
   **Note:** If your server's IP changes, run `scripts/pihole/update-server-ip.sh` to update it automatically.

3. **Start Pi-hole:**
   ```bash
   docker compose up -d
   ```
   
   **Note:** Pi-hole uses `host` networking mode to see real client IP addresses in the query log. This allows you to identify which devices are making DNS queries, rather than all queries appearing to come from the Docker gateway.

4. **Configure your router:**
   - Log into your router's admin interface
   - Find **DHCP Server Settings** (not just router DNS settings!)
   - Set **Primary DNS** to your server's IP address
   - Set **Secondary DNS** to `8.8.8.8` or `1.1.1.1`
   - Save and restart router if needed
   
   ⚠️ **Important:** You need to configure **DHCP DNS settings**, not just router DNS. These are often separate settings in router configuration.

5. **Access Pi-hole admin:**
   - Open browser to `http://YOUR_SERVER_IP/admin`
   - Login with password from `.env` file

6. **Verify it's working:**
   - See [Testing Pi-hole](#testing-pi-hole) below
   - Or run: `scripts/pihole/test-pihole.sh`

## Testing Pi-hole

### Quick Test Script

Run the test script on your server:
```bash
./scripts/pihole/test-pihole.sh
```

### Manual Testing

#### Method 1: Check Pi-hole Dashboard

1. **View Query Log:**
   - Go to `http://YOUR_SERVER_IP/admin`
   - Navigate to **Query Log** (left sidebar)
   - You should see DNS queries from devices on your network
   - Look for queries from different devices (phones, computers, etc.)

2. **Check Statistics:**
   - Go to **Dashboard** in Pi-hole admin
   - Check the **Queries** counter - it should be increasing
   - Check **Blocked** counter - should show blocked ad/tracking domains
   - **Clients** should show devices using Pi-hole

#### Method 2: Test DNS Resolution

**On the server:**
```bash
# Test DNS resolution through Pi-hole
dig @127.0.0.1 google.com

# Or using nslookup
nslookup google.com 127.0.0.1
```

**On a client device:**
```bash
# Linux/Mac
dig @YOUR_SERVER_IP google.com
nslookup google.com YOUR_SERVER_IP

# Check what DNS your device is using
# Linux
cat /etc/resolv.conf

# Mac
scutil --dns | grep nameserver

# Windows
ipconfig /all | findstr "DNS Servers"
```

#### Method 3: Test Ad-Blocking

1. **Visit a test site with ads:**
   - Visit `https://www.forbes.com` or `https://www.cnn.com`
   - Check if ads are blocked (you may see blank spaces or "blocked" messages)

2. **Test known ad domains:**
   - Visit `http://pi.hole` in your browser
   - You should see the Pi-hole block page
   - Or test: `http://doubleclick.net` (should be blocked)

3. **Check blocked domains in Pi-hole:**
   - Go to **Query Log** in Pi-hole admin
   - Look for entries marked as **Blocked** (red)
   - Common blocked domains: `doubleclick.net`, `googleadservices.com`, `googlesyndication.com`

#### Method 4: Verify Device DNS Settings

**Check if devices are using Pi-hole DNS:**

**Android:**
- Settings → Wi-Fi → Long press your network → Modify network → Advanced → IP settings
- Check DNS 1 and DNS 2 (should be your server IP)

**iPhone/iPad:**
- Settings → Wi-Fi → Tap (i) next to your network → Configure DNS
- Should show your server IP

**Mac:**
```bash
scutil --dns | grep nameserver
```

**Linux:**
```bash
cat /etc/resolv.conf
```

**Windows:**
```cmd
ipconfig /all
```

### Expected Results

✅ **Working correctly if:**
- Query Log shows queries from multiple devices
- Statistics show increasing query counts
- Blocked counter shows blocked domains
- DNS resolution works (google.com resolves)
- Ad domains are blocked (doubleclick.net returns 0.0.0.0 or fails)
- Devices show your server IP as DNS server

❌ **Not working if:**
- Query Log is empty (devices not using Pi-hole)
- No blocked domains (ad-blocking not working)
- DNS resolution fails
- Devices show different DNS servers

## Troubleshooting

For detailed troubleshooting, see [Pi-hole Troubleshooting](./pihole-troubleshooting.md)

**Quick fixes:**

- **Can't access Pi-hole web interface:**
  - Check firewall: `sudo ufw allow 80/tcp`
  - Verify container is running: `docker compose ps`
  - Check logs: `docker compose logs pihole`

- **Devices not using Pi-hole DNS:**
  - Run diagnostic: `./scripts/pihole/diagnose-pihole.sh`
  - See [Troubleshooting Guide](./pihole-troubleshooting.md) for router configuration

- **DNS not resolving:**
  - Check Pi-hole logs: `docker compose logs pihole`
  - Verify upstream DNS servers in Pi-hole settings
  - Test DNS directly: `dig @YOUR_SERVER_IP google.com`
  - Check firewall: `sudo ufw allow 53/tcp && sudo ufw allow 53/udp`

