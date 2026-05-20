---
description: Start the proc-compose stack defined by the nearest proc-compose.yml. Accepts process names as args to start a subset.
argument-hint: "[process names...]"
allowed-tools: Bash
---

Run `proc-compose up $ARGUMENTS` from the current working directory.

Before running:
1. Confirm a `proc-compose.yml` or `proc-compose.yaml` exists by walking up from cwd.
2. Run `proc-compose validate` first — if it errors, surface the parse error and stop. Do not call `up` on an invalid config.
3. If the user passed process names, verify they exist via `proc-compose list`. Unknown names should be flagged before invocation.

After running, summarise which processes started, which became ready, and any readiness/restart issues from the log tail.
