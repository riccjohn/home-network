# Server Monitoring - Research

**Date:** 2026-09-07
**Status:** Research Complete
**Depth:** Deep (2 codebase agents, 3 web agents)

## Summary

Goal: add server monitoring (overload, errors, unexpected-connection/SSH visibility) integrated into the Homepage dashboard, on a home-lab Docker Compose stack running on a modest Intel Haswell i3-4130T. The initial candidate (a single all-in-one Netdata container) turned out to have real rough edges — an Alpine-image gotcha, a reported CPU/iowait bug in its journal plugin, and a reported dashboard-behind-Traefik bug — for exactly the SSH/log-visibility piece it was meant to cover. **Resolved direction:** drop Netdata; ship Beszel (hub + agent, both on the standard `proxy` bridge network — host networking turned out to be optional and unnecessary for our needs) for overload/container visibility now, optionally Dozzle as a bookmark tile for container logs, and defer SSH/auth-log visibility to a third follow-up GitHub issue alongside the already-agreed fail2ban and push-notification issues.

## Relevant Files

- `docker-compose.yml` — single `proxy` bridge network; Pi-hole is the one existing `network_mode: host` service (line 12), with `traefik` given `extra_hosts: host.docker.internal:host-gateway` (lines 42-44) specifically to reach it.
- `traefik/traefik.yml` — `providers.docker` (label-based, `network: proxy`, `exposedByDefault: false`) plus `providers.file` watching `traefik/dynamic/` for services that can't use labels.
- `traefik/dynamic/services.yml` — Pi-hole's manual router/service block, backend `http://host.docker.internal:8080`. This is the _only_ place a host-network service gets routed; there is no auto-discovery for such services.
- `homepage/config/services.yaml` — Pi-hole's widget uses the hardcoded LAN IP (`http://192.168.0.243:8080`), not `host.docker.internal` (Homepage has no `extra_hosts` entry) and not a container name. Every other widget (Jellyfin, Portainer, Syncthing, Calibre-Web) uses plain bridge-network container DNS names, since those services share `proxy` with Homepage.
- `homepage/config/widgets.yaml` — existing `resources:` info-widget already reports host CPU/mem/disk (no container scoping set), independent of any new service.
- `.env.example`, `scripts/lint-config.sh` — enforce the 3-file wiring rule from CLAUDE.md for any new `{{HOMEPAGE_VAR_*}}`.

## Existing Patterns

### Pattern 1: Host-network service + manual Traefik file-provider routing

**Used in:** Pi-hole (`docker-compose.yml:7-29`, `traefik/dynamic/services.yml`)
**How it works:** `network_mode: host` bypasses Traefik's Docker-label discovery (host-network containers aren't on `proxy`), so routing is hand-written as a file-provider backend pointing at `host.docker.internal:<port>`. Homepage's widget instead hits the LAN IP directly, since Homepage has no `host.docker.internal` route.
**Applicable to new feature:** Only if a chosen monitoring service _requires_ host networking. Confirmed extendable, but every such service becomes one more manual, easy-to-forget wiring point (router, service backend, Homepage widget URL) — this repo currently has exactly one, deliberately, for Pi-hole's DNS role.

### Pattern 2: Bridge-network service + Docker-label routing

**Used in:** every other service (Jellyfin, Portainer, Homepage, Wallabag, etc.)
**How it works:** standard `traefik.*` labels + shared `proxy` network; Homepage reaches them by container DNS name.
**Applicable to new feature:** This is the default/preferred pattern in this repo. A monitoring service that doesn't strictly need host networking should use it.

## Web & Pattern Research

### Finding 1: Netdata's systemd-journal (log-browsing) plugin is real but has three concrete gotchas

