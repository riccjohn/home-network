# Server Monitoring (Beszel) - Implementation Plan

**Date:** 2026-09-08
**Status:** Plan - Ready for Review
**Tracker:** yaks
**Yaks Epic:** add-beszel-monitoring
**Design spec:** `docs/superpowers/specs/2026-09-08-server-monitoring-design.md`
**Research artifact:** `.light/sessions/server-monitoring-research.md`

## Context

Research (`.light/sessions/server-monitoring-research.md`) compared Netdata vs. Beszel for host/container overload visibility on this repo's Docker Compose stack. Netdata was dropped due to three corroborated risks (Alpine-image gotcha, a reported CPU/iowait bug in its journal plugin, and a reported Netdata-behind-Traefik dashboard bug). Beszel was chosen: hub + agent, both on the repo's standard `proxy` bridge network — Beszel's `network_mode: host` is documented as optional and only needed for host network-_throughput_ stats, which this feature doesn't need (Finding 8). This matches the repo's dominant pattern (bridge-network + Traefik Docker-label routing), avoiding the manual file-provider wiring that Pi-hole (the one host-network exception) requires.

The approved design (`docs/superpowers/specs/2026-09-08-server-monitoring-design.md`) specifies exact service blocks, Traefik labels, Homepage widget config, `.env.example` additions, `setup.sh` directory creation, README updates, and `.gitignore` entries. This plan sequences that design into ordered, independently-verifiable edits.

This is a configuration/infrastructure change — no application code, no test suite. Per CLAUDE.md, the gate is `./scripts/lint-config.sh` (validates the 3-file Homepage widget variable wiring) plus a live `docker compose` smoke check.

## Goal

Add Beszel (hub + agent) as a new bridge-network monitoring service, wired into Traefik, Homepage, and the repo's setup/doc conventions, giving CPU/mem/disk/container overload visibility on the dashboard.

## Acceptance Criteria

