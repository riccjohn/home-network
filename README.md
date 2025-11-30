# Home Network Setup

A centralized Docker Compose configuration for managing your home network services, including Pi-hole, Syncthing, Jellyfin, and Homepage, all accessible through a unified dashboard with Traefik as the reverse proxy.

## Services Included

- **Homepage** - Unified dashboard to access all services
- **Pi-hole** - DNS ad-blocker and network-wide tracker blocker
- **Syncthing** - Continuous file synchronization
- **Jellyfin** - Media server for movies, TV shows, and music
- **Traefik** - Reverse proxy and load balancer (no need to remember port numbers!)

## Prerequisites

- Docker and Docker Compose installed on your server
- Basic knowledge of Docker and networking
- A domain name (optional - can use local domain like `home.local`)

## Quick Start

1. **Clone or download this repository** to your server

2. **Run the setup script** (optional but recommended):
   ```bash
   ./setup.sh
   ```
   This will create necessary directories and help you get started.

3. **Create environment file** (if not done by setup script):
   ```bash
   cp env.example .env
   ```
   Edit `.env` and set your domain, timezone, media path, and Pi-hole password:
   ```bash
   DOMAIN=home.local
   TZ=America/New_York
   MEDIA_PATH=/path/to/your/media
   PIHOLE_PASSWORD=your_secure_password
   ```

4. **Start all services**:
   ```bash
   docker compose up -d
   ```

5. **Configure DNS/hosts file**:
   
   For local network access, add entries to your router's DNS or your device's `/etc/hosts` file:
   ```
   192.168.1.100  home.local
   192.168.1.100  homepage.home.local
   192.168.1.100  pihole.home.local
   192.168.1.100  syncthing.home.local
   192.168.1.100  jellyfin.home.local
   192.168.1.100  traefik.home.local
   ```
   Replace `192.168.1.100` with your server's IP address.

## Accessing Services

Once everything is running, you can access:

- **Homepage Dashboard**: `https://homepage.home.local` or `https://home.local`
- **Pi-hole**: `https://pihole.home.local`
- **Syncthing**: `https://syncthing.home.local`
- **Jellyfin**: `https://jellyfin.home.local`
- **Traefik Dashboard**: `https://traefik.home.local:8080` (or via Homepage)

All services are also accessible through the Homepage dashboard, so you don't need to remember individual URLs!

## Initial Setup for Each Service

### Pi-hole

1. Access `https://pihole.home.local` (or `http://YOUR_SERVER_IP:8053`)
2. Log in with the password set in your `.env` file (default: `changeme`)
3. **Configure your router to use Pi-hole as DNS server:**
   - Log into your router's admin panel (usually `192.168.1.1` or `192.168.0.1`)
   - Find the DNS settings (usually under "Network", "DHCP", or "Internet" settings)
   - Set the primary DNS server to your server's IP address (e.g., `192.168.1.100`)
   - Optionally set a secondary DNS (like `1.1.1.1` or `8.8.8.8`) as a backup
   - Save and apply the changes
   - **Important:** After changing DNS on the router, devices may need to renew their DHCP lease or reconnect to WiFi to pick up the new DNS settings

4. **Verify it's working:**
   - Check the Pi-hole dashboard - you should see DNS queries from devices on your network
   - Visit a website with ads - they should be blocked
   - Check the Pi-hole logs to see blocked queries

**Why this setup:** By configuring your router to use Pi-hole as the DNS server, ALL devices on your network (phones, tablets, computers, smart TVs, etc.) will automatically have ads blocked without needing to configure each device individually.

### Syncthing

1. Access `https://syncthing.home.local` (or `http://YOUR_SERVER_IP:8384`)
2. Set up your first folder to sync
3. Add devices you want to sync with
4. Configure sharing settings

### Jellyfin

1. Access `https://jellyfin.home.local` (or `http://YOUR_SERVER_IP:8096`)
2. Complete the initial setup wizard
3. Add your media libraries
4. Configure users and permissions

### Homepage

