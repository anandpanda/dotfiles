#!/usr/bin/env bash
# bash and sh load the shared environment: the first line of ~/.profile and ~/.bashrc
# sources it, ahead of any "return when not interactive" guard.
set -euo pipefail
for f in log file shell; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
for f in .profile .bashrc; do file_ensure_first_line "$HOME/$f" "$(shell_env_line)"; done
