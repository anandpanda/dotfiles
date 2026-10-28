#!/usr/bin/env bash
# Karabiner rewrites karabiner.json through the link when settings change in its UI.
# Report drift as info (like VS Code): review and commit, or git checkout to discard.
set -euo pipefail
repo="$DOTFILES_DIR/modules/karabiner/home/.config/karabiner/karabiner.json"
live="$HOME/.config/karabiner/karabiner.json"
[ -f "$live" ] || exit 0
python3 - "$repo" "$live" <<'PY' || echo "karabiner.json changed outside the repo (Karabiner UI): review and commit, or git checkout the file"
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
sys.exit(0 if a == b else 1)
PY
exit 0
