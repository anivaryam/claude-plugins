---
name: tunnel
description: Use when exposing a local port to the public internet through a self-hosted relay — HTTP/TCP/UDP tunnels, named or random IDs, subdomain or path-based routing, request inspector, daemon mode. Triggers on `tunnel` CLI invocations, the `~/.tunnel/config.yml` config, "expose this port publicly", "give me a public URL", "ngrok alternative", "self-hosted tunnel", or any setup needing inbound access to localhost from outside the LAN. Covers config (server URL + token), `tunnel http|tcp|udp`, named tunnels, daemon mode (`--silent` + `tunnel daemon status|monitor|stop`), Cloudflare Worker subdomain routing, relay deployment, and troubleshooting (`tunnel doctor`, `tunnel list`). Source: github.com/anivaryam/tunnel.
---

# tunnel

Self-hosted ngrok alternative. CLI client + relay server. You own the relay, so the public URL stays under your domain.

Repo: `github.com/anivaryam/tunnel`. Binary: `tunnel` (install via `brokit install tunnel`, release tarball, or `go install` — note: `go install` skips daemon mode).

## When to reach for it

- Need a public URL for a local dev server, webhook receiver, or demo.
- Need a public URL for TCP (Postgres, SSH) or UDP (DNS, game server).
- ngrok rate limits / quotas are blocking work.
- You control DNS and want the public URL under your own domain.

Do NOT use for: production traffic (deploy the app properly), bypassing corporate firewall policy, or anything where the public URL is the final delivery surface.

## One-time setup

```sh
tunnel config set-server https://relay.example.com
tunnel config set-token   <your-token>
tunnel config show                # confirm (token masked)
tunnel doctor                     # validate config + relay reachability
```

Config lives at `~/.tunnel/config.yml` (mode 0600). The `doctor` step is cheap and catches the common breakages (bad URL, unreachable relay, missing token) before you try to expose anything.

## Expose a port

```sh
tunnel http 3000                              # random 16-char ID
tunnel http 3000 --name api                   # stable, requestable name
tunnel http 3000 --inspect                    # local inspector at :4040
tunnel tcp  5432                              # Postgres / SSH / etc.
tunnel udp  53                                # DNS / game server / etc.
```

URL form depends on the relay's `BASE_DOMAIN`:
- **Path mode** (no `BASE_DOMAIN`): `https://relay.example.com/t/<id>/`
- **Subdomain mode** (`BASE_DOMAIN=relay.example.com`): `https://<id>.relay.example.com/`

Named tunnels follow the same rule with `<name>` in place of `<id>`. Name rules: 1–32 chars, `[a-z0-9-]`, no leading/trailing hyphen. Reserved names (`dashboard`, `metrics`, `mail`, `login`, `app`, `docs`, `status`, `staging`, `prod`, …) are rejected — full list in the relay's `internal/server/names.go`.

If a named tunnel disconnects, the name is held 60s for the same token to reclaim. Random IDs behave the same way.

## Daemon mode (Linux/macOS — `--silent`)

```sh
tunnel http 3000 --name api --silent
tunnel daemon status  --name api          # snapshot
tunnel daemon status  --name api --json   # scriptable
tunnel daemon monitor --name api          # interactive TUI
tunnel daemon stop    --name api          # graceful SIGTERM
```

`--silent` re-execs the process detached and waits ≤3s for the child to reach `state=connected`. If it doesn't, you get a one-line warning — check the log file.

Targeting: when started with `--name`, address by `--name`. When started without a name, address by `--port N --mode http|tcp|udp`.

