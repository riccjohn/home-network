# Claude Code Instructions

## Before creating a PR

Before opening a pull request, work through this checklist:

- [ ] Does `README.md` need a new env var, setup step, or service entry?
- [ ] Does any file in `docs/` need updating (or does a new doc belong there)?
- [ ] Does `.env.example` need a new variable with a comment?
- [ ] Does any script in `scripts/` need updating to reflect the change?

Then run `./scripts/lint-config.sh` and confirm it exits clean.
The script catches two classes of mismatch that cause silent runtime failures:

1. A `{{HOMEPAGE_VAR_*}}` reference in `homepage/config/*.yaml` that is not wired into `docker-compose.yml`
2. A `${VAR}` or `${VAR:-}` (no/empty default) in `docker-compose.yml` that is missing from `.env.example`

If a new service or widget adds variables, update **all three** files together:

- `homepage/config/services.yaml` (the `{{HOMEPAGE_VAR_*}}` widget key)
- `docker-compose.yml` homepage service `environment:` block
- `.env.example` (with a comment explaining where to get the value)

## Local dev environment

Use this to run and test services locally before opening a PR.

**Start the stack:**

```bash
./scripts/dev.sh up       # creates .env.dev and .dev/data/ on first run
./scripts/health-check.sh # verify all services respond
```

**Agentic test loop:**

```bash
# after making a change to a service's config or compose definition:
./scripts/dev.sh restart <service>
./scripts/health-check.sh <service>     # targeted check; exit 1 = still broken
./scripts/dev.sh logs <service>          # read logs to diagnose failures
```

**Tear down:**

```bash
./scripts/dev.sh down
```

**Services available in local dev** (health check ports):

| Service     | URL                   | Notes                               |
| ----------- | --------------------- | ----------------------------------- |
| traefik     | http://localhost:8080 | HTTP only; dashboard at /dashboard/ |
| homepage    | http://localhost:3001 |                                     |
| portainer   | http://localhost:9000 |                                     |
| filebrowser | http://localhost:8081 |                                     |
| wallabag    | http://localhost:8888 |                                     |

**Services skipped in local dev:**

- `pihole` — requires Linux host networking
- `jellyfin` — requires `/dev/dri` render device
- `syncthing` — sync ports (22000, 21027) conflict with a native Syncthing install

**Known timing issue:** Wallabag runs a DB migration on first start and takes ~30s before it responds.
If `health-check.sh` reports wallabag FAIL immediately after `up`, wait and re-run — it is not a real failure.

**Key files:**

- `docker-compose.dev.yml` — compose overrides (ports, volumes, disabled services)
- `traefik/traefik.dev.yml` — Traefik static config (HTTP only, no ACME)
- `.env.dev.example` — dev env template (safe to read; copied to `.env.dev` on first run)
- `.dev/` — local data directories (gitignored)

## Session initialization

At the start of every work session:

1. `git log --oneline -10` — understand recent changes
2. Read `.claude/tasks.json` — find the in-progress or next `todo` task
3. Work only on that task; do not self-assign new work without asking the user

## Task tracking

Tasks live in `.claude/tasks.json`. Rules:

- You may **only** change the `status` field (`todo` → `in_progress` → `done`)
- Never rewrite `description`, `acceptance_criteria`, or `steps`
- To add a new task, ask the user — do not create tasks unilaterally

## Project layout

- `docker-compose.yml` — all services; single `proxy` bridge network
- `homepage/config/` — Homepage dashboard config (services, widgets, settings)
- `traefik/` — reverse proxy config and dynamic rules
- `scripts/` — maintenance and validation scripts
- `.env.example` — canonical list of required env vars (copy to `.env` on the server)
