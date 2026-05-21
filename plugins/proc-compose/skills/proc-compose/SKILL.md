---
name: proc-compose
description: Use when orchestrating multiple local processes for a dev stack or single-container deploy — frontend+backend, microservices, ordered startup, prestart tasks, public tunnels. Triggers on `proc-compose.yml`/`proc-compose.yaml` files, `proc-compose` CLI invocations, "start the stack", "run everything together", "merge frontend and backend on one port", combined dev server requests, or container entrypoints that need to run more than one command. Covers config authoring, lifecycle (up/monitor/status/restart/reload/stop/list/uninstall), readiness probes, dependencies, daemon paths, log rotation, JSON outputs, and cloud deploy patterns. Source: github.com/anivaryam/proc-compose.
---

# proc-compose

Local process orchestrator. One YAML, one lifecycle, one log stream. Not Docker — no containers, no images, just `sh -c` with supervision.

Repo: `github.com/anivaryam/proc-compose`. Binary: `proc-compose` (installed via `brokit install proc-compose`, `~/.local/bin/`, or `go install`).

`brokit install` also lays down companions: `merge-port`, `tunnel`, `env-vault`, `proxy-relay`. Easiest way to unlock the `merge:` block and public tunnels.

## When to reach for it

Use proc-compose when the project needs >1 long-running command and the user wants them tied together. Signals:
- `proc-compose.yml` or `proc-compose.yaml` present (walks parent dirs from cwd)
- frontend + backend dev pair, microservices, worker+queue, prestart migrations
- container entrypoint that runs multiple children
- "give me a public URL" via the `tunnel` companion

Do NOT use for: single-process projects, Docker stacks (use `docker compose`), production multi-host orchestration (use k8s/nomad).

## Workflow

### New project (no config yet)

```sh
proc-compose bootstrap          # dry run, prints proposed yaml
proc-compose bootstrap --verify # parse-check generated config
proc-compose bootstrap --write  # create proc-compose.yml
proc-compose bootstrap --json   # machine-readable scan output
```

`bootstrap` builds on `doctor`. Scans Node/Go/Python layouts, detects npm/yarn/pnpm/bun runners, Vite/Next/SvelteKit/Astro, Go `cmd/**/main.go`, Django/Flask/Uvicorn/Hypercorn. Refuses to overwrite without `--force`. Always read the dry-run output before `--write` — cheapest review.

`proc-compose init --template node|go|python|minimal` for a hand-edit starting point instead of detection.

### Existing project

```sh
proc-compose validate           # parse-only, catches unknown fields / bad restart / cycles
proc-compose list               # show defined processes (alias: l)
proc-compose up                 # foreground, Ctrl+C stops all
proc-compose up frontend backend  # subset (deps auto-included)
proc-compose up --dry-run       # resolve + list, no start
proc-compose up --silent --log-file app.log  # daemonize
proc-compose monitor            # TUI on running daemon (alias: m)
proc-compose status             # one-shot snapshot
proc-compose status --json      # scriptable
proc-compose logs -n 200        # tail default log (-n 0 = full file)
proc-compose restart backend    # one process
proc-compose reload             # re-read config, restart changed defs
proc-compose stop               # SIGTERM, 10s grace, then SIGKILL
proc-compose stop --timeout 30  # extend graceful window
proc-compose stop --force       # SIGKILL now
proc-compose uninstall --name myapp  # remove systemd unit from --survive
```

`doctor` (no args) diagnoses an existing config — port conflicts, restart loops, missing binaries, readiness gaps, merge-port wiring. `doctor --write` can also generate `proc-compose.yml` when none exists (safe — refuses to overwrite). `doctor --json` for scripts.

### Command aliases

| Short | Full |
|-------|------|
| `u` | `up` |
| `m` | `monitor` |
| `r` | `restart` |
| `rl` | `reload` |
| `st` / `ps` | `status` |
| `l` | `list` |
| `i` | `init` |
| `doc` | `doctor` |
| `check` | `validate` |
| `un` | `uninstall` |

Also: `man [--dir DIR]` generates man pages, `completion <shell>` emits bash/zsh/fish/powershell autocomplete.

