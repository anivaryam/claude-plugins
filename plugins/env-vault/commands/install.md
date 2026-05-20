---
description: Install or update the env-vault binary. Prefers brokit, then npm, then release tarball.
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-binary.sh"`.

Installs the latest env-vault. Order: brokit (recommended for cross-tool management) → npm (`npm install -g env-vault`) → platform-matched release tarball into `~/.local/bin`.

After running, verify with `env-vault --help`. If the install used the tarball fallback and `~/.local/bin` isn't on PATH, surface the export line.
