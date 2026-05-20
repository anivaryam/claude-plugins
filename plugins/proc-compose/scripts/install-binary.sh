#!/usr/bin/env bash
# Install or update the proc-compose binary.
# Strategy: prefer brokit (cross-tool installer), fall back to the upstream
# install.sh which fetches the matching release binary into ~/.local/bin.

set -euo pipefail

TOOL="proc-compose"
REPO="anivaryam/proc-compose"

if command -v brokit >/dev/null 2>&1; then
  echo "→ Installing $TOOL via brokit (always latest, verified)..."
  exec brokit install "$TOOL"
fi

cat <<MSG
→ brokit not found on PATH. Falling back to upstream install.sh.
  brokit is the recommended path — it handles install, update, and uninstall
  for the entire anivaryam tool family in one command. Install it from:
    https://github.com/anivaryam/brokit
  Then re-run this command for one-step upgrades.

→ Fetching install.sh from $REPO@main...
MSG

INSTALL_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"
curl -fsSL "$INSTALL_URL" | bash

echo "→ Done. Verify with: $TOOL --version"
