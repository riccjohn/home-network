# Plan: Cloudflare Tunnel Integration

**tracker:** yaks

---

## Context

The home server runs all services internally and is not accessible outside the LAN. The goal is to expose the homepage dashboard externally without port forwarding, using Cloudflare Tunnel (cloudflared) and Cloudflare Access for authentication.

The project already uses Cloudflare for DNS and wildcard TLS certs (`*.woggles.work` via Let's Encrypt + Cloudflare DNS-01 challenge). Cloudflare Tunnel extends that dependency in a natural way: cloudflared runs as a Docker container, connects outbound to Cloudflare's edge, and routes incoming traffic to Traefik. Traefik's existing label-based routing is unchanged.

The tunnel will be remote-managed (dashboard-created), using a single `CLOUDFLARE_TUNNEL_TOKEN` env var — the simplest approach and consistent with how other secrets are handled in this project. DNS CNAMEs are created automatically by the dashboard.

---

## Goal

Add `cloudflared` as a Docker Compose service that exposes `homepage.woggles.work` externally via Cloudflare Tunnel, with Cloudflare Access (email OTP) enforcing authentication. Real client IPs are correctly propagated to Traefik via `forwardedHeaders.trustedIPs`.

---

## Acceptance Criteria

- [ ] `cloudflared` container starts successfully and connects to Cloudflare's edge
- [ ] `homepage.woggles.work` is accessible from outside the LAN after logging in via Cloudflare Access
- [ ] LAN access to all services continues to work unchanged
- [ ] `./scripts/lint-config.sh` exits clean with no errors
- [ ] `CLOUDFLARE_TUNNEL_TOKEN` is documented in `.env.example` with a comment explaining where to get it
- [ ] `README.md` documents the manual steps required in the Cloudflare dashboard (create tunnel, configure Access, add public hostname)

---

## Files to Modify

| File                  | Change                                                      |
| --------------------- | ----------------------------------------------------------- |
| `docker-compose.yml`  | Add `cloudflared` service                                   |
| `traefik/traefik.yml` | Add `forwardedHeaders.trustedIPs` to `websecure` entrypoint |
| `.env.example`        | Add `CLOUDFLARE_TUNNEL_TOKEN` with comment                  |
| `README.md`           | Add Cloudflare Tunnel setup section                         |

No files to create. No scripts need structural changes (remote-managed tunnel requires no local credential files).

---

## Implementation Phases

### Phase 1: Update Traefik config

**Goal:** Add `forwardedHeaders.trustedIPs` to the `websecure` entrypoint so Traefik correctly reads the real client IP from `X-Forwarded-For` headers sent by Cloudflare's edge servers.

**Tasks:**

- Add `forwardedHeaders.trustedIPs` block to the `websecure` entrypoint in `traefik/traefik.yml` with all published Cloudflare IP ranges plus the Docker bridge range (`172.16.0.0/12`)

**Verification:**

- `traefik/traefik.yml` contains `forwardedHeaders.trustedIPs` under `entryPoints.websecure`
- YAML is valid (no parse errors)

#### Agent Context

```
Files to modify:
  - traefik/traefik.yml

Changes:
  Add forwardedHeaders.trustedIPs to the websecure entrypoint.
  This is NOT an access control list — it tells Traefik to trust
  X-Forwarded-For headers arriving from Cloudflare's edge IPs.
  The trustForwardHeader option on middlewares is deprecated in
  Traefik v3.6.14+ — use entrypoint-level trustedIPs instead.

Cloudflare IP ranges to include:
  173.245.48.0/20, 103.21.244.0/22, 103.22.200.0/22, 103.31.4.0/22,
  141.101.64.0/18, 108.162.192.0/18, 190.93.240.0/20, 188.114.96.0/20,
  197.234.240.0/22, 198.41.128.0/17, 162.158.0.0/15, 104.16.0.0/13,
  104.24.0.0/14, 172.64.0.0/13, 131.0.72.0/22
  Plus: 127.0.0.1/32, 172.16.0.0/12 (Docker bridge)

Test command: none (config-only; verify YAML syntax by inspection or `docker compose config`)
Gate: traefik/traefik.yml parses cleanly and contains the trustedIPs block
Constraints: Do not change entryPoints addresses, redirections, or certResolver config
```

---

### Phase 2: Add cloudflared service

**Goal:** Add the `cloudflared` container to `docker-compose.yml` and document its required env var in `.env.example`.

**Tasks:**

- Add `cloudflared` service to `docker-compose.yml` (image: `cloudflare/cloudflared:latest`, command: `tunnel run`, env var: `TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}`, network: `proxy`, restart: `unless-stopped`)
- Add `CLOUDFLARE_TUNNEL_TOKEN=` to `.env.example` with a comment explaining where to get it (Zero Trust dashboard → Networks → Tunnels → create tunnel → copy token)

**Verification:**

- `docker compose config` exits clean (no missing variable errors — token is expected to be set in `.env`)
- `./scripts/lint-config.sh` exits clean
- `cloudflared` service appears in `docker compose ps` output after `docker compose up -d`

#### Agent Context

```
Files to modify:
  - docker-compose.yml
  - .env.example

docker-compose.yml — add this service at the end of the services block,
before the networks section:

  cloudflared:
    container_name: cloudflared
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
    networks:
      - proxy

.env.example — add after the CF_DNS_API_TOKEN block (keep Cloudflare vars together):

  # Cloudflare Tunnel token — get from Zero Trust dashboard:
  # https://one.dash.cloudflare.com/ → Networks → Tunnels → Create a tunnel → Docker → copy token
  CLOUDFLARE_TUNNEL_TOKEN=

Naming convention: TUNNEL_TOKEN is the env var name cloudflared reads internally.
CLOUDFLARE_TUNNEL_TOKEN is the project-level name in .env.

Test command: ./scripts/lint-config.sh
Gate: lint-config.sh exits 0 with no output
Constraints:
  - No volumes needed (remote-managed tunnel, ingress rules live in Cloudflare dashboard)
  - No traefik labels on cloudflared (it is not a service to be routed TO)
  - Do not add cloudflared to homepage or any other service's depends_on
```

---

### Phase 3: Update README

**Goal:** Document the manual Cloudflare dashboard steps required to complete setup, so a fresh server setup is fully reproducible from the repo alone.

**Tasks:**

- Add a "Cloudflare Tunnel" section to `README.md` covering:
  1. Create a tunnel in Zero Trust dashboard (Networks → Tunnels → Create → Docker) and copy the token to `.env`
  2. Add a public hostname in the tunnel config: `homepage.woggles.work` → `https://traefik` (with note about SSL mode: Full (Strict) in Cloudflare SSL/TLS settings)
  3. Configure Cloudflare Access (Zero Trust → Access → Applications → Add → Self-hosted): application domain `homepage.woggles.work`, policy type: email, add your email
  4. Note that DNS CNAME is created automatically by the dashboard — no manual DNS change needed

**Verification:**

- README contains a Cloudflare Tunnel section with all four steps above
- Steps are accurate and match what the Cloudflare dashboard actually requires

#### Agent Context

```
Files to modify:
  - README.md

Add a new section after the existing service/setup documentation.
The section should cover the four manual Cloudflare dashboard steps:
  1. Create tunnel → get token → add to .env as CLOUDFLARE_TUNNEL_TOKEN
  2. Add public hostname: homepage.woggles.work → https://traefik
     (origin server name: woggles.work; SSL mode: Full Strict in Cloudflare dashboard)
  3. Set up Cloudflare Access for homepage.woggles.work (email OTP policy)
  4. DNS is handled automatically — no manual change needed

Note in the README that the wildcard A record (* → 192.168.0.243) already
exists and does NOT conflict — the specific tunnel CNAME takes precedence.

Test command: none (documentation review)
Gate: README section present and complete
Constraints: Match existing README style and heading levels
```

---

## Constraints & Considerations

- **Remote-managed only:** No local `config.yaml` or credential JSON files. All tunnel ingress rules live in the Cloudflare dashboard. The plan explicitly does not support locally-managed tunnels.
- **Traefik routes unchanged:** cloudflared forwards to Traefik (`https://traefik`), not directly to services. All existing Traefik label routing continues to work exactly as before.
- **LAN access unaffected:** The wildcard A record (`* → 192.168.0.243`) continues to serve LAN-internal traffic. Pi-hole DNS resolves these locally. The tunnel CNAME only applies when resolved via Cloudflare's public DNS.
- **SSL/TLS mode:** Must be set to "Full (Strict)" in Cloudflare SSL/TLS settings. The existing `*.woggles.work` Let's Encrypt cert satisfies this requirement.
- **`CLOUDFLARE_TUNNEL_TOKEN` is a secret:** Treat it like a private key. It must never be committed to git (`.env` is already gitignored).
- **`lint-config.sh` will catch mismatches:** Any `${VAR}` reference in `docker-compose.yml` without a default must appear in `.env.example`. The new `${CLOUDFLARE_TUNNEL_TOKEN}` reference is covered by Phase 2.

---

## Out of Scope

- Exposing other services (jellyfin, portainer, filebrowser, etc.) — same pattern, just add public hostnames in the Cloudflare dashboard
- Cloudflare Access for services other than homepage
- Locally-managed tunnel (credentials file + config.yaml approach)
- The `cloudflarewarp` Traefik plugin — entrypoint-level `trustedIPs` is sufficient
- Removing or modifying the existing wildcard A record in Cloudflare DNS
