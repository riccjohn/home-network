# Plan: Add KOReader Sync Server

**tracker: yaks**

---

## Context

KOReader is an e-reader app (Kindle, Kobo, Android) that syncs reading progress across devices via a kosync-compatible server. The public service (`sync.koreader.rocks`) is a third-party dependency; this adds a self-hosted replacement.

Research findings:

- **Image:** `ghcr.io/nperez0111/koreader-sync:latest` — TypeScript/Bun/Hono, SQLite storage, port 3000, built-in health check at `GET /health`
- **Alternative considered:** `koreader/kosync` (official Lua/OpenResty + Redis) — heavier, less conventional; not chosen
- **Storage:** Named Docker volume `kosync-data` at `/app/data`; SQLite, no external DB needed
- **Auth:** `PASSWORD_SALT` env var required for account creation (generate via `openssl rand -hex 32`)
- **Routing:** Traefik on `proxy` network; no `ports:` mapping needed
- **Homepage:** Link-only entry (no widget API available); `si-koreader` icon via Simple Icons; Reading category already exists (contains Wallabag)
- **README:** Services table exists at lines 13–20; Wallabag was not added to it (out of scope here — we add KOReader Sync only)
- **lint-config.sh:** No `HOMEPAGE_VAR_*` references needed → script should pass without changes

---

## Goal

Add the `kosync` service to `docker-compose.yml` so KOReader devices can sync reading positions to the home server at `https://kosync.woggles.work`, and surface it on the Homepage dashboard.

---

## Acceptance Criteria

- [ ] `docker-compose.yml` includes `kosync` service with Traefik labels, `kosync-data` named volume, and `KOSYNC_PASSWORD_SALT` env var
- [ ] `kosync-data` volume declared at the compose root `volumes:` block
- [ ] `.env.example` has `KOSYNC_PASSWORD_SALT=` with a generation comment
- [ ] `homepage/config/services.yaml` has a KOReader Sync link in the Reading category
- [ ] `README.md` services table includes a KOReader Sync row
- [ ] `./scripts/lint-config.sh` exits 0 with no errors

---

## Files to Modify

| File                            | Change                                                           |
| ------------------------------- | ---------------------------------------------------------------- |
| `docker-compose.yml`            | Add `kosync` service block; add `kosync-data` to root `volumes:` |
| `.env.example`                  | Add `KOSYNC_PASSWORD_SALT=` with generation comment              |
| `homepage/config/services.yaml` | Add KOReader Sync link under Reading category                    |
| `README.md`                     | Add `KOReader Sync` row to services table                        |

---

## Implementation Phases

### Phase 1: Docker Compose — Add kosync service [no-test]

**Goal:** Wire the kosync container into the stack with Traefik routing and persistent storage.

**Tasks:**

- Add `kosync` service block after the Wallabag service in `docker-compose.yml`
- Add `kosync-data:` to the root `volumes:` block

**Verification:**

- [ ] `docker-compose config --quiet` exits 0 (compose file is valid)
- [ ] `kosync` service appears with `traefik.enable=true` label
- [ ] `kosync-data` volume is declared at root level

#### Agent Context

```
Files to modify:
  - docker-compose.yml

Service block to add (after wallabag service):
  kosync:
    container_name: kosync
    image: ghcr.io/nperez0111/koreader-sync:latest
    environment:
      - TZ=${TZ:-America/New_York}
      - PASSWORD_SALT=${KOSYNC_PASSWORD_SALT:-}
    volumes:
      - kosync-data:/app/data
    networks:
      - proxy
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.kosync.rule=Host(`kosync.woggles.work`)"
      - "traefik.http.routers.kosync.entrypoints=websecure"
      - "traefik.http.routers.kosync.tls.certresolver=cloudflare"
      - "traefik.http.services.kosync.loadbalancer.server.port=3000"

Root volumes block (currently has only `wallabag_images:`):
  Add: kosync-data:

Verification command: docker-compose config --quiet
GREEN gate: exits 0
```

