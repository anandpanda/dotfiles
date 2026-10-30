#!/usr/bin/env bash
# Owned settings keys must match the live file; enabled plugins installed; jq present.
set -euo pipefail
# shellcheck disable=SC1090
source "$DOTFILES_DIR/lib/claude.sh"
owned="$DOTFILES_DIR/modules/claude/settings.owned.json"
fail=0
if ! command -v jq >/dev/null 2>&1; then
  echo "jq missing: brew install jq"
  exit 1
fi
claude_settings_drift "$owned" "$HOME/.claude/settings.json" || fail=1
if command -v claude >/dev/null 2>&1; then
  installed="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)"
  while IFS= read -r id; do
    printf '%s\n' "$installed" | grep -qxF "$id" || {
      echo "plugin not installed: $id"
      fail=1
    }
  done < <(jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' "$owned")
fi
exit "$fail"
