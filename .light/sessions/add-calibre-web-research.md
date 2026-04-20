# Research: Add Calibre-Web Ebook Service (Issue #19)

## Feature Summary

Add Calibre-Web as a new service for browser-based access to an existing Calibre ebook library. The library is synced to the server via Syncthing and mounted **read-only** to prevent `metadata.db` corruption while both the desktop Calibre app and Calibre-Web have concurrent access.

Files affected:

- `docker-compose.yml` — new service + homepage env vars
- `.env.example` — three new vars
- `homepage/config/services.yaml` — new "Books" group

---

## Codebase Findings

### docker-compose.yml patterns

**Service skeleton (from jellyfin/portainer):**

```yaml
<service-name>:
  container_name: <service-name>
  image: <image>:<tag>
  environment:
    KEY: ${ENV_VAR:-default}
  volumes:
    - ./local/path:/container/path
    - ${HOST_PATH:-/mnt/fallback}:/mount/point:ro # :ro for read-only
  networks:
    - proxy
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.<name>.rule=Host(`<name>.woggles.work`)"
    - "traefik.http.routers.<name>.entrypoints=websecure"
    - "traefik.http.routers.<name>.tls.certresolver=cloudflare"
    - "traefik.http.services.<name>.loadbalancer.server.port=<port>"
  restart: unless-stopped
```

**Jellyfin uses read-only media mount** — same pattern required for Calibre:

```yaml
- ${MEDIA_PATH:-/mnt/media}:/media:ro
```

**Homepage env block (lines ~86-95) — existing pattern:**

```yaml
environment:
  - HOMEPAGE_VAR_PIHOLE_API_KEY=${PIHOLE_API_KEY:-}
  - HOMEPAGE_VAR_JELLYFIN_API_KEY=${JELLYFIN_API_KEY:-}
  - HOMEPAGE_VAR_TRAEFIK_USERNAME=${TRAEFIK_USERNAME:-}
  - HOMEPAGE_VAR_TRAEFIK_PASSWORD=${TRAEFIK_PASSWORD:-}
```

New vars append to this block using the same `${VAR:-}` empty-default pattern.

**Proxy network:** `driver: bridge, name: proxy` — used by all services except pihole.

---

### homepage/config/services.yaml patterns

**Current group order:**

1. Network
2. Infrastructure
3. Media
4. Files
5. Reading

**Insertion point for "Books":** Between Media (group 3) and Files (group 4), per issue spec.

**Widget with username/password (Traefik — existing pattern):**

```yaml
widget:
  type: traefik
  url: https://traefik.woggles.work
  username: "{{HOMEPAGE_VAR_TRAEFIK_USERNAME}}"
  password: "{{HOMEPAGE_VAR_TRAEFIK_PASSWORD}}"
```

**Calibre-Web widget** will follow the same username/password pattern plus a `fields` array — this matches the calibreweb widget type supported by Homepage.

Internal URL uses container name on proxy network: `http://calibre-web:8083` (not host IP).

---

### .env.example patterns

Sections separated by blank lines, each with a `# ServiceName` header comment. Multi-line explanatory comments above complex vars.

**Style to match:**

```bash
# Calibre-Web
# CALIBRE_PATH: Syncthing-synced library on the server — must contain metadata.db
CALIBRE_PATH=/mnt/sync/calibre-library
# Homepage dashboard credentials
CALIBREWEB_USERNAME=admin
CALIBREWEB_PASSWORD=
```

**Insertion point:** After FileBrowser section, before "Media and sync paths" section.

---

## Implementation Plan (from issue #19)

All details are pre-specified in the issue. No ambiguity detected.

### 1. `docker-compose.yml` — new service

```yaml
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
```

### 2. `docker-compose.yml` — homepage env additions

```yaml
HOMEPAGE_VAR_CALIBREWEB_USERNAME: ${CALIBREWEB_USERNAME:-}
HOMEPAGE_VAR_CALIBREWEB_PASSWORD: ${CALIBREWEB_PASSWORD:-}
```

### 3. `homepage/config/services.yaml` — new Books group

Insert between Media and Files groups:

```yaml
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
```

### 4. `.env.example` additions

```bash
# Calibre-Web
# Set CALIBRE_PATH to the Syncthing-synced Calibre library on the server (must contain metadata.db)
CALIBRE_PATH=/mnt/sync/calibre-library
# Used by the Homepage dashboard widget
CALIBREWEB_USERNAME=admin
CALIBREWEB_PASSWORD=
```

---

## Constraints & Risks

| Constraint                               | Detail                                                                          |
| ---------------------------------------- | ------------------------------------------------------------------------------- |
| **Read-only mount is critical**          | `/books:ro` prevents metadata.db corruption when desktop Calibre is also active |
| **linuxserver image needs PUID/PGID**    | Must be set to `1000` to match server user permissions                          |
| **Widget URL uses container name**       | `http://calibre-web:8083` — NOT the host IP; services share the proxy network   |
| **Homepage env uses `:-` empty default** | `${CALIBREWEB_USERNAME:-}` not `${CALIBREWEB_USERNAME:-somevalue}`              |
| **lint-config.sh gate**                  | Must pass before PR — checks HOMEPAGE*VAR*\* wiring and .env.example coverage   |

---

## Open Questions

None — issue #19 provides a complete, unambiguous implementation recipe. All patterns confirmed against existing codebase.

---

## Validation Checklist (pre-PR)

1. `./scripts/lint-config.sh` exits 0
2. `/books` mount has `:ro` flag
3. `PUID: 1000` / `PGID: 1000` in calibre-web environment
4. `networks: [proxy]` present (not host network)
5. `HOMEPAGE_VAR_CALIBREWEB_USERNAME` and `HOMEPAGE_VAR_CALIBREWEB_PASSWORD` in homepage env block
6. All three vars in `.env.example` with explanatory comments
7. Widget URL uses `http://calibre-web:8083` (container name, not host IP)
8. Books group inserted between Media and Files groups