---

### Phase 2: Environment — Add KOSYNC_PASSWORD_SALT [no-test]

**Goal:** Document the required secret in `.env.example`.

**Tasks:**

- Add `KOSYNC_PASSWORD_SALT=` entry to `.env.example` with a comment

**Verification:**

- [ ] `KOSYNC_PASSWORD_SALT=` appears in `.env.example`
- [ ] Comment explains how to generate the value

#### Agent Context

```
Files to modify:
  - .env.example

Entry to add (near other service secrets, e.g. after WALLABAG_SECRET block):

  # KOReader Sync Server — password hashing salt
  # Generate with: openssl rand -hex 32
  KOSYNC_PASSWORD_SALT=

Verification: grep KOSYNC_PASSWORD_SALT .env.example
GREEN gate: line is present
```

---

### Phase 3: Homepage — Add KOReader Sync link [no-test]

**Goal:** Surface kosync on the dashboard under the Reading category.

**Tasks:**

- Add KOReader Sync link entry in `homepage/config/services.yaml` under Reading category

**Verification:**

- [ ] Entry appears under `- Reading:` in services.yaml
- [ ] `href` points to `https://kosync.woggles.work`

#### Agent Context

```
Files to modify:
  - homepage/config/services.yaml

Current Reading category (line ~64):
  - Reading:
      - Wallabag:
          href: https://wallabag.woggles.work
          description: ...
          icon: wallabag

Add after Wallabag:
      - KOReader Sync:
          href: https://kosync.woggles.work
          description: KOReader reading progress sync
          icon: si-koreader

No HOMEPAGE_VAR_* variables needed — link only, no widget block.

Verification: grep -A3 "KOReader" homepage/config/services.yaml
GREEN gate: href line is present
```

---

### Phase 4: README — Add services table row [no-test]

**Goal:** Keep the README services table accurate.

**Tasks:**

- Add KOReader Sync row to the services table in `README.md` (lines 13–20)

**Verification:**

- [ ] KOReader Sync row appears in the services table

#### Agent Context

```
Files to modify:
  - README.md

Services table currently ends with:
  | FileBrowser | https://files.woggles.work        | File manager         |

Add after FileBrowser row:
  | KOReader Sync | https://kosync.woggles.work     | Reading progress sync |

Verification: grep "KOReader" README.md
GREEN gate: line is present
```

---

### Phase 5: Lint Verification [no-test]

**Goal:** Confirm the lint script passes with no HOMEPAGE_VAR mismatches or missing .env.example vars.

**Tasks:**

- Run `./scripts/lint-config.sh`

**Verification:**

- [ ] Script exits 0
- [ ] No HOMEPAGE*VAR*\* reference errors
- [ ] No missing .env.example variable errors

#### Agent Context

```
Files to read:
  - scripts/lint-config.sh (read-only — do not modify)
  - docker-compose.yml
  - .env.example
  - homepage/config/services.yaml

Verification command: ./scripts/lint-config.sh
GREEN gate: exits 0 with no error output

If it fails: check for any accidentally added HOMEPAGE_VAR_* references
in services.yaml that are not wired in docker-compose.yml, or any
${VAR:-} patterns in docker-compose.yml missing from .env.example.
```

---

## Constraints & Considerations

- **No application code** — all phases are config/YAML edits; no tests beyond compose validation and lint
- **Named volume, not bind mount** — SQLite data lives in `kosync-data` Docker volume; no host path needed
- **No ports: mapping** — Traefik handles all ingress on the `proxy` network
- **Icon fallback** — `si-koreader` resolves via Simple Icons; if it doesn't render, `mdi-book-sync` is a safe fallback
- **Post-deploy KOReader setup** (out of scope for this PR): Settings → Progress sync → Custom sync server → `https://kosync.woggles.work`

## Out of Scope

- Adding Wallabag to the README services table (pre-existing omission; separate PR)
- KOReader app configuration documentation
- Monitoring/alerting for the kosync service
