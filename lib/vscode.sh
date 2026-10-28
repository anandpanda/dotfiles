#!/usr/bin/env bash
# VS Code helpers: user dir per OS, extension list parsing, JSONC validation.

vscode_user_dir() {
  case "$(os_name)" in
    macos) echo "$HOME/Library/Application Support/Code/User" ;;
    *) echo "$HOME/.config/Code/User" ;;
  esac
}

# Ids one per line from FILE...; comments (# ...) and blanks dropped; lowercased.
# Each file is read on its own so a missing trailing newline cannot merge two ids.
vscode_ext_list() {
  local f
  for f in "$@"; do
    sed 's/#.*//' "$f"
    echo
  done | awk '{print $1}' | grep -v '^$' | tr '[:upper:]' '[:lower:]'
}

# JSONC -> JSON on stdout: comments and trailing commas removed, strings respected.
_jsonc_to_json() {
  python3 - "$1" <<'PY'
import json, sys
s = open(sys.argv[1]).read()
out, i, n = [], 0, len(s)
while i < n:
    c = s[i]
    if c == '"':                      # string: copy verbatim, honour escapes
        j = i + 1
        while j < n and s[j] != '"':
            j += 2 if s[j] == '\\' else 1
        out.append(s[i:j + 1]); i = j + 1
    elif s.startswith('//', i):
        j = s.find('\n', i); i = n if j < 0 else j
    elif s.startswith('/*', i):
        j = s.find('*/', i + 2); i = n if j < 0 else j + 2
    elif c == ',':                    # trailing comma: skip if next token closes
        j = i + 1
        while j < n and s[j] in ' \t\r\n': j += 1
        if j < n and s[j] in '}]': i += 1
        else: out.append(c); i += 1
    else:
        out.append(c); i += 1
sys.stdout.write(''.join(out))
PY
}

# 0 if FILE parses as JSONC.
jsonc_valid() {
  _jsonc_to_json "$1" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
}

# Top-level keys of a JSONC object, one per line.
jsonc_keys() {
  _jsonc_to_json "$1" | python3 -c 'import json,sys; [print(k) for k in json.load(sys.stdin)]'
}

# Wanted ids (ours + overlay), one per line, sorted.
vscode_wanted() {
  local lists=("$DOTFILES_DIR/modules/vscode/extensions.txt")
  [ -f "$(overlay_dir)/modules/vscode/extensions.txt" ] && lists+=("$(overlay_dir)/modules/vscode/extensions.txt")
  vscode_ext_list "${lists[@]}" | sort -u
}

# Path to the `code` CLI. DOTFILES_CODE overrides (empty means "none", for tests);
# else PATH; else the macOS app bundle (fresh Mac before the brew shim is linked).
vscode_bin() {
  if [ "${DOTFILES_CODE+set}" = set ]; then
    [ -n "$DOTFILES_CODE" ] && echo "$DOTFILES_CODE"
    [ -n "$DOTFILES_CODE" ]
    return
  fi
  if command -v code >/dev/null 2>&1; then
    command -v code
    return 0
  fi
  local app="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  [ -x "$app" ] && echo "$app" && return 0
  return 1
}

# Installed ids, lowercased, sorted. Empty when code is absent.
vscode_installed() {
  local c
  c="$(vscode_bin)" || return 0
  ("$c" --list-extensions 2>/dev/null || true) | tr '[:upper:]' '[:lower:]' | sort -u
}
