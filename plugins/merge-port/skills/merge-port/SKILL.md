---
name: merge-port
description: Use when combining a frontend and a backend onto one port via a local reverse proxy — sharing a single dev URL, fronting a tunnel with one origin, routing multiple backends behind path prefixes, or providing a single container entrypoint port. Triggers on `merge-port` CLI invocations, `.merge-port.yaml` config files, "merge client and server", "one port for frontend and backend", "single-port dev proxy", "/api routes to backend", or "route /api to server, /* to client". Covers simple vs route mode, API prefix auto-detect, WebSocket passthrough, detach/status/stop, dry-run validation, and cloud-entrypoint usage. Source: github.com/anivaryam/merge-port.
---

# merge-port

Local reverse proxy. Two upstreams (or many), one listen port. Pure path routing — no containers, no DNS, no TLS termination.

Repo: `github.com/anivaryam/merge-port`. Binary: `merge-port` (install via `brokit install merge-port`, `go install`, or release tarball).

## When to reach for it

- Frontend (5173) + backend (3001) → one URL (e.g. `:8080`) so cookies, fetches, and WebSockets share an origin.
- Tunnel a single port instead of two.
- Container entrypoint that must serve everything on `$PORT`.
- Multiple backends behind one origin (`/api` → 3001, `/auth` → 3002, `/` → 3000).

Do NOT use for: TLS termination (put a real LB in front), production load balancing across hosts, sticky sessions, or anything that needs request rewriting beyond prefix-based routing.

## Two modes

### Simple mode

```sh
merge-port --client 5173 --server 3001 --port 8080
```

- `/api/*` → server (3001)
- everything else → client (5173)

Repeatable `--api-prefix` to add more server routes:
```sh
merge-port --client 5173 --server 3001 \
  --api-prefix /api --api-prefix /auth --api-prefix /uploads
```

### Route mode

Multiple backends, explicit prefixes:
```sh
merge-port --route /api=3001 --route /auth=3002 --route /=3000
```

Target accepts: bare port (`3001`), `host:port`, or full URL (`http://admin.local:4000`).

**Route mode is exclusive with `--client`/`--server`/`--api-prefix`.** Pick one form.

Add `/=...` as catch-all in route mode if you want frontend fallback — without it, unmatched paths return 404.

Routing rule: **longest prefix wins.** WebSockets pass through transparently (the proxy honours upgrade frames).

## Config files

```sh
merge-port init                                # writes .merge-port.yaml in cwd
merge-port init --client 5173 --server 3001 --dry-run
```

Simple mode YAML:
```yaml
port: 8080
client: 3000
server: 3001
api_prefixes:
  - /api
  - /auth
```

Route mode YAML:
```yaml
port: 8080
routes:
  - prefix: /api
    target: "3001"
  - prefix: /
    target: "5173"
```

Lookup: `.merge-port.yaml` in cwd is auto-loaded. `--config path` requires the file to exist (missing config = error). Flags always override config values.

## Discover API prefixes

`merge-port discover --server 3001` probes common OpenAPI/Swagger endpoints and prints suggested `--api-prefix` flags plus a `proc-compose.yaml` snippet. `--json` for scripts. `--write-config .merge-port.yaml` to materialize directly.

Discovery only catches what the server actually exposes via OpenAPI. Frameworks that don't ship OpenAPI (vanilla Express, plain `net/http`) won't be detected — fall back to grepping the source or list them manually.

## Validate before binding

```sh
merge-port validate --client 5173 --server 3001
```

Checks: route syntax, listen-port availability, upstream TCP reachability. Note: listen-port check is point-in-time — another process can bind it between validate and start.

Dry-run to preview routing without binding or touching upstreams:
```sh
merge-port --client 5173 --server 3001 --dry-run
```

## Detached mode (Linux/macOS only)

```sh
merge-port --client 5173 --server 3001 --port 8080 --detach --log-file mp.log
merge-port status --port 8080
merge-port stop   --port 8080
```

Windows has no `setsid()` — `--detach` is unsupported, foreground only.

## Cloud entrypoint

Cloud platforms expose `$PORT`. Either pass `--port "$PORT"` or set `port:` in config to the same expression. The built-in `/_health` endpoint returns `200 ok` locally (never proxied) — point platform liveness probes at it.

Disable color in cloud logs: `NO_COLOR=1` or `--silent`.

## Integration with proc-compose

When using `proc-compose`, **do not declare a `merge-port` process manually.** Add a `merge:` block in `proc-compose.yml`; proc-compose auto-injects merge-port, wires `depends_on` on upstreams, sets TCP `ready_when` probes, and injects the merge URL into known client env vars (`VITE_API_*`, `NEXT_PUBLIC_API_*`, etc.). Manual entries fight the auto-injection.

When using merge-port standalone (no orchestrator), start upstreams first, then start merge-port. There is no upstream readiness wait in merge-port itself — it just proxies, and an unreachable upstream returns a connect error to the client.

## Gotchas

- **Route mode without `/=...` returns 404** on the root path. Add the catch-all if you want frontend fallback.
- **Auto-detected `api_prefixes` (in proc-compose) only catch top-level handlers.** Sub-router files miss. Set `api_prefixes:` explicitly for Django/Rails/Flask and modular Express/Koa setups.
- **WebSocket dev servers that enforce same-origin (Vite 5.1+, Next.js Turbopack)** may reject upgrades. merge-port strips `Origin` only on the tunnel companion; for merge-port itself, configure the dev server to allow the merge listen port as an origin.
- **`merge-port stop --port` only works for processes started with `--detach` on the same machine.** Foreground processes ignore it.
- **Listen-port validation is racy.** Another process can bind between validate and start. Don't rely on `validate` alone for orchestration — handle bind errors.
- **Windows: no `--detach`.** Always foreground.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error (bind failed, upstream unreachable, etc.) |
| 2 | Usage error (bad flags, bad route syntax) |

Script accordingly — `2` means the invocation is wrong, `1` means runtime failure.

## Verifying

```sh
merge-port --client 5173 --server 3001 --dry-run    # show effective routing
merge-port validate --client 5173 --server 3001     # check ports + reachability
merge-port --client 5173 --server 3001 --port 8080  # bind
curl -sf http://localhost:8080/_health              # liveness
curl -sf http://localhost:8080/api/whoami           # backend route hits backend
curl -sI http://localhost:8080/                     # client route hits frontend
```

For WebSocket: connect with `wscat -c ws://localhost:8080/ws` (or whatever the dev server uses) and confirm frames flow.