- [ ] `docker compose up -d beszel-hub beszel-agent` starts both containers and they stay healthy
- [ ] `https://beszel.woggles.work` is reachable through Traefik with a valid TLS cert
- [ ] Agent shows as connected/reporting in the hub UI after entering Key/Token
- [ ] Homepage's Beszel card renders live system/up counts
- [ ] `./scripts/lint-config.sh` exits clean
- [ ] README, `.env.example`, and `scripts/setup.sh` all reflect the new service (per CLAUDE.md's pre-PR checklist)

## Files to Modify

- `docker-compose.yml` — add `beszel-hub` and `beszel-agent` services; add `HOMEPAGE_VAR_BESZEL_USERNAME`/`HOMEPAGE_VAR_BESZEL_PASSWORD` to the `homepage` service's `environment:` block
- `.env.example` — add `BESZEL_USERNAME`, `BESZEL_PASSWORD`, `BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN` with comments
- `homepage/config/services.yaml` — add a `Monitoring` group with the `Beszel` widget
- `scripts/setup.sh` — add `mkdir -p beszel/hub_data` and `mkdir -p beszel/agent_data` to the directory-creation block
- `.gitignore` — add `beszel/hub_data/` and `beszel/agent_data/` under the "Service config volumes" section
- `README.md` — add a `Beszel` row to the services table, a new numbered setup step (after Calibre-Web, before Tailscale), and a `beszel/` entry in the `## Project Structure` tree

## Implementation Phases

This is a flat, no-test configuration change. Phases are ordered by dependency (a later phase's edit references vars/services a prior phase defines), each independently verifiable.

---

### Phase 1: Add Beszel services to docker-compose.yml

**Goal:** Define `beszel-hub` and `beszel-agent` as new services on the `proxy` network, per the design spec's exact block.

**Tasks:**

1. Add `beszel-hub` service after `calibre-web` (before the top-level `volumes:` key): image `henrygd/beszel:0.19.0`, network `proxy`, volume `./beszel/hub_data:/beszel_data`, env `APP_URL=https://beszel.woggles.work`, Traefik labels matching the Jellyfin/Portainer/Calibre-Web pattern (router rule `Host(\`beszel.woggles.work\`)`, entrypoint `websecure`, certresolver `cloudflare`, service port `8090`)
2. Add `beszel-agent` service: image `henrygd/beszel-agent:0.19.0`, network `proxy`, volumes `./beszel/agent_data:/var/lib/beszel-agent` and `/var/run/docker.sock:/var/run/docker.sock:ro`, env `HUB_URL=http://beszel-hub:8090`, `KEY=${BESZEL_AGENT_KEY}`, `TOKEN=${BESZEL_AGENT_TOKEN}`, no Traefik labels

**Verification:**

- [ ] `docker compose config` parses without error
- [ ] Both services appear under the `proxy` network with no `network_mode: host`

#### Agent Context

- **Files to modify:** `docker-compose.yml`
- **Commands to run:** `docker compose config --quiet` (validates YAML + interpolation without starting containers)
- **Acceptance gate:** `docker compose config --quiet` exits 0; the two new service blocks match the design spec's Architecture section exactly (image tags, networks, volumes, env vars, Traefik labels)
- **Architectural constraints:** Both services on `proxy` bridge network only — no `network_mode: host`, no manual `traefik/dynamic/services.yml` entry (this repo's Docker-label routing pattern, not the Pi-hole host-network exception). Pin image tags to `0.19.0` (repo convention — no `:latest` for these two, matching e.g. Wallabag/Jellyfin pinning style already in the file where used). Agent gets no Traefik labels — it has no web UI.

---

### Phase 2: Add Beszel variables to .env.example

**Goal:** Document all four new env vars with comments explaining where each value comes from, so `scripts/lint-config.sh`'s `${VAR}`-without-default check passes.

**Tasks:**

1. Add a `# Beszel (server monitoring)` section to `.env.example` with `BESZEL_USERNAME=`, `BESZEL_PASSWORD=` (hub superuser account, created at first run) and `BESZEL_AGENT_KEY=`, `BESZEL_AGENT_TOKEN=` (agent connection credentials, generated in the hub UI) — exact comment text per the design spec's `.env.example additions` section

**Verification:**

- [ ] All four vars present in `.env.example` with explanatory comments
- [ ] Every `${BESZEL_*}` reference added in Phase 1 (`KEY`, `TOKEN`) has a matching entry here

#### Agent Context

- **Files to modify:** `.env.example`
- **Acceptance gate:** `grep -E '^BESZEL_(USERNAME|PASSWORD|AGENT_KEY|AGENT_TOKEN)=' .env.example` returns all 4 lines
- **Architectural constraints:** Follow existing `.env.example` comment style (one-line explanation per var or var group, pointing at where to obtain the value — see the `Calibre-Web` and `Wallabag` sections immediately above for the pattern)

---

### Phase 3: Wire the Homepage Beszel widget (3-file rule)

**Goal:** Add the Monitoring group to Homepage and complete CLAUDE.md's required 3-file wiring for `{{HOMEPAGE_VAR_BESZEL_USERNAME}}` / `{{HOMEPAGE_VAR_BESZEL_PASSWORD}}`.

**Tasks:**

1. In `homepage/config/services.yaml`, add a new `Monitoring` group (placed after `Media`, before `Books`, following existing group ordering) containing the `Beszel` entry: `href`, `description`, `icon: beszel`, and `widget` block (`type: beszel`, `url: http://beszel-hub:8090`, `username`/`password` via `{{HOMEPAGE_VAR_*}}`, `version: 2`) — exact block per design spec's Homepage integration section
2. In `docker-compose.yml`'s `homepage` service `environment:` block, add `HOMEPAGE_VAR_BESZEL_USERNAME=${BESZEL_USERNAME:-}` and `HOMEPAGE_VAR_BESZEL_PASSWORD=${BESZEL_PASSWORD:-}`, placed after the existing `HOMEPAGE_VAR_CALIBREWEB_*` lines to match insertion order of other recently-added services
3. Run `./scripts/lint-config.sh` and confirm it exits clean (this is the script CLAUDE.md requires — it's the authoritative check for this phase, not a project test suite)

**Verification:**

- [ ] `./scripts/lint-config.sh` exits 0
- [ ] `homepage/config/services.yaml`'s Beszel widget references only vars wired in `docker-compose.yml` and `.env.example`

#### Agent Context

- **Files to modify:** `homepage/config/services.yaml`, `docker-compose.yml`
- **Commands to run:** `./scripts/lint-config.sh`
- **Acceptance gate:** `./scripts/lint-config.sh` exits 0 (catches both classes of mismatch: `{{HOMEPAGE_VAR_*}}` not wired into `docker-compose.yml`, and `${VAR}`/`${VAR:-}` missing from `.env.example` — the latter should already be satisfied by Phase 2)
- **Architectural constraints:** Must follow CLAUDE.md's rule that a new widget variable touches all three files together (`services.yaml`, `docker-compose.yml` homepage env block, `.env.example`) — `.env.example` was completed in Phase 2, this phase completes the other two and validates the full set. `url` uses the `beszel-hub` container DNS name (both share the `proxy` network with Homepage), not a LAN IP — Pi-hole's LAN-IP pattern is the one exception in this repo and doesn't apply here.

---

### Phase 4: Create Beszel data directories in scripts/setup.sh

**Goal:** Ensure `beszel/hub_data/` and `beszel/agent_data/` exist before first `docker compose up`, matching the pattern already used for Jellyfin/FileBrowser/Calibre-Web.

**Tasks:**

1. Add `mkdir -p beszel/hub_data` and `mkdir -p beszel/agent_data` to `scripts/setup.sh`'s directory-creation block (alongside the existing `mkdir -p calibre-web/config` etc., around line 88)

**Verification:**

- [ ] Running `./scripts/setup.sh` (or a dry read of the diff) shows the two new `mkdir -p` lines in the same block as the other service directories

#### Agent Context

- **Files to modify:** `scripts/setup.sh`
- **Acceptance gate:** `grep -c 'mkdir -p beszel/' scripts/setup.sh` returns `2`
- **Architectural constraints:** Insert into the existing directory-creation block (not a new standalone section) — no chmod needed (Beszel doesn't require the world-writable permissions that FileBrowser/Wallabag needed)

---

### Phase 5: Ignore Beszel runtime data in .gitignore

**Goal:** Keep `beszel/hub_data/` and `beszel/agent_data/` out of version control, matching every other service's runtime-data entry.

**Tasks:**

1. Add `beszel/hub_data/` and `beszel/agent_data/` to `.gitignore` under the "Service config volumes (machine-specific, potentially large)" section

**Verification:**

- [ ] `git check-ignore beszel/hub_data/anything beszel/agent_data/anything` both report a match (or equivalent manual confirmation the patterns are present)

#### Agent Context

- **Files to modify:** `.gitignore`
- **Acceptance gate:** Both new lines present under the existing "Service config volumes" comment block, following the flat `dirname/` pattern used for `calibre-web/config/` etc.
- **Architectural constraints:** None beyond matching existing pattern.

---

### Phase 6: Document Beszel in README

**Goal:** Bring README's services table, setup steps, and Project Structure tree up to date, per CLAUDE.md's pre-PR checklist.

**Tasks:**

1. Add a `Beszel` row to the services table (after `Calibre-Web`): `https://beszel.woggles.work` — "Server resource monitoring"
2. Add a new numbered setup step after "### 10. Set up Calibre-Web" and before "### 11. Enable remote access via Tailscale" (renumbering Tailscale's step to 12), documenting: `docker compose up -d beszel-hub` → visit the hub, create the superuser account (`BESZEL_USERNAME`/`BESZEL_PASSWORD`) → in hub UI **Add System**, copy Key/Token into `.env` as `BESZEL_AGENT_KEY`/`BESZEL_AGENT_TOKEN` → `docker compose up -d beszel-agent` — per design spec's README changes section
3. Add `beszel/` to the `## Project Structure` tree with `hub_data/` and `agent_data/` marked `(gitignored)`, matching the style of the `filebrowser/` entry at the bottom of the tree

**Verification:**

- [ ] Services table, numbered setup steps, and Project Structure tree all mention Beszel
- [ ] No duplicate or skipped step numbers after the Tailscale renumber

#### Agent Context

- **Files to modify:** `README.md`
- **Acceptance gate:** `grep -c 'Beszel\|beszel' README.md` shows entries in all three locations (table, setup steps, project structure); step numbering is sequential with no gaps or duplicates
- **Architectural constraints:** Follow the existing numbered-step and table-row formatting exactly; don't renumber any step before Calibre-Web's.

---

### Phase 7: Full verification

**Goal:** Confirm the complete feature works end-to-end per the design spec's testing/verification plan.

**Tasks:**

1. Run `./scripts/lint-config.sh` — must exit clean
2. `docker compose config --quiet` — confirm no YAML/interpolation errors across all edited files
3. (On the server, or a local Docker environment) `docker compose up -d beszel-hub beszel-agent` — confirm both containers start and stay healthy
4. Confirm hub reachable at `https://beszel.woggles.work` through Traefik (TLS cert, routing)
5. Confirm agent shows as connected/reporting in the hub UI after entering Key/Token
6. Confirm Homepage's Beszel card renders live system/up counts

**Verification:**

- [ ] All acceptance criteria from the top of this plan are met
- [ ] `./scripts/lint-config.sh` exits 0

#### Agent Context

- **Commands to run:** `./scripts/lint-config.sh`, `docker compose config --quiet`
- **Acceptance gate:** Both commands exit 0. Live container/Traefik/Homepage verification (steps 3-6) requires the target Docker host (dev machine or server) — if run in an environment without Docker access, report that these steps are deferred to a manual check on the server and require user follow-up rather than claiming they passed.
- **Architectural constraints:** None — this is a verification-only phase, no file edits.

## Constraints & Considerations

### Architectural

- Both new services stay on the `proxy` bridge network — no `network_mode: host`, no `traefik/dynamic/services.yml` entry (that pattern is reserved for Pi-hole's DNS-role exception)
- Agent has no Traefik route (no web UI to expose)
- Pin image tags (`0.19.0`) rather than `:latest`, per this feature's design spec

### Testing

- No application test suite applies — this is Docker Compose / YAML / Markdown configuration
- The functional gate is `./scripts/lint-config.sh` (3-file Homepage-widget wiring check) plus `docker compose config --quiet` for syntax, plus a live smoke test (container health, Traefik TLS, hub-agent connection, Homepage widget rendering) that requires actual Docker access

### Security

- Hub auth is Beszel's own built-in superuser account — no Traefik basicauth middleware needed (unlike Traefik's own dashboard)
- Docker socket is mounted read-only (`:ro`) into the agent, matching the existing Traefik/dockerproxy read-only pattern

## Out of Scope

- SSH/auth-log and general host-level log visibility (deferred to a follow-up issue — see design spec's Follow-up GitHub issues section)
- Dozzle (container log viewer) — separate follow-up issue
- Alerting/push notifications — separate follow-up issue
- fail2ban / automatic banning — separate follow-up issue

## Approval Checklist

Before implementing, verify:

- [x] All files to create/modify listed
- [x] Implementation phases have clear boundaries
- [x] Each phase has an Agent Context block with file paths, commands, and acceptance gate
- [x] Acceptance criteria are testable
- [x] Constraints documented
- [x] Out of scope items noted

## Next Steps

After human review and approval:

1. Run `/implement` to execute — dispatches agents from task graph
2. Each phase is a single no-test agent task (no TDD triplet — configuration-only change)
3. If interrupted, `/implement` picks up where it left off via readiness computation
