#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title dots doctor
# @raycast.mode fullOutput
# Optional parameters:
# @raycast.icon 🩺
# @raycast.packageName dotfiles
export PATH="/opt/homebrew/bin:$PATH"
exec just --justfile "$HOME/personal/dotfiles/justfile" --working-directory "$HOME/personal/dotfiles" doctor
