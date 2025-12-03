# Home Network Server

[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-Required-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D20.0.0-339933?logo=node.js)](https://nodejs.org/)
[![pnpm](https://img.shields.io/badge/pnpm-8.15.4-F69220?logo=pnpm)](https://pnpm.io/)
[![CI](https://github.com/riccjohn/home-network/actions/workflows/ci.yml/badge.svg)](https://github.com/riccjohn/home-network/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A self-hosted home network server setup running on Ubuntu Server, managed entirely through Docker Compose. This project provides a complete home network infrastructure with DNS, ad-blocking, service dashboard, reverse proxy, and secure remote access capabilities.

## Overview

This project provides a complete home network infrastructure including:

- [<img src="https://cdn.simpleicons.org/pihole/000000" alt="Pi-hole" width="20" height="20"> **Pi-hole**](https://pi-hole.net/) - Network-wide DNS and ad-blocking
- [<img src="https://cdn.simpleicons.org/homepage/000000" alt="Homepage" width="20" height="20"> **Homepage**](https://gethomepage.dev/) - Service dashboard and navigation hub
- [<img src="https://cdn.simpleicons.org/traefikproxy/000000" alt="Traefik" width="20" height="20"> **Traefik**](https://traefik.io/) - Reverse proxy for easy service access (planned)
- [<img src="https://cdn.simpleicons.org/tailscale/000000" alt="Tailscale" width="20" height="20"> **Tailscale**](https://tailscale.com/) - Secure remote access VPN (planned)
- **Additional Services** - [<img src="https://cdn.simpleicons.org/jellyfin/000000" alt="Jellyfin" width="20" height="20"> Jellyfin](https://jellyfin.org/), [<img src="https://cdn.simpleicons.org/syncthing/000000" alt="Syncthing" width="20" height="20"> Syncthing](https://syncthing.net/), [<img src="https://cdn.simpleicons.org/coder/000000" alt="Code-Server" width="20" height="20"> Code-Server](https://coder.com/), and more (planned)

All services are accessible from devices across the network (Linux, Android, TVs, Mac, iPhone, iPad, etc.).

## Services

### Currently Implemented

- [<img src="https://cdn.simpleicons.org/pihole/000000" alt="Pi-hole" width="20" height="20"> **Pi-hole**](https://pi-hole.net/) - Network-wide DNS and ad-blocking service
- [<img src="https://cdn.simpleicons.org/homepage/000000" alt="Homepage" width="20" height="20"> **Homepage**](https://gethomepage.dev/) - Service dashboard and navigation hub

### Planned Services

- [<img src="https://cdn.simpleicons.org/traefikproxy/000000" alt="Traefik" width="20" height="20"> **Traefik**](https://traefik.io/) - Reverse proxy with automatic SSL/TLS
- [<img src="https://cdn.simpleicons.org/tailscale/000000" alt="Tailscale" width="20" height="20"> **Tailscale**](https://tailscale.com/) - Secure remote access VPN
- [<img src="https://cdn.simpleicons.org/jellyfin/000000" alt="Jellyfin" width="20" height="20"> **Jellyfin**](https://jellyfin.org/) - Media streaming server
- [<img src="https://cdn.simpleicons.org/syncthing/000000" alt="Syncthing" width="20" height="20"> **Syncthing**](https://syncthing.net/) - File synchronization
- [<img src="https://cdn.simpleicons.org/coder/000000" alt="Code-Server" width="20" height="20"> **Code-Server**](https://coder.com/cde) - VSCode in browser for remote development

For detailed progress information and implementation status, see [PLANNING.md](./PLANNING.md).

## Prerequisites

Before setting up the home network server, ensure you have the following installed:

- **Docker** - Container runtime ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose** - Container orchestration ([Install Docker Compose](https://docs.docker.com/compose/install/))
- **Node.js** - Version 20.0.0 or higher ([Install Node.js](https://nodejs.org/))
- **pnpm** - Version 8.15.4 ([Install pnpm](https://pnpm.io/installation))

### Verify Prerequisites

```bash
# Check Docker
docker --version

# Check Docker Compose
docker compose version

# Check Node.js
node --version  # Should be >= 20.0.0

# Check pnpm
pnpm --version  # Should be 8.15.4
```

## Installation & Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd home-network
```

### 2. Install Development Dependencies

```bash
pnpm install
```

### 3. Run Setup Script

The setup script will:

- Verify Docker and Docker Compose are installed
- Create necessary directories
- Auto-detect your server IP address
- Create or update the `.env` file

```bash
./setup.sh
```

### 4. Configure Environment Variables

Edit the `.env` file with your settings. See `.env.example` for all available environment variables and their descriptions.

### 5. Configure Router DNS

Configure your router to use Pi-hole as the DNS server:

1. Log into your router's admin interface
2. Find DNS settings (usually in DHCP or Network settings)
3. Set Primary DNS to your server IP (e.g., `192.168.0.243`)
4. Set Secondary DNS to a backup (e.g., `8.8.8.8` or `1.1.1.1`)
5. Save and restart router if needed

### 6. Start Services

```bash
docker compose up -d
```

### 7. Access Services

- [<img src="https://cdn.simpleicons.org/pihole/000000" alt="Pi-hole" width="20" height="20"> **Pi-hole Admin**](https://pi-hole.net/): `http://YOUR_SERVER_IP/admin`
- [<img src="https://cdn.simpleicons.org/homepage/000000" alt="Homepage" width="20" height="20"> **Homepage**](https://gethomepage.dev/): `http://YOUR_SERVER_IP:3000`

## Project Structure

```
home-network/
├── docker-compose.yml      # Main orchestration file
├── .env                    # Environment variables (gitignored)
├── .env.example           # Environment template
├── setup.sh               # Initial setup script
├── package.json           # Node.js dependencies
├── PLANNING.md            # Detailed planning and progress document
├── docs/                  # Service-specific documentation
│   └── pihole-*.md
├── scripts/               # Service-specific scripts
│   └── pihole/
├── pihole/                # Pi-hole data directories
│   ├── etc/
│   └── etc-dnsmasq.d/
└── homepage/              # Homepage configuration
    └── config/
```

## Progress & Planning

For detailed information about:

- Implementation progress and status
- Phased rollout strategy
- Architecture overview
- Security considerations
- Network configuration details
- Future plans and roadmap

See **[PLANNING.md](./PLANNING.md)** for the complete planning document.

## Scripts

- `scripts/pihole/test-pihole.sh` - Test Pi-hole functionality

## Contributing

This is a personal home network setup project. Contributions and suggestions are welcome!
