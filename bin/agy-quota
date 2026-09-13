#!/usr/bin/env python3
"""
agy-quota / agy-tokens - Antigravity Multi-Account Token & Quota Bulk Checker
Lightweight, ultra-fast CLI tool to check quotas & tokens across all logged-in AGY accounts.
"""

import os
import sys
import time
import json
import glob
import base64
import argparse
import datetime
import urllib.request
import urllib.parse
import urllib.error
import ssl
from concurrent.futures import ThreadPoolExecutor

# Cryptography for Cockpit AES-GCM token decryption
try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    HAS_CRYPTO = True
except ImportError:
    HAS_CRYPTO = False

# Rich for terminal UI
try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.text import Text
    from rich.columns import Columns
    from rich.box import ROUNDED, SIMPLE
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

CLOUD_CODE_BASE = "https://daily-cloudcode-pa.googleapis.com"
CLI_DIR = os.path.expanduser("~/.gemini/antigravity-cli")
CLI_TOKEN_PATH = os.path.join(CLI_DIR, "antigravity-oauth-token")

# Native standalone storage for AGY accounts
STORAGE_DIR = CLI_DIR
KEY_PATH = os.path.join(STORAGE_DIR, "account-token.key")
ACCOUNTS_DIR = os.path.join(STORAGE_DIR, "accounts")

# Fallback legacy Cockpit dir if needed
COCKPIT_DIR = os.path.expanduser("~/.antigravity_cockpit")

