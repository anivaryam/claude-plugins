---
name: proc-compose
description: Use when orchestrating multiple local processes for a dev stack or single-container deploy — frontend+backend, microservices, ordered startup, prestart tasks, public tunnels. Triggers on `proc-compose.yml`/`proc-compose.yaml` files, `proc-compose` CLI invocations, "start the stack", "run everything together", "merge frontend and backend on one port", combined dev server requests, or container entrypoints that need to run more than one command. Covers config authoring, lifecycle (up/monitor/status/restart/reload/stop), readiness probes, dependencies, daemon paths, and cloud deploy patterns. Source: github.com/anivaryam/proc-compose.
---

# proc-compose

Local process orchestrator. One YAML, one lifecycle, one log stream. Not Docker — no containers, no images, just `sh -c` with supervision.

Repo: `github.com/anivaryam/proc-compose`. Binary: `proc-compose` (installed via `brokit install proc-compose`, `~/.local/bin/`, or `go install`).

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
```

`bootstrap` builds on `doctor`. Scans Node/Go/Python layouts, detects npm/yarn/pnpm/bun runners, Vite/Next/SvelteKit/Astro, Go `cmd/**/main.go`, Django/Flask/Uvicorn/Hypercorn. Refuses to overwrite without `--force`. Always read the dry-run output before `--write` — it's the cheapest review.

`proc-compose init --template node|go|python|minimal` is an alternative when you want a hand-edit starting point instead of detection.

### Existing project

```sh
proc-compose validate           # parse-only, catches unknown fields / bad restart / cycles
proc-compose up                 # foreground, Ctrl+C stops all
proc-compose up frontend backend  # subset
proc-compose up --silent --log-file app.log  # daemonize
proc-compose monitor            # TUI on running daemon
proc-compose status             # one-shot snapshot
proc-compose status --json      # scriptable
proc-compose logs -n 200        # tail default log
proc-compose restart backend    # one process
proc-compose reload             # re-read config, restart changed defs
proc-compose stop               # SIGTERM, 10s grace, then SIGKILL
proc-compose stop --force       # SIGKILL now
```

`doctor` (no args) diagnoses an existing config — port conflicts, restart loops, missing binaries, readiness gaps, merge-port wiring.

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
    shutdown_timeout: 30        # seconds before SIGKILL
    ready_when:
      http: http://localhost:3000/health
      # or: tcp: localhost:5432
      # or: log: "ready regex"
    ready_timeout: 60           # -1 = no limit
    depends_on: [other]
```

### service vs task

- **service**: long-running. Ready when started OR `ready_when` passes. Restart policies apply.
- **task**: one-shot (migrations, codegen, seeds). Ready = exit 0. Must be `restart: never`. No `ready_when`/`ready_timeout`/`max_restarts`. Non-zero exit fails the stack.
- Task-only stacks **cannot daemonize** (`--silent` refuses) — nothing to manage after they exit.

### Readiness

Pick the cheapest signal that actually proves the process serves traffic:
- `http`: GET returns 2xx
- `tcp`: connect succeeds (good for DBs)
- `log`: regex matches stdout (good for opaque servers)

Probes poll every 3s. Default deadline 60s. Without `ready_when`, a service is "ready" the moment it starts — fine for dependents that don't actually need it up yet, dangerous if they do.

### Restart + backoff

Exponential, 1s doubling to 30s max. Resets after the process stays up longer than current backoff. Cap with `max_restarts` to avoid silent failure loops.

### merge-port auto-injection

When `merge:` is present, proc-compose:
1. Spawns a `merge-port` process automatically (binary must be on PATH — install via `brokit install merge-port`)
2. Adds `ready_when: tcp localhost:<port>` to each upstream **only if** the user didn't set one
3. Sets `depends_on: [client, server, ...]` on the injected `merge-port`
4. Auto-detects `api_prefixes` by grepping top-level routes (Express/Koa/Fastify/Hono/Go chi/gorilla). Sub-routers and Django/Rails/Flask need explicit `api_prefixes:`
5. Injects merge URL into client env for known vars: `VITE_API_*`, `REACT_APP_*`, `NEXT_PUBLIC_API_*`, `NUXT_PUBLIC_API_BASE`, `PUBLIC_API_URL`. Path suffix preserved. Explicit `env:` always wins. Override client process detection with `merge.client_process`.

