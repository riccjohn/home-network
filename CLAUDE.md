# Claude Code Instructions

## Before creating a PR

Always run `./scripts/lint-config.sh` and confirm it exits clean before opening a pull request.
The script catches two classes of mismatch that cause silent runtime failures:

1. A `{{HOMEPAGE_VAR_*}}` reference in `homepage/config/*.yaml` that is not wired into `docker-compose.yml`
2. A `${VAR}` or `${VAR:-}` (no/empty default) in `docker-compose.yml` that is missing from `.env.example`

If a new service or widget adds variables, update **all three** files together:

- `homepage/config/services.yaml` (the `{{HOMEPAGE_VAR_*}}` widget key)
- `docker-compose.yml` homepage service `environment:` block
- `.env.example` (with a comment explaining where to get the value)

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