# Google Cloud Code / Antigravity OAuth Desktop Credentials
# Configured via environment variables or ~/.config/agy-quota/credentials.json
def load_oauth_credentials():
    cid = os.environ.get("AGY_CLIENT_ID")
    csec = os.environ.get("AGY_CLIENT_SECRET")
    if cid and csec:
        return cid, csec

    paths = [
        os.path.expanduser("~/.config/agy-quota/credentials.json"),
        os.path.join(CLI_DIR, "oauth_client.json"),
        os.path.join(COCKPIT_DIR, "oauth_client.json"),
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    c_id = data.get("client_id")
                    c_sec = data.get("client_secret")
                    if c_id and c_sec:
                        return c_id, c_sec
            except Exception:
                pass
    return "", ""

CLIENT_ID, CLIENT_SECRET = load_oauth_credentials()

USER_AGENT = "antigravity/1.20.5 linux/amd64 google-api-nodejs-client/10.3.0"
GOOG_CLIENT = "gl-node/22.21.1"


def get_ssl_context():
    ctx = ssl.create_default_context()
    return ctx


def load_aes_key():
    if not HAS_CRYPTO:
        return None
    # Check primary storage first, then fallback to cockpit
    for p in [KEY_PATH, os.path.join(COCKPIT_DIR, "account-token.key")]:
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    key_b64 = f.read().strip()
                return base64.b64decode(key_b64)
            except Exception:
                continue
    return None


def decrypt_cockpit_token(aes_key, enc_obj):
    if not aes_key or not HAS_CRYPTO or not enc_obj:
        return None
    try:
        nonce = base64.b64decode(enc_obj["nonce"])
        ciphertext = base64.b64decode(enc_obj["ciphertext"])
        aesgcm = AESGCM(aes_key)
        decrypted = aesgcm.decrypt(nonce, ciphertext, None)
        return json.loads(decrypted.decode("utf-8"))
    except Exception:
        return None


def parse_tier_string(tier_obj):
    if not tier_obj:
        return "FREE"
    if isinstance(tier_obj, str):
        raw = tier_obj
    elif isinstance(tier_obj, dict):
        raw = tier_obj.get("id") or tier_obj.get("name") or "free"
    else:
        raw = str(tier_obj)

    raw_lower = raw.lower()
    if "ultra" in raw_lower:
        return "ULTRA"
    if "pro" in raw_lower:
        return "PRO"
    if "enterprise" in raw_lower:
        return "ENTERPRISE"
    if "standard" in raw_lower:
        return "STANDARD"
    if "free" in raw_lower:
        return "FREE"
    return raw.replace("g1-", "").replace("-tier", "").upper()


def discover_accounts():
    accounts = []
    seen_emails = set()
    active_cli_refresh = None
    active_cli_access = None

    # 1. Read Active CLI Token
    active_cli_token_obj = None
    if os.path.exists(CLI_TOKEN_PATH):
        try:
            with open(CLI_TOKEN_PATH, "r", encoding="utf-8") as f:
                cli_data = json.load(f)
            active_cli_token_obj = cli_data.get("token", {})
            active_cli_refresh = active_cli_token_obj.get("refresh_token")
            active_cli_access = active_cli_token_obj.get("access_token")
        except Exception:
            pass

    aes_key = load_aes_key()

    # 2. Read Managed Accounts (from native AGY storage first, fallback to Cockpit)
    dirs_to_check = []
    if os.path.isdir(ACCOUNTS_DIR):
        dirs_to_check.append((ACCOUNTS_DIR, "agy"))
    cockpit_acc_dir = os.path.join(COCKPIT_DIR, "accounts")
    if os.path.isdir(cockpit_acc_dir) and cockpit_acc_dir != ACCOUNTS_DIR:
        dirs_to_check.append((cockpit_acc_dir, "cockpit"))

    for adir, src_label in dirs_to_check:
        for path in sorted(glob.glob(os.path.join(adir, "*.json"))):
            if path.endswith(".bak"):
                continue
            try:
                with open(path, "r", encoding="utf-8") as f:
                    acc_raw = json.load(f)
                acc_id = acc_raw.get("id")
                email = acc_raw.get("email")
                name = acc_raw.get("name")
                enc_token = acc_raw.get("token_encrypted")
                cached_quota = acc_raw.get("quota")

                token_data = decrypt_cockpit_token(aes_key, enc_token) if aes_key else None
                refresh_token = token_data.get("refresh_token") if token_data else None
                access_token = token_data.get("access_token") if token_data else None
                resolved_email = email or (token_data.get("email") if token_data else None)
                if resolved_email and resolved_email.lower() in seen_emails:
                    continue

                is_active = bool(refresh_token and active_cli_refresh and refresh_token == active_cli_refresh)

                accounts.append({
                    "id": acc_id,
                    "email": resolved_email,
                    "name": name,
                    "refresh_token": refresh_token,
                    "access_token": access_token,
                    "cached_quota": cached_quota,
                    "is_active_cli": is_active,
                    "source": src_label,
                    "file_path": path
                })
                if resolved_email:
                    seen_emails.add(resolved_email.lower())
            except Exception:
                continue

    # 3. Add Active CLI Token if not already in cockpit accounts
    if active_cli_token_obj and active_cli_refresh:
        # Check if active is already marked
        has_active = any(a.get("is_active_cli") for a in accounts)
        if not has_active:
            # Check user info for active CLI account
            uinfo = get_user_info(active_cli_access) if active_cli_access else {}
            cli_email = uinfo.get("email", "Active CLI Account")
            cli_name = uinfo.get("name", "CLI Session")
            
            # Match by email
            matched = False
            for a in accounts:
                if a.get("email") and a.get("email").lower() == cli_email.lower():
                    a["is_active_cli"] = True
                    matched = True
                    break
            
            if not matched and cli_email.lower() not in seen_emails:
                accounts.insert(0, {
                    "id": "cli_active",
                    "email": cli_email,
                    "name": cli_name,
                    "refresh_token": active_cli_refresh,
                    "access_token": active_cli_access,
                    "cached_quota": None,
                    "is_active_cli": True,
                    "source": "cli",
                    "file_path": CLI_TOKEN_PATH
                })

    return accounts


def refresh_access_token(refresh_token):
    if not refresh_token:
        return None, "No refresh token available"
    ctx = get_ssl_context()
    post_data = urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token"
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=post_data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("access_token"), None
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        return None, f"HTTP {e.code}: {body}"
    except Exception as e:
        return None, str(e)


def get_user_info(access_token):
    ctx = get_ssl_context()
    req = urllib.request.Request(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=6) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return {}


def fetch_account_details(account, fetch_models=False):
    res = {
        "id": account.get("id"),
        "email": account.get("email"),
        "name": account.get("name"),
        "is_active_cli": account.get("is_active_cli", False),
        "source": account.get("source"),
        "status": "UNKNOWN",
        "tier": "FREE",
        "gemini_5h": None,
        "gemini_weekly": None,
        "claude_5h": None,
        "claude_weekly": None,
        "models": {},
        "raw_summary": None,
        "error": None
    }

    refresh_tok = account.get("refresh_token")
    access_tok = account.get("access_token")

    # Refresh token to ensure validity
    if refresh_tok:
        new_tok, err = refresh_access_token(refresh_tok)
        if new_tok:
            access_tok = new_tok
            res["access_token"] = new_tok
        elif not access_tok:
            res["status"] = "AUTH_FAILED"
            res["error"] = err
            return res

    if not access_tok:
        res["status"] = "NO_TOKEN"
        res["error"] = "No valid access or refresh token found"
        return res

    # Resolve email/name if missing or generic
    if not res["email"] or "@" not in res["email"] or res["email"] == "Active CLI Account":
        uinfo = get_user_info(access_tok)
        if uinfo.get("email"):
            res["email"] = uinfo.get("email")
        if uinfo.get("name"):
            res["name"] = uinfo.get("name")

    headers = {
        "Authorization": f"Bearer {access_tok}",
        "User-Agent": USER_AGENT,
        "x-goog-api-client": GOOG_CLIENT,
        "Content-Type": "application/json"
    }
    ctx = get_ssl_context()

    # 1. Fetch Tier info (loadCodeAssist)
    try:
        req_tier = urllib.request.Request(
            f"{CLOUD_CODE_BASE}/v1internal:loadCodeAssist",
            headers=headers,
            data=b"{}"
        )
        with urllib.request.urlopen(req_tier, context=ctx, timeout=8) as r:
            tier_data = json.loads(r.read().decode("utf-8"))
            paid_tier = tier_data.get("paidTier")
            curr_tier = tier_data.get("currentTier")
            res["tier"] = parse_tier_string(paid_tier or curr_tier or "FREE")
    except Exception:
        res["tier"] = "FREE"

    # 2. Fetch Quota Summary (retrieveUserQuotaSummary)
    try:
        req_q = urllib.request.Request(
            f"{CLOUD_CODE_BASE}/v1internal:retrieveUserQuotaSummary",
            headers=headers,
            data=b"{}"
        )
        with urllib.request.urlopen(req_q, context=ctx, timeout=8) as r:
            qsummary = json.loads(r.read().decode("utf-8"))
            res["raw_summary"] = qsummary
            res["status"] = "ACTIVE"

            for group in qsummary.get("groups", []):
                gname = group.get("displayName", "").lower()
                for bucket in group.get("buckets", []):
                    b_id = bucket.get("bucketId", "")
                    rem_frac = bucket.get("remainingFraction", 0.0)
                    pct = round(rem_frac * 100.0, 1)
                    reset_time = bucket.get("resetTime")
                    desc = bucket.get("description", "")
                    b_info = {
                        "percentage": pct,
                        "remaining_fraction": rem_frac,
                        "reset_time": reset_time,
                        "description": desc
                    }
                    if "gemini" in b_id or "gemini" in gname:
                        if "5h" in b_id:
                            res["gemini_5h"] = b_info
                        elif "weekly" in b_id:
                            res["gemini_weekly"] = b_info
                    elif "3p" in b_id or "claude" in gname or "gpt" in gname:
                        if "5h" in b_id:
                            res["claude_5h"] = b_info
                        elif "weekly" in b_id:
                            res["claude_weekly"] = b_info
    except urllib.error.HTTPError as e:
        res["status"] = f"HTTP_{e.code}"
        res["error"] = f"API error: {e.code}"
    except Exception as e:
        res["status"] = "ERROR"
        res["error"] = str(e)

    # 3. Optional: Fetch model detailed quota
    if fetch_models:
        try:
            req_m = urllib.request.Request(
                f"{CLOUD_CODE_BASE}/v1internal:fetchAvailableModels",
                headers=headers,
                data=b"{}"
            )
            with urllib.request.urlopen(req_m, context=ctx, timeout=8) as r:
                mdata = json.loads(r.read().decode("utf-8"))
                for m_id, m_val in mdata.get("models", {}).items():
                    qinfo = m_val.get("quotaInfo", {})
                    res["models"][m_id] = {
                        "display_name": m_val.get("displayName") or m_id,
                        "percentage": round(qinfo.get("remainingFraction", 0.0) * 100.0, 1),
                        "reset_time": qinfo.get("resetTime"),
                        "recommended": m_val.get("recommended", False)
                    }
        except Exception:
            pass

    return res


def format_time_remaining(iso_str):
    if not iso_str:
        return "N/A"
    try:
        dt = datetime.datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.datetime.now(datetime.timezone.utc)
        diff = dt - now
        total_seconds = int(diff.total_seconds())
        if total_seconds <= 0:
            return "ready"
        days = total_seconds // 86400
        hours = (total_seconds % 86400) // 3600
        minutes = (total_seconds % 3600) // 60
        parts = []
        if days > 0:
            parts.append(f"{days}d")
        if hours > 0:
            parts.append(f"{hours}h")
        if minutes > 0 and days == 0:
            parts.append(f"{minutes}m")
        return "in " + " ".join(parts) if parts else "in <1m"
    except Exception:
        return iso_str[:16]


def make_bar_plain(pct, width=8):
    if pct is None:
        return "   N/A  "
    filled = int(round(width * (pct / 100.0)))
    empty = width - filled
    return f"[{'=' * filled}{' ' * empty}] {pct:>5.1f}%"


def make_bar_rich(pct, width=8):
    if pct is None:
        return Text("  N/A  ", style="dim")
    filled = int(round(width * (pct / 100.0)))
    empty = width - filled
    if pct >= 80:
        color = "green"
    elif pct >= 40:
        color = "yellow"
    elif pct > 0:
        color = "dark_orange"
    else:
        color = "red bold"
    t = Text()
    t.append("█" * filled, style=color)
    t.append("░" * empty, style="dim")
    t.append(f" {pct:>5.1f}%", style=f"{color} bold")
    return t


def render_rich_table(results):
    console = Console()
    
    table = Table(
        title="[bold cyan]Antigravity Multi-Account Quota & Token Overview[/bold cyan]",
        title_style="bold cyan",
        header_style="bold magenta",
        box=ROUNDED,
        show_lines=True
    )

    table.add_column("#", justify="right", style="dim", width=3)
    table.add_column("Account / Email", style="bold white", min_width=24)
    table.add_column("Name", style="cyan", min_width=12)
    table.add_column("Tier", justify="center", width=10)
    table.add_column("Gemini 5h", justify="left", min_width=16)
    table.add_column("Gemini Wk", justify="left", min_width=16)
    table.add_column("Claude 5h", justify="left", min_width=16)
    table.add_column("Claude Wk", justify="left", min_width=16)
    table.add_column("Next Reset", justify="right", min_width=9)

    for i, acc in enumerate(results, 1):
        email_str = acc.get("email") or "Unknown"
        if acc.get("is_active_cli"):
            email_text = Text()
            email_text.append("[ACTIVE] ", style="bold yellow")
            email_text.append(email_str, style="bold green")
            email_text.append("\n(Active CLI)", style="italic green")
        else:
            email_text = Text(email_str)

        name_str = acc.get("name") or "-"
        tier_str = str(acc.get("tier", "FREE")).upper()
        if tier_str == "PRO":
            tier_text = Text("PRO", style="bold green")
        elif tier_str == "ULTRA":
            tier_text = Text("ULTRA", style="bold magenta")
        elif tier_str == "ENTERPRISE":
            tier_text = Text("ENTERPRISE", style="bold cyan")
        else:
            tier_text = Text(tier_str, style="dim")

        if acc.get("status") != "ACTIVE":
            status_text = Text(f"[{acc.get('status')}]", style="bold red")
            table.add_row(
                str(i), email_text, name_str, tier_text,
                status_text, Text("-", style="dim"), Text("-", style="dim"), Text("-", style="dim"),
                Text(str(acc.get("error", "-")), style="dim red")
            )
            continue

        g5 = acc.get("gemini_5h", {}).get("percentage") if acc.get("gemini_5h") else None
        gw = acc.get("gemini_weekly", {}).get("percentage") if acc.get("gemini_weekly") else None
        c5 = acc.get("claude_5h", {}).get("percentage") if acc.get("claude_5h") else None
        cw = acc.get("claude_weekly", {}).get("percentage") if acc.get("claude_weekly") else None

        resets = []
        for b in [acc.get("gemini_5h"), acc.get("claude_5h")]:
            if b and b.get("reset_time"):
                resets.append(b.get("reset_time"))
        next_reset = format_time_remaining(min(resets)) if resets else "-"

        table.add_row(
            str(i),
            email_text,
            name_str,
            tier_text,
            make_bar_rich(g5),
            make_bar_rich(gw),
            make_bar_rich(c5),
            make_bar_rich(cw),
            Text(next_reset, style="cyan")
        )

    console.print()
    console.print(table)
    
    total = len(results)
    active = sum(1 for a in results if a.get("status") == "ACTIVE")
    limited_5h = sum(
        1 for a in results
        if ((a.get("gemini_5h") or {}).get("percentage") == 0 or (a.get("claude_5h") or {}).get("percentage") == 0)
    )

    summary_text = (
        f"[bold]Total Accounts:[/bold] {total} | "
        f"[bold green]Ready/Active:[/bold green] {active} | "
        f"[bold red]5h Limited:[/bold red] {limited_5h} | "
        f"[dim]Run [cyan]agy-quota -d[/cyan] for model breakdown, [cyan]-s <#>[/cyan] to switch CLI account[/dim]"
    )
    console.print(Panel(summary_text, border_style="cyan", expand=False))
    console.print()


def render_plain_table(results):
    print("\n=== Antigravity Multi-Account Quota & Token Overview ===")
    header = f"{'#':<3} {'Account / Email':<32} {'Tier':<10} {'Gemini 5h':<16} {'Gemini Wk':<16} {'Claude 5h':<16} {'Claude Wk':<16} {'Reset'}"
    print("-" * len(header))
    print(header)
    print("-" * len(header))

    for i, acc in enumerate(results, 1):
        email_str = acc.get("email") or "Unknown"
        if acc.get("is_active_cli"):
            email_str = f"* {email_str}"
        tier = str(acc.get("tier", "FREE")).upper()

        if acc.get("status") != "ACTIVE":
            print(f"{i:<3} {email_str:<32} {tier:<10} [{acc.get('status')}] {acc.get('error', '')}")
            continue

        g5 = make_bar_plain(acc.get("gemini_5h", {}).get("percentage") if acc.get("gemini_5h") else None)
        gw = make_bar_plain(acc.get("gemini_weekly", {}).get("percentage") if acc.get("gemini_weekly") else None)
        c5 = make_bar_plain(acc.get("claude_5h", {}).get("percentage") if acc.get("claude_5h") else None)
        cw = make_bar_plain(acc.get("claude_weekly", {}).get("percentage") if acc.get("claude_weekly") else None)

        resets = []
        for b in [acc.get("gemini_5h"), acc.get("claude_5h")]:
            if b and b.get("reset_time"):
                resets.append(b.get("reset_time"))
        next_reset = format_time_remaining(min(resets)) if resets else "-"

        print(f"{i:<3} {email_str:<32} {tier:<10} {g5:<16} {gw:<16} {c5:<16} {cw:<16} {next_reset}")

    print("-" * len(header))
    print(f"(* = Active CLI account) Total: {len(results)} accounts\n")


def render_detail_view(results):
    if HAS_RICH and sys.stdout.isatty():
        console = Console()
        for i, acc in enumerate(results, 1):
            title = f"[bold cyan]Account #{i}: {acc.get('email')} ({acc.get('name')})[/bold cyan]"
            if acc.get("is_active_cli"):
                title += " [bold yellow]* ACTIVE CLI[/bold yellow]"

            lines = []
            lines.append(f"[bold]Tier:[/bold] {acc.get('tier')}  |  [bold]Status:[/bold] {acc.get('status')}  |  [bold]Source:[/bold] {acc.get('source')}")
            
            # Buckets
            lines.append("\n[bold underline]Quota Buckets:[/bold underline]")
            if acc.get("gemini_5h"):
                g5 = acc["gemini_5h"]
                lines.append(f"  • Gemini 5-Hour: {g5['percentage']}% (Reset: {format_time_remaining(g5['reset_time'])} - {g5['reset_time']})")
                if g5.get("description"):
                    lines.append(f"    [dim]{g5['description']}[/dim]")
            if acc.get("gemini_weekly"):
                gw = acc["gemini_weekly"]
                lines.append(f"  • Gemini Weekly: {gw['percentage']}% (Reset: {format_time_remaining(gw['reset_time'])} - {gw['reset_time']})")
                if gw.get("description"):
                    lines.append(f"    [dim]{gw['description']}[/dim]")
            if acc.get("claude_5h"):
                c5 = acc["claude_5h"]
                lines.append(f"  • Claude 5-Hour: {c5['percentage']}% (Reset: {format_time_remaining(c5['reset_time'])} - {c5['reset_time']})")
                if c5.get("description"):
                    lines.append(f"    [dim]{c5['description']}[/dim]")
            if acc.get("claude_weekly"):
                cw = acc["claude_weekly"]
                lines.append(f"  • Claude Weekly: {cw['percentage']}% (Reset: {format_time_remaining(cw['reset_time'])} - {cw['reset_time']})")
                if cw.get("description"):
                    lines.append(f"    [dim]{cw['description']}[/dim]")

            # Models
            if acc.get("models"):
                lines.append("\n[bold underline]Individual Models Breakdown:[/bold underline]")
                for mid, minf in sorted(acc["models"].items()):
                    star = "* " if minf.get("recommended") else "  "
                    lines.append(f"  {star}{mid:<32} -> {minf['percentage']:>5.1f}%  (Reset: {format_time_remaining(minf['reset_time'])})")

            console.print(Panel("\n".join(lines), title=title, border_style="cyan", box=ROUNDED))
            console.print()
    else:
        for i, acc in enumerate(results, 1):
            print(f"\n=======================================================")
            print(f"Account #{i}: {acc.get('email')} ({acc.get('name')}) {'[ACTIVE CLI]' if acc.get('is_active_cli') else ''}")
            print(f"Tier: {acc.get('tier')} | Status: {acc.get('status')} | Source: {acc.get('source')}")
            print(f"Gemini 5h: {acc.get('gemini_5h', {}).get('percentage')}% | Weekly: {acc.get('gemini_weekly', {}).get('percentage')}%")
            print(f"Claude 5h: {acc.get('claude_5h', {}).get('percentage')}% | Weekly: {acc.get('claude_weekly', {}).get('percentage')}%")
            if acc.get("models"):
                print("Models:")
                for mid, minf in sorted(acc["models"].items()):
                    print(f"  - {mid:<32}: {minf['percentage']}%")
        print("=======================================================\n")


def switch_cli_account(target_query, accounts):
    target = None
    if target_query.isdigit():
        idx = int(target_query) - 1
        if 0 <= idx < len(accounts):
            target = accounts[idx]
    
    if not target:
        for acc in accounts:
            if target_query.lower() in (acc.get("email") or "").lower() or target_query == acc.get("id"):
                target = acc
                break

    if not target:
        print(f"Error: Account matching '{target_query}' not found.")
        sys.exit(1)

    refresh_token = target.get("refresh_token")
    if not refresh_token:
        print(f"Error: No refresh token found for {target.get('email')}.")
        sys.exit(1)

    print(f"Refreshing token for {target.get('email')}...")
    access_token, err = refresh_access_token(refresh_token)
    if not access_token:
        print(f"Error refreshing token: {err}")
        sys.exit(1)

    expiry = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=3590)).isoformat()

    cli_token_payload = {
        "token": {
            "access_token": access_token,
            "token_type": "Bearer",
            "refresh_token": refresh_token,
            "expiry": expiry
        },
        "auth_method": "consumer"
    }

    os.makedirs(os.path.dirname(CLI_TOKEN_PATH), exist_ok=True)
    with open(CLI_TOKEN_PATH, "w", encoding="utf-8") as f:
        json.dump(cli_token_payload, f, indent=2)

    print(f"Successfully switched active AGY CLI token to: {target.get('email')} ({target.get('name')})")


