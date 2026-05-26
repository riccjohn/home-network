# Session: cloudflare-tunnel-integration

# Date: 2026-05-26

## Research Summary

Key findings from research artifact (cloudflare-tunnel-integration-research.md):

- Remote-managed tunnel via dashboard token is the simplest approach, consistent with existing secret management
- cloudflared forwards to Traefik (container name), not individual services — all existing label routing unchanged
- entrypoint-level `forwardedHeaders.trustedIPs` is the correct approach for Traefik v3.6+ (middleware trustForwardHeader is deprecated)
- SSL/TLS must be Full (Strict) — satisfied by existing \*.woggles.work Let's Encrypt cert
- No local config.yaml or credential files needed for remote-managed tunnel
- Wildcard A record (\* → 192.168.0.243) does not conflict — specific tunnel CNAME takes precedence

## Plan Summary

**Phases:**

1. Update `traefik/traefik.yml` — add `forwardedHeaders.trustedIPs` to websecure entrypoint with all Cloudflare IP ranges + Docker bridge
2. Add `cloudflared` service to `docker-compose.yml` + `CLOUDFLARE_TUNNEL_TOKEN` to `.env.example`
3. Add Cloudflare Tunnel setup section to `README.md` (4 manual dashboard steps)

**Acceptance Criteria:**

- cloudflared container starts and connects to Cloudflare's edge
- homepage.woggles.work accessible externally via Cloudflare Access (email OTP)
- LAN access to all services unchanged
- lint-config.sh exits clean
- CLOUDFLARE_TUNNEL_TOKEN documented in .env.example
- README documents all manual dashboard steps

**Architectural decisions:**

- Remote-managed tunnel only (no local config.yaml)
- cloudflared on proxy network, no Traefik labels, no depends_on
- TUNNEL_TOKEN (cloudflared's internal var) mapped from CLOUDFLARE_TUNNEL_TOKEN (project var)

## Execution Log

See: .light/sessions/2026-05-26-cloudflare-tunnel-integration-execution.md

```
[DISPATCHED] phase-1-traefik-forwarded-headers — agent type: agent-no-test, mode: sync
[GATE PASS] phase-1-traefik-forwarded-headers — VALIDATE gate passed
[CLOSED] phase-1-traefik-forwarded-headers
[DISPATCHED] phase-2-cloudflared-service — agent type: agent-no-test, mode: sync
[GATE PASS] phase-2-cloudflared-service — VALIDATE gate passed
[CLOSED] phase-2-cloudflared-service
[DISPATCHED] phase-3-readme-docs — agent type: agent-no-test, mode: sync
[GATE PASS] phase-3-readme-docs — VALIDATE gate passed
[CLOSED] phase-3-readme-docs
```

## Outcome

- Final `./scripts/lint-config.sh`: PASS (all 14 vars clean, including CLOUDFLARE_TUNNEL_TOKEN)
- 4 files modified, 85 lines added
- All 3 acceptance criteria met (lint, .env.example, README)
- Note: live tunnel connectivity requires manual Cloudflare dashboard steps (documented in README)
