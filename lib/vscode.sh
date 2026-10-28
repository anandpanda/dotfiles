#!/usr/bin/env bash
# VS Code helpers: user dir per OS, extension list parsing, JSONC validation.

vscode_user_dir() {
  case "$(os_name)" in
    macos) echo "$HOME/Library/Application Support/Code/User" ;;
    *) echo "$HOME/.config/Code/User" ;;
  esac
}

# Ids one per line from FILE...; comments (# ...) and blanks dropped; lowercased.
vscode_ext_list() {
  cat "$@" | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '[:upper:]' '[:lower:]'
}

# 0 if FILE parses as JSON with comments (// and /* */) and trailing commas.
jsonc_valid() {
  python3 - "$1" <<'PY'
import json, re, sys
s = open(sys.argv[1]).read()
s = re.sub(r'(?m)^\s*//.*$', '', s)
s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
s = re.sub(r',(\s*[}\]])', r'\1', s)
json.loads(s)
PY
}

# Wanted ids (ours + overlay), one per line, sorted.
vscode_wanted() {
  local lists=("$DOTFILES_DIR/modules/vscode/extensions.txt")
  [ -f "$(overlay_dir)/modules/vscode/extensions.txt" ] && lists+=("$(overlay_dir)/modules/vscode/extensions.txt")
  vscode_ext_list "${lists[@]}" | sort -u
}

# Installed ids, lowercased, sorted. Empty when code is absent.
vscode_installed() {
  command -v code >/dev/null 2>&1 || return 0
  (code --list-extensions 2>/dev/null || true) | tr '[:upper:]' '[:lower:]' | sort -u
}