## Config — `proc-compose.yml`

```yaml
merge:                          # optional, requires merge-port binary
  client: 5173
  server: 3001
  port: 8080                    # falls back to $PORT then 8080

processes:
  name:
    cmd: "command"              # required, passed to sh -c
    mode: service               # or "task" (one-shot)
    dir: "./subdir"
    env_file: ".env"
    env:
      KEY: "value"              # overrides env_file
    restart: never              # never | on-failure | always (services only)
    max_restarts: 5             # 0 = unlimited
    shutdown_timeout: 30        # seconds before SIGKILL (default: 5)
    ready_when:
      http: http://localhost:3000/health
      # or: tcp: localhost:5432
      # or: log: "ready regex"
    ready_timeout: 60           # default 60; -1 = no limit
    depends_on: [other]
```

### service vs task

- **service**: long-running. Ready when started OR `ready_when` passes. Restart policies apply.
- **task**: one-shot (migrations, codegen, seeds). Ready = exit 0. Must be `restart: never`. No `ready_when`/`ready_timeout`/`max_restarts`. Non-zero exit fails the stack.
- Task-only stacks **cannot daemonize** (`--silent` refuses) — nothing to manage after they exit.

### Readiness

Pick cheapest signal that actually proves process serves traffic:
- `http`: GET returns 2xx
- `tcp`: connect succeeds (good for DBs)
- `log`: regex matches stdout (good for opaque servers)

Probes poll every 3s. Default deadline 60s. Without `ready_when`, a service is "ready" the moment it starts — fine for dependents that don't actually need it up yet, dangerous if they do.

### Restart + backoff

Exponential, 1s doubling to 30s max. Resets after process stays up longer than current backoff. Cap with `max_restarts` to avoid silent failure loops.

### merge-port auto-injection

When `merge:` is present, proc-compose:
1. Spawns a `merge-port` process automatically (binary must be on PATH — install via `brokit install merge-port`)
2. Adds `ready_when: tcp localhost:<port>` to each upstream **only if** user didn't set one
3. Sets `depends_on: [client, server, ...]` on the injected `merge-port`
4. Auto-detects `api_prefixes` by grepping top-level routes — Express/Koa/Fastify/Hono (`app.use`, `app.get`, etc.) and Go chi/gorilla/`net/http` (`Route`, `Mount`, `Handle`, `HandleFunc`). Sub-routers and Django/Rails/Flask need explicit `api_prefixes:`
5. Injects merge URL into client env for these well-known vars when present in `.env.example`/`.env`:
   `VITE_API_BASE_URL`, `VITE_API_URL`, `VITE_SERVER_URL`, `REACT_APP_API_URL`, `REACT_APP_BASE_URL`, `REACT_APP_API_BASE_URL`, `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_API_BASE_URL`, `NUXT_PUBLIC_API_BASE`, `PUBLIC_API_URL`.
   Path suffix preserved. Explicit `env:` always wins. Override client process detection with `merge.client_process`.

Route mode for multiple backends:
```yaml
merge:
  routes:
    - /api=3001
    - /auth=3002
    - /=3000
```
Mutually exclusive with `client`/`server`/`api_prefixes`.

## Monitor TUI

`proc-compose monitor` opens a live TUI on the running daemon.

| Key | Action |
|-----|--------|
| `q` / `Ctrl+C` | Quit |
| `?` / `h` | Toggle help overlay (Esc/Space/any key dismisses) |
| `↑` / `↓` or `k` / `j` | Navigate processes |
| `Enter` | Toggle log filter for selected process |
| `a` | Show all logs (clear filter) |
| `PgUp` / `PgDn` | Scroll log area |
| `G` | Jump to live tail |
| `g` | Jump to top of buffer |

Header line: `ready N/M  tasks N done  failed N  restarting N`. Completed tasks stay visible as `✓ completed` with readiness `done`. `NO_COLOR=1` or `--no-color` strips ANSI in both runner and monitor.

## `status --json` shape

Per-process fields include `mode` (service/task), `ready` (true only when `ready_when` passed, not merely started), restart count, uptime, status (`running`/`restarting`/`failed`/`completed`). Use `ready` to distinguish "process started" from "process serving traffic" in CI scripts. Tasks show `completed` once exit 0; non-zero → `failed`.