def export_token(target_query, accounts):
    target = None
    if target_query.isdigit():
        idx = int(target_query) - 1
        if 0 <= idx < len(accounts):
            target = accounts[idx]
    if not target:
        for acc in accounts:
            if target_query.lower() in (acc.get("email") or "").lower() or target_query == acc.get("id"):
                target = acc
                break
    if not target:
        print(f"Error: Account matching '{target_query}' not found.", file=sys.stderr)
        sys.exit(1)

    access_token, err = refresh_access_token(target.get("refresh_token"))
    if not access_token:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)
    print(access_token)


def add_new_account():
    import http.server
    import webbrowser
    import uuid
    import threading

    auth_code_container = {"code": None, "error": None}
    redirect_port = 1455
    redirect_uri = f"http://localhost:{redirect_port}/auth/callback"

    class OAuthCallbackHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            pass  # Suppress default server logs

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path.startswith("/auth/callback") or parsed.path.startswith("/"):
                query = urllib.parse.parse_qs(parsed.query)
                if "code" in query:
                    auth_code_container["code"] = query["code"][0]
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(b"""
                    <!DOCTYPE html>
                    <html>
                    <head><title>Antigravity Auth Success</title>
                    <style>
                      body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                      .card { background: #1e293b; padding: 2rem; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); text-align: center; max-width: 400px; }
                      h1 { color: #38bdf8; font-size: 1.5rem; margin-bottom: 0.5rem; }
                      p { color: #94a3b8; font-size: 0.95rem; }
                    </style>
                    </head>
                    <body>
                      <div class="card">
                        <h1>Login Berhasil</h1>
                        <p>Akun Antigravity berhasil dihubungkan! Anda dapat menutup tab ini dan kembali ke terminal.</p>
                      </div>
                    </body>
                    </html>
                    """)
                elif "error" in query:
                    auth_code_container["error"] = query["error"][0]
                    self.send_response(400)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(b"<h1>Auth Failed</h1><p>Gagal login atau dibatalkan.</p>")
                else:
                    self.send_response(404)
                    self.end_headers()

    server = None
    try:
        server = http.server.HTTPServer(("127.0.0.1", redirect_port), OAuthCallbackHandler)
    except Exception as e:
        print(f"Error binding to port {redirect_port}: {e}")
        print("Pastikan tidak ada aplikasi Cockpit/tools lain yang sedang menggunakan port 1455.")
        sys.exit(1)

    scopes = [
        "openid",
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs"
    ]
    scope_str = " ".join(scopes)

    auth_params = {
        "client_id": CLIENT_ID,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": scope_str,
        "access_type": "offline",
        "prompt": "consent"
    }
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(auth_params)

    print("\n" + "=" * 65)
    print("      LOGIN & TAMBAH AKUN ANTIGRAVITY (AGY)")
    print("=" * 65)
    print("\nSilakan buka tautan berikut di browser Anda untuk login:\n")
    print(auth_url)
    print("\n" + "-" * 65)
    print("Menunggu konfirmasi login dari browser (Tekan Ctrl+C untuk batal)...")

    try:
        webbrowser.open(auth_url)
    except Exception:
        pass

    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    # Wait for callback or timeout (120s)
    start_time = time.time()
    while time.time() - start_time < 120:
        if auth_code_container["code"] or auth_code_container["error"]:
            break
        time.sleep(0.5)

    server.shutdown()
    server.server_close()

    code = auth_code_container["code"]
    if not code:
        if auth_code_container["error"]:
            print(f"\nError autentikasi: {auth_code_container['error']}")
        else:
            print("\nTimeout: Tidak menerima callback dari browser dalam 120 detik.")
        sys.exit(1)

    print("\nMenerima kode otorisasi, menukar token...")
    ctx = get_ssl_context()
    post_data = urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=post_data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            token_resp = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"Gagal menukar token dengan Google: {e}")
        sys.exit(1)

    access_token = token_resp.get("access_token")
    refresh_token = token_resp.get("refresh_token")
    expires_in = token_resp.get("expires_in", 3599)
    id_token = token_resp.get("id_token", "")

    if not access_token or not refresh_token:
        print("Error: Google tidak mengembalikan refresh token. Pastikan memilih 'Izinkan' saat login.")
        sys.exit(1)

    # Fetch user info
    uinfo = get_user_info(access_token)
    email = uinfo.get("email", "unknown@gmail.com")
    name = uinfo.get("name", email.split("@")[0])

    print(f"Berhasil login sebagai: {name} ({email})")

    # Load / Create AES Key
    aes_key = load_aes_key()
    if not aes_key:
        if not os.path.exists(STORAGE_DIR):
            os.makedirs(STORAGE_DIR, exist_ok=True)
        # Generate new AES key
        aes_key = AESGCM.generate_key(bit_length=256)
        with open(KEY_PATH, "w", encoding="utf-8") as f:
            f.write(base64.b64encode(aes_key).decode("utf-8"))

    # Encrypt token payload
    now_ts = int(time.time())
    token_to_encrypt = {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "expires_in": expires_in,
        "expiry_timestamp": now_ts + expires_in,
        "token_type": "Bearer",
        "email": email,
        "oauth_client_key": "antigravity_enterprise",
        "id_token": id_token,
        "session_id": str(uuid.uuid4())[:21]
    }

    nonce = os.urandom(12)
    aesgcm = AESGCM(aes_key)
    ciphertext = aesgcm.encrypt(nonce, json.dumps(token_to_encrypt).encode("utf-8"), None)

    account_id = str(uuid.uuid4())
    account_doc = {
        "created_at": now_ts,
        "disabled": False,
        "email": email,
        "id": account_id,
        "last_used": now_ts,
        "name": name,
        "quota": {
            "credits": [],
            "is_forbidden": False,
            "last_updated": now_ts,
            "models": [],
            "subscription_tier": "free-tier",
            "tier_id": None
        },
        "token_encrypted": {
            "algorithm": "AES-256-GCM",
            "ciphertext": base64.b64encode(ciphertext).decode("utf-8"),
            "encrypted_at": now_ts,
            "key_id": "local-account-token-key-v1",
            "nonce": base64.b64encode(nonce).decode("utf-8"),
            "version": 1
        },
        "usage_updated_at": now_ts
    }

    # Save to ~/.gemini/antigravity-cli/accounts/<uuid>.json
    os.makedirs(ACCOUNTS_DIR, exist_ok=True)
    acc_file_path = os.path.join(ACCOUNTS_DIR, f"{account_id}.json")
    with open(acc_file_path, "w", encoding="utf-8") as f:
        json.dump(account_doc, f, indent=2)

    # Update accounts.json in native STORAGE_DIR
    index_path = os.path.join(STORAGE_DIR, "accounts.json")
    accounts_index = {"version": "2.0", "accounts": [], "current_account_id": None}
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                accounts_index = json.load(f)
        except Exception:
            pass

    # Avoid duplicate email in index
    accounts_index["accounts"] = [a for a in accounts_index.get("accounts", []) if a.get("email") != email]
    accounts_index["accounts"].append({
        "id": account_id,
        "email": email,
        "name": name,
        "created_at": now_ts,
        "last_used": now_ts
    })

    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(accounts_index, f, indent=2)

    print(f"\nSukses menyimpan akun ke AGY storage: {acc_file_path}")

    # Set as active CLI account
    expiry_iso = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=expires_in - 10)).isoformat()
    cli_payload = {
        "token": {
            "access_token": access_token,
            "token_type": "Bearer",
            "refresh_token": refresh_token,
            "expiry": expiry_iso
        },
        "auth_method": "consumer"
    }
    os.makedirs(os.path.dirname(CLI_TOKEN_PATH), exist_ok=True)
    with open(CLI_TOKEN_PATH, "w", encoding="utf-8") as f:
        json.dump(cli_payload, f, indent=2)

    print(f"Akun aktif CLI Antigravity sekarang: {email}")
    print("\nJalankan 'agy-quota' untuk melihat kuota token terbaru!\n")


