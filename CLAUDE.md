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

## Project layout

- `docker-compose.yml` — all services; single `proxy` bridge network
- `homepage/config/` — Homepage dashboard config (services, widgets, settings)
- `traefik/` — reverse proxy config and dynamic rules
- `scripts/` — maintenance and validation scripts
- `.env.example` — canonical list of required env vars (copy to `.env` on the server)