Daemon files (per-user, mode 0700):
- Linux: `$XDG_RUNTIME_DIR/tunnel/tunnel-<hash>.{sock,pid,log}` (falls back to `$TMPDIR/tunnel-<uid>/`)
- macOS: `$TMPDIR/tunnel-<uid>/`
- Windows: `%LOCALAPPDATA%\tunnel\` plus `\\.\pipe\tunnel-<hash>`

`tunnel list` enumerates active tunnels via the relay's dashboard API. `tunnel list --json` for scripts.

`go install` and `make install-no-daemon` strip daemon support. If `--silent` says "not built", reinstall via the release binary or `make install`.

## Multiple tunnels

Fully isolated — open as many as you need.

```sh
tunnel http 3000 --name api
tunnel http 5173 --name frontend
tunnel tcp 5432  --name db
```

Default per-token cap is 50 simultaneous tunnels (`TUNNEL_MAX_TUNNELS_PER_TOKEN`); per-IP cap 100. Hit the cap → 429.

With subdomain routing each app gets its own browser origin (cookies, WebSockets, caches don't cross). Prefer subdomain mode for any multi-app setup.

## Deploying the relay

Relay is a single Go binary. Deploy on Railway (Dockerfile), Docker, or any VPS. Key env vars:

| Var | Notes |
|-----|-------|
| `TUNNEL_AUTH_TOKENS` | **Required.** Comma-separated valid tokens |
| `PORT` | HTTP port (default 8080) |
| `BASE_DOMAIN` | Enables subdomain routing |
| `CF_WORKER_ENABLED` + `TUNNEL_WORKER_SECRET` | Cloudflare Worker subdomain mode (Railway free tier) |
| `SINGLE_TUNNEL_MODE=true` | Only one tunnel; root domain proxies directly, no path prefix |
| `TUNNEL_TRUST_PROXY` | **Default false.** Set `true` ONLY when behind a trusted TLS-terminating LB. Setting `true` on the public edge lets peers lie about source IP |
| `TUNNEL_MAX_TUNNELS_PER_TOKEN` / `TUNNEL_MAX_TUNNELS_PER_IP` | Defaults 50 / 100. Set `0` to disable |
| `TUNNEL_WS_ORIGINS` | WebSocket Origin allowlist. Empty (default) skips check — CLI clients send no Origin header |

Subdomain options:
- **Direct wildcard DNS** (VPS / Railway Pro): add `*.<base>` record, set `BASE_DOMAIN`.
- **Cloudflare Worker** (Railway free tier): see README — Worker forwards `*.<base>` to relay with `X-Worker-Secret` header; relay verifies with constant-time compare.

Relay never terminates TLS — put a TLS-terminating LB in front (Railway, Cloudflare, fly.io).

## SPA / Vite / Next.js support

Path-based routing injects a `<script>` into HTML that rewrites `window.WebSocket`, `fetch`, `XMLHttpRequest.open`, and `EventSource` to route through `/t/<id>/`, plus a `history.replaceState` so SPA routers see clean paths. No injection in subdomain mode — own origin, no rewriting needed.

The CLI strips `Origin` before dialling the local WebSocket so Vite 5.1+ and Next.js Turbopack don't reject the proxied upgrade.

## proc-compose integration

Tunnel client = foreground; tunnel daemon = background. If proc-compose kills the client, the daemon keeps running and the public URL leaks. **Wrap the command with `trap`:**

```yaml
processes:
  tunnel:
    cmd: bash -c 'trap "tunnel stop --name myapp" EXIT TERM INT; tunnel http 8080 --name myapp; wait'
    depends_on: [merge-port]
    restart: on-failure
    ready_when:
      http: http://localhost:8080/health
```

**Never pass `--silent` to `tunnel` from inside proc-compose.** It daemonizes and exits immediately; proc-compose treats the immediate exit as a crash and restart-loops.

After `proc-compose stop`, verify cleanup:
```sh
ls /tmp/tunnel-*.sock 2>/dev/null            # empty
ps aux | grep "tunnel http" | grep -v grep   # empty
```

## Common failure patterns

- **`relay URL is invalid`** — config has a malformed URL. Re-run `tunnel config set-server <url>` (validates scheme + host).
- **Connection refused / DNS error** — relay unreachable. `tunnel doctor` will pinpoint.
- **429 Too Many Requests** — per-token or per-IP cap hit. Bump or disable.
- **`connection refused` from tunnel proxy** — local app bound to `::1` only. Bind to `0.0.0.0` or `127.0.0.1`. CLI dials `127.0.0.1:<port>` explicitly.
- **`--inspect` shows "inspector disabled"** — port 4040 in use. `lsof -i :4040` to find the holder, or run without `--inspect`.
- **`--silent` warns about not reaching `connected`** — bad URL, bad token, network down. Check log file printed at start, or `tunnel daemon status --name X`.
- **Daemon files from v1.6.x** — old `$TMPDIR/tunnel-<hash>.*` paths. Stop pre-1.7 daemons before upgrade; new commands look at `$XDG_RUNTIME_DIR/tunnel/` only.
- **Tunnel daemon leaks after Ctrl+C** — only happens when using the daemon (`--silent`). Foreground tunnels exit cleanly. For proc-compose, use the `trap` pattern above.

## Verifying

```sh
tunnel doctor                                    # config + relay reachability
tunnel config show                               # confirm server/token
tunnel http 3000 --name test                     # expose
curl -sf https://test.relay.example.com/         # hit it (subdomain mode)
curl -sf https://relay.example.com/t/test/       # hit it (path mode)
tunnel list                                      # confirm registration
tunnel daemon status --name test --json | jq     # state=connected
```

For TCP/UDP: connect to the dynamically allocated relay port (printed at start), e.g. `psql postgresql://...@db.relay.example.com:<port>/`.

## Gotchas

- **`TUNNEL_TRUST_PROXY=true` on the public edge is a security hole.** Only set when behind a trusted TLS-terminating LB.
- **Single dashboard URL per relay** — no per-token namespacing on the admin dashboard.
- **Inspector port hard-coded `127.0.0.1:4040`** — not configurable. One inspector at a time per machine.
- **TCP/UDP tunnels with dynamic ports** work best on a self-hosted VPS where the relay can bind arbitrary ports. Some PaaS providers restrict this.
- **Reserved names list is long.** Phishing-surface and infrastructure-style names (`mail`, `login`, `auth`, `account`, `billing`, etc.) are blocked. Pick app-specific names.
- **Windows daemon support is real but has fewer integration tests** than Linux/macOS.
