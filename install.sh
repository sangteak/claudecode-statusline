#!/usr/bin/env bash
# Claude Code Statusline - Installer (Linux / macOS)
# Usage: curl -fsSL https://raw.githubusercontent.com/sangteak/claudecode-statusline/main/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/sangteak/claudecode-statusline/main"
HOOKS_DIR="$HOME/.claude/hooks"
SCRIPT_DST="$HOOKS_DIR/statusline.py"
SETTINGS="$HOME/.claude/settings.json"

printf '\n  Claude Code Statusline Installer\n'
printf '  ---------------------------------\n\n'

# 1. Detect Python 3
if command -v python3 >/dev/null 2>&1; then
    PY="python3"
elif command -v python >/dev/null 2>&1; then
    PY="python"
else
    printf '  [1/3] Python 3 not found. Install python3 first.\n'
    exit 1
fi
printf '  [1/3] Python found (%s)\n' "$PY"

# 2. Install statusline.py — copy local file if running from a clone, else download
mkdir -p "$HOOKS_DIR"
SELF="${BASH_SOURCE[0]:-$0}"
SRC_DIR=""
if [ -f "$SELF" ]; then
    SRC_DIR="$(cd "$(dirname "$SELF")" && pwd)"
fi

if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/statusline.py" ]; then
    cp "$SRC_DIR/statusline.py" "$SCRIPT_DST"
    printf '  [2/3] statusline.py copied from local repo\n'
elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/statusline.py" -o "$SCRIPT_DST"
    printf '  [2/3] statusline.py downloaded\n'
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$SCRIPT_DST" "$REPO_RAW/statusline.py"
    printf '  [2/3] statusline.py downloaded\n'
else
    printf '  [2/3] curl or wget required.\n'
    exit 1
fi

# 3. Update settings.json (merge via Python — no jq dependency)
"$PY" - "$SETTINGS" "$PY" "$SCRIPT_DST" <<'PYEOF'
import json, os, sys
settings_path, py, script = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}
data["statusLine"] = {"type": "command", "command": '%s "%s"' % (py, script)}
os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
printf '  [3/3] settings.json updated\n'

printf '\n  Done! Restart Claude Code to apply.\n'
printf '  NOTE: A Nerd Font (e.g. Hack Nerd Font Mono) is required for icons.\n\n'
