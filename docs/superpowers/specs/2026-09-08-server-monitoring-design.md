# Server Monitoring (Beszel) — Design

**Date:** 2026-09-08
**Status:** Approved for implementation
**Research artifact:** `.light/sessions/server-monitoring-research.md`

## Goal

Give visibility into server overload (CPU/mem/disk, container resource use) via the Homepage dashboard, using a lightweight service that fits this repo's existing "one bridge-network container per concern" pattern.

## Non-goals (this PR)

- SSH/auth-log visibility and general host-level error/log visibility — deferred to a follow-up issue (neither Beszel nor a container-log tool can see host-level `sshd`, which isn't containerized in this stack; the earlier Netdata candidate had unresolved bugs — see research artifact Findings 1-2).
- Container-level log viewing (Dozzle) — deferred to a follow-up issue, scoped separately to keep this PR small.
- Alerting/push notifications — deferred to a follow-up issue.
- Automatic banning (fail2ban) — deferred to a follow-up issue.

## Why Beszel, and why no host networking

Beszel's agent defaults to `network_mode: host` in its official examples, but its own docs state this is only required for *host network-interface throughput* stats and is explicitly optional ("If host network stats aren't needed, you can remove this requirement and map the port manually instead" — research artifact Finding 8). We only need CPU/mem/disk/container overload visibility, not network throughput, so both `beszel-hub` and `beszel-agent` run on the standard `proxy` bridge network like every other service except Pi-hole. This avoids the manual Traefik file-provider wiring and host-network/Traefik-dashboard risk that sank the original Netdata plan.

The agent has no web UI of its own — it's an outbound client to the hub over a private port — so it needs no Traefik route regardless of network mode.

## Architecture

Two new services in `docker-compose.yml`:

### `beszel-hub`
- Image: `henrygd/beszel:0.19.0` (pinned per repo convention)
- Networks: `proxy`
- Volumes: `./beszel/hub_data:/beszel_data`
- Environment: `APP_URL=https://beszel.woggles.work`
- Traefik labels: standard pattern (see Traefik section) — no basicauth middleware needed, Beszel has its own built-in superuser auth.
- Persistent data dir created by `scripts/setup.sh` (mirrors `jellyfin/config`, `filebrowser/config`, etc.)

### `beszel-agent`
- Image: `henrygd/beszel-agent:0.19.0`
- Networks: `proxy`
- Volumes:
  - `./beszel/agent_data:/var/lib/beszel-agent`
  - `/var/run/docker.sock:/var/run/docker.sock:ro` (container stats — same read-only pattern as Traefik's docker.sock mount)
- Environment:
  - `HUB_URL=http://beszel-hub:8090` (container DNS name, same network — no LAN IP or `host.docker.internal` needed since both are bridge-network)
  - `KEY=${BESZEL_AGENT_KEY}` (from hub UI, see setup flow)
  - `TOKEN=${BESZEL_AGENT_TOKEN}` (from hub UI, see setup flow)
- No Traefik labels — nothing to route.

## Traefik

Standard Docker-label routing for `beszel-hub` only, matching the Jellyfin/Portainer/Wallabag pattern exactly (no manual `traefik/dynamic/services.yml` entry needed):

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.beszel.rule=Host(`beszel.woggles.work`)"
  - "traefik.http.routers.beszel.entrypoints=websecure"
  - "traefik.http.routers.beszel.tls.certresolver=cloudflare"
  - "traefik.http.services.beszel.loadbalancer.server.port=8090"
```

## Homepage integration

New "Monitoring" group in `homepage/config/services.yaml`:

```yaml
- Monitoring:
    - Beszel:
        href: https://beszel.woggles.work
        description: Server resource monitoring
        icon: beszel
        widget:
          type: beszel
          url: http://beszel-hub:8090
          username: "{{HOMEPAGE_VAR_BESZEL_USERNAME}}"
          password: "{{HOMEPAGE_VAR_BESZEL_PASSWORD}}"
          version: 2
```

Overview mode (no `systemId`) — shows systems/up counts across all monitored systems, which for this single-server stack is effectively an at-a-glance health card. `url` uses the container DNS name since Homepage and `beszel-hub` share the `proxy` network (confirmed pattern from research: bridge-network services use container names; only Pi-hole, the one host-network exception, uses a LAN IP).

Per CLAUDE.md's three-file rule, wire the same credentials into:
- `docker-compose.yml` homepage `environment:` block: `HOMEPAGE_VAR_BESZEL_USERNAME=${BESZEL_USERNAME:-}`, `HOMEPAGE_VAR_BESZEL_PASSWORD=${BESZEL_PASSWORD:-}`
- `.env.example`: `BESZEL_USERNAME=` and `BESZEL_PASSWORD=` with a comment pointing at the hub's superuser account (created during setup)

Then run `./scripts/lint-config.sh` to confirm.

## `.env.example` additions

```env
# Beszel (server monitoring)
# Hub superuser account — create at https://beszel.woggles.work on first run
BESZEL_USERNAME=
BESZEL_PASSWORD=
# Agent connection credentials — generated in the hub UI (Add System), see README
BESZEL_AGENT_KEY=
BESZEL_AGENT_TOKEN=
```

## `scripts/setup.sh` changes

Add to the directory-creation block:
```bash
mkdir -p beszel/hub_data
mkdir -p beszel/agent_data
```

## README changes

- Add `Beszel` row to the services table: `https://beszel.woggles.work` — "Server resource monitoring"
- New numbered setup step (after the Calibre-Web step, before Tailscale), following the Jellyfin/Portainer "post-first-run" pattern already established in step 8:
  1. `docker compose up -d beszel-hub`
  2. Visit `https://beszel.woggles.work`, create the superuser account — use as `BESZEL_USERNAME`/`BESZEL_PASSWORD` in `.env`
  3. In the hub UI, **Add System** — copy the generated Key and Token into `.env` as `BESZEL_AGENT_KEY`/`BESZEL_AGENT_TOKEN`
  4. `docker compose up -d beszel-agent`
- Update `## Project Structure` tree to add `beszel/hub_data/` and `beszel/agent_data/` (gitignored, like other runtime dirs)

## `.gitignore`

Add `beszel/hub_data/` and `beszel/agent_data/` (runtime data, matching the existing pattern for `jellyfin/config`, `portainer/data`, etc.)

## Testing / verification plan

- `docker compose up -d beszel-hub beszel-agent` on a local/dev check (or the server) — confirm both containers start and stay healthy.
- Confirm hub reachable at `https://beszel.woggles.work` through Traefik (TLS cert, routing).
- Confirm agent shows as connected/reporting in the hub UI after entering Key/Token.
- Run `./scripts/lint-config.sh` — must exit clean.
- Confirm Homepage's Beszel card renders live system/up counts.
- No golden-path browser testing beyond the above is applicable (infra/dashboard config, not app UI).

## Follow-up GitHub issues to file (not implemented in this PR)

1. **Add Dozzle** for real-time container log viewing (bridge-network, Traefik-routed, plain Homepage bookmark tile — no native widget exists yet).
2. **Add fail2ban** for automatic SSH ban-on-abuse.
3. **Add push notifications** for monitoring alerts — check Beszel's own built-in alerting first before reaching for a separate tool (e.g. ntfy).
4. **SSH/auth-log and host-error visibility** — neither Beszel nor Dozzle cover host-level `sshd`/journald. Re-evaluate Netdata (Debian image, journal plugin only) vs. a lightweight custom journald-based approach, given the Alpine-image gotcha, CPU/iowait bug report, and Traefik-dashboard bug report surfaced in `.light/sessions/server-monitoring-research.md`.
