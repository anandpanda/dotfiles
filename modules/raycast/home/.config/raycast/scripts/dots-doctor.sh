#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title dots doctor
# @raycast.mode fullOutput
# Optional parameters:
# @raycast.icon 🩺
# @raycast.packageName dotfiles
# Raycast runs scripts with a bare PATH (no Homebrew); find the checkout through this script's own link.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
self="$(readlink "$0" || echo "$0")"
d="$(cd "$(dirname "$self")" && pwd -P)"
DOTFILES_DIR="${d%/modules/raycast/*}"
exec just --justfile "$DOTFILES_DIR/justfile" --working-directory "$DOTFILES_DIR" doctor
