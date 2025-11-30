# Home Network Server

A self-hosted home network server setup running on Ubuntu Server, managed entirely through Docker Compose.

## Overview

This project provides a complete home network infrastructure including:

- **Pi-hole** - Network-wide DNS and ad-blocking
- **Homepage** - Service dashboard and navigation hub
- **Traefik** - Reverse proxy for easy service access
- **Additional Services** - Jellyfin, Syncthing, and more

All services are accessible from devices across the network (Linux, Android, TVs, Mac, iPhone, iPad, etc.).

## Planning

See [PLANNING.md](./PLANNING.md) for the complete implementation plan, including:

- Phased rollout strategy
- Architecture overview
- Security considerations
- CI/CD practices
- Network configuration details

## Quick Start

1. Clone this repository
2. Run the setup script:
   ```bash
   ./setup.sh
   ```
3. Edit `.env` file with your settings
4. Start services:
   ```bash
   docker compose up -d
   ```

## Current Status

✅ **Phase 1: Pi-hole MVP** - Ready for deployment

See [PLANNING.md](./PLANNING.md) for the complete implementation roadmap.

## Services

### Pi-hole

Network-wide DNS and ad-blocking service.

**Quick Setup:**

1. Run `./setup.sh` (auto-detects server IP)
2. Configure router DHCP DNS to use your server IP
3. Start: `docker compose up -d`
4. Access: `http://YOUR_SERVER_IP/admin`

**Documentation:**

- [Pi-hole Setup & Configuration](./docs/pihole-setup.md)
- [Pi-hole Troubleshooting](./docs/pihole-troubleshooting.md)

**Scripts:**

- `scripts/pihole/test-pihole.sh` - Test Pi-hole functionality
- `scripts/pihole/diagnose-pihole.sh` - Network diagnostic tool
- `scripts/pihole/update-server-ip.sh` - Update server IP in .env

## Project Structure

```
home-network/
├── docker-compose.yml      # Main orchestration file
├── .env                    # Environment variables (gitignored)
├── setup.sh                # Initial setup script
├── docs/                   # Service-specific documentation
│   └── pihole-*.md
├── scripts/                # Service-specific scripts
│   └── pihole/
└── [service]/             # Service data directories
```

## License

[Add your license here]
