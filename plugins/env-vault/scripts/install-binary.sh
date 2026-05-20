#!/usr/bin/env bash
# Install or update the env-vault binary.
# Strategy: prefer brokit. Otherwise prefer npm (cross-platform), then fall
# back to fetching the platform-matched release tarball directly.

set -euo pipefail

TOOL="env-vault"
REPO="anivaryam/env-vault"

if command -v brokit >/dev/null 2>&1; then
  echo "→ Installing $TOOL via brokit (always latest, verified)..."
  exec brokit install "$TOOL"
fi

if command -v npm >/dev/null 2>&1; then
  echo "→ brokit not found. Installing $TOOL globally via npm..."
  exec npm install -g env-vault
fi

cat <<MSG
→ Neither brokit nor npm found on PATH. Falling back to release tarball.
  Recommended path is brokit — handles install, update, and uninstall for
  the entire anivaryam tool family. See: https://github.com/anivaryam/brokit
MSG

uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"
uname_m="$(uname -m)"
case "$uname_m" in
  x86_64|amd64) arch="amd64" ;;
  aarch64|arm64) arch="arm64" ;;
  *) echo "✗ Unsupported architecture: $uname_m"; exit 1 ;;
esac
case "$uname_s" in
  linux|darwin) os="$uname_s" ;;
  *) echo "✗ Unsupported OS: $uname_s. Use brokit or download from https://github.com/$REPO/releases manually."; exit 1 ;;
esac

URL="https://github.com/${REPO}/releases/latest/download/${TOOL}_${os}_${arch}.tar.gz"
DEST="${HOME}/.local/bin"
mkdir -p "$DEST"

echo "→ Downloading $URL..."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/${TOOL}.tar.gz"
tar -xzf "$TMP/${TOOL}.tar.gz" -C "$TMP"
mv "$TMP/${TOOL}" "$DEST/${TOOL}"
chmod +x "$DEST/${TOOL}"

echo "→ Installed to $DEST/${TOOL}"
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "⚠ $DEST is not on PATH. Add to ~/.bashrc:  export PATH=\"$DEST:\$PATH\"" ;;
esac
echo "→ Verify with: $TOOL --help"
