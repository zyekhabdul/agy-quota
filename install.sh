#!/usr/bin/env bash
# Standalone 1-line installer for agy-quota
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"

echo "==> Installing agy-quota to $INSTALL_DIR/agy-quota..."
curl -fsSL https://raw.githubusercontent.com/zyekhabdul/agy-quota/main/bin/agy-quota -o "$INSTALL_DIR/agy-quota"
chmod +x "$INSTALL_DIR/agy-quota"
ln -sf "$INSTALL_DIR/agy-quota" "$INSTALL_DIR/agy-tokens"

echo "==> Checking Python dependencies..."
if ! python3 -c "import rich, cryptography" >/dev/null 2>&1; then
    echo "[ NOTE ] Optional packages 'rich' and 'cryptography' enhance table UI and encryption."
    echo "Install via: pip install rich cryptography"
fi

echo "==> Installation complete! Run 'agy-quota' or 'agy-tokens'."
