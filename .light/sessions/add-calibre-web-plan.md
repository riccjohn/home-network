# Plan: Add Calibre-Web Ebook Service

**tracker:** yaks

---

## Context

Issue #19 requests Calibre-Web as a browser-based frontend for an existing Calibre ebook library synced to the server via Syncthing. The library mount must be **read-only** to prevent `metadata.db` corruption when desktop Calibre and Calibre-Web run concurrently. Research confirmed all patterns against the codebase — no ambiguity.

---

## Goal

Add a `calibre-web` Docker service behind Traefik, wire it into the Homepage dashboard with a Books group, and document the three new env vars in `.env.example`.

---

## Acceptance Criteria

- [ ] `calibre-web` service defined in `docker-compose.yml` using `lscr.io/linuxserver/calibre-web:latest`
- [ ] `/books` mount has `:ro` flag; `PUID: 1000` / `PGID: 1000` set
- [ ] Traefik labels route `calibre-web.woggles.work` → port 8083
- [ ] `HOMEPAGE_VAR_CALIBREWEB_USERNAME` and `HOMEPAGE_VAR_CALIBREWEB_PASSWORD` in homepage env block
- [ ] Books group inserted between Media and Files groups in `services.yaml`
- [ ] `CALIBRE_PATH`, `CALIBREWEB_USERNAME`, `CALIBREWEB_PASSWORD` added to `.env.example` with comments
- [ ] `./scripts/lint-config.sh` exits 0

---

## Files to Modify

| File                            | Change                                        |
| ------------------------------- | --------------------------------------------- |
| `docker-compose.yml`            | Add `calibre-web` service + homepage env vars |
| `homepage/config/services.yaml` | Add Books group between Media and Files       |
| `.env.example`                  | Add three new vars with comments              |

---

## Implementation Phases

### Phase 1 — docker-compose.yml changes

**Goal:** Add the calibre-web service and homepage env vars.

**Tasks:**

- Add `calibre-web` service block after existing services (before the `networks:` section)
- Append `HOMEPAGE_VAR_CALIBREWEB_USERNAME` and `HOMEPAGE_VAR_CALIBREWEB_PASSWORD` to the homepage service `environment:` block

**Verification:**

- `/books:ro` present in volumes
- `PUID: 1000` / `PGID: 1000` in environment
- `networks: [proxy]` present
- Traefik labels use `calibre-web.woggles.work` and port `8083`
- Homepage env block contains both new `HOMEPAGE_VAR_*` entries

#### Agent Context

```
Files to modify:
  - docker-compose.yml

Changes:
  1. Add calibre-web service:
     calibre-web:
       container_name: calibre-web
       image: lscr.io/linuxserver/calibre-web:latest
       environment:
         PUID: 1000
         PGID: 1000
         TZ: ${TZ:-America/New_York}
       volumes:
         - ./calibre-web/config:/config
         - ${CALIBRE_PATH:-/mnt/calibre}:/books:ro
       networks:
         - proxy
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.calibre-web.rule=Host(`calibre-web.woggles.work`)"
         - "traefik.http.routers.calibre-web.entrypoints=websecure"
         - "traefik.http.routers.calibre-web.tls.certresolver=cloudflare"
         - "traefik.http.services.calibre-web.loadbalancer.server.port=8083"
       restart: unless-stopped

  2. In the homepage service environment block, append:
       - HOMEPAGE_VAR_CALIBREWEB_USERNAME=${CALIBREWEB_USERNAME:-}
       - HOMEPAGE_VAR_CALIBREWEB_PASSWORD=${CALIBREWEB_PASSWORD:-}

Test command: docker compose config --quiet && echo "compose valid"
RED gate: N/A (no-test phase)
GREEN gate: docker compose config exits 0
Constraints: mount must use :ro; widget URL must use container name not host IP
```

---

### Phase 2 — homepage/config/services.yaml Books group

**Goal:** Add Books group with Calibre-Web widget between Media and Files groups.

**Tasks:**

- Insert Books group with calibreweb widget between the Media and Files groups

**Verification:**

- Group order: Network → Infrastructure → Media → Books → Files → Reading
- Widget uses `http://calibre-web:8083` (container name)
- `fields` includes `["books", "authors", "categories", "series"]`
- `{{HOMEPAGE_VAR_CALIBREWEB_USERNAME}}` / `{{HOMEPAGE_VAR_CALIBREWEB_PASSWORD}}` template vars used

#### Agent Context

```
Files to modify:
  - homepage/config/services.yaml

Change:
  Insert between Media group and Files group:
  - Books:
      - Calibre-Web:
          href: https://calibre-web.woggles.work
          description: Ebook library
          icon: calibre-web
          widget:
            type: calibreweb
            url: http://calibre-web:8083
            username: "{{HOMEPAGE_VAR_CALIBREWEB_USERNAME}}"
            password: "{{HOMEPAGE_VAR_CALIBREWEB_PASSWORD}}"
            fields: ["books", "authors", "categories", "series"]

Test command: docker compose config --quiet && echo "compose valid"
RED gate: N/A (no-test phase)
GREEN gate: docker compose config exits 0
Constraints: widget URL must use container name (http://calibre-web:8083), not host IP
```

---

### Phase 3 — .env.example documentation

**Goal:** Document the three new env vars with explanatory comments.

**Tasks:**

- Add Calibre-Web section to `.env.example` after the FileBrowser section (before "Media and sync paths")

**Verification:**

- Three vars present: `CALIBRE_PATH`, `CALIBREWEB_USERNAME`, `CALIBREWEB_PASSWORD`
- `CALIBRE_PATH` has multi-line comment explaining Syncthing sync requirement
- `CALIBREWEB_PASSWORD` has empty value (not a default)

#### Agent Context

```
Files to modify:
  - .env.example

Change:
  After the FileBrowser section, insert:
  # Calibre-Web
  # Set CALIBRE_PATH to the Syncthing-synced Calibre library on the server (must contain metadata.db)
  CALIBRE_PATH=/mnt/sync/calibre-library
  # Used by the Homepage dashboard widget
  CALIBREWEB_USERNAME=admin
  CALIBREWEB_PASSWORD=

RED gate: N/A (no-test phase)
GREEN gate: ./scripts/lint-config.sh exits 0
Constraints: use empty default for CALIBREWEB_PASSWORD (no value); match existing section style
```

---

### Phase 4 — Lint validation

**Goal:** Confirm all three files are consistent and lint-config.sh passes.

**Tasks:**

- Run `./scripts/lint-config.sh` and verify exit 0

**Verification:**

- All HOMEPAGE*VAR*\* references in services.yaml are wired in docker-compose.yml
- All `${VAR:-}` vars in docker-compose.yml are present in .env.example
- Script exits 0

#### Agent Context

```
Files to read:
  - docker-compose.yml
  - homepage/config/services.yaml
  - .env.example

Test command: ./scripts/lint-config.sh
RED gate: N/A (no-test phase)
GREEN gate: ./scripts/lint-config.sh exits 0
```

---

## Constraints & Considerations

- **Read-only mount is critical:** `/books:ro` — omitting this risks metadata.db corruption
- **linuxserver image:** requires `PUID: 1000` / `PGID: 1000` for file permission matching
- **Widget URL uses container name:** `http://calibre-web:8083` — all services share the `proxy` network
- **Homepage env pattern:** `${VAR:-}` empty default (not `${VAR:-somevalue}`)
- **No new networks or volumes sections needed** — proxy network already exists

---

## Out of Scope

- Calibre-Web initial setup / first-run configuration (done manually after deploy)
- Syncthing configuration for the library sync path
- KOReader sync integration with Calibre-Web
