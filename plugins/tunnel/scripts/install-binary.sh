#!/usr/bin/env bash
# Install or update the tunnel binary.
# Strategy: prefer brokit (includes daemon mode + cosign-verified releases),
# fall back to the upstream install.sh which fetches the matching release.

set -euo pipefail

TOOL="tunnel"
REPO="anivaryam/tunnel"

if command -v brokit >/dev/null 2>&1; then
  echo "→ Installing $TOOL via brokit (always latest, verified, daemon mode included)..."
  exec brokit install "$TOOL"
fi

cat <<MSG
→ brokit not found on PATH. Falling back to upstream install.sh.
  Recommended path is brokit — handles install, update, and uninstall for
  the entire anivaryam tool family. See: https://github.com/anivaryam/brokit

→ Fetching install.sh from $REPO@main...
  (Verifies sha256 against checksums.txt; cosign verification is optional —
  see the tunnel README for the cosign command if you want full attestation.)
MSG

INSTALL_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"
curl -fsSL "$INSTALL_URL" | sh

echo "→ Done. Verify with: $TOOL --version  (and: $TOOL doctor)"
