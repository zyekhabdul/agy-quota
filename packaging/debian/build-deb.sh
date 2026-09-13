#!/usr/bin/env bash
set -euo pipefail

PKG_NAME="agy-quota"
PKG_VER="1.2.0"
PKG_ARCH="all"
DIST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$DIST_DIR/build_deb/${PKG_NAME}_${PKG_VER}_${PKG_ARCH}"

echo "==> Building Debian (.deb) package for $PKG_NAME v$PKG_VER..."
rm -rf "$DIST_DIR/build_deb"
mkdir -p "$WORK_DIR/DEBIAN"
mkdir -p "$WORK_DIR/usr/bin"
mkdir -p "$WORK_DIR/usr/share/doc/$PKG_NAME"

cat << 'EOF' > "$WORK_DIR/DEBIAN/control"
Package: agy-quota
Version: 1.2.0
Section: utils
Priority: optional
Architecture: all
Depends: python3 (>= 3.8), python3-cryptography, python3-rich
Maintainer: zyekhabdul <zyekhabdulqadirjailani@gmail.com>
Description: Antigravity Multi-Account Token, Quota & Tier Bulk Checker
 Lightweight, ultra-fast CLI tool to check quotas, token balances, and tier
 statuses across multiple Google Antigravity accounts.
 Includes alias: agy-tokens.
EOF

PROJECT_ROOT="$(cd "$DIST_DIR/../.." && pwd)"
cp "$PROJECT_ROOT/bin/agy-quota" "$WORK_DIR/usr/bin/agy-quota"
chmod 755 "$WORK_DIR/usr/bin/agy-quota"
ln -sf agy-quota "$WORK_DIR/usr/bin/agy-tokens"

cp "$PROJECT_ROOT/README.md" "$WORK_DIR/usr/share/doc/$PKG_NAME/"
cp "$PROJECT_ROOT/LICENSE" "$WORK_DIR/usr/share/doc/$PKG_NAME/copyright"

dpkg-deb --build --root-owner-group "$WORK_DIR" "$DIST_DIR/${PKG_NAME}_${PKG_VER}_${PKG_ARCH}.deb"
rm -rf "$DIST_DIR/build_deb"

echo "==> Done! Created: $DIST_DIR/${PKG_NAME}_${PKG_VER}_${PKG_ARCH}.deb"
