# Session Artifact — Add Calibre-Web — 2026-04-19

## Research Summary

Researched codebase patterns for adding a new service. Key findings:

- Services follow a standard skeleton with `container_name`, `image`, `environment`, `volumes`, `networks`, `labels`, `restart`
- Read-only mounts use `:ro` (confirmed from Jellyfin pattern) — critical to prevent `metadata.db` corruption when desktop Calibre and Calibre-Web run concurrently
- Homepage env vars use `${VAR:-}` empty-default pattern (no fallback value for credentials)
- Widget internal URL uses container name (`http://calibre-web:8083`), not host IP — all services share the `proxy` bridge network
- New "Books" group inserts between Media and Files groups in `services.yaml`

## Plan Summary

**Goal:** Add `calibre-web` Docker service behind Traefik, wire into Homepage dashboard with Books group, document env vars.

**Phases:**

1. Add `calibre-web` service + homepage env vars to `docker-compose.yml`
2. Add Books group with calibreweb widget to `homepage/config/services.yaml`
3. Add `CALIBRE_PATH`, `CALIBREWEB_USERNAME`, `CALIBREWEB_PASSWORD` to `.env.example`
4. Lint validation via `./scripts/lint-config.sh`

**Acceptance criteria (all met):**

- `calibre-web` service using `lscr.io/linuxserver/calibre-web:latest`
- `/books:ro` mount, `PUID: 1000` / `PGID: 1000`
- Traefik routes `calibre-web.woggles.work` → port 8083
- `HOMEPAGE_VAR_CALIBREWEB_USERNAME` and `HOMEPAGE_VAR_CALIBREWEB_PASSWORD` in homepage env block
- Books group between Media and Files in `services.yaml`
- Three new vars in `.env.example` with comments
- `./scripts/lint-config.sh` exits 0

## Execution Log

```
[DISPATCHED] phase-1-docker-compose — agent type: no-test, mode: sync
[GATE PASS] phase-1-docker-compose — GREEN gate passed
[CLOSED] phase-1-docker-compose
[DISPATCHED] phase-2-services-yaml — agent type: no-test, mode: sync
[GATE PASS] phase-2-services-yaml — GREEN gate passed
[CLOSED] phase-2-services-yaml
[DISPATCHED] phase-3-env-example — agent type: no-test, mode: sync
[GATE PASS] phase-3-env-example — GREEN gate passed
[CLOSED] phase-3-env-example
[DISPATCHED] phase-4-lint-validation — agent type: no-test, mode: sync
[GATE PASS] phase-4-lint-validation — GREEN gate passed
[CLOSED] phase-4-lint-validation
```

## Outcome

All 4 phases passed. `./scripts/lint-config.sh` exits 0 — 8 homepage config var checks and 13 docker-compose env var checks all green. No remediations required.

**Files modified:**

- `docker-compose.yml` — calibre-web service + homepage env vars
- `homepage/config/services.yaml` — Books group with calibreweb widget
- `.env.example` — CALIBRE_PATH, CALIBREWEB_USERNAME, CALIBREWEB_PASSWORD
