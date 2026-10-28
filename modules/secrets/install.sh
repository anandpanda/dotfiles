#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../../lib/secrets.sh
source "$DOTFILES_DIR/lib/secrets.sh"
d="$(secrets_dir)"
if [ -d "$d" ]; then
  echo "skip $d"
elif [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry] mkdir $d (mode 700)"
else
  mkdir -p "$d" && chmod 700 "$d" && echo "mkdir $d"
fi
missing="$(secrets_missing)"
if [ -n "$missing" ]; then
  echo "missing secrets (create files under $d):"
  while IFS= read -r line; do echo "  $line"; done <<<"$missing"
fi