1. Access `https://homepage.home.local` (or `http://YOUR_SERVER_IP:3000`)
2. The services should already be configured in `homepage/config/services.yaml`
3. Customize the appearance in `homepage/config/settings.yaml`

## Configuration Files

- `docker-compose.yml` - Main service definitions
- `.env` - Environment variables (create from `env.example`)
- `homepage/config/` - Homepage configuration files
- `pihole/etc/` - Pi-hole configuration and blocklists
- `traefik/letsencrypt/` - SSL certificates (auto-generated)

## Ports Used

- **80** - HTTP (Traefik)
- **443** - HTTPS (Traefik)
- **53** - DNS (Pi-hole)
- **3000** - Homepage (direct access)
- **8053** - Pi-hole Web UI (direct access)
- **8096** - Jellyfin (direct access)
- **8384** - Syncthing (direct access)
- **8080** - Traefik Dashboard (direct access)

## SSL Certificates

Traefik is configured to automatically obtain SSL certificates from Let's Encrypt. For local networks:

- If using a real domain, ensure it points to your server and ports 80/443 are accessible
- If using a local domain (like `home.local`), you may need to use self-signed certificates or disable SSL verification in your browser

## Troubleshooting

### Docker Permission Denied Error

If you see `permission denied while trying to connect to the Docker daemon socket`, you need to add your user to the docker group:

```bash
sudo usermod -aG docker $USER
```

Then log out and log back in, or run:
```bash
newgrp docker
```

After this, you should be able to run `docker compose` commands without `sudo`.

**Note:** Avoid using `sudo` with docker compose as it can cause permission issues with volume mounts.

### Services not accessible via Traefik

1. Check that services are running: `docker compose ps`
2. Verify Traefik labels are correct in `docker-compose.yml`
3. Check Traefik logs: `docker compose logs traefik`

### DNS not working / Ad blocking not working

1. **Verify router DNS configuration:**
   - Check that your router's DNS settings point to your server's IP address
   - Ensure devices have renewed their DHCP lease (disconnect/reconnect WiFi or restart devices)
   
2. **Check Pi-hole is running:**
   - Access Pi-hole dashboard and check for DNS queries
   - If no queries appear, devices aren't using Pi-hole as DNS
   
3. **Verify port 53 is accessible:**
   - Ensure port 53 is not blocked by firewall: `sudo ufw allow 53/tcp && sudo ufw allow 53/udp`
   - If you see "port 53 already in use" errors, configure systemd-resolved:
     - Edit `/etc/systemd/resolved.conf`: `sudo nano /etc/systemd/resolved.conf`
     - Add: `DNSStubListener=no` under `[Resolve]`
     - Restart: `sudo systemctl restart systemd-resolved`
   
4. **Test DNS manually:**
   - From a device, run: `nslookup google.com YOUR_SERVER_IP`
   - Should return results if Pi-hole is working

### Can't access services

1. Check firewall rules allow ports 80, 443, and service-specific ports
2. Verify DNS/hosts file entries are correct
3. Try accessing services directly via IP:port (e.g., `http://192.168.1.100:3000`)

## Updating Services

To update all services to their latest versions:

```bash
docker compose pull
docker compose up -d
```

## Stopping Services

To stop all services:

```bash
docker compose down
```

To stop and remove all volumes (⚠️ **WARNING**: This deletes all data):

```bash
docker compose down -v
```

## Backup

Important data is stored in the following directories:
- `pihole/etc/` - Pi-hole configuration and blocklists
- `syncthing/` - Syncthing configuration and data
- `jellyfin/` - Jellyfin configuration
- `homepage/config/` - Homepage configuration

Regularly backup these directories to preserve your settings.

## Security Notes

⚠️ **Important**: This setup does not include authentication by default. For security:

1. Deploy behind a VPN for remote access
2. Use a reverse proxy with authentication (e.g., Authelia, Authentik)
3. Keep services updated regularly
4. Use strong passwords for all services
5. Consider firewall rules to restrict access

## License

This configuration is provided as-is for personal use.

## Contributing

Feel free to submit issues or pull requests if you have improvements or find bugs.

