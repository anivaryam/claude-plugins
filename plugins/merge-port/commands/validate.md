---
description: Validate merge-port routing — route syntax, listen-port availability, upstream TCP reachability. Non-binding.
argument-hint: "[--client PORT --server PORT | --route /prefix=PORT ...] [--port LISTEN]"
allowed-tools: Bash
---

Run `merge-port validate $ARGUMENTS`.

This is a point-in-time check — it confirms the routing config parses, the listen port is currently free, and each upstream accepts TCP connections. Another process can still bind the listen port between validate and start, and an upstream that responds to TCP may still be unhealthy at HTTP layer.

After running, report each check (route syntax, listen port, each upstream) with pass/fail. If any upstream is unreachable, suggest the user start it before invoking `merge-port`. If the listen port is in use, identify the holder with `lsof -i :<port>` or `ss -ltnp 'sport = :<port>'` and surface the result.
