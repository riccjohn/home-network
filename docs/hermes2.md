# Hermes 2 (sandboxed agent)

Two hostnames front a second Hermes agent that runs on its own dedicated laptop, not on this server. That machine is deliberately
contained: it can use the internet, but it cannot start connections to the
LAN or to any other device on the tailnet. This server's Traefik is the only
thing that talks to it.

| URL                                      | What                               | Backend port |
| ---------------------------------------- | ---------------------------------- | ------------ |
| `https://hermes2.woggles.work`           | Chat webapp                        | 9120         |
| `https://hermes2-dashboard.woggles.work` | Dashboard (config, keys, sessions) | 9119         |

This mirrors the naming of the first agent (`hermes` = webapp,
`hermes-dashboard` = dashboard).

## How traffic flows

```
browser ──https──▶ Traefik (this server) ──http over the tailnet──▶ Hermes 2 :9120 / :9119
```

- **DNS**: both names are listed in `pihole/etc-dnsmasq.d/woggles.hosts`
  like every other service, so LAN clients get the LAN IP and tailnet clients
  get the Tailscale IP (see [tailscale.md](tailscale.md)).
- **TLS**: terminated here with the existing `*.woggles.work` certificate.
- **Backend hop**: plain HTTP to the machine's Tailscale IP. Tailscale
  already encrypts it with WireGuard, so no second certificate is needed.
- **Routing**: a file-provider router in `traefik/dynamic/services.yml`
  (same pattern as Pi-hole), because the backend is not a container on the
  `proxy` network.
- **Access control**: the `hermes2-ips` allowlist (tailnet + LAN) and the
  shared `rate-limit` middleware. The dashboard and webapp also each have
  their own login.

## Required Tailscale ACL

Only this server may reach the webapp and dashboard ports on the Hermes 2 machine, and the
machine itself may not initiate connections to anything. In the
[ACL editor](https://login.tailscale.com/admin/acls), tag the machine
(`tag:hermes`) and grant:

```jsonc
"grants": [
  // maintenance from your own devices
  {"src": ["autogroup:member"], "dst": ["tag:hermes"], "ip": ["tcp:22", "udp:60000-61000"]},
  // dashboard and webapp: only this server's Traefik
  {"src": ["<this server's Tailscale IP>"], "dst": ["tag:hermes"], "ip": ["tcp:9119", "tcp:9120"]},
]
```

There must be **no** grant with `tag:hermes` as the source. Without the second
grant above, the routes return `502`.

## Hermes configuration on the Hermes 2 machine

Both services refuse requests whose `Host` header they were not told about
(`Invalid Host header`), so each needs its public URL in the Hermes config
(`~/.hermes/config.yaml`):

```yaml
dashboard:
  public_url: "https://hermes2-dashboard.woggles.work"
webapp:
  enabled: true
  host: 0.0.0.0 # a specific address is not accepted; firewall port 9120 to tailscale0
  port: 9120
  public_url: "https://hermes2.woggles.work"
```

- The dashboard must run as `hermes dashboard`. `hermes serve` is the headless
  desktop-app backend and answers with "web UI disabled".
- The webapp is served by the gateway (`hermes gateway run`) and needs a sign-in
  provider because it binds a non-loopback address.
- The webapp bundle is not built by default. Without it the page shows "The
  Webapp is not built". Build it once with `hermes webapp --build-only`
  (a few minutes; it downloads npm packages), then reload the page.
- `webapp.host` accepts only loopback or a wildcard, so the machine's firewall
  must drop 9120 on every interface except `tailscale0`.

## Adding or changing the route

- The backend addresses (`hermes2-svc` and `hermes2-dashboard-svc` in
  `traefik/dynamic/services.yml`) use the Hermes 2 machine's **Tailscale IP**. Update it if that node is ever
  re-registered.
- The Traefik container reaches it through the host's Tailscale interface.
  Docker masquerades the container's traffic, so the ACL should see this
  server's Tailscale IP as the source (the check below confirms it).

## Verifying

From this server:

```bash
# each should print an HTTP status line (401/302 is fine: the login answered)
docker exec traefik wget -S -O /dev/null --timeout=5 http://<hermes2-tailscale-ip>:9119 2>&1 | head -3
docker exec traefik wget -S -O /dev/null --timeout=5 http://<hermes2-tailscale-ip>:9120 2>&1 | head -3
```

From any device on the tailnet or LAN, both URLs should load a login page. From a device outside both, it should be
rejected (`403`).

If either check fails, the usual causes are: the ACL grant is missing, the
Hermes service on that port is not running, or the address in `services.yml`
is stale.
