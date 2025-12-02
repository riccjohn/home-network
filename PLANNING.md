# Home Network Server - Planning Document

## Overview

This document outlines the phased approach to setting up a home network server running on an Ubuntu Server (ThinkCentre) that will provide various self-hosted services accessible from multiple devices (Linux, Android, TVs, Mac, iPhone, iPad, etc.).

**Key Requirements:**

- Single `docker-compose.yml` file to manage all services
- Good CI/CD practices built into the project
- Services accessible from all devices on the network
- Secure and maintainable architecture

---

## Architecture Overview

### Infrastructure Components

1. **Docker & Docker Compose** - Container orchestration
2. **Pi-hole** - Network-wide DNS and ad-blocking
3. **Homepage** - Service dashboard and navigation hub
4. **Traefik** - Reverse proxy with automatic SSL/TLS
5. **Tailscale** - Secure remote access VPN
6. **Future Services** - Jellyfin, Syncthing, Code-Server (VSCode), and others

### Network Architecture

```
Internet
   │
   ├─ Router (configured to use Pi-hole as DNS)
   │
   └─ Ubuntu Server (ThinkCentre)
       │
       ├─ Docker Network
       │   │
       │   ├─ Pi-hole (Port 53, 80, 443)
       │   ├─ Traefik (Port 80, 443) - Reverse Proxy
       │   ├─ Homepage (via Traefik)
       │   ├─ Tailscale (VPN for remote access)
       │   ├─ Code-Server (VSCode in browser)
       │   └─ Future Services (via Traefik)
       │
       └─ Volumes (persistent data)

Remote Access (via Tailscale)
   │
   ├─ Mobile Devices (iPhone, iPad, Android)
   ├─ Remote Laptops/Computers
   └─ All devices can securely access services via Tailscale VPN
```

---

## Phase 1: Pi-hole MVP 🎯

### Goal

Get Pi-hole up and running as the network's DNS server with ad-blocking capabilities.

### Objectives

- [x] Set up Pi-hole container in docker-compose
- [x] Configure Docker network for Pi-hole
- [x] Configure router to use Pi-hole as DNS server
- [x] Verify ad-blocking is working across network
- [x] Test DNS resolution from multiple devices
- [ ] Local domain name resolution (will be configured in Phase 3 with Traefik)

### Implementation Details

**Docker Compose Configuration:**

- Pi-hole service with proper network configuration
- Persistent volumes for Pi-hole configuration
- Environment variables for admin password
- Port mappings: 53 (DNS), 80 (Web UI), 443 (HTTPS)

**Router Configuration:**

- Set primary DNS to server's IP address
- Set secondary DNS to a backup (e.g., 1.1.1.1 or 8.8.8.8)
- Ensure DHCP is configured to distribute Pi-hole DNS to clients

**Testing Checklist:**

- [x] Pi-hole web interface accessible (via IP: `http://192.168.0.243/admin`)
- [x] DNS queries resolve correctly
- [x] Ad-blocking works (test with known ad domains)
- [x] All devices on network using Pi-hole DNS
- [x] Query logs visible in Pi-hole dashboard

**Note on Domain Names:**

- Currently accessing Pi-hole via IP address (`http://192.168.0.243/admin`)
- Local domain name resolution (e.g., `newton.local`) will be configured in Phase 3 with Traefik
- DNS configuration will be handled through Pi-hole's web interface or `custom.list` file when needed

**Success Criteria:**

- ✅ All network devices automatically use Pi-hole for DNS
- ✅ Ad-blocking is active and working
- ✅ Pi-hole dashboard shows queries from network devices
- ✅ No DNS resolution issues for external domains
- ⏳ Local domain names will be configured in Phase 3

---

## Phase 2: Homepage Integration 🏠

### Goal