def sync_from_servv(host="servv", remote_path=None):
    import subprocess
    import uuid

    if not remote_path:
        remote_path = os.environ.get("AGY_REMOTE_AUTH_DIR", "~/Projects/cli-proxy-api/auth")

    print(f"\n[Sync] Mengambil list akun Antigravity dari '{host}' ({remote_path})...")
    cmd = ["ssh", host, f'for f in {remote_path}/antigravity-*.json; do [ -f "$f" ] && cat "$f" && echo ""; done']
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except Exception as e:
        print(f"Gagal menghubungkan ke {host} via SSH: {e}")
        sys.exit(1)

    if proc.returncode != 0:
        print(f"Error SSH dari {host}: {proc.stderr}")
        sys.exit(1)

    remote_accounts = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
            if data.get("type") == "antigravity" and data.get("refresh_token"):
                remote_accounts.append(data)
        except Exception:
            pass

    if not remote_accounts:
        print(f"Tidak ditemukan file auth antigravity di {host}:{remote_path}/")
        return

    print(f"Ditemukan {len(remote_accounts)} akun di server '{host}'. Melakukan sinkronisasi ke AGY lokal...")

    aes_key = load_aes_key()
    if not aes_key:
        if not os.path.exists(STORAGE_DIR):
            os.makedirs(STORAGE_DIR, exist_ok=True)
        aes_key = AESGCM.generate_key(bit_length=256)
        with open(KEY_PATH, "w", encoding="utf-8") as f:
            f.write(base64.b64encode(aes_key).decode("utf-8"))

    aesgcm = AESGCM(aes_key)

    local_accounts_by_email = {}
    index_path = os.path.join(STORAGE_DIR, "accounts.json")
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                idx_data = json.load(f)
            for a in idx_data.get("accounts", []):
                local_accounts_by_email[a.get("email", "").lower()] = a
        except Exception:
            pass

    for p in glob.glob(os.path.join(ACCOUNTS_DIR, "*.json")):
        if p.endswith(".bak"):
            continue
        try:
            with open(p, "r", encoding="utf-8") as f:
                d = json.load(f)
            em = (d.get("email") or "").lower()
            if em:
                local_accounts_by_email[em] = {"id": d.get("id"), "email": d.get("email"), "name": d.get("name"), "path": p}
        except Exception:
            pass

    now_ts = int(time.time())
    imported_count = 0
    updated_count = 0

    for rem in remote_accounts:
        email = rem.get("email")
        if not email:
            continue
        em_lower = email.lower()
        access_token = rem.get("access_token")
        refresh_token = rem.get("refresh_token")
        expires_in = rem.get("expires_in", 3599)
        name = email.split("@")[0]

        token_to_encrypt = {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "expires_in": expires_in,
            "expiry_timestamp": now_ts + expires_in,
            "token_type": "Bearer",
            "email": email,
            "oauth_client_key": "antigravity_enterprise",
            "id_token": "",
            "session_id": str(uuid.uuid4())[:21]
        }

        nonce = os.urandom(12)
        ciphertext = aesgcm.encrypt(nonce, json.dumps(token_to_encrypt).encode("utf-8"), None)

        if em_lower in local_accounts_by_email:
            acc_id = local_accounts_by_email[em_lower]["id"]
            acc_file_path = os.path.join(ACCOUNTS_DIR, f"{acc_id}.json")
            doc = {}
            if os.path.exists(acc_file_path):
                try:
                    with open(acc_file_path, "r", encoding="utf-8") as f:
                        doc = json.load(f)
                except Exception:
                    pass
            if not doc:
                doc = {"id": acc_id, "email": email, "name": name, "created_at": now_ts}

            doc["token_encrypted"] = {
                "algorithm": "AES-256-GCM",
                "ciphertext": base64.b64encode(ciphertext).decode("utf-8"),
                "encrypted_at": now_ts,
                "key_id": "local-account-token-key-v1",
                "nonce": base64.b64encode(nonce).decode("utf-8"),
                "version": 1
            }
            doc["disabled"] = False
            with open(acc_file_path, "w", encoding="utf-8") as f:
                json.dump(doc, f, indent=2)
            updated_count += 1
        else:
            acc_id = str(uuid.uuid4())
            acc_file_path = os.path.join(ACCOUNTS_DIR, f"{acc_id}.json")
            doc = {
                "created_at": now_ts,
                "disabled": False,
                "email": email,
                "id": acc_id,
                "last_used": now_ts,
                "name": name,
                "quota": {
                    "credits": [],
                    "is_forbidden": False,
                    "last_updated": now_ts,
                    "models": [],
                    "subscription_tier": "free-tier",
                    "tier_id": None
                },
                "token_encrypted": {
                    "algorithm": "AES-256-GCM",
                    "ciphertext": base64.b64encode(ciphertext).decode("utf-8"),
                    "encrypted_at": now_ts,
                    "key_id": "local-account-token-key-v1",
                    "nonce": base64.b64encode(nonce).decode("utf-8"),
                    "version": 1
                },
                "usage_updated_at": now_ts
            }
            os.makedirs(ACCOUNTS_DIR, exist_ok=True)
            with open(acc_file_path, "w", encoding="utf-8") as f:
                json.dump(doc, f, indent=2)

            local_accounts_by_email[em_lower] = {"id": acc_id, "email": email, "name": name}
            imported_count += 1

    # Rebuild accounts.json
    new_index_accounts = []
    for em_lower, info in local_accounts_by_email.items():
        new_index_accounts.append({
            "id": info["id"],
            "email": info.get("email", em_lower),
            "name": info.get("name", em_lower.split("@")[0]),
            "created_at": now_ts,
            "last_used": now_ts
        })

    with open(index_path, "w", encoding="utf-8") as f:
        json.dump({"version": "2.0", "accounts": new_index_accounts, "current_account_id": None}, f, indent=2)

    print(f"Sukses sinkronisasi! (Baru: {imported_count}, Diperbarui: {updated_count}, Total di lokal: {len(new_index_accounts)})\n")


