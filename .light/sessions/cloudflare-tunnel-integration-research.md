# Research: Cloudflare Tunnel Integration

**Goal:** Expose homepage (and optionally other services) externally via Cloudflare Tunnel, with Cloudflare Access for auth. No port forwarding. Fits into existing docker-compose.yml pattern.

---

## Existing Setup Summary

- **Network:** Single `proxy` bridge network; all services (traefik, homepage, jellyfin, etc.) join it. Exception: pihole uses `network_mode: host`.
- **Routing:** Traefik v3 with Docker label discovery (`exposedByDefault: false`, network: proxy). Services declare their own labels.
- **TLS:** Wildcard `*.woggles.work` cert via Let's Encrypt + Cloudflare DNS-01 challenge (`CF_DNS_API_TOKEN`). Already trusted by Cloudflare.
- **Env vars:** Pattern is `{SERVICE}_{TYPE}` (e.g., `CF_DNS_API_TOKEN`, `PIHOLE_API_KEY`). All required vars (no-default `${VAR}`) must appear in `.env.example`. Validated by `scripts/lint-config.sh`.
- **Auth today:** Only Traefik dashboard has basicauth middleware. Homepage has no auth layer.
- **Homepage:** `homepage.woggles.work`, port 3000, `HOMEPAGE_ALLOWED_HOSTS=homepage.woggles.work` already set — no change needed for external hostname.

---

## Recommended Architecture

```
Internet → Cloudflare Edge → [Cloudflare Access] → cloudflared container → Traefik → homepage
```

cloudflared joins the `proxy` network. It routes all external traffic to Traefik (not directly to services), so Traefik's existing label-based routing continues unchanged.

---

## Key Decisions

### 1. Tunnel type: Remote-managed (dashboard) — use this

Two options exist:

- **Remote-managed (dashboard):** Create tunnel in Zero Trust dashboard → get a token → `TUNNEL_TOKEN` env var → ingress rules configured in dashboard → Cloudflare auto-creates DNS CNAMEs.
- **Locally-managed (config.yaml):** `cloudflared tunnel create` → credentials JSON file + `cert.pem` → ingress in `config.yaml` → manual CNAME creation.

**Use remote-managed.** Single env var (`CLOUDFLARE_TUNNEL_TOKEN`), no files to mount, automatic DNS, matches the project's pattern of dashboard-configured secrets.

### 2. cloudflared ingress destination

Two valid approaches:

- `http://traefik` — simpler; cloudflared hits Traefik on port 80, Traefik redirects to 443 (one extra hop, harmless).
- `https://traefik` with `originServerName: woggles.work` — skips the redirect hop; requires SNI config. Since the `*.woggles.work` LE cert is valid and trusted, Full (Strict) SSL mode works.

**Recommendation:** Use `https://traefik` with `originServerName: woggles.work` and Cloudflare SSL mode set to Full (Strict). Cleaner and more secure.

### 3. Cloudflare Access

Configure in Zero Trust dashboard → Access → Applications → Self-hosted:

- Application domain: `homepage.woggles.work`
- Policy: email allowlist (just your email for now; add others per-subdomain later)
- Auth method: One-time PIN via email (no extra IdP setup needed)
- Access enforced at Cloudflare edge — requests that fail Access never reach cloudflared or Traefik

This is the right model for "only me now, maybe others to specific services later."

### 4. Real client IP (forwardedHeaders)

**This is not an access control list — it does not restrict who can connect.** You can connect from any IP (hotel, public WiFi, etc.) as long as you pass Cloudflare Access auth.

This setting tells Traefik: "trust the `X-Forwarded-For` header when it comes from one of these IPs." When Cloudflare's edge servers forward a request to cloudflared → Traefik, the source IP Traefik sees is a Cloudflare datacenter IP. Cloudflare sets `X-Forwarded-For` to your real connecting IP. Without `trustedIPs`, Traefik ignores that header (a security default to prevent spoofing) and logs/reports the Cloudflare edge IP instead of yours.

Add `forwardedHeaders.trustedIPs` to the `websecure` entrypoint in `traefik.yml` (Cloudflare's published IP ranges, plus Docker bridge):

```yaml
entryPoints:
  websecure:
    address: ":443"
    forwardedHeaders:
      trustedIPs:
        - "173.245.48.0/20"
        - "103.21.244.0/22"
        - "103.22.200.0/22"
        - "103.31.4.0/22"
        - "141.101.64.0/18"
        - "108.162.192.0/18"
        - "190.93.240.0/20"
        - "188.114.96.0/20"
        - "197.234.240.0/22"
        - "198.41.128.0/17"
        - "162.158.0.0/15"
        - "104.16.0.0/13"
        - "104.24.0.0/14"
        - "172.64.0.0/13"
        - "131.0.72.0/22"
        - "127.0.0.1/32"
        - "172.16.0.0/12" # Docker bridge range
```

Note: `trustForwardHeader` on individual middlewares is deprecated in Traefik v3.6.14+ (removed in v4). Entrypoint-level `forwardedHeaders.trustedIPs` is the correct approach.

---

## Files to Change

| File                  | Change                                                                                         |
| --------------------- | ---------------------------------------------------------------------------------------------- |
| `docker-compose.yml`  | Add `cloudflared` service (image, command, env var, network)                                   |
| `traefik/traefik.yml` | Add `forwardedHeaders.trustedIPs` to `websecure` entrypoint                                    |
| `.env.example`        | Add `CLOUDFLARE_TUNNEL_TOKEN=` with comment pointing to Zero Trust → Networks → Tunnels        |
| `scripts/setup.sh`    | No structural change needed (no files to create for remote-managed tunnel)                     |
| `README.md`           | Add Cloudflare Tunnel setup section (create tunnel in dashboard, copy token, configure Access) |

`scripts/lint-config.sh` validation will catch the new env var automatically once it's in `.env.example` and referenced in `docker-compose.yml` without a default.

---

## cloudflared Service (draft)

```yaml
cloudflared:
  container_name: cloudflared
  image: cloudflare/cloudflared:latest
  restart: unless-stopped
  command: tunnel run
  environment:
    - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
  networks:
    - proxy
```

No volumes needed for remote-managed tunnel. Ingress rules (which hostnames to expose) are managed in the Cloudflare dashboard, not in a local config file.

---

## DNS

When you add a public hostname in the Zero Trust dashboard (Networks → Tunnels → [tunnel] → Public Hostname), Cloudflare automatically creates the CNAME:
`homepage.woggles.work → <UUID>.cfargotunnel.com`

**DNS record situation:** Cloudflare already has a wildcard A record `* → 192.168.0.243` (DNS only, not proxied). When the tunnel dashboard creates a specific CNAME for `homepage.woggles.work`, Cloudflare uses the most-specific record — the CNAME takes precedence over the wildcard automatically. No manual cleanup needed.

---

## Open Questions

1. Cloudflare Zero Trust free tier supports up to 50 users for Access — confirmed this covers needs.

---

**Include `forwardedHeaders.trustedIPs` in the initial implementation** — not much added complexity and ensures logs and any IP-based middleware work correctly from the start.

---

## Out of Scope for This Phase

- Exposing other services (jellyfin, portainer, etc.) — same pattern, add public hostnames in dashboard
- The Traefik plugin approach (`cloudflarewarp`) — adds complexity; entrypoint trustedIPs is sufficient
- Migrating to locally-managed tunnel — no benefit for this use case
