# Server Monitoring (Beszel) — Session Summary

**Date:** 2026-09-08
**Tracker:** yaks
**Epic:** add-beszel-monitoring

## Research Summary

Compared Netdata vs. Beszel for host/container overload visibility on this repo's Docker Compose stack (i3-4130T, ~11 containers). Netdata was dropped due to three corroborated risks: an Alpine-image gotcha (default image lacks the journal plugin), a reported CPU/iowait bug in that plugin, and a reported Netdata-behind-Traefik dashboard bug. Beszel was chosen instead — hub + agent, both on the repo's standard `proxy` bridge network. Beszel's `network_mode: host` is documented as optional, needed only for host network-_throughput_ stats, which this feature doesn't require — so it avoids the host-network + Traefik-file-provider pattern that only Pi-hole uses in this repo. SSH/auth-log visibility, Dozzle, alerting, and fail2ban were explicitly deferred to separate follow-up issues.

Full detail: `.light/sessions/server-monitoring-research.md`

## Plan Summary

Flat, no-test, dependency-ordered 7-phase configuration change (no application test suite applies):

1. **P1-Compose-Services** — add `beszel-hub` (pinned `henrygd/beszel:0.19.0`, `proxy` network, Traefik labels, `APP_URL`) and `beszel-agent` (pinned `henrygd/beszel-agent:0.19.0`, `proxy` network, read-only docker.sock mount, no Traefik labels) to `docker-compose.yml`.
2. **P2-Env-Vars** — document `BESZEL_USERNAME`, `BESZEL_PASSWORD`, `BESZEL_AGENT_KEY`, `BESZEL_AGENT_TOKEN` in `.env.example`.
3. **P3-Homepage-Widget** — add a `Monitoring` group with the Beszel widget to `homepage/config/services.yaml`, complete the CLAUDE.md 3-file wiring rule in `docker-compose.yml`'s homepage `environment:` block.
4. **P4-Setup-Script** — add `beszel/hub_data` and `beszel/agent_data` directory creation to `scripts/setup.sh`.
5. **P5-Gitignore** — ignore `beszel/hub_data/` and `beszel/agent_data/` runtime data.
6. **P6-Docs-README** — document Beszel in the services table, a new numbered setup step (renumbering the Tailscale step from 11 to 12), and the Project Structure tree.
7. **P7-Full-Verification** — run `./scripts/lint-config.sh` and `docker compose config --quiet`; defer live container/TLS/UI checks to the server.

Key architectural decision: both services stay on the `proxy` bridge network only — no `network_mode: host`, no manual `traefik/dynamic/services.yml` entry (that pattern stays reserved for Pi-hole's DNS-role exception). Agent gets zero Traefik labels (no web UI). Image tags pinned, not `:latest`.

Full detail: `.light/sessions/server-monitoring-plan.md`

## Execution Log

All 7 phases dispatched sequentially as `agent-no-test` (P1–P6) and `agent-validate` (P7), each gated before advancing. No remediations needed — every phase passed its acceptance gate on the first attempt.

Full detail: `.light/sessions/2026-09-08-server-monitoring-execution.md`

## Outcome

- **Final verification:** `./scripts/lint-config.sh` exits 0; `docker compose config --quiet` exits 0.
- **plannotator review:** LGTM — no changes requested.
- **Acceptance criteria:**
  - [x] `./scripts/lint-config.sh` exits clean
  - [x] README, `.env.example`, and `scripts/setup.sh` all reflect the new service
  - [ ] `docker compose up -d beszel-hub beszel-agent` starts both containers and they stay healthy — **deferred**, requires Docker on the target host (dev Mac has no Docker daemon running)
  - [ ] `https://beszel.woggles.work` reachable through Traefik with a valid TLS cert — **deferred**, requires the server
  - [ ] Agent shows as connected/reporting in the hub UI after entering Key/Token — **deferred**, manual step on the server
  - [ ] Homepage's Beszel card renders live system/up counts — **deferred**, manual step on the server

All config/wiring work is complete and verified. Remaining items require deploying to the Ubuntu server (192.168.0.243), entering real `BESZEL_AGENT_KEY`/`BESZEL_AGENT_TOKEN` values, and visually confirming the hub/Homepage UI — the user should complete these per README step 11 after merging.