**Sources:** [Systemd Journal Logs](https://learn.netdata.cloud/docs/logs/systemd-journal-logs/), [systemd-journal.plugin README](https://github.com/netdata/netdata/blob/master/src/collectors/systemd-journal.plugin/README.md), [Issue #16746](https://github.com/netdata/netdata/issues/16746)
**Confidence:** High (capability exists) / Medium (exact SSH-filter UX) / High (gotchas)
**Summary:** The plugin gives a genuine log browser (filter/search by any journal field including `SYSLOG_IDENTIFIER=sshd` and `PRIORITY`), not just alarms — v1.44+. But: (1) the **default `netdata/netdata` image is Alpine and does not ship this plugin** — the Debian image variant is required; (2) an open, unresolved GitHub issue reports the plugin causing multi-hour CPU/iowait/RAM spikes in a containerized deployment; (3) there is **no built-in health.d alarm template for SSH brute-force/failed-login-rate** — that would need custom config, contradicting the "zero-config" assumption in the original design.
**Implication for this feature:** The SSH/error-visibility piece of the original Netdata plan is meaningfully more fragile and higher-effort than assumed. Not a clean win.

### Finding 2: Open bug — Netdata dashboard reportedly fails to load behind Traefik

**Sources:** [Netdata issue #14709](https://github.com/netdata/netdata/issues/14709), [Traefik issue #11645](https://github.com/traefik/traefik/issues/11645)
**Confidence:** Medium (issue exists; current resolution status unclear)
**Summary:** A reported issue has Netdata's dashboard JS asset (`dashboard-react.js`) failing to resolve behind Traefik. Separately, Traefik's own label-based Docker discovery is documented as incompatible with `network_mode: host` (matching what this repo already works around for Pi-hole), so this exact "Netdata + host-network + Traefik" combination carries two independent, partially-corroborated risk reports.
**Implication for this feature:** Directly relevant to the original design (Netdata behind Traefik, host-network, exactly like Pi-hole). Adds real risk to shipping that combination without a fallback plan.

### Finding 3: Resource footprint favors composable lightweight tools over both candidates

**Sources:** [Netdata Scalability docs](https://learn.netdata.cloud/docs/welcome-to-netdata/scalability), [Beszel vs Netdata](https://instapods.com/apps/beszel/vs/netdata/), [Beszel vs Prometheus+Grafana](https://instapods.com/apps/beszel/vs/prometheus/)
**Confidence:** Medium (vendor/blog figures, no controlled benchmark at this exact scale)
**Summary:** Netdata: officially <200MiB RAM / <5% CPU standalone, third-party reports range 150–500MB in practice. Prometheus+Grafana+node-exporter+cAdvisor+Alertmanager: ~400–700MB+ combined, with Prometheus alone reported to need up to ~1GB under moderate scrape load in some guides. Beszel's agent: ~10-15MB.
**Implication for this feature:** On an i3-4130T already running ~11 containers, Beszel's footprint is a much smaller commitment than either candidate, for the metrics/overload piece specifically.

### Finding 4: Beszel covers overload metrics well but has zero log/SSH visibility (feature request open, unimplemented)

**Sources:** [Beszel GitHub](https://github.com/henrygd/beszel), [Beszel issue #890](https://github.com/henrygd/beszel/issues/890), [Homepage Beszel widget](https://gethomepage.dev/widgets/services/beszel/)
**Confidence:** High
**Summary:** Beszel (hub + lightweight Go agents) natively monitors CPU/mem/disk/network and **Docker container stats** via the Docker socket. It has a **native Homepage widget**. It has no log viewer and no SSH/connection-attempt tracking — a GitHub feature request for connection logging (to enable fail2ban-style integration) is open and unimplemented.
**Implication for this feature:** Strong fit for "is it overloaded" — clean, low-risk, matches this repo's one-container-per-concern pattern, likely runs fine on the `proxy` bridge network like every other service here (no `network_mode: host` requirement documented for its core metrics, though this should be confirmed at implementation time). Does not address "errors" or "SSH connection spikes" at all.

### Finding 5: Dozzle solves in-container log visibility but not host-level SSH auth logs

**Sources:** [Dozzle guide](https://www.dash0.com/guides/dozzle-docker), [gethomepage discussion #1250](https://github.com/gethomepage/homepage/discussions/1250)
**Confidence:** High
**Summary:** Dozzle is a ~10-15MB real-time Docker container log viewer with search, alerting webhooks (Slack/Discord/ntfy), and light per-container resource charts. **No native Homepage widget** (requested, not shipped — would need a plain bookmark tile). Critically, **sshd is a host systemd service in this stack, not a Docker container** — Dozzle has no visibility into host auth logs regardless.
**Implication for this feature:** Good candidate for general container-level "errors," but does not solve the SSH-spike requirement at all — that gap is orthogonal to the Beszel-vs-Netdata choice.

### Finding 6: Uptime Kuma is not a fit

**Sources:** [Homepage Uptime Kuma widget](https://gethomepage.dev/widgets/services/uptime-kuma/)
**Confidence:** High
**Summary:** Purely external/synthetic HTTP/TCP/ping uptime checking against endpoints; irrelevant to host resource overload or SSH connection visibility.

### Finding 7: 2025-2026 homelab sentiment trends away from all-in-one/heavy stacks for single-host setups

**Sources:** [Beszel vs Netdata vs Prometheus+Grafana (Big Iron)](https://www.bigiron.cc/guides/beszel-vs-netdata-vs-prometheus-grafana-for-homelab-metrics), [7 monitoring tools tested](https://dev.to/vikasprogrammer/i-tested-7-self-hosted-monitoring-tools-on-a-3-vps-in-2026-heres-the-one-i-kept-aoa)
**Confidence:** Low-Medium (aggregator/blog sources, not primary Reddit threads — those were not directly retrievable this session)
**Summary:** Secondary sources describe Beszel+Dozzle as a common current homelab pairing replacing heavier all-in-one or Prometheus-stack setups for single-host use, and characterize a full Prometheus+Grafana stack as often unnecessary ("ego, not requirement") for one box.
**Implication for this feature:** Directionally supports the composable approach but is the weakest-confidence finding here; treat as a tiebreaker, not a primary driver.

### Contested Findings

- **Netdata network mode:** Official docs still recommend `network_mode: host` for full feature parity (Finding 3, High confidence) — this is _not_ contested. What's contested is whether the SSH/log piece is worth that cost given Findings 1-2's gotchas. **Recommendation:** don't adopt Netdata's host-network + journal-plugin combo for v1; revisit as its own scoped follow-up if the lighter approach proves insufficient.

## Constraints & Considerations

- CLAUDE.md's 3-file rule (`services.yaml` / `docker-compose.yml` homepage env / `.env.example`) and `scripts/lint-config.sh` apply to any new widget credentials. _(codebase)_
- Repo convention strongly favors bridge-network + Docker-label Traefik routing; `network_mode: host` is currently a one-off exception (Pi-hole), not the norm. _(codebase)_
- Modest hardware (i3-4130T) already running ~11 containers — footprint matters more here than on typical homelab hardware. _(web research, confidence: Medium)_
- Netdata-behind-Traefik carries two independently-reported (if not fully confirmed-current) risk reports that directly affect the original design. _(web research, confidence: Medium)_
- SSH is a host-level systemd service in this stack, not a container — no Docker-log-viewer tool (Dozzle) can see it; only a journald/auth-log-aware tool (Netdata's journal plugin, or a custom lightweight reader) can. _(codebase + web research, confidence: High)_
- Fail2ban (auto-ban) and push notifications were already explicitly deferred by the user to separate follow-up GitHub issues before this research ran — that scoping decision stands.

## Resolved (follow-up research, 2026-09-08)

### Finding 8: Beszel's `network_mode: host` is only needed for host-level _network throughput_ stats, and is explicitly optional

**Sources:** [Beszel agent installation docs](https://www.beszel.dev/guide/agent-installation), [same-system docker-compose example](https://github.com/henrygd/beszel/blob/main/supplemental/docker/same-system/docker-compose.yml)
**Confidence:** High
**Summary:** The official agent compose file does use `network_mode: host`, but the docs state this is _only_ required "to access the host's network interface stats" and explicitly say: "If host network stats aren't needed, you can remove this requirement and map the port manually instead." No `/proc`/`/sys` bind mounts are used in the official examples at all — only `/var/run/docker.sock:ro` (for container stats) and a data volume. Critically, **the agent has no web UI of its own** — it's a client that connects outbound to the hub over a private port (default `45876`, or a unix socket per the same-system example); there is nothing to route through Traefik for the agent regardless of network mode.
**Implication for this feature:** Because our stated needs are CPU/mem/disk/container overload (not raw network throughput), the agent can run on the normal `proxy` bridge network, reachable by the hub via plain container DNS (or a shared socket volume) — exactly like every other service in this repo except Pi-hole. This avoids the host-network + Traefik-file-provider pattern (and its associated risks from Findings 1-2) entirely. Only the **hub** needs a Traefik route, and it's a standard bridge-network container with its own built-in auth (no basicauth middleware needed, unlike the original Netdata plan).

### Decision: drop Netdata, ship Beszel now

User reviewed Findings 1-2 (Alpine-image gotcha, CPU/iowait bug report, dashboard-behind-Traefik bug report) and agreed Netdata isn't the right choice given those risks relative to the payoff. Agreed direction:

- **Ship now:** Beszel hub + agent, both on the `proxy` bridge network (per Finding 8), hub routed through Traefik with a native Homepage widget. Optionally Dozzle for container-level log/error visibility, added as a plain bookmark tile on Homepage (no native widget — confirmed acceptable).
- **Defer to follow-up GitHub issues** (alongside the already-agreed fail2ban and push-notification issues): SSH connection/auth visibility and broader error/log visibility, since neither Beszel nor Dozzle address host-level journald/auth-log monitoring, and Netdata's journal-plugin approach carries the risks in Findings 1-2. A future issue can re-evaluate Netdata (Debian image, journal plugin only) vs. a lighter custom journald-based approach once there's appetite to take on that scope.

## Next Steps

Return to `superpowers:brainstorming`'s "Presenting the design" step with this resolved direction (Beszel + optional Dozzle, both bridge-network, no host-networking/Traefik-file-provider needed) and get final design sign-off before writing the spec doc.
