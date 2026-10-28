#!/usr/bin/env bash
# Make ~/.ssh/config include our conf.d. Keys are handled in preflight.sh.
set -euo pipefail
for f in log ssh; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
ssh_ensure_include