def main():
    parser = argparse.ArgumentParser(
        description="Antigravity Multi-Account Token & Quota Bulk Checker",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  agy-quota                   # Bulk check quota across all accounts
  agy-quota --sync            # Sync all accounts from servv (cli-proxy-api pool)
  agy-quota --add             # Login & add a new Google account to AGY
  agy-quota --detail          # Show complete model & quota details for all accounts
  agy-quota -d errorreceh     # Show detail for a specific account
  agy-quota --switch 2        # Switch active AGY CLI token to account #2
  agy-quota --export 1        # Print access token for account #1 (for curl/scripts)
  agy-quota --json            # Output complete data in JSON format
  agy-quota --watch 30        # Continuously monitor quotas every 30s
        """
    )
    parser.add_argument("-a", "--add", "--login", action="store_true", help="Login and add a new Google/Antigravity account via browser")
    parser.add_argument("--sync", "--sync-servv", nargs="?", const="servv", default=None, help="Sync all accounts from remote proxy server (default: servv)")
    parser.add_argument("--sync-path", default=None, help="Remote path containing antigravity auth json files (default: ~/Projects/cli-proxy-api/auth)")
    parser.add_argument("-d", "--detail", nargs="?", const="all", default=None, help="Detailed breakdown for all models or specific account email/id")
    parser.add_argument("-j", "--json", action="store_true", help="Output raw JSON data")
    parser.add_argument("-s", "--switch", type=str, help="Switch active Antigravity CLI account to specified email, name or index (#)")
    parser.add_argument("-e", "--export", type=str, help="Export/print fresh Bearer access token for specified account")
    parser.add_argument("-w", "--watch", type=int, nargs="?", const=15, default=None, help="Live watch mode (auto refresh every N seconds, default 15)")
    parser.add_argument("-c", "--cache", action="store_true", help="Use local cached quota without making live API requests")
    parser.add_argument("-t", "--threads", type=int, default=8, help="Number of concurrent worker threads (default: 8)")

    args = parser.parse_args()

    # 0. Sync from remote servv
    if args.sync:
        sync_from_servv(args.sync, args.sync_path)

    # 0. Add / Login new account
    if args.add:
        add_new_account()
        return

    accounts = discover_accounts()
    if not accounts:
        print("No Antigravity accounts found in ~/.gemini/antigravity-cli/accounts")
        print("Run 'agy-quota --add' to login and add a new account.")
        sys.exit(1)

    # 1. Switch CLI account
    if args.switch:
        switch_cli_account(args.switch, accounts)
        return

    # 2. Export token
    if args.export:
        export_token(args.export, accounts)
        return

    # 3. Live or Cached Fetching
    fetch_models = bool(args.detail)

    def run_check():
        if args.cache:
            results = []
            for acc in accounts:
                q = acc.get("cached_quota") or {}
                results.append({
                    "id": acc.get("id"),
                    "email": acc.get("email"),
                    "name": acc.get("name"),
                    "is_active_cli": acc.get("is_active_cli"),
                    "source": acc.get("source"),
                    "status": "CACHED",
                    "tier": parse_tier_string(q.get("subscription_tier", "FREE")),
                    "gemini_5h": next((m for m in q.get("models", []) if m.get("name") == "gemini-5h"), None),
                    "gemini_weekly": next((m for m in q.get("models", []) if m.get("name") == "gemini-weekly"), None),
                    "claude_5h": next((m for m in q.get("models", []) if m.get("name") == "3p-5h"), None),
                    "claude_weekly": next((m for m in q.get("models", []) if m.get("name") == "3p-weekly"), None),
                    "models": {m.get("name"): m for m in q.get("models", [])}
                })
        else:
            with ThreadPoolExecutor(max_workers=min(args.threads, len(accounts))) as executor:
                results = list(executor.map(lambda a: fetch_account_details(a, fetch_models=fetch_models), accounts))

        # Sort: active CLI first, then alphabetical by email
        results.sort(key=lambda x: (not x.get("is_active_cli", False), (x.get("email") or "").lower()))
        return results

    if args.watch:
        try:
            while True:
                os.system("clear" if os.name != "nt" else "cls")
                results = run_check()
                if HAS_RICH and sys.stdout.isatty():
                    render_rich_table(results)
                else:
                    render_plain_table(results)
                print(f"[Watch Mode] Refreshed at {datetime.datetime.now().strftime('%H:%M:%S')} (Interval: {args.watch}s). Press Ctrl+C to stop.")
                time.sleep(args.watch)
        except KeyboardInterrupt:
            print("\nStopped.")
            return

    results = run_check()

    if args.json:
        print(json.dumps(results, indent=2))
        return

    if args.detail:
        if args.detail != "all":
            q = args.detail.lower()
            filtered = [r for r in results if q in (r.get("email") or "").lower() or q == str(r.get("id"))]
            if not filtered and args.detail.isdigit():
                idx = int(args.detail) - 1
                if 0 <= idx < len(results):
                    filtered = [results[idx]]
            results = filtered or results
        render_detail_view(results)
    else:
        if HAS_RICH and sys.stdout.isatty():
            render_rich_table(results)
        else:
            render_plain_table(results)


if __name__ == "__main__":
    main()

