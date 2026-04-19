# Session: Add KOReader Sync Server (2026-04-19)

## Research Summary

- **Image chosen:** `ghcr.io/nperez0111/koreader-sync:latest` — TypeScript/Bun/Hono, SQLite storage at `/app/data`, port 3000, built-in health check
- **Alternative considered:** `koreader/kosync` (official, Lua/OpenResty + Redis) — heavier, not chosen
- `PASSWORD_SALT` env var required for account creation; named Docker volume for SQLite persistence
- No Homepage widget available for kosync — link-only entry using `si-koreader` (Simple Icons)
- No `HOMEPAGE_VAR_*` references needed → lint script passes without homepage environment changes

## Plan Summary

**Goal:** Add `kosync` to the stack so KOReader devices sync reading positions to `https://kosync.woggles.work`.

**Phases:**

1. Docker Compose — add `kosync` service block + `kosync-data` named volume
2. Environment — add `KOSYNC_PASSWORD_SALT=` to `.env.example`
3. Homepage — add KOReader Sync link under Reading category in `services.yaml`
4. README — add KOReader Sync row to services table
5. Lint Verification — confirm `./scripts/lint-config.sh` exits 0

**Acceptance Criteria (all met):**

- `docker-compose.yml` includes `kosync` service with Traefik labels and `kosync-data` volume
- `.env.example` has `KOSYNC_PASSWORD_SALT=` with generation comment
- `homepage/config/services.yaml` has KOReader Sync link in Reading category
- `README.md` services table includes KOReader Sync row
- `./scripts/lint-config.sh` exits 0

## Execution Log

[DISPATCHED] group epic-add-koreader-sync-server-21z5 phase-1-docker-compose — agent type: no-test, mode: sync
[GATE PASS] group epic-add-koreader-sync-server-21z5 phase-1-docker-compose — GREEN gate passed
[CLOSED] group epic-add-koreader-sync-server-21z5 phase-1-docker-compose
[DISPATCHED] group epic-add-koreader-sync-server-21z5 phase-2-env-example — agent type: no-test, mode: sync
[GATE PASS] group epic-add-koreader-sync-server-21z5 phase-2-env-example — GREEN gate passed
[CLOSED] group epic-add-koreader-sync-server-21z5 phase-2-env-example
[DISPATCHED] group epic-add-koreader-sync-server-21z5 phase-3-homepage — agent type: no-test, mode: sync
[GATE PASS] group epic-add-koreader-sync-server-21z5 phase-3-homepage — GREEN gate passed
[CLOSED] group epic-add-koreader-sync-server-21z5 phase-3-homepage
[DISPATCHED] group epic-add-koreader-sync-server-21z5 phase-4-readme — agent type: no-test, mode: sync
[GATE PASS] group epic-add-koreader-sync-server-21z5 phase-4-readme — GREEN gate passed
[CLOSED] group epic-add-koreader-sync-server-21z5 phase-4-readme
[DISPATCHED] group epic-add-koreader-sync-server-21z5 phase-5-lint-verification — agent type: no-test, mode: sync
[GATE PASS] group epic-add-koreader-sync-server-21z5 phase-5-lint-verification — GREEN gate passed
[CLOSED] group epic-add-koreader-sync-server-21z5 phase-5-lint-verification

## Outcome

All 5 phases completed. `./scripts/lint-config.sh` exits 0 — 6 HOMEPAGE*VAR*\* references and 11 .env.example vars all verified. All acceptance criteria met.
