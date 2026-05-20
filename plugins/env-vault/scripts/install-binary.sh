#!/usr/bin/env bash
# Install or update the env-vault binary.
# Strategy: prefer brokit (cross-tool installer), fall back to the upstream
# install.sh which fetches the platform-matched release tarball.

set -euo pipefail

TOOL="env-vault"
REPO="anivaryam/env-vault"

if command -v brokit >/dev/null 2>&1; then
  echo "→ Installing $TOOL via brokit (always latest, verified)..."
  exec brokit install "$TOOL"
fi

cat <<MSG
→ brokit not found on PATH. Falling back to upstream install.sh.
  Recommended path is brokit — handles install, update, and uninstall for
  the entire anivaryam tool family. See: https://github.com/anivaryam/brokit

→ Fetching install.sh from $REPO@main...
  (Drops the binary into /usr/local/bin by default. Override with
  INSTALL_DIR=~/.local/bin before re-running if /usr/local/bin needs sudo.)
MSG

INSTALL_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"
curl -fsSL "$INSTALL_URL" | sh

echo "→ Done. Verify with: $TOOL --help"
