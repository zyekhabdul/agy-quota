#!/usr/bin/env bash
# Standalone 1-line installer for agy-quota
set -euo pipefail

# Auto-detect Termux environment ($PREFIX/bin) vs standard Linux/macOS ($HOME/.local/bin)
if [ -n "${PREFIX:-}" ] && [ -d "${PREFIX}/bin" ]; then
    DEFAULT_DIR="${PREFIX}/bin"
    IS_TERMUX=1
else
    DEFAULT_DIR="$HOME/.local/bin"
    IS_TERMUX=0
fi

INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"
mkdir -p "$INSTALL_DIR"

echo "==> Installing agy-quota to $INSTALL_DIR/agy-quota..."
curl -fsSL https://raw.githubusercontent.com/zyekhabdul/agy-quota/main/bin/agy-quota -o "$INSTALL_DIR/agy-quota"
chmod +x "$INSTALL_DIR/agy-quota"
ln -sf "$INSTALL_DIR/agy-quota" "$INSTALL_DIR/agy-tokens"

echo "==> Checking Python dependencies..."
if ! python3 -c "import rich, cryptography" >/dev/null 2>&1; then
    if [ "$IS_TERMUX" -eq 1 ]; then
        echo "[ NOTE ] Installing python-cryptography via pkg in Termux..."
        pkg install -y python python-cryptography
        pip install rich || true
    else
        echo "[ NOTE ] Optional packages 'rich' and 'cryptography' enhance table UI and encryption."
        echo "Install via: pip install rich cryptography"
    fi
fi

echo "==> Installation complete! Run 'agy-quota' or 'agy-tokens'."