## Daemon files

Per-config-path, hashed:

```
$XDG_RUNTIME_DIR/pc-<hash>.sock   # IPC (status/monitor/restart/reload/stop)
$XDG_RUNTIME_DIR/pc-<hash>.pid
$XDG_RUNTIME_DIR/pc-<hash>.log    # default; absent if --log-file used
```

Falls back to `$TMPDIR` if `XDG_RUNTIME_DIR` unset. `proc-compose logs` reads the default `.log`; if user passed `--log-file PATH`, read `PATH` directly — `logs` reports "no log file found".

## Logging

```sh
proc-compose up --log-format json              # structured logs for aggregators
proc-compose up --no-color                     # strip ANSI (also: NO_COLOR=1)
proc-compose up --silent --log-file app.log \
  --max-log-size 52428800                      # rotate at 50 MB, keeps 3 rotated files
```

`--log-format json` emits structured per-line events — preferred for Railway/Render/Fly log dashboards. `--max-log-size` only applies with `--log-file`; rotation keeps up to 3 historical files.

## Common patterns

### Daemonize + wait for ready (CI / entrypoint)

```sh
proc-compose up --silent --log-file app.log \
  --wait-ready --wait-timeout 60
```

Without `--wait-ready`, `--silent` returns once socket binds — processes may still be starting. With it, blocks until every probe passes and every task completes. Non-zero exit on failure → script-friendly.

### Container entrypoint

```sh
proc-compose up --silent \
  --log-format json \
  --no-color \
  --wait-ready --wait-timeout 90 \
  --health-port 8081
```

`/health` on `:8081` returns 200 only when all managed processes are running. Platform routes traffic when probe passes. Cloud platforms set `$PORT` → proc-compose passes it to merge proxy if `merge.port` is unset.

### Survive reboot (Linux user systemd)

```sh
proc-compose up --survive --name myapp --install
proc-compose up --survive --name myapp --install --force  # overwrite existing unit
proc-compose uninstall --name myapp                       # clean removal
```

Writes/enables `~/.config/systemd/user/proc-compose-myapp.service`. `uninstall` disables and removes. Not on Windows.

### Public tunnel

`tunnel` binary spawns a background daemon (unix socket in `$TMPDIR`); the foreground command is a client attached to it. If proc-compose kills only the client, the daemon keeps running and the public URL stays open. Wrap with `trap` so SIGTERM stops the daemon too:

```yaml
merge:
  client: 5173
  server: 3001
  port: 8080

processes:
  frontend:
    cmd: npm run dev
    dir: ./frontend
    env: { PORT: "5173" }
  backend:
    cmd: go run .
    dir: ./backend
    env: { PORT: "3001" }
  tunnel:
    cmd: bash -c 'trap "tunnel stop --name myapp" EXIT TERM INT; tunnel http 8080 --name myapp; wait'
    depends_on: [merge-port]
    restart: on-failure
    ready_when:
      http: http://localhost:8080/health   # probe upstream, not tunnel
```

Anatomy of the wrapper:
- `trap "tunnel stop --name myapp" EXIT TERM INT` — runs on shutdown, kills the daemon + cleans socket. Without it, `proc-compose stop` / Ctrl+C leaves the URL exposed.
- `tunnel http 8080 --name myapp` — foreground client. `--name` gives a stable public URL across restarts.
- `; wait` — bash needs an active wait to receive SIGTERM and fire the trap. Drop it and signals get missed.

`ready_when` should probe the **upstream** the tunnel fronts (merge-port at 8080 here), not the tunnel itself. Dependents then wait for actual reachability, not just tunnel client spawn.

**Never pass `--silent` to `tunnel`** — it daemonizes and exits immediately, proc-compose sees a crash and restart-loops.

### Multiple tunnels for multiple services

Repeat the pattern per service. Each tunnel waits on its upstream so the public URL only opens once the local service serves requests:

