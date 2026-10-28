#!/usr/bin/env bash
# AltTab replaces Cmd-Tab, but its default hold key is Option; switch it to Command once. Idempotent.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/log.sh"
command -v defaults >/dev/null 2>&1 || exit 0
domain=com.lwouis.alt-tab-macos
# `defaults read` prints non-ASCII values in the session's text encoding (escaped on a CI
# runner), so compare the exported plist in Python instead of its printed form.
if defaults export "$domain" - 2>/dev/null |
  python3 -c 'import plistlib,sys; d=plistlib.loads(sys.stdin.buffer.read()); sys.exit(0 if d.get("holdShortcut")=="⌘" else 1)'; then
  echo "skip alttab holdShortcut"
  exit 0
fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  log_dry "set alttab holdShortcut ⌘"
  exit 0
fi
defaults write "$domain" holdShortcut -string "⌘"
echo "set alttab holdShortcut ⌘ (restart AltTab to apply)"
