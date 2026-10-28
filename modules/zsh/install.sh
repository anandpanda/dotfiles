#!/usr/bin/env bash
# ZDOTDIR makes zsh ignore ~/.zshrc, ~/.zprofile, ~/.zlogin. Move any that exist
# into the backup dir so nothing silently stops applying.
set -euo pipefail
for f in log link; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zlogin"; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  backup_move "$f"
done
