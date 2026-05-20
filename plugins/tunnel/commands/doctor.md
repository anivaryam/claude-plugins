---
description: Validate tunnel config, file permissions, server URL parse, relay reachability, and auth token.
allowed-tools: Bash
---

Run `tunnel doctor`.

This walks the config file, file permissions, server URL parse, relay reachability (`GET /health`), and auth token presence. Each step prints a colored ✓/!/✗ marker.

After running, if any step failed:
- Bad URL → recommend `tunnel config set-server <url>` (validates scheme + host).
- Relay unreachable → check DNS, firewall, relay deployment status. Try `curl -sfI <server>/health` directly.
- Token missing → `tunnel config set-token <tok>`.
- Permissions wrong → re-saving the config (`tunnel config set-token <same-value>`) tightens to `0600` automatically.

If everything passes, the next step is `tunnel http <port>` (or `tcp`/`udp`).
