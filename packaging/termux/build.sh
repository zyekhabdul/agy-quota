# Termux package definition for agy-quota
TERMUX_PKG_HOMEPAGE=https://github.com/zyekhabdul/agy-quota
TERMUX_PKG_DESCRIPTION="Antigravity Multi-Account Token, Quota & Tier Bulk Checker"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="zyekhabdul <zyekhabdulqadirjailani@gmail.com>"
TERMUX_PKG_VERSION=1.2.0
TERMUX_PKG_SRCURL=https://github.com/zyekhabdul/agy-quota/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=SKIP
TERMUX_PKG_DEPENDS="python, python-cryptography"
TERMUX_PKG_PLATFORM_INDEPENDENT=true
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_make_install() {
    pip install . --prefix="$TERMUX_PREFIX" --no-deps
}

termux_step_post_massage() {
    ln -sf agy-quota "$TERMUX_PREFIX/bin/agy-tokens"
}
