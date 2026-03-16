# Tailscale Remote Access

Tailscale provides secure remote access to the home server without exposing any ports to the internet. It uses WireGuard under the hood — all traffic between devices is end-to-end encrypted.

## What it enables

- SSH into the server from anywhere using its Tailscale IP (100.x.x.x) — no need to expose port 22
- Access to services that are not publicly routed (e.g. Portainer at `<tailscale-ip>:9000`)
- The existing `*.woggles.work` domains continue to work as-is over LAN; Tailscale is a supplement for remote access

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

## Accessing services remotely

The `*.woggles.work` domains resolve to the server's LAN IP (`192.168.0.243`) and are not reachable from outside the home network — this is intentional. Remote access goes through the Tailscale IP instead.

### Jellyfin

Jellyfin's port is bound to all interfaces, so it's reachable directly:

```
http://<tailscale-ip>:8096
```

The **Jellyfin mobile app** supports multiple server addresses — add both so it uses whichever is reachable:

- `https://jellyfin.woggles.work` — used on the home network
- `http://<tailscale-ip>:8096` — used when remote

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

## Security recommendations

- **Enable 2FA** on your Tailscale account (under Settings → Account). This is the primary credential protecting remote access.
- **Review ACLs** in the admin console. By default all devices on the tailnet can reach each other; you can restrict this.
- Do not use `--advertise-routes` unless you intentionally want all tailnet devices to reach the full LAN.
