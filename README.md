# Home Network Server

[![CI](https://github.com/riccjohn/home-network/actions/workflows/ci.yml/badge.svg)](https://github.com/riccjohn/home-network/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Docker Compose](https://img.shields.io/badge/docker_compose-2496ED?logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/traefik_v3-24A1C1?logo=traefikproxy&logoColor=white)
![Ubuntu](https://img.shields.io/badge/ubuntu_server-E95420?logo=ubuntu&logoColor=white)

Self-hosted home server stack running on Ubuntu Server (Lenovo ThinkCentre), managed with Docker Compose. Traefik handles reverse proxying and wildcard TLS via Cloudflare DNS-01 challenge.

## Services

| Service       | URL                               | Description                |
| ------------- | --------------------------------- | -------------------------- |
| Homepage      | https://homepage.woggles.work     | Dashboard                  |
| Pi-hole       | https://pihole.woggles.work/admin | DNS ad-blocker             |
| Traefik       | https://traefik.woggles.work      | Reverse proxy              |
| Jellyfin      | https://jellyfin.woggles.work     | Media server               |
| Syncthing     | https://syncthing.woggles.work    | File sync                  |
| Portainer     | https://portainer.woggles.work    | Container management       |
| FileBrowser   | https://files.woggles.work        | File manager               |
| KOReader Sync | https://kosync.woggles.work       | Reading progress sync      |
| Calibre-Web   | https://calibre-web.woggles.work  | Ebook library              |
| Beszel        | https://beszel.woggles.work       | Server resource monitoring |

## Prerequisites

- Ubuntu Server with Docker and Docker Compose installed
- Domain registered at Cloudflare (`woggles.work`)
- Cloudflare API token with **Zone:DNS:Edit** permission (see step 3 below)

## Setup

### 1. Clone and run setup script

```bash
git clone <repository-url>
cd home-network
./scripts/setup.sh
```

The setup script creates required directories, sets `acme.json` to `600` (required by Traefik), and auto-detects your server IP.

### 2. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in:

| Variable                  | How to get it                                           |
| ------------------------- | ------------------------------------------------------- |
| `PIHOLE_PASSWORD`         | Choose a password                                       |
| `ADMIN_EMAIL`             | Your email — used for Let's Encrypt expiry notices      |
| `CF_DNS_API_TOKEN`        | See step 3 below                                        |
| `TRAEFIK_DASHBOARD_USERS` | Set automatically by `setup.sh` (prompted during setup) |
| `RENDER_GID`              | Run `getent group render \| cut -d: -f3` on the server  |
| `SERVER_IP`               | Auto-detected by setup script; verify it's correct      |
| `MEDIA_PATH`              | Path to your media drive (e.g. `/mnt/media`)            |
| `SYNC_PATH`               | Path to your sync drive (e.g. `/mnt/sync`)              |
| `FILEBROWSER_PATH`        | Path FileBrowser serves (e.g. `/mnt/data`)              |

`PIHOLE_API_KEY`, `JELLYFIN_API_KEY`, `PORTAINER_API_KEY`, and `PORTAINER_ENV_ID` can be left empty until after first run (see step 7).

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

No router port forwarding needed — all access is LAN-only. Remote access is handled by Tailscale (see step 12).

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

Run the post-setup script — it fetches API keys from each service and writes them to `.env` automatically:

```bash
./scripts/post-setup.sh
```

The script handles:

- **Portainer** — creates the admin account (if not yet done), generates an API token, and looks up the environment ID
- **Pi-hole** — reads the API key from the running container using `PIHOLE_PASSWORD` from `.env`
- **Jellyfin** — authenticates with admin credentials to create an API key

**Before running the script**, complete the Jellyfin initial setup wizard at `https://jellyfin.woggles.work` — it cannot be automated. The script will detect if it hasn't been done yet and remind you.

If any service fails, the script skips it and prints instructions. Re-run it after fixing the issue — it skips services that are already configured.

**FileBrowser** generates a random password on first start. Find it with `docker logs filebrowser` — look for "User 'admin' initialized with randomly generated password". Log in at `https://files.woggles.work` and change it immediately.

### 9. Set up KOReader Sync

Generate and add the password salt before starting the service:

```bash
echo "KOSYNC_PASSWORD_SALT=$(openssl rand -hex 32)" >> .env
docker compose up -d kosync
```

Then in the KOReader app on each device: **Settings → Progress sync → Custom sync server** → enter `https://kosync.woggles.work` → Register with a username and password. Each device registers once and syncs automatically on open/close.

### 10. Set up Calibre-Web

Calibre-Web reads the Calibre library synced to the server via Syncthing. It mounts the same `SYNC_PATH` directory that Syncthing uses, so no extra path variable is needed.

In the Syncthing UI, set your Calibre folder path to `/data1/Calibre_Library` (Syncthing's data mount inside the container). Then start the service:

```bash
docker compose up -d calibre-web
```

**First-run setup:**

1. Open `https://calibre-web.woggles.work` and complete the setup wizard
2. When prompted for the database path, enter `/sync/Calibre_Library` (adjust the subfolder name to match what you used in Syncthing)
3. Create an admin account — use these credentials as `CALIBREWEB_USERNAME` and `CALIBREWEB_PASSWORD` in `.env` (the Homepage widget uses them to show library stats)

### 11. Set up Beszel (server monitoring)

```bash
docker compose up -d beszel-hub
```

1. Visit `https://beszel.woggles.work`, create the superuser account — use as `BESZEL_USERNAME`/`BESZEL_PASSWORD` in `.env`
2. In the hub UI, **Add System** — copy the generated Key and Token into `.env` as `BESZEL_AGENT_KEY`/`BESZEL_AGENT_TOKEN`
3. Start the agent:

```bash
docker compose up -d beszel-agent
```

### 12. Enable remote access via Tailscale

The setup script installs Tailscale automatically on Linux. To activate it, authenticate with your Tailscale account:

```bash
sudo tailscale up --ssh
```

Tailscale will print a URL — open it in a browser and authorize the device. The `--ssh` flag enables Tailscale SSH, so you can connect from anywhere using the server's Tailscale IP without exposing port 22.

```bash
# Confirm it's connected and get the Tailscale IP
tailscale status

# From any device with Tailscale installed (e.g. your laptop):
ssh john@<tailscale-ip>
```

See [docs/tailscale.md](docs/tailscale.md) for security recommendations and managing device access.

## Updating

After pulling changes, run the update script to provision any new directories, pull fresh images, and restart only changed containers:

```bash
./scripts/update.sh
```

To force-recreate all containers (e.g. after a major config change):

```bash
./scripts/update.sh --all
```

The script runs in order: `git pull` → `setup.sh` (new dirs/files) → `docker compose pull` → `docker compose up -d` → image prune. A service status table is printed at the end.

## Releases & Rollback

This is a solo home-lab project, so there's no CI/CD pipeline — just a lightweight tagging convention that marks a known-good point on `main` after each merge, in case a rollback is ever needed.

**Tagging convention:** after merging a PR to `main`, tag the resulting commit with a date-based version:

```bash
git tag -a v2026.09.08 -m "Add Beszel server monitoring" && git push origin v2026.09.08
```

Use `vYYYY.MM.DD` format (not semver — this isn't a versioned library, it's a deployed date-stamped state). If multiple releases happen the same day, append `.2`, `.3`, etc. (e.g. `v2026.09.08.2`).

**Rollback procedure:** to roll the server back to a known-good state:

```bash
git fetch --tags
git checkout v2026.09.08
./scripts/update.sh
```

This leaves the repo in a detached HEAD state pointing at that tag — fine for a rollback, but to resume normal work afterward run `git checkout main` again.

**Caveat on image pinning:** rollback via git tag only restores `docker-compose.yml` and other tracked files to that point in time — it does **not** guarantee the same container images if a service uses an unpinned `:latest` tag, since `docker compose pull` fetches whatever `:latest` currently resolves to, not what it resolved to on the tagged date. The following services currently use `:latest` and so only have partial rollback fidelity:

- `pihole`
- `dockerproxy`
- `homepage`
- `portainer`
- `filebrowser`
- `syncthing`
- `kosync`
- `calibre-web`

(`jellyfin` specifies no tag at all, which Docker also resolves to `:latest`, so it has the same caveat.) Services pinned to a specific tag (`traefik`, `wallabag`, `beszel-hub`, `beszel-agent`) have full rollback fidelity. Pinning the rest is a separate follow-up.

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
├── docs/
│   └── tailscale.md            # Tailscale remote access guide
├── scripts/
│   ├── setup.sh                # initial setup
│   ├── update.sh               # pull changes and redeploy
│   └── post-setup.sh           # grab API keys after first run
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
├── portainer/
│   └── data/                   # portainer data (gitignored)
├── filebrowser/
│   ├── database/               # filebrowser database (gitignored)
│   └── config/                 # filebrowser settings (gitignored)
└── beszel/
    ├── hub_data/                # beszel hub data (gitignored)
    └── agent_data/              # beszel agent data (gitignored)
```
