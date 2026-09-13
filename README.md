# agy-quota

Antigravity Multi-Account Token, Quota & Tier Bulk Checker.

---

## Overview

`agy-quota` (alias `agy-tokens`) is a high-performance CLI utility designed to inspect, monitor, and manage quotas, token balances, and tier statuses across multiple Google Antigravity (AGY) accounts.

It queries Google Cloud Code internal endpoints concurrently to provide an immediate bird's-eye view of account health, rate limits, tier levels (Free, Standard, Pro, Ultra, Enterprise), and reset windows.

## Key Features

- **Concurrent Bulk Checking**: Evaluates all configured Google accounts in parallel via a multi-threaded worker pool.
- **Rich Terminal Interface**: Renders clean, color-coded tables showing Account Email, Display Name, Tier, and Reset Timers.
- **Single-Account Deep Inspection**: `--detail` / `-d` provides granular per-model quotas (Gemini 2.0 Flash, Gemini 1.5 Pro, Claude Sonnet, etc.).
- **Zero-Downtime Account Switching**: Switch your active Antigravity CLI token to any configured account with `agy-quota -s <index>`.
- **Token Exporter**: Export fresh OAuth Bearer access tokens on-demand (`agy-quota -e <index>`) for automation scripts and curl commands.
- **Remote SSH Account Pooling**: Synchronize account pools from remote proxy servers or VPS hosts (`agy-quota --sync`).
- **Continuous Watch Mode**: Monitor token replenishment live with customizable refresh intervals (`agy-quota -w 15`).
- **Encrypted Local Storage**: Encrypts offline session credentials locally using AES-256-GCM (`~/.gemini/antigravity-cli/account-token.key`).

## Requirements

- Python >= 3.8
- `cryptography` (for AES-256-GCM local token encryption/decryption)
- `rich` (for terminal formatting, tables, and progress bars)

*Note: If `rich` or `cryptography` are not available, agy-quota automatically falls back to plain text formatting and standard unencrypted token storage.*

### Option 1: Official Python Package (PyPI / pip)

```bash
pip install agy-quota
# Or install locally from built wheel:
pip install dist/agy_quota-1.2.0-py3-none-any.whl
```

### Option 2: 1-Line Standalone Installer (Linux / macOS / Termux)

```bash
curl -fsSL https://raw.githubusercontent.com/zyekhabdul/agy-quota/main/install.sh | bash
```

### Option 3: Arch Linux (AUR & PKGBUILD)

```bash
# Using an AUR helper:
yay -S agy-quota-git
# or paru -S agy-quota-git

# Manual PKGBUILD build:
git clone https://github.com/zyekhabdul/agy-quota.git
cd agy-quota/packaging/aur-git
makepkg -si
```

### Option 4: Debian / Ubuntu (.deb)

```bash
# Build locally:
bash packaging/debian/build-deb.sh
sudo dpkg -i packaging/debian/agy-quota_1.2.0_all.deb
```

### Option 5: macOS / Linux Homebrew

```bash
brew install zyekhabdul/tap/agy-quota
# Or install directly from formula:
brew install packaging/homebrew/agy-quota.rb
```

### Option 6: Termux (Android)

```bash
curl -fsSL https://raw.githubusercontent.com/zyekhabdul/agy-quota/main/packaging/termux/build.sh | bash
```

### Option 7: Using Makefile

```bash
git clone https://github.com/zyekhabdul/agy-quota.git
cd agy-quota
make install
```
*Installs by default to `~/.local/bin/agy-quota` and creates a symlink alias `agy-tokens`.*

## Usage

### 1. Basic Bulk Overview
Check quota status across all accounts:
```bash
agy-quota
```

### 2. Fast Cached Inspection
View cached metadata instantly without making outbound network calls:
```bash
agy-quota -c
```

### 3. Detailed Model Breakdown
View exhaustive per-model quota limits and replenishment times:
```bash
# Detail for all accounts
agy-quota -d

# Detail for a specific account email or username keyword
agy-quota -d myemail@gmail.com
```

### 4. Switch Active CLI Account
Switch the active `antigravity` CLI token on your local system:
```bash
agy-quota -s 2
```

### 5. Export Fresh Access Token
Print a fresh Bearer access token for scripting:
```bash
TOKEN=$(agy-quota -e 1)
curl -H "Authorization: Bearer $TOKEN" https://daily-cloudcode-pa.googleapis.com/...
```

### 6. Synchronize Pool from Remote Server
Fetch and import accounts from a remote gateway over SSH:
```bash
agy-quota --sync servv
```

### 7. Add / Login New Account
Authenticate a new Google account via OAuth in your default browser:
```bash
agy-quota --add
```

## Configuration & Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `AGY_CLIENT_ID` | Embedded Default | Custom Google OAuth Desktop Client ID |
| `AGY_CLIENT_SECRET` | Embedded Default | Custom Google OAuth Desktop Client Secret |
| `AGY_REMOTE_AUTH_DIR` | `~/Projects/cli-proxy-api/auth` | Remote directory path used for `--sync` |

## Security & Privacy Architecture

- **Zero-Knowledge OAuth**: Uses standard Google OAuth authorization codes. Plaintext passwords are never handled, captured, or transmitted.
- **Local AES-256-GCM Encryption**: Account session tokens stored on disk are encrypted using a local AES-256 key with unique 96-bit nonces.
- **Sanitized Remote Sync**: Sync operations pull structured JSON tokens over secure SSH connections only.

## Disclaimer

This software is for personal productivity, workflow management, and research purposes. It is not officially affiliated with, endorsed by, or sponsored by Google LLC.

## License

MIT License. Copyright (c) 2026 Zyekh Abdul (zyekhabdul).
