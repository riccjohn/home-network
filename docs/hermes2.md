# Hermes 2 (sandboxed agent)

`https://hermes2.woggles.work` fronts a second Hermes agent that runs on its
own dedicated laptop, not on this server. That machine is deliberately
contained: it can use the internet, but it cannot start connections to the
LAN or to any other device on the tailnet. This server's Traefik is the only
thing that talks to it.

## How traffic flows

```
browser ──https──▶ Traefik (this server) ──http over the tailnet──▶ Hermes 2 :9119
```

- **DNS**: `hermes2.woggles.work` is listed in `pihole/etc-dnsmasq.d/woggles.hosts`
  like every other service, so LAN clients get the LAN IP and tailnet clients
  get the Tailscale IP (see [tailscale.md](tailscale.md)).
- **TLS**: terminated here with the existing `*.woggles.work` certificate.
- **Backend hop**: plain HTTP to the machine's Tailscale IP. Tailscale
  already encrypts it with WireGuard, so no second certificate is needed.
- **Routing**: a file-provider router in `traefik/dynamic/services.yml`
  (same pattern as Pi-hole), because the backend is not a container on the
  `proxy` network.
- **Access control**: the `hermes2-ips` allowlist (tailnet + LAN) and the
  shared `rate-limit` middleware. The dashboard also has its own login.

## Required Tailscale ACL

Only this server may reach the dashboard port on the Hermes 2 machine, and the
machine itself may not initiate connections to anything. In the
[ACL editor](https://login.tailscale.com/admin/acls), tag the machine
(`tag:hermes`) and grant:

```jsonc
"grants": [
  // maintenance from your own devices
  {"src": ["autogroup:member"], "dst": ["tag:hermes"], "ip": ["tcp:22", "udp:60000-61000"]},
  // dashboard: only this server's Traefik
  {"src": ["<this server's Tailscale IP>"], "dst": ["tag:hermes"], "ip": ["tcp:9119"]},
]
```

There must be **no** grant with `tag:hermes` as the source. Without the second
grant above, the route returns `502`.

## Adding or changing the route

- The backend address (`hermes2-svc` in `traefik/dynamic/services.yml`) is the
  Hermes 2 machine's **Tailscale IP**. Update it if that node is ever
  re-registered.
- The Traefik container reaches it through the host's Tailscale interface.
  Docker masquerades the container's traffic, so the ACL should see this
  server's Tailscale IP as the source (the check below confirms it).

## Verifying

From this server:

```bash
# should print an HTTP status line (401 is fine: it means the dashboard's login answered)
docker exec traefik wget -S -O /dev/null --timeout=5 http://<hermes2-tailscale-ip>:9119 2>&1 | head -3
```

From any device on the tailnet or LAN, `https://hermes2.woggles.work` should
load the dashboard login page. From a device outside both, it should be
rejected (`403`).

If the first check fails, the usual causes are: the ACL grant is missing, the
Hermes 2 service is not running, or the address in `services.yml` is stale.
