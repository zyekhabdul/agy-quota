#!/usr/bin/env bash
# Termux installer script for agy-quota
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BINDIR="$PREFIX/bin"

echo "==> Installing agy-quota for Termux in $BINDIR..."
mkdir -p "$BINDIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
install -m 755 "$SCRIPT_DIR/bin/agy-quota" "$BINDIR/agy-quota"
ln -sf agy-quota "$BINDIR/agy-tokens"

echo "==> Verifying Python dependencies in Termux..."
if ! python3 -c "import rich, cryptography" >/dev/null 2>&1; then
    echo "==> Installing cryptography and rich via pip..."
    pip install cryptography rich
fi

echo "==> Success! Run 'agy-quota' or 'agy-tokens' to launch."
