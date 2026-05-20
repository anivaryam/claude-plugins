---
description: Scan the current project and propose a proc-compose.yml. Defaults to dry-run.
argument-hint: "[--write] [--verify] [--force]"
allowed-tools: Bash
---

Run `proc-compose bootstrap $ARGUMENTS` in the current directory.

Default behaviour (no args) is read-only — proc-compose scans Node/Go/Python project layouts, detects runners, dev servers, and main entrypoints, then prints the proposed YAML. Nothing is written.

When the user asks for the file to be created, append `--write`. Refuse to add `--force` unless they have explicitly asked to overwrite an existing config — bootstrap will not clobber an existing `proc-compose.yml`/`proc-compose.yaml` without it.

Use `--verify` to round-trip the generated config through proc-compose's parser without writing.

After running, summarise the detected processes, any flagged gaps (missing binaries, port conflicts, readiness gaps, restart loops), and the recommended next step (`up`, `validate`, edit a specific field, etc.).