Route mode for multiple backends:
```yaml
merge:
  routes:
    - /api=3001
    - /auth=3002
    - /=3000
```
Mutually exclusive with `client`/`server`/`api_prefixes`.

## Daemon files

Per-config-path, hashed:

```
$XDG_RUNTIME_DIR/pc-<hash>.sock   # IPC (status/monitor/restart/reload/stop)
$XDG_RUNTIME_DIR/pc-<hash>.pid
$XDG_RUNTIME_DIR/pc-<hash>.log    # default; absent if --log-file used
```

Falls back to `$TMPDIR` if `XDG_RUNTIME_DIR` unset. `proc-compose logs` reads the default `.log`; if user passed `--log-file PATH`, read `PATH` directly — `logs` will report "no log file found".

## Common patterns

### Daemonize + wait for ready (CI / entrypoint)

```sh
proc-compose up --silent --log-file app.log \
  --wait-ready --wait-timeout 60
```

Without `--wait-ready`, `--silent` returns once the socket binds — processes may still be starting. With it, blocks until every probe passes.

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
```

Writes/enables `~/.config/systemd/user/proc-compose-myapp.service`. Not on Windows.

### Public tunnel

`tunnel` binary spawns a background daemon; foreground command is a client. If proc-compose kills the client, the daemon leaks. Wrap with `trap`:

```yaml
tunnel:
  cmd: bash -c 'trap "tunnel stop --name myapp" EXIT TERM INT; tunnel http 8080 --name myapp; wait'
  depends_on: [merge-port]
  restart: on-failure
```

**Never pass `--silent` to `tunnel`** — it daemonizes and exits immediately, proc-compose sees a crash and restart-loops.

## Environment

| Var | Effect |
|-----|--------|
| `NO_COLOR` | Disables ANSI in runner + monitor (any non-empty) |
| `PORT` | Used as `merge.port` if unset (cloud platforms) |
| `XDG_RUNTIME_DIR` | Socket/PID/log base |

System env propagates to children. `env_file` merged first, `env:` block overrides.

## Gotchas

- `-v` on `up` is `--verbose`, not `--version`. Use `--version` explicitly.
- Config discovery walks parent dirs — `up` from a monorepo subdir uses repo-level config. Use `-f` to pin.
- `reload` only handles modified processes. Add/remove a process → reports `partial`, restart the daemon.
- Tasks can't be dependencies via `ready_when` — they're "ready" only on exit 0. A non-zero task exit fails the whole stack.
- Auto-detected `api_prefixes` only catch top-level handlers. Sub-router files miss → set `api_prefixes:` explicitly.
- Merge URL env injection reads `.env.example` (or `.env`) of the client process. If neither exists or var name isn't in the well-known list, set `env:` on the client manually.
- Windows: no graceful stop (always `taskkill /T /F`), no `--survive`, shell syntax is `cmd /c` (Unix `$VAR`/`./path` may break).
- `--silent` requires ≥1 service. Task-only stack → daemon refuses, run foreground.

## Writing a config — decision flow

1. List processes. For each: is it long-running (service) or one-shot (task)?
2. Set `cmd` + `dir`. Use `env_file` for secrets, `env:` for overrides.
3. Order: which processes need others up first? Add `depends_on`. Add `ready_when` on dependencies so dependents wait for actual readiness, not just process start.
4. Restart policy: dev servers `never` (let user see crashes). Backends `on-failure`. Workers `always`. Tasks must be `never`.
5. If frontend+backend on separate ports and user wants one URL → add `merge:` block. Don't manually wire `merge-port` as a process.
6. `proc-compose validate` → `proc-compose up --dry-run` to list processes without starting → `proc-compose up`.

## Verifying

Before claiming a config works:
```sh
proc-compose validate              # parse
proc-compose up --dry-run          # list resolved processes
proc-compose up                    # actually run, watch readiness
proc-compose status --json | jq    # confirm ready: true for all
```

For daemonized stacks: `--wait-ready --wait-timeout N` returns non-zero if anything fails to come up — script-friendly.
