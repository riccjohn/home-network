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
5. **Future Services** - Jellyfin, Syncthing, and others

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
       │   └─ Future Services (via Traefik)
       │
       └─ Volumes (persistent data)
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

- [ ] Add Homepage service to docker-compose
- [ ] Configure Homepage with initial service links
- [ ] Set up Homepage configuration directory
- [ ] Integrate Homepage with Pi-hole (show status)
- [ ] Access Homepage from network devices

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

**Testing Checklist:**

- [ ] Homepage accessible from network devices
- [ ] Pi-hole link works from Homepage
- [ ] Homepage displays correctly on all device types
- [ ] Configuration persists across container restarts

**Success Criteria:**

- Homepage serves as central navigation hub
- All services accessible via Homepage links
- Homepage responsive on mobile and desktop devices

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

## Phase 4: Additional Services 📦

### Goal

Add more self-hosted services to the home network setup.

### Planned Services

#### Jellyfin (Media Server)

- **Purpose:** Media streaming and management
- **Access:** `jellyfin.newton.local`
- **Requirements:** Media storage volumes, GPU passthrough (optional)
- **Integration:** Homepage widget for media stats

#### Syncthing (File Synchronization)

- **Purpose:** File sync across devices
- **Access:** `syncthing.newton.local`
- **Requirements:** Data volumes for synced folders
- **Integration:** Homepage link, status widget

#### Future Services (To Be Determined)

- Additional services as needed
- Each service will follow the same pattern:
  - Add to docker-compose.yml
  - Configure Traefik labels
  - Add to Homepage config
  - Document in README

### Implementation Pattern

For each new service:

1. Add service definition to docker-compose.yml
2. Configure Traefik labels for routing
3. Add service link to Homepage config
4. Create necessary volume directories
5. Update documentation
6. Test accessibility from all devices

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
- VPN access for remote management (future)

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
├── jellyfin/
│   ├── config/               # Jellyfin config
│   └── cache/                # Jellyfin cache
├── syncthing/
│   ├── config/               # Syncthing config
│   └── data/                 # Synced data
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

- ✅ Homepage accessible from all devices
- ✅ Homepage provides navigation to all services
- ✅ Service status visible in Homepage

### Phase 3 Success

- ✅ All services accessible via domain names
- ✅ No port numbers needed for access
- ✅ Traefik automatically routes new services

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

4. **Ongoing:** Add services as needed
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

**Last Updated:** 2025-11-30
**Status:** Phase 1 Complete, Phase 2 Next