Add Homepage (https://github.com/gethomepage/homepage) as a service dashboard to navigate and monitor all services.

### Objectives

- [x] Add Homepage service to docker-compose
- [x] Configure Homepage with initial service links
- [x] Set up Homepage configuration directory
- [ ] Integrate Homepage with Pi-hole (show status) - needs service status indicators
- [x] Access Homepage from network devices

### Implementation Details

**Docker Compose Configuration:**

- Homepage service with proper network configuration
- Volume mount for Homepage config directory
- Environment variables for configuration
- Initial port mapping (will be removed when Traefik is added)

**Homepage Configuration:**

- Create initial `config/config.yaml` with:
  - Service links (Pi-hole admin interface)
  - Basic widgets (time, date, weather)
  - Service status indicators
- Configure Pi-hole integration widget (if available)

**Outstanding Items:**

The following items still need to be completed for Phase 2:

- **Configuration Persistence Verification:** Test that Homepage configuration persists across container restarts (verify volume mounts are working correctly)
- **Service Status Indicators:** Set up service status monitoring to show Pi-hole status in Homepage (integrate Pi-hole status API/widget)
- **Basic Widgets Setup:** Expand widget configuration beyond the current resources widget (time, date, weather, or other useful widgets)

**Testing Checklist:**

- [x] Homepage accessible from network devices (192.168.0.243:3000)
- [x] Pi-hole link works from Homepage
- [ ] Homepage displays correctly on all device types
- [ ] Configuration persists across container restarts (needs verification)
- [ ] Service status indicators working
- [ ] Basic widgets configured (resources widget exists, but more widgets may be needed)

**Success Criteria:**

- ✅ Homepage serves as central navigation hub
- ✅ All services accessible via Homepage links
- ⏳ Homepage responsive on mobile and desktop devices (needs testing on all device types)
- ⏳ Service status indicators working (outstanding)
- ⏳ Configuration persists across container restarts (needs verification)

---

## Phase 3: Traefik Reverse Proxy 🔄

### Goal

Implement Traefik as a reverse proxy to access services via friendly domain names without remembering ports.

### Objectives

- [ ] Add Traefik service to docker-compose
- [ ] Configure Traefik with Docker provider
- [ ] Set up automatic service discovery via labels
- [ ] Configure routing rules for Homepage
- [ ] Configure routing rules for Pi-hole
- [ ] Set up local domain resolution (home.local)
- [ ] Remove direct port mappings (use Traefik only)

### Implementation Details

**Docker Compose Configuration:**

- Traefik service with Docker socket access
- Traefik dashboard (protected)
- Dynamic configuration via labels
- Network configuration for service communication

**Traefik Configuration:**

- Docker provider enabled
- Entrypoints: HTTP (80), HTTPS (443)
- Router rules for each service:
  - `homepage.newton.local` → Homepage
  - `pihole.newton.local` → Pi-hole
  - `traefik.newton.local` → Traefik dashboard
- Middleware for security headers

**Service Labels (Example):**

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.homepage.rule=Host(`homepage.newton.local`)"
  - "traefik.http.routers.homepage.entrypoints=web"
```

**DNS Configuration:**

- Configure Pi-hole to resolve `*.newton.local` to server IP (192.168.0.243)
- Add wildcard DNS entry via Pi-hole web interface (Local DNS Records) or directly in `pihole/etc/custom.list`:
  - Format: `.newton.local 192.168.0.243` (wildcard for all subdomains)
  - Or add individual entries: `pihole.newton.local 192.168.0.243`, `homepage.newton.local 192.168.0.243`, etc.
- Alternative: Router DNS entries or `/etc/hosts` entries for `*.newton.local`
- Or use mDNS/Bonjour for automatic discovery

**Testing Checklist:**

- [ ] Traefik dashboard accessible
- [ ] Services accessible via domain names
- [ ] Port mappings removed from services
- [ ] Services only accessible through Traefik
- [ ] Routing works from all device types

**Success Criteria:**

- All services accessible via friendly domain names
- No need to remember port numbers
- Traefik automatically discovers new services
- Clean, maintainable routing configuration

---

## Phase 4: Tailscale Secure Remote Access 🔐

### Goal

Set up Tailscale to enable secure, encrypted remote access to all services from anywhere without exposing ports to the internet.

### Objectives

- [ ] Add Tailscale service to docker-compose
- [ ] Configure Tailscale authentication (auth key)
- [ ] Set up Tailscale subnet routing (optional, for full network access)
- [ ] Configure services to be accessible via Tailscale IP
- [ ] Test remote access from mobile devices and remote locations
- [ ] Configure Tailscale MagicDNS for friendly service names
- [ ] Document remote access procedures

### Implementation Details

**Docker Compose Configuration:**

- Tailscale container with host network mode (required for proper routing)
- Persistent volume for Tailscale state (`/var/lib/tailscale`)
- Environment variables for authentication
- Proper restart policy

**Tailscale Setup Steps:**

1. **Create Tailscale Account & Auth Key:**
   - Sign up at https://tailscale.com (free tier available, up to 100 devices)
   - Generate auth key from Tailscale admin console (Settings → Keys)
   - Use one-time key or reusable key for server
   - Store auth key in `.env` file (never commit to git)

2. **Container Configuration:**
   - Use official `tailscale/tailscale` image
   - Mount `/var/lib/tailscale` for persistent state
   - Set `TS_AUTHKEY` environment variable from `.env`
   - Use `network_mode: host` for proper networking
   - Add `TS_STATE_DIR` for state persistence

3. **Service Access:**
   - Services accessible via Tailscale IP (e.g., `100.x.x.x:3000` for Homepage)
   - Can use Tailscale MagicDNS (e.g., `homepage.your-tailnet.ts.net`)
   - Works alongside local network access (no conflicts)
   - No router port forwarding needed

**Remote Access Configuration:**

- **Homepage:** Accessible via Tailscale IP + port (e.g., `100.x.x.x:3000`) or MagicDNS
- **Pi-hole:** Accessible via Tailscale IP + port 80 (e.g., `100.x.x.x/admin`)
- **Code-Server (VSCode):** Accessible via Tailscale IP + port or MagicDNS (perfect for remote development)
- **Future Services (Jellyfin, etc.):** All accessible via Tailscale network
- **Traefik:** When implemented, services accessible via Traefik through Tailscale

**Security Benefits:**

- No port forwarding required on router (eliminates attack surface)
- Encrypted WireGuard-based VPN (end-to-end encryption)
- Zero-trust network model (devices must be authorized)
- Access control via Tailscale admin console
- Works behind NAT/firewalls without configuration
- Automatic key rotation and security updates

**Tailscale Features to Configure:**

- **MagicDNS:** Enable for friendly service names (e.g., `homepage.your-tailnet.ts.net`)
- **Subnet Routing (Optional):** Allow remote devices to access entire home network
- **ACLs (Access Control Lists):** Fine-grained access control if needed
- **Device Tags:** Organize and manage devices

**Testing Checklist:**

- [ ] Tailscale container running and authenticated
- [ ] Server appears in Tailscale admin console
- [ ] Can access Homepage remotely via Tailscale IP
- [ ] Can access Pi-hole remotely via Tailscale IP
- [ ] MagicDNS working (if enabled)
- [ ] Remote access works from mobile devices (iPhone, Android)
- [ ] Remote access works from different networks
- [ ] Services remain accessible on local network
- [ ] No conflicts between local and remote access

**Success Criteria:**

- All services accessible securely from remote locations
- No router port forwarding needed
- Access works from all device types (mobile, laptop, etc.)
- Services remain accessible on local network
- Tailscale dashboard shows connected devices
- Remote access is encrypted and secure

**File Structure Addition:**

```
home-network/
├── ...
└── tailscale/
    └── state/              # Tailscale state (mounted from /var/lib/tailscale)
```

**Environment Variables (.env):**

```bash
# Tailscale Configuration
TAILSCALE_AUTHKEY=tskey-auth-xxxxx  # One-time or reusable auth key
TAILSCALE_HOSTNAME=newton-server    # Optional: custom hostname in Tailscale
```

---

## Phase 5: Additional Services 📦

### Goal

Add more self-hosted services to the home network setup.

### Planned Services

#### Jellyfin (Media Server)

- **Purpose:** Media streaming and management
- **Access:** `jellyfin.newton.local` (local) or via Tailscale (remote)
- **Requirements:** Media storage volumes, GPU passthrough (optional)
- **Integration:** Homepage widget for media stats
- **Remote Access:** Via Tailscale network (secure streaming from anywhere)

#### Syncthing (File Synchronization)

- **Purpose:** File sync across devices
- **Access:** `syncthing.newton.local` (local) or via Tailscale (remote)
- **Requirements:** Data volumes for synced folders
- **Integration:** Homepage link, status widget
- **Remote Access:** Via Tailscale network

#### Code-Server (VSCode in Browser) 💻

- **Purpose:** Full VSCode editor accessible via web browser for remote development
- **Access:** `code.newton.local` (local) or via Tailscale (remote)
- **Requirements:** 
  - Volume mounts for project directories
  - Persistent configuration and extensions
  - Secure authentication (password or OAuth)
- **Integration:** Homepage link, status widget
- **Remote Access:** Via Tailscale network (perfect for remote development)
- **Use Cases:**
  - Edit code on server from any device
  - Work on projects remotely without SSH/SCP
  - Full VSCode experience with extensions, terminal, Git integration
  - Access server filesystem directly

**Implementation Details:**

- Use official `codercom/code-server` image
- Mount project directories (e.g., `/home/newton/docs`, `/home/newton/projects`)
- Configure authentication via password or OAuth
- Persistent volume for extensions and settings
- Accessible via Traefik with proper routing
- Secure access via Tailscale for remote development

#### Future Services (To Be Determined)

- Additional services as needed
- Each service will follow the same pattern:
  - Add to docker-compose.yml
  - Configure Traefik labels (for local access)
  - Accessible via Tailscale (for remote access)
  - Add to Homepage config
  - Document in README

### Implementation Pattern

For each new service:

1. Add service definition to docker-compose.yml
2. Configure Traefik labels for routing (local access)
3. Service automatically accessible via Tailscale (remote access)
4. Add service link to Homepage config
5. Create necessary volume directories
6. Update documentation
7. Test accessibility from local and remote networks

---

## CI/CD Practices 🔄

### Version Control

- Git repository for all configuration files
- `.env.example` template (never commit `.env`)
- `.gitignore` properly configured
- Meaningful commit messages

### Automation

- **Pre-commit hooks:**
  - YAML linting (docker-compose.yml)
  - Shell script linting (setup.sh)
  - Prettier formatting
- **GitHub Actions / CI:**
  - Validate docker-compose.yml syntax
  - Test setup script
  - Check for security issues (docker images)
  - Validate configuration files

### Deployment

- **Manual deployment:**
  ```bash
  git pull
  docker compose pull
  docker compose up -d
  ```
- **Future automation:**
  - Webhook-based auto-deployment
  - Health checks and rollback procedures

### Configuration Management

- Environment variables in `.env` file
- Configuration templates in repository
- Documentation for all configuration options
- Change log for tracking updates

---

## Security Considerations 🔒

### Network Security

- Services behind reverse proxy (Traefik)
- No direct internet exposure (unless needed)
- Firewall rules on router
- Tailscale VPN for secure remote access (Phase 4)
- No port forwarding required (Tailscale handles connectivity)
- Encrypted end-to-end connections via WireGuard

### Container Security

- Use official, maintained Docker images
- Regular image updates
- Non-root users where possible
- Read-only filesystems where applicable
- Resource limits

### Access Control

- Strong passwords for all services
- Traefik basic auth for admin interfaces
- HTTPS/TLS certificates (Let's Encrypt via Traefik - future)
- Regular security updates

### Data Protection

- Encrypted volumes for sensitive data
- Regular backups of configuration
- Backup strategy for service data

---

## Network Configuration Details

### DNS Setup

- **Router Configuration:**
  - Primary DNS: Server IP (Pi-hole)
  - Secondary DNS: 1.1.1.1 or 8.8.8.8 (backup)
- **DHCP:** Router should distribute Pi-hole DNS to all clients

### Domain Resolution

- **Current Status:** Services accessed via IP addresses (e.g., `http://192.168.0.243/admin`)
- **Phase 3 Approach:** Configure Pi-hole to resolve `*.newton.local` to server IP
  - Add wildcard entry via Pi-hole web interface or directly in `pihole/etc/custom.list`:
    - Format: `.newton.local 192.168.0.243` (wildcard for all subdomains)
  - Traefik will handle routing based on subdomain (e.g., `pihole.newton.local`)
- **Alternative Options:**
  - Router DNS entries for `*.newton.local`
  - `/etc/hosts` entries on each device
  - mDNS/Bonjour for automatic discovery

### Port Requirements

- **Phase 1:** Port 53 (DNS), 80 (Pi-hole web)
- **Phase 2:** Port 3000 (Homepage) - temporary
- **Phase 3:** Port 80, 443 (Traefik) - all services via Traefik
- **Future:** Only Traefik ports exposed, all services internal

---

## File Structure

```
home-network/
├── docker-compose.yml          # Main orchestration file
├── .env                        # Environment variables (gitignored)
├── .env.example               # Environment template
├── .gitignore                 # Git ignore rules
├── README.md                  # Project documentation
├── PLANNING.md                # This file
├── setup.sh                   # Initial setup script
├── traefik/
│   ├── traefik.yml           # Traefik static config
│   └── letsencrypt/          # SSL certificates
├── pihole/
│   ├── etc/                  # Pi-hole config (includes custom.list for local DNS)
│   └── etc-dnsmasq.d/        # DNSmasq config (optional, for advanced configs)
├── scripts/
│   └── pihole/
│       ├── update-server-ip.sh   # Update server IP in .env
│       └── test-pihole.sh        # Test Pi-hole functionality
├── homepage/
│   └── config/               # Homepage config files
├── tailscale/
│   └── state/                # Tailscale state (mounted from /var/lib/tailscale)
├── jellyfin/
│   ├── config/               # Jellyfin config
│   └── cache/                # Jellyfin cache
├── syncthing/
│   ├── config/               # Syncthing config
│   └── data/                 # Synced data
├── code-server/
│   ├── config/               # Code-server config
│   └── data/                 # Code-server data (extensions, settings)
└── media/                    # Media files (Jellyfin)
```

---

## Success Metrics

### Phase 1 Success

- ✅ Network-wide ad-blocking active
- ✅ All devices using Pi-hole DNS
- ✅ Pi-hole dashboard accessible and functional (via IP: `http://192.168.0.243/admin`)
- ⏳ Domain name access will be added in Phase 3 with Traefik

### Phase 2 Success

- ✅ Homepage accessible from all devices (192.168.0.243:3000)
- ✅ Homepage provides navigation to all services
- ⏳ Service status visible in Homepage (outstanding - needs service status indicators)
- ⏳ Configuration persistence verified (outstanding - needs testing)
- ⏳ Basic widgets configured (resources widget exists, but more widgets may be needed)

### Phase 3 Success

- [ ]  All services accessible via domain names
- [ ] No port numbers needed for access
- [ ] Traefik automatically routes new services

### Phase 4 Success

- [ ] All services accessible securely from remote locations
- [ ] No router port forwarding needed
- [ ] Remote access works from all device types
- [ ] Services remain accessible on local network

### Overall Success

- ✅ Single docker-compose.yml manages all services
- ✅ CI/CD practices in place and working
- ✅ All devices can access all services
- ✅ System is maintainable and documented

---

## Next Steps

1. **Immediate:** Begin Phase 1 implementation
   - Set up Pi-hole in docker-compose.yml
   - Configure network and volumes
   - Test DNS functionality

2. **After Phase 1:** Move to Phase 2
   - Add Homepage service
   - Configure initial dashboard

3. **After Phase 2:** Implement Phase 3
   - Add Traefik reverse proxy
   - Migrate services to Traefik routing

4. **After Phase 3:** Implement Phase 4
   - Add Tailscale for secure remote access
   - Configure remote access to all services
   - Test from mobile devices and remote locations

5. **Ongoing:** Add services as needed
   - Follow established patterns
   - Maintain documentation
   - Keep CI/CD practices

---

## Notes

- This is a living document and will be updated as the project evolves
- Each phase should be fully tested before moving to the next
- Keep backups of all configuration files
- Document any deviations from this plan
- Consider performance implications as services are added

---

**Last Updated:** 2025-01-27
**Status:** Phase 1 Complete ✅ | Phase 2 In Progress (Homepage running, outstanding: configuration persistence verification, service status indicators, basic widgets) | Phase 4 (Tailscale) Planned
