#!/usr/bin/env bash
# Owned settings keys must match the live file; names the keys that drifted.
set -euo pipefail
# shellcheck disable=SC1090
source "$DOTFILES_DIR/lib/claude.sh"
claude_settings_drift "$DOTFILES_DIR/modules/claude/settings.owned.json" "$HOME/.claude/settings.json"
