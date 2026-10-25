# Tailscale Remote Access

Tailscale provides secure remote access to the home server without exposing any ports to the internet. It uses WireGuard under the hood — all traffic between devices is end-to-end encrypted.

## What it enables

- SSH into the server from anywhere using its Tailscale IP (100.x.x.x) — no need to expose port 22
- Access to services that are not publicly routed (e.g. Portainer at `<tailscale-ip>:9000`)
- The existing `*.woggles.work` domains work over LAN as-is, and can also resolve correctly when remote on the tailnet — see [Resolving `*.woggles.work` remotely](#resolving-woggleswork-remotely-magicdns-split-dns) below

## What it does NOT do

This setup does **not** use `--advertise-routes`. Only the server itself joins the tailnet — the rest of the LAN is not exposed to Tailscale peers. This keeps the blast radius small: a compromised Tailscale account can reach the server but not every other device on the network.

## Installation

The `setup.sh` script installs the Tailscale package automatically on Linux. To verify it ran:

```bash
tailscale version
```

If you need to install manually:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

## Authenticate and enable SSH

This step is interactive — it opens a browser auth flow:

```bash
sudo tailscale up --ssh
```

Tailscale will print a URL. Open it in a browser, log in with your Tailscale account, and authorize the device. The `--ssh` flag enables Tailscale SSH, which allows connecting via your Tailscale identity rather than SSH keys.

## Verification

```bash
# Confirm the server is connected and get its Tailscale IP
tailscale status

# From another device on your tailnet (e.g. your laptop with Tailscale installed):
ssh john@<tailscale-ip>

# Access Portainer remotely (not exposed publicly):
# http://<tailscale-ip>:9000
```

## Managing access

All device management is in the Tailscale admin console: https://login.tailscale.com/admin

From there you can:

- See which devices are connected
- Revoke a device immediately if a machine is lost or compromised
- Review access logs
- Configure ACLs to restrict which devices can reach which ports

## Resolving `*.woggles.work` remotely (MagicDNS split DNS)

By default, `*.woggles.work` only resolves on the home LAN: Pi-hole answers those queries with the server's LAN IP (`192.168.0.243`, see `pihole/etc-dnsmasq.d/02-local-dns.conf`), and this setup doesn't advertise subnet routes (`--advertise-routes`), so remote tailnet devices have no path to that LAN IP at all. Without split DNS, remote access means falling back to per-service `<tailscale-ip>:<port>` URLs, as described below.

To make `*.woggles.work` resolve correctly over Tailscale too — so the same URLs work at home and remotely — add a split DNS override in the Tailscale admin console that points `woggles.work` at the server's **Tailscale IP** instead of its LAN IP. The Tailscale IP is always reachable over the tailnet, whether a device is on the home LAN or remote, so this works in both cases. Traefik already listens on ports 80/443 on all interfaces and serves the existing wildcard cert for `*.woggles.work`, so no changes are needed in this repo (`docker-compose.yml`, Traefik config, and Pi-hole config are all unaffected).

**Steps (Tailscale admin console — not something this repo can configure for you):**

1. Go to the [Tailscale admin console → DNS](https://login.tailscale.com/admin/dns)
2. Enable **MagicDNS** if it isn't already on
3. Under **Nameservers**, click **Add nameserver** → **Custom**
4. Enter the server's Tailscale IP (run `tailscale status` on the server to get it)
5. Check **Restrict to domain** and enter `woggles.work`
6. Save

### Verification

With Tailscale connected on a device **outside** the home network:

```
https://jellyfin.woggles.work
https://homepage.woggles.work
```

should both load directly, with no port or IP needed. On the home network, the same URLs should keep working exactly as before (split DNS only changes resolution for tailnet devices, and only for the `woggles.work` suffix).

## Accessing services remotely

If you haven't set up split DNS above, `*.woggles.work` domains resolve to the server's LAN IP (`192.168.0.243`) and aren't reachable from outside the home network. Without it, remote access goes through the Tailscale IP and per-service ports instead.

### Jellyfin

Jellyfin's port is bound to all interfaces, so it's reachable directly:

```
http://<tailscale-ip>:8096
```

If split DNS (above) is configured, `https://jellyfin.woggles.work` works remotely too — in which case you don't need to do anything below. As a fallback, or for devices without split DNS applied, the **Jellyfin mobile app** supports multiple server addresses — add both so it uses whichever is reachable:

- `https://jellyfin.woggles.work` — used on the home network, and remotely once split DNS is set up
- `http://<tailscale-ip>:8096` — always works remotely, with or without split DNS

### Portainer

Portainer is bound to `127.0.0.1:9000` (loopback only) and is not reachable via the Tailscale IP directly. Use SSH port forwarding to tunnel it to your local machine:

```bash
ssh -L 9000:localhost:9000 john@<tailscale-ip>
# then open: http://localhost:9000
```

### Pi-hole admin

Pi-hole's web UI runs on port 8080 on the host. It is reachable via Tailscale IP directly:

```
http://<tailscale-ip>:8080/admin
```

### Syncthing, FileBrowser, Traefik dashboard

These have no host port bindings — they are only accessible through Traefik on the home network (`*.woggles.work`). There is no remote access path for these services without additional configuration. They are admin-only tools and rarely need remote access.

The Traefik dashboard (`traefik.woggles.work`) requires BasicAuth credentials even on the LAN. Set `TRAEFIK_DASHBOARD_USERS` in `.env` before starting Traefik (see README step 2).

## Homepage widget API key

The Homepage Tailscale widget reads `TAILSCALE_DEVICE_ID` and `TAILSCALE_API_KEY` from `.env` (see `.env.example` for where to find them). Tailscale API access tokens expire after at most 90 days. When the widget starts showing an API error, generate a new token at https://login.tailscale.com/admin/settings/keys, update `TAILSCALE_API_KEY` in the server's `.env`, and run `docker compose up -d homepage`.

## Known caveat: Tailscale can bypass Pi-hole ad-blocking

On macOS (and likely other OSes), when a device is connected to Tailscale, the OS resolver prioritizes Tailscale's MagicDNS resolver (`100.100.100.100`) over the LAN resolver that normally points at Pi-hole — even while the device is on the home network. You can confirm this on a Mac with `scutil --dns`: the Tailscale resolver shows up at a lower (higher-priority) `order` than the LAN one. The practical effect is that Pi-hole's ad-blocking is silently skipped for DNS queries from any device connected to Tailscale, since those queries never reach Pi-hole.

The split DNS override above only fixes resolution for the `woggles.work` suffix — it doesn't address this. If you want Pi-hole's ad-blocking to keep working while Tailscale is connected, you can add Pi-hole itself as a **global** tailnet nameserver:

1. Go to the [Tailscale admin console → DNS](https://login.tailscale.com/admin/dns)
2. Under **Nameservers**, add the server's LAN IP (`192.168.0.243`) — **not** restricted to a domain, so it applies to all queries
3. Enable **Override local DNS** if you want this to take priority tailnet-wide

Treat this as a separate, optional step from the split DNS override above — and be aware of its limit: a global nameserver pointing at the LAN IP is only reachable by tailnet devices that are actually on the home LAN (this setup doesn't advertise subnet routes). A device that's fully remote won't be able to reach `192.168.0.243` at all, so depending on how it handles an unreachable nameserver, DNS could simply fail rather than fall back gracefully. Test this from a remote device before relying on it, and revert the nameserver entry if it causes problems while away from home.

## Security recommendations

- **Enable 2FA** on your Tailscale account (under Settings → Account). This is the primary credential protecting remote access.
- **Review ACLs** in the admin console. By default all devices on the tailnet can reach each other; you can restrict this.
- Do not use `--advertise-routes` unless you intentionally want all tailnet devices to reach the full LAN.
