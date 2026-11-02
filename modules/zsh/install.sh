#!/usr/bin/env bash
# ZDOTDIR makes zsh ignore ~/.zshrc, ~/.zprofile, ~/.zlogin. Move any that exist
# into the backup dir so nothing silently stops applying.
set -euo pipefail
for f in log os link vscode; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zlogin"; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  backup_move "$f"
done

if [ "$(os_name)" = linux ]; then
  m="$(vscode_server_settings_file)"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    log_dry "merge the zsh terminal profile into $m"
  else
    owned="$(mktemp)"
    vscode_server_zsh_settings >"$owned"
    mkdir -p "$(dirname "$m")"
    vscode_settings_merge "$owned" "$m"
    rm -f "$owned"
  fi
fi
