#!/usr/bin/env bash
# Create the folders this module lists in contexts/personal and contexts/work.
set -euo pipefail
for f in log profile contexts; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for list in "$here"/contexts/*; do
  while IFS=$'\t' read -r _ d; do
    if [ -d "$d" ]; then
      echo "skip $d"
    elif [ "${DRY_RUN:-0}" = 1 ]; then
      echo "[dry] mkdir $d"
    else
      mkdir -p "$d" && echo "mkdir $d"
    fi
  done < <(_contexts_read "$(basename "$list")" "$list")
done
