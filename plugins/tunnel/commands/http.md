---
description: Expose a local HTTP port through the configured relay. Pass --name for a stable URL.
argument-hint: "<port> [--name X] [--inspect] [--silent]"
allowed-tools: Bash
---

Run `tunnel http $ARGUMENTS`.

Before running:
1. Verify config exists at `~/.tunnel/config.yml` (or run `tunnel config show`). If absent, walk the user through `tunnel config set-server` / `set-token` first.
2. Run `tunnel doctor` if this is the first invocation in the session — it catches bad URLs, unreachable relays, and missing tokens cheaply.
3. If `--silent` is in args **and** the tunnel will be started inside a proc-compose stack, abort and explain — `--silent` daemonizes and exits, which proc-compose treats as a crash. Use the `trap` foreground pattern instead.
4. If `--name` is in args, confirm it satisfies `[a-z0-9-]{1,32}` (no leading/trailing hyphen) and isn't in the relay's reserved-name list (`dashboard`, `metrics`, `mail`, `login`, `app`, `docs`, `status`, `staging`, `prod`, etc.).

After running, print the public URL, confirm it's reachable with `curl -sf <url>`, and if `--silent` was used, verify with `tunnel daemon status --name <name>` (or `--port N --mode http` if no name was given).
