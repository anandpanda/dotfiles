#!/usr/bin/env bash
# Create the folders this module lists in contexts/personal and contexts/work, for the
# identities the profile declares only (a work-only machine gets no personal folders).
set -euo pipefail
for f in log profile contexts; do
  # shellcheck disable=SC1090
  source "$DOTFILES_DIR/lib/$f.sh"
done
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for ctx in $(profile_identities "$(contexts_profile)"); do
  list="$here/contexts/$ctx"
  while IFS=$'\t' read -r _ d; do
    if [ -d "$d" ]; then
      echo "skip $d"
    elif [ "${DRY_RUN:-0}" = 1 ]; then
      echo "[dry] mkdir $d"
    else
      mkdir -p "$d" && echo "mkdir $d"
    fi
  done < <(_contexts_read "$ctx" "$list")
done
