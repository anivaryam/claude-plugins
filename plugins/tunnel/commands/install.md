---
description: Install or update the tunnel binary. Prefers brokit (daemon mode + cosign-verified), falls back to upstream install.sh.
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-binary.sh"`.

Installs the latest tunnel release. brokit is recommended because it includes daemon mode (`--silent`, `tunnel daemon ...`) and verifies releases via cosign. The fallback `install.sh` from main verifies sha256 against `checksums.txt` but skips cosign attestation by default — see the tunnel README if full attestation is required.

After running, verify with `tunnel --version` and `tunnel doctor`. The doctor check confirms the configured relay is reachable.
