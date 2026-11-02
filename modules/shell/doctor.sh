#!/usr/bin/env bash
# ~/.profile and ~/.bashrc load the shared environment on their first line.
set -euo pipefail
# shellcheck disable=SC1091
source "$DOTFILES_DIR/lib/shell.sh"
rc=0
for f in .profile .bashrc; do
  if [ "$(head -1 "$HOME/$f" 2>/dev/null)" != "$(shell_env_line)" ]; then
    echo "$HOME/$f does not load env.sh first (dots install)"
    rc=1
  fi
done
exit "$rc"
