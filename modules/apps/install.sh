#!/usr/bin/env bash
# AltTab replaces Cmd-Tab, but its default hold key is Option; switch it to Command once. Idempotent.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/log.sh"
command -v defaults >/dev/null 2>&1 || exit 0
domain=com.lwouis.alt-tab-macos
cur="$(defaults read "$domain" holdShortcut 2>/dev/null || true)"
if [ "$cur" = "⌘" ]; then
  echo "skip alttab holdShortcut"
  exit 0
fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  log_dry "set alttab holdShortcut ⌘"
  exit 0
fi
defaults write "$domain" holdShortcut -string "⌘"
echo "set alttab holdShortcut ⌘ (restart AltTab to apply)"