```yaml
processes:
  api-a:
    cmd: npm run dev
    dir: ./service-a
    env: { PORT: "7001" }
    ready_when: { http: http://localhost:7001/health }
    restart: on-failure
  api-b:
    cmd: npm run dev
    dir: ./service-b
    env: { PORT: "7002" }
    ready_when: { http: http://localhost:7002/health }
    restart: on-failure
  api-a-tunnel:
    cmd: bash -c 'trap "tunnel stop --name api-a" EXIT TERM INT; tunnel http 7001 --name api-a; wait'
    depends_on: [api-a]
    restart: on-failure
    ready_when: { http: http://localhost:7001/health }
  api-b-tunnel:
    cmd: bash -c 'trap "tunnel stop --name api-b" EXIT TERM INT; tunnel http 7002 --name api-b; wait'
    depends_on: [api-b]
    restart: on-failure
    ready_when: { http: http://localhost:7002/health }
```

### Verify clean tunnel shutdown

After `proc-compose stop`, no daemon should remain:

```sh
proc-compose stop
ls /tmp/tunnel-*.sock 2>/dev/null         # should be empty
ps aux | grep "tunnel http" | grep -v grep  # should be empty
```

If sockets or processes linger, the `trap` didn't fire — usually because `wait` is missing or `--silent` was passed.

## Environment

| Var | Effect |
|-----|--------|
| `NO_COLOR` | Disables ANSI in runner + monitor (any non-empty) |
| `PORT` | Used as `merge.port` if unset (cloud platforms) |
| `XDG_RUNTIME_DIR` | Socket/PID/log base |
| `PROC_COMPOSE_INSTALL_DIR` | `install.sh` override (default `~/.local/bin`) |
| `PROC_COMPOSE_VERSION` | `install.sh` version pin |

System env propagates to children. `env_file` merged first, `env:` block overrides.

## Gotchas

- `-v` on `up` is `--verbose`, not `--version`. Use `--version` explicitly.
- Config discovery walks parent dirs — `up` from a monorepo subdir uses repo-level config. Use `-f` to pin.
- `reload` only handles modified processes (changed `cmd`/`env`/`dir`/etc.). Add/remove a process → reports `partial`, restart the daemon.
- Tasks can't be dependencies via `ready_when` — they're "ready" only on exit 0. Non-zero task exit fails the whole stack.
- Auto-detected `api_prefixes` only catch top-level handlers. Sub-router files miss → set `api_prefixes:` explicitly.
- Merge URL env injection reads `.env.example` (or `.env`) of the client process. If neither exists or var name isn't in the well-known list, set `env:` on the client manually.
- `shutdown_timeout` default is `5`s — override per-process for slow shutdowns (DB flush, graceful drain).
- `--max-log-size` requires `--log-file`. Without `--log-file`, log lives in `$XDG_RUNTIME_DIR/pc-<hash>.log` and does not auto-rotate.
- Windows: no graceful stop (always `taskkill /T /F`, `stop --timeout` ignored), no `--survive`, shell syntax is `cmd /c` (Unix `$VAR`/`./path` may break).
- `--silent` requires ≥1 service. Task-only stack → daemon refuses, run foreground.

## Writing a config — decision flow

1. List processes. For each: long-running (service) or one-shot (task)?
2. Set `cmd` + `dir`. Use `env_file` for secrets, `env:` for overrides.
3. Order: which processes need others up first? Add `depends_on`. Add `ready_when` on dependencies so dependents wait for actual readiness, not just process start.
4. Restart policy: dev servers `never` (let user see crashes). Backends `on-failure`. Workers `always`. Tasks must be `never`.
5. If frontend+backend on separate ports and user wants one URL → add `merge:` block. Don't manually wire `merge-port` as a process.
6. `proc-compose validate` → `proc-compose up --dry-run` to list processes without starting → `proc-compose up`.

## Verifying

Before claiming a config works:
```sh
proc-compose validate              # parse
proc-compose list                  # confirm processes resolved
proc-compose up --dry-run          # list resolved processes with deps
proc-compose up                    # actually run, watch readiness
proc-compose status --json | jq    # confirm ready: true for all
```

For daemonized stacks: `--wait-ready --wait-timeout N` returns non-zero if anything fails to come up — script-friendly.
