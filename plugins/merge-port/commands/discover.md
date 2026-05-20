---
description: Probe a running backend for OpenAPI/Swagger endpoints and suggest --api-prefix flags.
argument-hint: "--server PORT [--client PORT] [--write-config PATH] [--json]"
allowed-tools: Bash
---

Run `merge-port discover $ARGUMENTS`.

The backend must already be running on the named port — discovery hits its OpenAPI/Swagger endpoints. If discovery returns nothing, the framework probably doesn't ship OpenAPI; grep the source for top-level route registrations instead and recommend manual `api_prefixes`.

When `--write-config PATH` is passed, confirm with the user before overwriting an existing file.

After running, summarise the detected prefixes and tell the user the exact merge-port invocation (or proc-compose `merge:` block) to use them.
