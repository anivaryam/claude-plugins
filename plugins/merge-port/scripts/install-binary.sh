#!/usr/bin/env bash
# Install or update the merge-port binary.
# Strategy: prefer brokit, fall back to the upstream install.sh.

set -euo pipefail

TOOL="merge-port"
REPO="anivaryam/merge-port"

if command -v brokit >/dev/null 2>&1; then
  echo "→ Installing $TOOL via brokit (always latest, verified)..."
  exec brokit install "$TOOL"
fi

cat <<MSG
→ brokit not found on PATH. Falling back to upstream install.sh.
  Recommended path is brokit — handles install, update, and uninstall for
  the entire anivaryam tool family. See: https://github.com/anivaryam/brokit

→ Fetching install.sh from $REPO@main...
MSG

INSTALL_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"
curl -fsSL "$INSTALL_URL" | sh

echo "→ Done. Verify with: $TOOL --version"
