---
description: Diagnose proc-compose setup. Scans project layout or audits an existing config.
argument-hint: "[--write] [--json]"
allowed-tools: Bash
---

Run `proc-compose doctor $ARGUMENTS` in the current working directory.

Without a config, `doctor` proposes one based on detected Node/Go/Python project layouts. With a config, it audits paths, env files, port conflicts, readiness gaps, restart loops, merge-port setup, and likely-missing binaries.

When `--write` is passed and no `proc-compose.yml`/`proc-compose.yaml` exists, doctor creates the file. Do not pass `--write` if a config already exists — it refuses to overwrite anyway, but the dry-run output is more useful in that case.

After running, summarise findings grouped by severity (error / warning / info) with file:line evidence where available, and suggest the next action: edit the config, install a missing binary (e.g. `brokit install merge-port`), or run `proc-compose validate` / `up --dry-run`.
