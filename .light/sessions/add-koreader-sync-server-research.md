# Research: Add KOReader Sync Server

## Feature Summary

Add a self-hosted KOReader progress-sync server so KOReader (e-reader app) can sync reading positions across devices without relying on the public `sync.koreader.rocks` service. The server stores only reading positions (keyed by file MD5 hash), not book files.

---

## Recommended Image

### `ghcr.io/nperez0111/koreader-sync:latest`

**Confidence: High** — actively maintained, powers the public kosync.nickthesick.com demo, cross-referenced across GitHub + Docker Hub.

- Language: TypeScript (Bun + Hono)
- Storage: SQLite — no external DB service needed
- Port: `3000`
- Health endpoint: `GET /health` → HTTP 200 (Docker HEALTHCHECK built in)

**Alternative:** `koreader/kosync:latest` (official, Lua/OpenResty) — bundles Redis inside the container, port 17200 behind a proxy. Protocol-compatible but heavier and less conventionally configured.

---

## Integration Points

### docker-compose.yml — new service block

```yaml
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
```

Named volume at the compose root:

```yaml
volumes:
  kosync-data:
```

### .env.example — new variable

```
# KOReader Sync Server
# Generate with: openssl rand -hex 32
KOSYNC_PASSWORD_SALT=
```

### homepage/config/services.yaml — new entry

The "Reading" category already exists (contains Wallabag). Add kosync there. No official Homepage widget type exists for kosync, so this will be a simple link entry.

```yaml
- Reading:
    - KOReader Sync:
        href: https://kosync.woggles.work
        description: KOReader reading progress sync
        icon: si-koreader
```

(`koreader` is not in the walkxcode/dashboard-icons pack, but `si-koreader` resolves via Simple Icons and renders in KOReader's brand teal.)

No `HOMEPAGE_VAR_*` variable needed — no API widget, just a link.

### docker-compose.yml homepage environment block

No changes needed (no HOMEPAGE*VAR*\* required for a link-only entry).

### scripts/lint-config.sh

No HOMEPAGE_VAR references to add, so the lint script should pass without changes. Verify after wiring.

---

## Constraints and Decisions

### PASSWORD_SALT is required

The env var `PASSWORD_SALT` must be set or accounts cannot be created. Use `openssl rand -hex 32` to generate. Fits the existing pattern of secret env vars like `WALLABAG_SECRET`.

### Named volume vs bind mount

The SQLite database at `/app/data` must be persisted. A named Docker volume (`kosync-data`) is the right choice — no host path needed, matches how Wallabag uses named volumes (`wallabag_images`).

### No port exposure needed

All traffic goes through Traefik (`proxy` network). No `ports:` mapping is needed. KOReader connects via `https://kosync.woggles.work`.

### Homepage widget: link only

No Homepage widget type exists for KOReader sync. The entry will be a link (no `widget:` block), same pattern as services that don't expose an API dashboard hook. The icon `koreader` may or may not be in the Homepage icon library — fallback to `mdi-book-sync` if not found.

### KOReader app setup (post-deploy)

In the KOReader app: Settings → Progress sync → Custom sync server → enter `https://kosync.woggles.work` → Register with username + password. Each device registers once and auto-syncs on open/close.

---

## Open Questions

None — all questions resolved during research.

---

## Files to Change

| File                            | Change                                                     |
| ------------------------------- | ---------------------------------------------------------- |
| `docker-compose.yml`            | Add `kosync` service block; add `kosync-data` named volume |
| `.env.example`                  | Add `KOSYNC_PASSWORD_SALT=` with generation instructions   |
| `homepage/config/services.yaml` | Add link entry to Reading category                         |
| `README.md`                     | Add kosync row to services table if one exists             |
| `docs/`                         | Check if a per-service doc page is needed                  |
