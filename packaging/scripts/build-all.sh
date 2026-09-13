#!/usr/bin/env bash
set -euo pipefail

# agy-quota Multi-Platform Packaging Master Runner
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=================================================="
echo "agy-quota Multi-Platform Packaging Orchestrator"
echo "=================================================="

# 1. Python Wheel & Sdist
echo ""
echo "[ 1/3 ] Building Python Wheel & Sdist..."
cd "$ROOT_DIR"
python3 -m build --wheel --sdist

# 2. Debian / Ubuntu .deb
echo ""
echo "[ 2/3 ] Building Debian (.deb) Package..."
bash "$ROOT_DIR/packaging/debian/build-deb.sh"

# 3. Syntax tests
echo ""
echo "[ 3/3 ] Running deterministic syntax verification..."
python3 -m py_compile "$ROOT_DIR/bin/agy-quota"
"$ROOT_DIR/bin/agy-quota" --help >/dev/null

echo ""
echo "=================================================="
echo "ALL PACKAGES SUCCESSFULLY VERIFIED & BUILT:"
echo "=================================================="
ls -lh "$ROOT_DIR/dist"/*.whl "$ROOT_DIR/dist"/*.tar.gz
ls -lh "$ROOT_DIR/packaging/debian"/*.deb
echo "=================================================="
