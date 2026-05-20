---
description: Enumerate active tunnels via the relay's dashboard API.
argument-hint: "[--json]"
allowed-tools: Bash
---

Run `tunnel list $ARGUMENTS`.

Without `--json`, this prints a human table of active tunnels (name/id, mode, target port, public URL). With `--json`, the same data is emitted as machine-readable JSON.

If the list is empty but the user expected a tunnel to be running:
1. Check `tunnel daemon status --name <X>` (or `--port N --mode http`) — a daemon may have crashed.
2. Inspect the daemon log file printed at start, or check `$XDG_RUNTIME_DIR/tunnel/tunnel-*.log`.
3. Re-run `tunnel doctor` to confirm the relay is still reachable and the token is still valid.
