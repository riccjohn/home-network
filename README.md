# Home Network Server

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Self-hosted home server stack running on Ubuntu Server (Lenovo ThinkCentre), managed with Docker Compose. Traefik handles reverse proxying and wildcard TLS via Cloudflare DNS-01 challenge.

## Services

| Service   | URL                               | Description          |
| --------- | --------------------------------- | -------------------- |
| Homepage  | https://homepage.woggles.work     | Dashboard            |
| Pi-hole   | https://pihole.woggles.work/admin | DNS ad-blocker       |
| Traefik   | https://traefik.woggles.work      | Reverse proxy        |
| Jellyfin  | https://jellyfin.woggles.work     | Media server         |
| Syncthing | https://syncthing.woggles.work    | File sync            |
| Portainer | https://portainer.woggles.work    | Container management |

## Prerequisites

- Ubuntu Server with Docker and Docker Compose installed
- Domain registered at Cloudflare (`woggles.work`)
- Cloudflare API token with **Zone:DNS:Edit** permission (see step 3 below)

## Setup

### 1. Clone and run setup script

```bash
git clone <repository-url>
cd home-network
./setup.sh
```

The setup script creates required directories, sets `acme.json` to `600` (required by Traefik), and auto-detects your server IP.

### 2. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in:

| Variable           | How to get it                                          |
| ------------------ | ------------------------------------------------------ |
| `PIHOLE_PASSWORD`  | Choose a password                                      |
| `ADMIN_EMAIL`      | Your email — used for Let's Encrypt expiry notices     |
| `CF_DNS_API_TOKEN` | See step 3 below                                       |
| `RENDER_GID`       | Run `getent group render \| cut -d: -f3` on the server |
| `SERVER_IP`        | Auto-detected by setup script; verify it's correct     |
| `MEDIA_PATH`       | Path to your media drive (e.g. `/mnt/media`)           |
| `SYNC_PATH`        | Path to your sync drive (e.g. `/mnt/sync`)             |

`PIHOLE_API_KEY` and `JELLYFIN_API_KEY` can be left empty until after first run (see step 7).

### 3. Create a Cloudflare API token

Traefik uses Cloudflare's DNS-01 ACME challenge to issue a wildcard TLS cert. You need a scoped API token (not the global API key):

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) > **My Profile** > **API Tokens**
2. Click **Create Token** > **Create Custom Token**
3. Set permissions: **Zone** → **DNS** → **Edit**
4. Under **Zone Resources**: Include → Specific zone → `woggles.work`
5. Copy the token into `.env` as `CF_DNS_API_TOKEN`

### 4. Add DNS records in Cloudflare

Add two **A records** pointing to your server's LAN IP. Set proxy status to **DNS only** (grey cloud — do NOT enable the orange proxy):

| Type | Name             | Content         | Proxy    |
| ---- | ---------------- | --------------- | -------- |
| A    | `woggles.work`   | `192.168.0.243` | DNS only |
| A    | `*.woggles.work` | `192.168.0.243` | DNS only |

### 5. Point your router's DNS to Pi-hole

So all LAN devices resolve `*.woggles.work` to the server:

1. Log into your router's admin interface
2. Find **DHCP / DNS** settings
3. Set **Primary DNS** to your server IP (e.g. `192.168.0.243`)
4. Set **Secondary DNS** to `8.8.8.8` (fallback if Pi-hole is down)
5. Save and apply — devices will pick up the new DNS on their next DHCP renewal (or reconnect)

Pi-hole's local DNS config at `pihole/etc-dnsmasq.d/02-local-dns.conf` already resolves `*.woggles.work` to the server IP — no changes needed there.

### 6. Open ports 80 and 443 on the server firewall

Traefik binds to ports 80 and 443. If `ufw` is active:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

No router port forwarding needed — all access is LAN-only. External access will be added via Tailscale in a future phase.

### 7. Start services

```bash
docker compose up -d
```

Watch Traefik obtain the wildcard cert from Let's Encrypt (takes ~2 minutes due to DNS propagation):

```bash
docker compose logs -f traefik
# Look for: "INF Register..." then no more "unable to find certificate" errors
```

### 8. Post-first-run: grab API keys

**Pi-hole API key** (for Homepage widget):

1. Go to `https://pihole.woggles.work/admin` > **Settings** > **API**
2. Copy the API key into `.env` as `PIHOLE_API_KEY`
3. Run `docker compose restart homepage`

**Jellyfin API key** (for Homepage widget):

1. Go to `https://jellyfin.woggles.work` and complete initial setup
2. Go to **Dashboard** > **API Keys** > **+**
3. Copy the key into `.env` as `JELLYFIN_API_KEY`
4. Run `docker compose restart homepage`

**Portainer API key** (for Homepage widget):

1. Go to `https://portainer.woggles.work` and complete initial setup (do this promptly — it times out after a few minutes)
2. Go to **Account Settings** > **Access Tokens** > **Add access token**
3. Copy the key into `.env` as `PORTAINER_API_KEY`
4. Add `key: "{{HOMEPAGE_VAR_PORTAINER_API_KEY}}"` under the Portainer widget in `homepage/config/services.yaml`
5. Run `docker compose restart homepage`

## Hardware Transcoding

Jellyfin uses Intel VA-API on the Haswell i3-4130T. Find the render group ID and set it in `.env`:

```bash
getent group render | cut -d: -f3
# add result as RENDER_GID in .env
```

## Project Structure

```
home-network/
├── docker-compose.yml
├── .env.example
├── setup.sh
├── pihole/
│   └── etc-dnsmasq.d/
│       └── 02-local-dns.conf   # wildcard DNS for *.woggles.work
├── traefik/
│   ├── traefik.yml             # static config
│   ├── dynamic/
│   │   ├── tls.yml             # wildcard cert config
│   │   └── services.yml        # Pi-hole backend
│   └── letsencrypt/
│       └── acme.json           # cert storage (gitignored)
├── homepage/
│   └── config/                 # dashboard YAML configs
├── jellyfin/
│   └── config/                 # jellyfin config (gitignored)
├── syncthing/
│   └── config/                 # syncthing config (gitignored)
└── portainer/
    └── data/                   # portainer data (gitignored)
```

## Future

Tailscale remote access planned as a future phase.
