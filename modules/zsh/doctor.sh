#!/usr/bin/env bash
# On Linux, VS Code's remote server opens this machine's Homebrew zsh.
set -euo pipefail
for f in log os vscode; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
[ "$(os_name)" = linux ] || exit 0
m="$(vscode_server_settings_file)"
owned="$(mktemp)"
trap 'rm -f "$owned"' EXIT
vscode_server_zsh_settings >"$owned"
if ! drifted="$(vscode_settings_drift "$owned" "$m" 2>/dev/null)"; then
  while IFS= read -r k; do echo "VS Code server setting drifted: ${k:-missing $m}"; done <<<"${drifted:-}"
  exit 1
fi
