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

🚧 **Planning Phase** - See [PLANNING.md](./PLANNING.md) for implementation roadmap.

## License

[Add your license here]

