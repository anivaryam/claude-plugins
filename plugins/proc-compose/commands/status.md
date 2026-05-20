---
description: Show proc-compose daemon process states. Use --json for scriptable output.
argument-hint: "[--json]"
allowed-tools: Bash
---

Run `proc-compose status $ARGUMENTS` against the running daemon for the current config file.

If no daemon is running, the command will report that and exit non-zero — surface that result to the user and suggest `proc-compose up --silent` if they want a background daemon.

When `--json` is passed, parse the output with `jq` if available and present a compact human summary: per-process `state`, `ready`, `restarts`, and `uptime`. Flag any process whose `ready: false` after the deadline, or with `restarts > 0`.
