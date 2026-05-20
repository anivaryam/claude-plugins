---
description: Start merge-port. With no args, uses .merge-port.yaml in cwd. Pass --client/--server or --route flags to override.
argument-hint: "[--client PORT --server PORT | --route /prefix=PORT ...] [--port LISTEN]"
allowed-tools: Bash
---

Run `merge-port $ARGUMENTS` from the current working directory.

Before running:
1. If no args were passed and no `.merge-port.yaml` exists in cwd or any ancestor, ask the user which mode they want (simple or route) and which ports.
2. If both `--client/--server` and `--route` are present, abort and explain they're mutually exclusive — pick one form.
3. Run `merge-port --dry-run` first (with the same args) to print the effective routing. Show that output to the user before binding the port.

After running, confirm the listen port is reachable (`curl -sf http://localhost:<port>/_health`) and that representative routes hit the expected upstream. Flag any port conflicts or upstream-unreachable errors.
