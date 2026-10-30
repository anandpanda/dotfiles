#!/usr/bin/env bash
# Merge the settings keys the dotfiles own into ~/.claude/settings.json.
set -euo pipefail
for f in log claude; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
if [ "${DRY_RUN:-0}" = 1 ]; then
  log_dry "merge owned settings into $HOME/.claude/settings.json"
  exit 0
fi
claude_settings_merge "$DOTFILES_DIR/modules/claude/settings.owned.json" "$HOME/.claude/settings.json"
