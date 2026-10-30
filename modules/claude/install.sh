#!/usr/bin/env bash
# Merge the settings keys the dotfiles own into ~/.claude/settings.json and prune links to removed hooks.
set -euo pipefail
for f in log claude; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
hooks_src="$DOTFILES_DIR/modules/claude/home/.claude/hooks"
hooks_dst="$HOME/.claude/hooks"
if [ "${DRY_RUN:-0}" = 1 ]; then
  log_dry "merge owned settings into $HOME/.claude/settings.json"
  log_dry "prune stale links in $hooks_dst"
  exit 0
fi
if [ -d "$hooks_dst" ]; then
  for link in "$hooks_dst"/*; do
    if [ -L "$link" ] && [[ "$(readlink "$link")" == "$hooks_src"/* ]]; then
      rm "$link"
      echo "prune $link"
    fi
  done
  rmdir "$hooks_dst" 2>/dev/null || true
fi
claude_settings_merge "$DOTFILES_DIR/modules/claude/settings.owned.json" "$HOME/.claude/settings.json"
