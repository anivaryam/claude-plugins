---
description: Install or update the proc-compose binary. Prefers brokit, falls back to upstream install.sh.
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-binary.sh"`.

This installs the latest proc-compose release. It uses brokit if available (recommended — handles install, update, and uninstall for the whole anivaryam tool family in one command), otherwise it fetches the upstream `install.sh` from the proc-compose repo's main branch.

Before running, confirm the user actually wants to install or upgrade. If `proc-compose --version` already prints a version, this command will replace it with the latest — make sure that's the intent.

After running, verify with `proc-compose --version` and report the installed version. If `~/.local/bin` is the install target and isn't on PATH, surface the export line.
