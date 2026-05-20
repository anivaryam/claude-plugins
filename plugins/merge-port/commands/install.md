---
description: Install or update the merge-port binary. Prefers brokit, falls back to upstream install.sh.
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-binary.sh"`.

Installs the latest merge-port release via brokit (recommended) or the upstream `install.sh` from main. Confirm with the user before replacing an existing install (`merge-port --version` to check).

After running, verify with `merge-port --version`. If `~/.local/bin` is the target and isn't on PATH, surface the export line.
